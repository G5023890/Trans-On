import Foundation

struct LocalTranslationStatus {
    let ready: Bool
    let summary: String
    let detail: String
    let cacheBytes: Int64
}

struct LocalTranslationBatchResult {
    let texts: [String]
    let status: LocalTranslationStatus
}

final class LocalTranslationClient {
    static let shared = LocalTranslationClient()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func fetchStatus() async -> LocalTranslationStatus {
        do {
            let response = try await perform(action: .status, texts: nil)
            return response.localStatus
        } catch {
            return LocalTranslationStatus(
                ready: false,
                summary: "Local helper unavailable",
                detail: error.localizedDescription,
                cacheBytes: 0
            )
        }
    }

    func prepareModels() async -> LocalTranslationStatus {
        do {
            let response = try await perform(action: .prepare, texts: nil)
            return response.localStatus
        } catch {
            return LocalTranslationStatus(
                ready: false,
                summary: "Local helper failed",
                detail: error.localizedDescription,
                cacheBytes: 0
            )
        }
    }

    func translateBatch(texts: [String]) async throws -> LocalTranslationBatchResult {
        let response = try await perform(action: .translate, texts: texts)
        guard response.ok else {
            throw LocalTranslationError.helperFailure(response.error ?? "Local helper returned an unknown error.")
        }

        return LocalTranslationBatchResult(texts: response.texts ?? [], status: response.localStatus)
    }

    private func perform(action: LocalTranslationAction, texts: [String]?) async throws -> LocalTranslationResponse {
        guard let helperURL = helperExecutableURL else {
            throw LocalTranslationError.helperMissing
        }

        let request = LocalTranslationRequest(action: action, texts: texts)
        let requestData = try encoder.encode(request)

        let process = Process()
        process.executableURL = helperURL

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        inputPipe.fileHandleForWriting.write(requestData)
        inputPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard !outputData.isEmpty else {
            let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrMessage = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let stderrMessage, !stderrMessage.isEmpty {
                throw LocalTranslationError.helperFailure(stderrMessage)
            }
            throw LocalTranslationError.helperFailure("Local helper produced no output.")
        }

        do {
            return try decoder.decode(LocalTranslationResponse.self, from: outputData)
        } catch {
            throw LocalTranslationError.decodeFailure
        }
    }

    private var helperExecutableURL: URL? {
        let bundleURL = Bundle.main.bundleURL
        let direct = bundleURL.appendingPathComponent("Contents/MacOS/TransOnTranslationHelper")
        if FileManager.default.isExecutableFile(atPath: direct.path) {
            return direct
        }

        let fallback = bundleURL.appendingPathComponent("Contents/Helpers/TransOnTranslationHelper")
        if FileManager.default.isExecutableFile(atPath: fallback.path) {
            return fallback
        }

        return nil
    }
}

enum LocalTranslationError: LocalizedError {
    case helperMissing
    case helperFailure(String)
    case decodeFailure

    var errorDescription: String? {
        switch self {
        case .helperMissing:
            return "Local translation helper is missing from the app bundle."
        case .helperFailure(let message):
            return message
        case .decodeFailure:
            return "Local translation helper returned malformed JSON."
        }
    }
}

private enum LocalTranslationAction: String, Codable {
    case status
    case prepare
    case translate
}

private struct LocalTranslationRequest: Codable {
    let action: LocalTranslationAction
    let texts: [String]?
}

private struct LocalTranslationResponse: Codable {
    let ok: Bool
    let texts: [String]?
    let status: LocalTranslationStatusPayload
    let error: String?
}

private struct LocalTranslationStatusPayload: Codable {
    let ready: Bool
    let summary: String
    let detail: String
    let cacheBytes: Int64
}

private extension LocalTranslationStatus {
    init(payload: LocalTranslationStatusPayload) {
        self.init(
            ready: payload.ready,
            summary: payload.summary,
            detail: payload.detail,
            cacheBytes: payload.cacheBytes
        )
    }
}

private extension LocalTranslationResponse {
    var localStatus: LocalTranslationStatus {
        LocalTranslationStatus(payload: status)
    }
}
