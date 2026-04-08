import Foundation
import NaturalLanguage

TransOnTranslationHelperMain().run()

private final class TransOnTranslationHelperMain {
    func run() {
        let semaphore = DispatchSemaphore(value: 0)
        Task(priority: .userInitiated) {
            await self.runAsync()
            semaphore.signal()
        }
        semaphore.wait()
    }

    private func runAsync() async {
        let manager = LocalOpusMtManager()

        do {
            let request = try Request.read()
            let response: Response

            switch request.action {
            case .status:
                response = try await manager.statusResponse()
            case .prepare:
                response = try await manager.prepareResponse()
            case .translate:
                response = try await manager.translateResponse(texts: request.texts ?? [])
            }

            try response.write()
        } catch {
            let fallbackStatus = await manager.currentStatus()
            let response = Response(
                ok: false,
                texts: nil,
                status: fallbackStatus,
                error: error.localizedDescription
            )
            try? response.write()
            fputs("[TransOnTranslationHelper] \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

private enum RequestAction: String, Codable {
    case status
    case prepare
    case translate
}

private struct Request: Codable {
    let action: RequestAction
    let texts: [String]?

    static func read() throws -> Request {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard !data.isEmpty else {
            return Request(action: .status, texts: nil)
        }
        return try JSONDecoder.transOn.decode(Request.self, from: data)
    }
}

private struct Response: Codable {
    let ok: Bool
    let texts: [String]?
    let status: StatusPayload
    let error: String?

    func write() throws {
        let data = try JSONEncoder.transOn.encode(self)
        FileHandle.standardOutput.write(data)
    }
}

private struct StatusPayload: Codable {
    let ready: Bool
    let summary: String
    let detail: String
    let cacheBytes: Int64
}

private struct TranslationItem: Codable {
    let text: String
    let source: String?
}

private struct TranslationRequest: Codable {
    let items: [TranslationItem]
    let modelsRoot: String
}

private struct TranslationResult: Codable {
    let ok: Bool
    let texts: [String]?
    let error: String?
}

private struct ModelCatalogEntry: Codable {
    let id: String
    let source: String
    let target: String
    let version: String
    let url: String

    var archiveFilename: String {
        "\(id)-\(version).zip"
    }
}

private struct InstalledModelRecord: Codable {
    let id: String
    let version: String
    let remoteETag: String?
    let archiveSHA256: String?
    let modelBytes: Int64
    let installedAt: Date
}

private struct StateFile: Codable {
    var schemaVersion: Int
    var installedModels: [InstalledModelRecord]
    var bootstrapVersion: String?
}

private final class LocalOpusMtManager {
    private let fileManager = FileManager.default
    private let urlSession = URLSession(configuration: .ephemeral)
    private let encoder = JSONEncoder.transOn
    private let decoder = JSONDecoder.transOn
    private let bootstrapVersion = "ctranslate2-4.7.1-sentencepiece-0.2.1-sacremoses-0.1.1-subword-nmt-0.3.8-tokenizer-v3"

    private let catalog: [ModelCatalogEntry] = [
        ModelCatalogEntry(
            id: "en-ru",
            source: "en",
            target: "ru",
            version: "opus-2020-02-11",
            url: "https://object.pouta.csc.fi/OPUS-MT-models/en-ru/opus-2020-02-11.zip"
        ),
        ModelCatalogEntry(
            id: "he-en",
            source: "he",
            target: "en",
            version: "opus-2019-12-05",
            url: "https://object.pouta.csc.fi/OPUS-MT-models/he-en/opus-2019-12-05.zip"
        )
    ]

    private var rootDirectory: URL {
        applicationSupportDirectory
            .appendingPathComponent("com.grigorym.TransOn", isDirectory: true)
            .appendingPathComponent("LocalOPUSMT", isDirectory: true)
    }

    private var venvDirectory: URL { rootDirectory.appendingPathComponent("venv", isDirectory: true) }
    private var modelsDirectory: URL { rootDirectory.appendingPathComponent("models", isDirectory: true) }
    private var scriptsDirectory: URL { rootDirectory.appendingPathComponent("scripts", isDirectory: true) }
    private var tempDirectory: URL { rootDirectory.appendingPathComponent("tmp", isDirectory: true) }
    private var stateFileURL: URL { rootDirectory.appendingPathComponent("state.json") }
    private var pythonScriptURL: URL { scriptsDirectory.appendingPathComponent("translate.py") }
    private var bootstrapMarkerURL: URL { rootDirectory.appendingPathComponent("bootstrap.marker") }

    func currentStatus() async -> StatusPayload {
        await ensureRootDirectories()
        let state = loadState()
        let installed = installedModelRecords(from: state)
        let ready = isEnvironmentBootstrapped() && catalog.allSatisfy { model in
            installed[model.id] != nil && hasTokenizerArtifacts(for: convertedModelDirectory(for: model))
        }
        let summary: String
        let detail: String

        if ready {
            summary = "Local OPUS-MT ready"
            detail = "en -> ru direct, he -> en -> ru pivot. Cached models are stored in Application Support."
        } else if !isEnvironmentBootstrapped() {
            summary = "Local OPUS-MT not prepared"
            detail = "Tap Prepare / Update to install ctranslate2 and download the local model cache."
        } else {
            let missing = catalog.map(\.id).filter { modelID in
                guard installed[modelID] != nil else { return true }
                return !hasTokenizerArtifacts(for: convertedModelDirectory(for: catalog.first { $0.id == modelID }!))
            }
            summary = "Missing local models"
            detail = missing.isEmpty ? "Model cache is incomplete." : "Missing: \(missing.joined(separator: ", "))."
        }

        return StatusPayload(
            ready: ready,
            summary: summary,
            detail: detail,
            cacheBytes: directorySize(at: rootDirectory)
        )
    }

    func statusResponse() async throws -> Response {
        let status = await currentStatus()
        return Response(ok: status.ready, texts: nil, status: status, error: nil)
    }

    func prepareResponse() async throws -> Response {
        await ensureRootDirectories()
        try await bootstrapPythonEnvironmentIfNeeded()
        try await ensureModels()
        let status = await currentStatus()
        return Response(ok: status.ready, texts: nil, status: status, error: status.ready ? nil : "Local model cache is not ready.")
    }

    func translateResponse(texts: [String]) async throws -> Response {
        await ensureRootDirectories()
        try await bootstrapPythonEnvironmentIfNeeded()
        try await ensureModels()

        let status = await currentStatus()
        guard status.ready else {
            return Response(ok: false, texts: nil, status: status, error: status.detail)
        }

        let items = texts.map { text -> TranslationItem in
            TranslationItem(text: text, source: detectSourceLanguage(for: text))
        }
        let payload = TranslationRequest(items: items, modelsRoot: modelsDirectory.path)
        let requestData = try encoder.encode(payload)

        let resultData = try await runPythonTranslator(input: requestData)
        let result = try decoder.decode(TranslationResult.self, from: resultData)
        let finalStatus = await currentStatus()
        return Response(ok: result.ok, texts: result.texts, status: finalStatus, error: result.error)
    }

    private func ensureRootDirectories() async {
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: scriptsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    private func bootstrapPythonEnvironmentIfNeeded() async throws {
        guard !isEnvironmentBootstrapped() else { return }

        let python3 = try resolvedPython3URL()
        let createVenv = try runProcess(
            python3,
            arguments: ["-m", "venv", venvDirectory.path]
        )
        guard createVenv.exitCode == 0 else {
            throw HelperError.processFailed("python3 -m venv", createVenv.stderr)
        }

        let venvPython = venvDirectory.appendingPathComponent("bin/python")
        let upgradePip = try runProcess(venvPython, arguments: ["-m", "pip", "install", "--upgrade", "pip"])
        guard upgradePip.exitCode == 0 else {
            throw HelperError.processFailed("pip upgrade", upgradePip.stderr)
        }

        let installPackages = try runProcess(
            venvPython,
            arguments: [
                "-m", "pip", "install",
                "ctranslate2==4.7.1",
                "sentencepiece==0.2.1",
                "sacremoses==0.1.1",
                "subword-nmt==0.3.8"
            ]
        )
        guard installPackages.exitCode == 0 else {
            throw HelperError.processFailed("pip install", installPackages.stderr)
        }

        try writeTranslatorScriptIfNeeded()
        try Data(bootstrapVersion.utf8).write(to: bootstrapMarkerURL, options: [.atomic])
    }

    private func ensureModels() async throws {
        await ensureRootDirectories()

        let state = loadState()
        var updatedState = state
        let existing = installedModelRecords(from: state)
        let converter = venvDirectory.appendingPathComponent("bin/ct2-opus-mt-converter")

        for model in catalog {
            let remote = try await remoteMetadata(for: model.url)
            let needsInstall: Bool
            if let installed = existing[model.id] {
                needsInstall = installed.version != model.version || installed.remoteETag != remote.etag || !fileManager.fileExists(atPath: convertedModelDirectory(for: model).path) || !hasTokenizerArtifacts(for: convertedModelDirectory(for: model))
            } else {
                needsInstall = true
            }

            guard needsInstall else { continue }

            let archiveURL = try await downloadArchive(for: model)
            let extractedDir = tempDirectory.appendingPathComponent(model.id + "-source", isDirectory: true)
            try? fileManager.removeItem(at: extractedDir)
            try fileManager.createDirectory(at: extractedDir, withIntermediateDirectories: true)
            try unzip(archiveURL: archiveURL, destination: extractedDir)

            let outputDir = convertedModelDirectory(for: model)
            try? fileManager.removeItem(at: outputDir)
            try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let convertWithQuantization = try runProcess(
                converter,
                arguments: [
                    "--model_dir", extractedDir.path,
                    "--output_dir", outputDir.path,
                    "--quantization", "int8",
                    "--force"
                ]
            )

            if convertWithQuantization.exitCode != 0 {
                let fallback = try runProcess(
                    converter,
                    arguments: [
                        "--model_dir", extractedDir.path,
                        "--output_dir", outputDir.path,
                        "--force"
                    ]
                )
                guard fallback.exitCode == 0 else {
                    throw HelperError.processFailed("ct2-opus-mt-converter", fallback.stderr.isEmpty ? convertWithQuantization.stderr : fallback.stderr)
                }
            }

            try preserveTokenizerArtifacts(from: extractedDir, to: outputDir)

            let checksum = try sha256(for: archiveURL)
            let bytes = directorySize(at: outputDir)
            let record = InstalledModelRecord(
                id: model.id,
                version: model.version,
                remoteETag: remote.etag,
                archiveSHA256: checksum,
                modelBytes: bytes,
                installedAt: Date()
            )

            updatedState.installedModels.removeAll { $0.id == model.id }
            updatedState.installedModels.append(record)

            try? fileManager.removeItem(at: extractedDir)
            try? fileManager.removeItem(at: archiveURL)
        }

        updatedState.schemaVersion = 1
        updatedState.bootstrapVersion = bootstrapVersion
        saveState(updatedState)
    }

    private func runPythonTranslator(input: Data) async throws -> Data {
        let python = venvDirectory.appendingPathComponent("bin/python")
        let script = pythonScriptURL.path
        let result = try runProcess(
            python,
            arguments: [script],
            input: input
        )
        guard result.exitCode == 0 else {
            throw HelperError.processFailed("translate.py", result.stderr)
        }
        return result.stdout
    }

    private func writeTranslatorScriptIfNeeded() throws {
        if fileManager.fileExists(atPath: pythonScriptURL.path),
           let existing = try? String(contentsOf: pythonScriptURL, encoding: .utf8),
           existing.contains("helper-script-version: 3") {
            return
        }
        let script = """
        # helper-script-version: 3
        import json
        import os
        import re
        import sys

        import ctranslate2
        import sentencepiece as spm
        from sacremoses import MosesDetokenizer, MosesPunctNormalizer, MosesTokenizer
        from subword_nmt.apply_bpe import BPE

        REQUEST = json.load(sys.stdin)
        ITEMS = REQUEST.get("items", [])
        MODELS_ROOT = REQUEST["modelsRoot"]

        EN_RU = os.path.join(MODELS_ROOT, "en-ru")
        HE_EN = os.path.join(MODELS_ROOT, "he-en")

        _translators = {}
        _tokenizers = {}
        _normalizers = {}
        _detokenizers = {}

        def load_model(model_dir):
            if model_dir not in _translators:
                translator = ctranslate2.Translator(model_dir, device="cpu")
                source_spm = os.path.join(model_dir, "source.spm")
                source_bpe = os.path.join(model_dir, "source.bpe")
                if os.path.exists(source_spm):
                    tokenizer = spm.SentencePieceProcessor()
                    tokenizer.load(source_spm)
                    _tokenizers[model_dir] = ("spm", tokenizer)
                elif os.path.exists(source_bpe):
                    with open(source_bpe, "r", encoding="utf-8") as codes:
                        bpe = BPE(codes)
                    _tokenizers[model_dir] = ("bpe", bpe)
                else:
                    raise RuntimeError(f"Missing tokenizer artifacts in {model_dir}.")
                _translators[model_dir] = translator
            return _translators[model_dir], _tokenizers[model_dir]

        def translate(model_dir, text):
            translator, tokenizer = load_model(model_dir)
            tokenizer_kind, tokenizer_impl = tokenizer
            if tokenizer_kind == "spm":
                tokens = tokenizer_impl.encode(text, out_type=str)
            elif tokenizer_kind == "bpe":
                language = "en"
                if os.path.basename(model_dir) == "he-en":
                    language = "he"
                normalizer = _normalizers.get(language)
                if normalizer is None:
                    normalizer = MosesPunctNormalizer(lang=language)
                    _normalizers[language] = normalizer
                moses_tokenizer = MosesTokenizer(lang=language)
                detokenizer = _detokenizers.get(language)
                if detokenizer is None:
                    detokenizer = MosesDetokenizer(lang=language)
                    _detokenizers[language] = detokenizer
                normalized = normalizer.normalize(text)
                pretokenized = moses_tokenizer.tokenize(normalized, return_str=True)
                tokens = tokenizer_impl.process_line(pretokenized).split()
            else:
                raise RuntimeError(f"Unsupported tokenizer kind: {tokenizer_kind}")
            results = translator.translate_batch([tokens], beam_size=4)
            if tokenizer_kind == "spm":
                decoded = tokenizer_impl.decode(results[0].hypotheses[0])
                decoded = decoded.replace("▁", " ")
                return re.sub(r"\\s+", " ", decoded).strip()

            detokenized = " ".join(results[0].hypotheses[0])
            detokenized = detokenized.replace("@@ ", "").replace(" @@ ", "").replace(" @-@ ", "-")
            detokenized = detokenized.replace("▁", " ").strip()
            return _detokenizers[language].detokenize(detokenized.split())

        def detect_source(item):
            source = item.get("source")
            if source in ("en", "he"):
                return source

            text = item.get("text", "")
            if re.search(r"[\\u0590-\\u05FF]", text):
                return "he"
            if re.search(r"[A-Za-z]", text):
                return "en"
            return None

        translated = []
        for item in ITEMS:
            text = item.get("text", "")
            source = detect_source(item)
            if source is None:
                print(json.dumps({"ok": False, "error": "Unsupported source language.", "texts": translated}), file=sys.stdout)
                sys.exit(2)

            if source == "en":
                translated.append(translate(EN_RU, text))
            elif source == "he":
                pivot = translate(HE_EN, text)
                translated.append(translate(EN_RU, pivot))

        print(json.dumps({"ok": True, "texts": translated}), file=sys.stdout)
        """
        guard let scriptData = script.data(using: .utf8) else {
            throw HelperError.processFailed("writeTranslatorScriptIfNeeded", "Unable to encode translator script.")
        }
        try scriptData.write(to: pythonScriptURL, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: pythonScriptURL.path)
    }

    private func writeState(_ state: StateFile) throws {
        let data = try encoder.encode(state)
        try data.write(to: stateFileURL, options: [.atomic])
    }

    private func saveState(_ state: StateFile) {
        try? writeState(state)
    }

    private func loadState() -> StateFile {
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? decoder.decode(StateFile.self, from: data) else {
            return StateFile(schemaVersion: 1, installedModels: [], bootstrapVersion: nil)
        }
        return state
    }

    private func installedModelRecords(from state: StateFile) -> [String: InstalledModelRecord] {
        Dictionary(uniqueKeysWithValues: state.installedModels.map { ($0.id, $0) })
    }

    private func isEnvironmentBootstrapped() -> Bool {
        let python = venvDirectory.appendingPathComponent("bin/python")
        guard fileManager.fileExists(atPath: python.path),
              fileManager.fileExists(atPath: pythonScriptURL.path),
              let marker = try? String(contentsOf: bootstrapMarkerURL, encoding: .utf8) else {
            return false
        }
        return marker.trimmingCharacters(in: .whitespacesAndNewlines) == bootstrapVersion
    }

    private func convertedModelDirectory(for model: ModelCatalogEntry) -> URL {
        modelsDirectory.appendingPathComponent(model.id, isDirectory: true)
    }

    private func preserveTokenizerArtifacts(from sourceDir: URL, to destinationDir: URL) throws {
        let artifacts = [
            "source.spm",
            "source.bpe",
            "source.tcmodel"
        ]

        for artifact in artifacts {
            let sourceURL = sourceDir.appendingPathComponent(artifact)
            guard fileManager.fileExists(atPath: sourceURL.path) else { continue }

            let destinationURL = destinationDir.appendingPathComponent(artifact)
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    private func hasTokenizerArtifacts(for modelDir: URL) -> Bool {
        fileManager.fileExists(atPath: modelDir.appendingPathComponent("source.spm").path)
            || fileManager.fileExists(atPath: modelDir.appendingPathComponent("source.bpe").path)
    }

    private func remoteMetadata(for urlString: String) async throws -> RemoteMetadata {
        guard let url = URL(string: urlString) else {
            throw HelperError.invalidURL(urlString)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HelperError.processFailed("HEAD", "No HTTP response returned.")
        }
        let etag = http.value(forHTTPHeaderField: "ETag")?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return RemoteMetadata(etag: etag, contentLength: http.expectedContentLength)
    }

    private func downloadArchive(for model: ModelCatalogEntry) async throws -> URL {
        guard let url = URL(string: model.url) else {
            throw HelperError.invalidURL(model.url)
        }
        let archiveURL = tempDirectory.appendingPathComponent(model.archiveFilename)
        try? fileManager.removeItem(at: archiveURL)
        let (downloadedURL, response) = try await urlSession.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HelperError.processFailed("download", "Unexpected response while downloading \(model.id).")
        }
        try? fileManager.removeItem(at: archiveURL)
        try fileManager.moveItem(at: downloadedURL, to: archiveURL)
        return archiveURL
    }

    private func unzip(archiveURL: URL, destination: URL) throws {
        let result = try runProcess(
            URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-x", "-k", archiveURL.path, destination.path]
        )
        guard result.exitCode == 0 else {
            throw HelperError.processFailed("ditto", result.stderr)
        }
    }

    private func detectSourceLanguage(for text: String) -> String? {
        if text.range(of: #"[\u0590-\u05FF]"#, options: .regularExpression) != nil {
            return "he"
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        if let englishScore = hypotheses[.english], englishScore >= 0.7 {
            return "en"
        }
        if let hebrewScore = hypotheses[.hebrew], hebrewScore >= 0.7 {
            return "he"
        }

        if let dominant = recognizer.dominantLanguage {
            switch dominant {
            case .english:
                return "en"
            case .hebrew:
                return "he"
            default:
                break
            }
        }

        if text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil,
           text.unicodeScalars.allSatisfy({ $0.isASCII }) {
            return "en"
        }

        return nil
    }

    private func resolvedPython3URL() throws -> URL {
        if let url = ProcessInfo.processInfo.environment["PYTHON3"], !url.isEmpty {
            return URL(fileURLWithPath: url)
        }

        let candidates = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/opt/local/bin/python3",
            "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3"
        ]
        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        throw HelperError.processFailed("python3", "Unable to locate python3.")
    }

    private func runProcess(_ executableURL: URL, arguments: [String], input: Data? = nil) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let input {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            try process.run()
            stdinPipe.fileHandleForWriting.write(input)
            stdinPipe.fileHandleForWriting.closeFile()
        } else {
            try process.run()
        }

        process.waitUntilExit()

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: String(data: stderr, encoding: .utf8) ?? "")
    }

    private func sha256(for url: URL) throws -> String {
        let result = try runProcess(
            URL(fileURLWithPath: "/usr/bin/shasum"),
            arguments: ["-a", "256", url.path]
        )
        guard result.exitCode == 0 else {
            throw HelperError.processFailed("shasum", result.stderr)
        }

        let output = String(data: result.stdout, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output
            .split(separator: " ")
            .first
            .map(String.init) ?? ""
    }

    private func directorySize(at url: URL) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    private var applicationSupportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
    }
}

private struct RemoteMetadata {
    let etag: String?
    let contentLength: Int64
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: Data
    let stderr: String
}

private enum HelperError: LocalizedError {
    case invalidURL(String)
    case processFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid URL: \(value)"
        case .processFailed(let step, let output):
            if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(step) failed."
            }
            return "\(step) failed: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}

private extension JSONEncoder {
    static var transOn: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var transOn: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension FileManager {
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories, attributes: nil)
    }
}
