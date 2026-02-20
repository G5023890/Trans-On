import AppKit
import Carbon.HIToolbox
import Security
import ServiceManagement

struct HotKeyChoice {
    let title: String
    let keyCode: UInt32

    static let all: [HotKeyChoice] = [
        .init(title: "A", keyCode: UInt32(kVK_ANSI_A)),
        .init(title: "B", keyCode: UInt32(kVK_ANSI_B)),
        .init(title: "C", keyCode: UInt32(kVK_ANSI_C)),
        .init(title: "D", keyCode: UInt32(kVK_ANSI_D)),
        .init(title: "E", keyCode: UInt32(kVK_ANSI_E)),
        .init(title: "F", keyCode: UInt32(kVK_ANSI_F)),
        .init(title: "G", keyCode: UInt32(kVK_ANSI_G)),
        .init(title: "H", keyCode: UInt32(kVK_ANSI_H)),
        .init(title: "I", keyCode: UInt32(kVK_ANSI_I)),
        .init(title: "J", keyCode: UInt32(kVK_ANSI_J)),
        .init(title: "K", keyCode: UInt32(kVK_ANSI_K)),
        .init(title: "L", keyCode: UInt32(kVK_ANSI_L)),
        .init(title: "M", keyCode: UInt32(kVK_ANSI_M)),
        .init(title: "N", keyCode: UInt32(kVK_ANSI_N)),
        .init(title: "O", keyCode: UInt32(kVK_ANSI_O)),
        .init(title: "P", keyCode: UInt32(kVK_ANSI_P)),
        .init(title: "Q", keyCode: UInt32(kVK_ANSI_Q)),
        .init(title: "R", keyCode: UInt32(kVK_ANSI_R)),
        .init(title: "S", keyCode: UInt32(kVK_ANSI_S)),
        .init(title: "T", keyCode: UInt32(kVK_ANSI_T)),
        .init(title: "U", keyCode: UInt32(kVK_ANSI_U)),
        .init(title: "V", keyCode: UInt32(kVK_ANSI_V)),
        .init(title: "W", keyCode: UInt32(kVK_ANSI_W)),
        .init(title: "X", keyCode: UInt32(kVK_ANSI_X)),
        .init(title: "Y", keyCode: UInt32(kVK_ANSI_Y)),
        .init(title: "Z", keyCode: UInt32(kVK_ANSI_Z))
    ]
}

enum TranslationProvider: Int {
    case webGtx = 0
    case googleCloud = 1
    case argos = 2

    var title: String {
        switch self {
        case .webGtx:
            return "Google Web (gtx)"
        case .googleCloud:
            return "Google Cloud API"
        case .argos:
            return "Argos (offline)"
        }
    }
}

final class KeychainStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func upsert(value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }

        return false
    }

    @discardableResult
    func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private let keychain = KeychainStore(service: "com.grigorym.SelectedTextOverlay")
    private let hotKeyCodeKey = "hotKeyCode"
    private let hotKeyModifiersKey = "hotKeyModifiers"
    private let fontSizeKey = "fontSize"
    private let launchAtLoginKey = "launchAtLogin"
    private let translationProviderKey = "translationProvider"
    private let legacyGoogleCloudApiKeyKey = "googleCloudApiKey"
    private let googleCloudApiKeyAccount = "googleCloudApiKey"
    private let argosDirectHeRuInstalledKey = "argosDirectHeRuInstalled"
    private let argosLastPackageCheckAtKey = "argosLastPackageCheckAt"
    private let argosLastPackageCheckSummaryKey = "argosLastPackageCheckSummary"

    private(set) var hotKeyCode: UInt32
    private(set) var hotKeyModifiers: UInt32
    private(set) var fontSize: CGFloat
    private(set) var launchAtLogin: Bool
    private(set) var translationProvider: TranslationProvider
    private(set) var googleCloudApiKey: String
    private(set) var argosDirectHeRuInstalled: Bool
    private(set) var argosLastPackageCheckAt: Date?
    private(set) var argosLastPackageCheckSummary: String

    private init() {
        let defaultCode = UInt32(kVK_ANSI_L)
        let defaultModifiers = UInt32(cmdKey | shiftKey)

        let storedCode = defaults.object(forKey: hotKeyCodeKey) as? Int
        let storedModifiers = defaults.object(forKey: hotKeyModifiersKey) as? Int
        let storedFont = defaults.object(forKey: fontSizeKey) as? Double

        hotKeyCode = UInt32(storedCode ?? Int(defaultCode))
        hotKeyModifiers = UInt32(storedModifiers ?? Int(defaultModifiers))
        fontSize = CGFloat(storedFont ?? 22)
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
        translationProvider = TranslationProvider(rawValue: defaults.integer(forKey: translationProviderKey)) ?? .webGtx
        argosDirectHeRuInstalled = defaults.bool(forKey: argosDirectHeRuInstalledKey)
        if let timestamp = defaults.object(forKey: argosLastPackageCheckAtKey) as? TimeInterval {
            argosLastPackageCheckAt = Date(timeIntervalSince1970: timestamp)
        } else {
            argosLastPackageCheckAt = nil
        }
        argosLastPackageCheckSummary = defaults.string(forKey: argosLastPackageCheckSummaryKey) ?? ""
        let keychainValue = keychain.read(account: googleCloudApiKeyAccount)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !keychainValue.isEmpty {
            googleCloudApiKey = keychainValue
        } else {
            let legacy = defaults.string(forKey: legacyGoogleCloudApiKeyKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !legacy.isEmpty {
                _ = keychain.upsert(value: legacy, account: googleCloudApiKeyAccount)
                defaults.removeObject(forKey: legacyGoogleCloudApiKeyKey)
            }
            googleCloudApiKey = legacy
        }
    }

    func setHotKey(code: UInt32, modifiers: UInt32) {
        hotKeyCode = code
        hotKeyModifiers = modifiers
        defaults.set(Int(code), forKey: hotKeyCodeKey)
        defaults.set(Int(modifiers), forKey: hotKeyModifiersKey)
    }

    func setFontSize(_ newValue: CGFloat) {
        let clamped = min(max(newValue, 12), 56)
        fontSize = clamped
        defaults.set(Double(clamped), forKey: fontSizeKey)
    }

    func setLaunchAtLogin(_ newValue: Bool) {
        launchAtLogin = newValue
        defaults.set(newValue, forKey: launchAtLoginKey)
    }

    func setTranslationProvider(_ provider: TranslationProvider) {
        translationProvider = provider
        defaults.set(provider.rawValue, forKey: translationProviderKey)
    }

    func setGoogleCloudApiKey(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        googleCloudApiKey = trimmed
        defaults.removeObject(forKey: legacyGoogleCloudApiKeyKey)
        if trimmed.isEmpty {
            _ = keychain.delete(account: googleCloudApiKeyAccount)
            return
        }
        let saved = keychain.upsert(value: trimmed, account: googleCloudApiKeyAccount)
        if !saved {
            NSLog("Failed to save Google Cloud API key to Keychain.")
        }
    }

    func updateArgosPackageStatus(directHeRuInstalled: Bool?, summary: String) {
        if let directHeRuInstalled {
            argosDirectHeRuInstalled = directHeRuInstalled
            defaults.set(directHeRuInstalled, forKey: argosDirectHeRuInstalledKey)
        }

        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        argosLastPackageCheckSummary = trimmedSummary
        defaults.set(trimmedSummary, forKey: argosLastPackageCheckSummaryKey)

        let now = Date()
        argosLastPackageCheckAt = now
        defaults.set(now.timeIntervalSince1970, forKey: argosLastPackageCheckAtKey)
    }
}

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class EscapeTextView: NSTextView {
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

final class OverlayView: NSView {
    private let textView = EscapeTextView()
    private let scrollView = NSScrollView()
    private let loadingContainer = NSView()
    private let loadingIndicator = NSProgressIndicator()
    private let loadingLabel = NSTextField(labelWithString: "Идет перевод")
    private var loadingTimer: Timer?
    private var loadingBaseMessage = "Идет перевод"
    private var loadingDotFrame = 0
    var onEscape: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        layer?.cornerRadius = 18
        layer?.masksToBounds = true

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .white
        textView.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        textView.alignment = .left
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.onEscape = { [weak self] in
            self?.onEscape?()
        }

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.wantsLayer = false
        loadingContainer.isHidden = true

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .regular
        loadingIndicator.isDisplayedWhenStopped = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        loadingLabel.textColor = .white
        loadingLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        loadingLabel.alignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingContainer.addSubview(loadingIndicator)
        loadingContainer.addSubview(loadingLabel)

        addSubview(scrollView)
        addSubview(loadingContainer)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            loadingContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            loadingContainer.topAnchor.constraint(equalTo: topAnchor),
            loadingContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingContainer.centerYAnchor, constant: -12),

            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 14),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: loadingContainer.leadingAnchor, constant: 20),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingContainer.trailingAnchor, constant: -20)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func updateText(_ text: String) {
        stopLoadingAnimation()
        loadingIndicator.stopAnimation(nil)
        loadingContainer.isHidden = true
        scrollView.isHidden = false
        textView.string = text
        textView.scrollToBeginningOfDocument(nil)
        window?.makeFirstResponder(textView)
    }

    func showLoading(message: String) {
        startLoadingAnimation(message: message)
        scrollView.isHidden = true
        loadingContainer.isHidden = false
        loadingIndicator.startAnimation(nil)
    }

    private func startLoadingAnimation(message: String) {
        loadingBaseMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if loadingBaseMessage.isEmpty {
            loadingBaseMessage = "Идет перевод"
        }
        loadingDotFrame = 0
        loadingLabel.stringValue = loadingBaseMessage
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.loadingDotFrame = (self.loadingDotFrame + 1) % 4
            self.loadingLabel.stringValue = self.loadingBaseMessage + String(repeating: ".", count: self.loadingDotFrame)
        }
        RunLoop.main.add(loadingTimer!, forMode: .common)
    }

    private func stopLoadingAnimation() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingDotFrame = 0
    }

    func setFontSize(_ size: CGFloat) {
        textView.font = NSFont.systemFont(ofSize: size, weight: .medium)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

final class OverlayController {
    private let panel: OverlayPanel
    private let content: OverlayView

    init() {
        let rect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 700)
        let width = min(1000, rect.width * 0.8)
        let height = min(500, rect.height * 0.5)
        let origin = NSPoint(x: rect.midX - width / 2, y: rect.midY - height / 2)

        panel = OverlayPanel(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .none

        content = OverlayView(frame: panel.contentView?.bounds ?? .zero)
        content.autoresizingMask = [.width, .height]
        content.onEscape = { [weak panel] in
            panel?.orderOut(nil)
        }
        panel.contentView = content
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 18
        panel.contentView?.layer?.masksToBounds = true
    }

    func show(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }
        content.updateText(text)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func showLoading(message: String) {
        content.showLoading(message: message)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func setFontSize(_ size: CGFloat) {
        content.setFontSize(size)
    }
}

final class SelectionService {
    private struct ClipboardTextSnapshot {
        let plain: String?
        let rtf: Data?
        let html: String?

        var isEmpty: Bool {
            plain == nil && rtf == nil && html == nil
        }
    }

    private let pasteboard = NSPasteboard.general
    private var isFetchingSelection = false

    func fetchSelectedText(completion: @escaping (String?) -> Void) {
        guard !isFetchingSelection else {
            NSSound.beep()
            return
        }

        isFetchingSelection = true
        let snapshot = captureTextSnapshot()
        let initialChangeCount = pasteboard.changeCount

        sendCopyShortcut()

        pollForClipboardChange(initialChangeCount: initialChangeCount, attempts: 12) { [weak self] text in
            guard let self else {
                completion(text)
                return
            }

            self.restoreTextSnapshot(snapshot)
            self.isFetchingSelection = false
            completion(text)
        }
    }

    private func captureTextSnapshot() -> ClipboardTextSnapshot {
        ClipboardTextSnapshot(
            plain: pasteboard.string(forType: .string),
            rtf: pasteboard.data(forType: .rtf),
            html: pasteboard.string(forType: .html)
        )
    }

    private func restoreTextSnapshot(_ snapshot: ClipboardTextSnapshot) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }

        let item = NSPasteboardItem()
        var hasContent = false

        if let plain = snapshot.plain {
            hasContent = item.setString(plain, forType: .string) || hasContent
        }

        if let rtf = snapshot.rtf {
            hasContent = item.setData(rtf, forType: .rtf) || hasContent
        }

        if let html = snapshot.html {
            hasContent = item.setString(html, forType: .html) || hasContent
        }

        guard hasContent else { return }
        pasteboard.writeObjects([item])
    }

    private func pollForClipboardChange(initialChangeCount: Int, attempts: Int, completion: @escaping (String?) -> Void) {
        if pasteboard.changeCount != initialChangeCount {
            completion(pasteboard.string(forType: .string))
            return
        }

        guard attempts > 0 else {
            completion(nil)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.pollForClipboardChange(initialChangeCount: initialChangeCount, attempts: attempts - 1, completion: completion)
        }
    }

    private func sendCopyShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeC: CGKeyCode = 8

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeC, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeC, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}

final class TranslationService {
    private struct ParagraphItem {
        let index: Int
        let text: String
    }

    private enum Segment {
        case paragraph(Int)
        case separator(String)
    }

    struct ArgosPackageSyncResult {
        let success: Bool
        let directHeRuInstalled: Bool?
        let summary: String
    }

    private struct ArgosPackageSyncPayload {
        let ok: Bool
        let directAfter: Bool
        let directAvailableCount: Int
        let installedNow: Bool
        let updatedPairs: [String]
        let warnings: [String]
        let fatalError: String
    }

    private let settings: AppSettings
    private let session: URLSession
    private let workerQueue = DispatchQueue(label: "transon.translation.worker", qos: .userInitiated)
    private let maintenanceQueue = DispatchQueue(label: "transon.translation.maintenance", qos: .utility)
    private let argosCliPath = "\(NSHomeDirectory())/Library/Application Support/ArgosTranslate/bin/argos-translate"
    private let argosBasePath = "\(NSHomeDirectory())/Library/Application Support/ArgosTranslate"
    private let maxChunkChars = 1800
    private let maxBatchParagraphs = 6
    private let maxRetries = 3

    init(settings: AppSettings) {
        self.settings = settings
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    func checkAndUpdateArgosPackages(completion: @escaping (ArgosPackageSyncResult) -> Void) {
        maintenanceQueue.async {
            guard FileManager.default.isExecutableFile(atPath: self.argosCliPath) else {
                DispatchQueue.main.async {
                    completion(
                        ArgosPackageSyncResult(
                            success: false,
                            directHeRuInstalled: nil,
                            summary: "Argos CLI не найден или не исполняемый: \(self.argosCliPath)"
                        )
                    )
                }
                return
            }

            let pythonPath = "/usr/bin/python3"
            guard FileManager.default.isExecutableFile(atPath: pythonPath) else {
                DispatchQueue.main.async {
                    completion(
                        ArgosPackageSyncResult(
                            success: false,
                            directHeRuInstalled: nil,
                            summary: "Не найден интерпретатор Python: \(pythonPath)"
                        )
                    )
                }
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-c", Self.argosPackageSyncPythonScript]

            var env = ProcessInfo.processInfo.environment
            env["ARGOS_PACKAGES_DIR"] = env["ARGOS_PACKAGES_DIR"] ?? "\(self.argosBasePath)/packages"
            let pythonLibPath = "\(self.argosBasePath)/python_lib"
            if let currentPythonPath = env["PYTHONPATH"], !currentPythonPath.isEmpty {
                env["PYTHONPATH"] = "\(pythonLibPath):\(currentPythonPath)"
            } else {
                env["PYTHONPATH"] = pythonLibPath
            }
            process.environment = env

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    completion(
                        ArgosPackageSyncResult(
                            success: false,
                            directHeRuInstalled: nil,
                            summary: "Не удалось запустить проверку Argos: \(error.localizedDescription)"
                        )
                    )
                }
                return
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputText = String(data: outputData, encoding: .utf8) ?? ""
            let errorText = String(data: errorData, encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                let trimmedError = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    completion(
                        ArgosPackageSyncResult(
                            success: false,
                            directHeRuInstalled: nil,
                            summary: "Проверка Argos завершилась с кодом \(process.terminationStatus).\n\(trimmedError.prefix(300))"
                        )
                    )
                }
                return
            }

            guard let payload = Self.parseArgosPackageSyncPayload(from: outputText) else {
                let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    completion(
                        ArgosPackageSyncResult(
                            success: false,
                            directHeRuInstalled: nil,
                            summary: "Не удалось разобрать ответ Argos.\n\(trimmedOutput.prefix(300))"
                        )
                    )
                }
                return
            }

            let summary = Self.makeArgosPackageSyncSummary(from: payload, stderr: errorText)
            let result = ArgosPackageSyncResult(
                success: payload.ok,
                directHeRuInstalled: payload.ok ? payload.directAfter : nil,
                summary: summary
            )

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func translateToRussian(_ text: String, completion: @escaping (String?) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let provider = settings.translationProvider
        guard !trimmed.isEmpty else {
            completion(nil)
            return
        }

        if shouldSkipTranslation(trimmed) {
            completion(trimmed)
            return
        }

        workerQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(trimmed) }
                return
            }

            let (segments, paragraphs) = self.extractParagraphs(from: trimmed)
            let translatable = paragraphs.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let chunks = self.makeChunks(from: translatable, maxChars: self.maxChunkChars, maxParagraphs: self.maxBatchParagraphs)

            guard !chunks.isEmpty else {
                DispatchQueue.main.async { completion(trimmed) }
                return
            }

            self.translateChunks(chunks, at: 0, provider: provider, translatedByParagraph: [:]) { translatedByParagraph in
                let merged = self.reassemble(segments: segments, paragraphs: paragraphs, translatedByParagraph: translatedByParagraph)
                DispatchQueue.main.async {
                    completion(merged ?? trimmed)
                }
            }
        }
    }

    private func extractParagraphs(from text: String) -> ([Segment], [ParagraphItem]) {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let separatorRegex = try? NSRegularExpression(pattern: #"\n\s*\n+"#)
        let matches = separatorRegex?.matches(in: text, options: [], range: fullRange) ?? []

        var segments: [Segment] = []
        var paragraphs: [ParagraphItem] = []
        var cursor = 0

        for match in matches {
            let paragraphRange = NSRange(location: cursor, length: match.range.location - cursor)
            let paragraph = nsText.substring(with: paragraphRange)
            let paragraphIndex = paragraphs.count
            paragraphs.append(ParagraphItem(index: paragraphIndex, text: paragraph))
            segments.append(.paragraph(paragraphIndex))

            let separator = nsText.substring(with: match.range)
            segments.append(.separator(separator))
            cursor = match.range.location + match.range.length
        }

        let tailRange = NSRange(location: cursor, length: nsText.length - cursor)
        let tail = nsText.substring(with: tailRange)
        let tailIndex = paragraphs.count
        paragraphs.append(ParagraphItem(index: tailIndex, text: tail))
        segments.append(.paragraph(tailIndex))

        return (segments, paragraphs)
    }

    private func makeChunks(from paragraphs: [ParagraphItem], maxChars: Int, maxParagraphs: Int) -> [[ParagraphItem]] {
        var result: [[ParagraphItem]] = []
        var current: [ParagraphItem] = []
        var currentChars = 0

        for paragraph in paragraphs {
            let chars = paragraph.text.count
            if current.isEmpty {
                current = [paragraph]
                currentChars = chars
                continue
            }

            if currentChars + chars <= maxChars && current.count < maxParagraphs {
                current.append(paragraph)
                currentChars += chars
            } else {
                result.append(current)
                current = [paragraph]
                currentChars = chars
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }

    private func translateChunks(
        _ chunks: [[ParagraphItem]],
        at index: Int,
        provider: TranslationProvider,
        translatedByParagraph: [Int: String],
        completion: @escaping ([Int: String]) -> Void
    ) {
        guard index < chunks.count else {
            completion(translatedByParagraph)
            return
        }

        let chunk = chunks[index]
        translateChunkWithRetry(chunk, provider: provider, attempt: 1) { [weak self] translated in
            guard let self else {
                completion(translatedByParagraph)
                return
            }

            var merged = translatedByParagraph
            for (offset, item) in chunk.enumerated() {
                merged[item.index] = translated[offset]
            }

            let delay = Double.random(in: 0.3...0.5)
            self.workerQueue.asyncAfter(deadline: .now() + delay) {
                self.translateChunks(chunks, at: index + 1, provider: provider, translatedByParagraph: merged, completion: completion)
            }
        }
    }

    private func translateChunkWithRetry(
        _ chunk: [ParagraphItem],
        provider: TranslationProvider,
        attempt: Int,
        completion: @escaping ([String]) -> Void
    ) {
        requestBatchTranslation(for: chunk.map(\.text), provider: provider) { [weak self] translated in
            guard let self else {
                completion(chunk.map(\.text))
                return
            }

            if let translated, translated.count == chunk.count {
                completion(translated)
                return
            }

            guard attempt < self.maxRetries else {
                self.translateChunkIndividually(chunk, provider: provider, at: 0, translated: [], completion: completion)
                return
            }

            let backoff = min(1.6, 0.35 * pow(2.0, Double(attempt - 1)))
            let jitter = Double.random(in: 0.08...0.2)
            self.workerQueue.asyncAfter(deadline: .now() + backoff + jitter) {
                self.translateChunkWithRetry(chunk, provider: provider, attempt: attempt + 1, completion: completion)
            }
        }
    }

    private func translateChunkIndividually(
        _ chunk: [ParagraphItem],
        provider: TranslationProvider,
        at index: Int,
        translated: [String],
        completion: @escaping ([String]) -> Void
    ) {
        guard index < chunk.count else {
            completion(translated)
            return
        }

        let paragraph = chunk[index].text
        translateParagraphWithRetry(paragraph, provider: provider, attempt: 1) { [weak self] translatedParagraph in
            guard let self else {
                completion(translated + [translatedParagraph ?? paragraph])
                return
            }

            let next = translated + [translatedParagraph ?? paragraph]
            self.translateChunkIndividually(chunk, provider: provider, at: index + 1, translated: next, completion: completion)
        }
    }

    private func translateParagraphWithRetry(
        _ text: String,
        provider: TranslationProvider,
        attempt: Int,
        completion: @escaping (String?) -> Void
    ) {
        let parts = splitLongParagraph(text, maxChars: maxChunkChars)
        translateParagraphParts(parts, provider: provider, at: 0, translatedParts: [], attempt: attempt) { translatedParts in
            guard let translatedParts else {
                completion(nil)
                return
            }
            completion(translatedParts.joined())
        }
    }

    private func translateParagraphParts(
        _ parts: [String],
        provider: TranslationProvider,
        at index: Int,
        translatedParts: [String],
        attempt: Int,
        completion: @escaping ([String]?) -> Void
    ) {
        guard index < parts.count else {
            completion(translatedParts)
            return
        }

        requestBatchTranslation(for: [parts[index]], provider: provider) { [weak self] translated in
            guard let self else {
                completion(nil)
                return
            }

            if let piece = translated?.first {
                self.translateParagraphParts(parts, provider: provider, at: index + 1, translatedParts: translatedParts + [piece], attempt: 1, completion: completion)
                return
            }

            guard attempt < self.maxRetries else {
                completion(nil)
                return
            }

            let backoff = min(1.6, 0.35 * pow(2.0, Double(attempt - 1)))
            let jitter = Double.random(in: 0.08...0.2)
            self.workerQueue.asyncAfter(deadline: .now() + backoff + jitter) {
                self.translateParagraphParts(parts, provider: provider, at: index, translatedParts: translatedParts, attempt: attempt + 1, completion: completion)
            }
        }
    }

    private func requestBatchTranslation(
        for paragraphs: [String],
        provider: TranslationProvider,
        completion: @escaping ([String]?) -> Void
    ) {
        guard !paragraphs.isEmpty else {
            completion([])
            return
        }

        switch provider {
        case .webGtx:
            requestWebGtxBatchTranslation(for: paragraphs) { [weak self] translated in
                guard let self else {
                    completion(translated)
                    return
                }

                if translated != nil {
                    completion(translated)
                    return
                }

                if self.googleCloudApiKey() != nil {
                    NSLog("Google Web (gtx) failed, trying Google Cloud API.")
                    self.requestGoogleCloudBatchTranslation(for: paragraphs, completion: completion)
                } else {
                    self.requestGoogleMobileWebBatchTranslation(for: paragraphs, completion: completion)
                }
            }
        case .googleCloud:
            requestGoogleCloudBatchTranslation(for: paragraphs) { [weak self] translated in
                guard let self else {
                    completion(translated)
                    return
                }

                if translated != nil {
                    completion(translated)
                    return
                }

                NSLog("Google Cloud translation failed, falling back to Google Web (gtx).")
                self.requestWebGtxBatchTranslation(for: paragraphs) { gtxTranslated in
                    if gtxTranslated != nil {
                        completion(gtxTranslated)
                        return
                    }
                    self.requestGoogleMobileWebBatchTranslation(for: paragraphs, completion: completion)
                }
            }
        case .argos:
            requestArgosBatchTranslation(for: paragraphs) { [weak self] translated in
                guard let self else {
                    completion(translated)
                    return
                }

                if translated != nil {
                    completion(translated)
                    return
                }

                NSLog("Argos translation failed, falling back to Google Web (gtx) chain.")
                self.requestBatchTranslation(for: paragraphs, provider: .webGtx, completion: completion)
            }
        }
    }

    private func requestWebGtxBatchTranslation(for paragraphs: [String], completion: @escaping ([String]?) -> Void) {
        guard var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single") else {
            completion(nil)
            return
        }

        var queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: "ru"),
            URLQueryItem(name: "dt", value: "t")
        ]
        queryItems.append(contentsOf: paragraphs.map { URLQueryItem(name: "q", value: $0) })
        components.queryItems = queryItems

        guard let url = components.url else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12

        session.dataTask(with: request) { data, response, error in
            guard
                error == nil,
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                let data
            else {
                completion(nil)
                return
            }
            completion(Self.parseBatchTranslatedTexts(from: data, expectedCount: paragraphs.count))
        }.resume()
    }

    private func requestGoogleMobileWebBatchTranslation(for paragraphs: [String], completion: @escaping ([String]?) -> Void) {
        requestGoogleMobileWebBatchTranslation(paragraphs, at: 0, translated: [], completion: completion)
    }

    private func requestGoogleMobileWebBatchTranslation(
        _ paragraphs: [String],
        at index: Int,
        translated: [String],
        completion: @escaping ([String]?) -> Void
    ) {
        guard index < paragraphs.count else {
            completion(translated)
            return
        }

        requestGoogleMobileWebTranslation(for: paragraphs[index]) { [weak self] item in
            guard let self else {
                completion(nil)
                return
            }
            guard let item else {
                completion(nil)
                return
            }
            self.requestGoogleMobileWebBatchTranslation(paragraphs, at: index + 1, translated: translated + [item], completion: completion)
        }
    }

    private func requestGoogleMobileWebTranslation(for text: String, completion: @escaping (String?) -> Void) {
        guard var components = URLComponents(string: "https://translate.google.com/m") else {
            completion(nil)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: "ru"),
            URLQueryItem(name: "q", value: text)
        ]
        guard let url = components.url else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        session.dataTask(with: request) { data, response, error in
            guard
                error == nil,
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                let data,
                let html = String(data: data, encoding: .utf8)
            else {
                completion(nil)
                return
            }

            guard let rawResult = Self.extractFirstRegexMatch(
                pattern: #"<div class=\"result-container\">(.*?)</div>"#,
                in: html
            ) else {
                completion(nil)
                return
            }

            completion(Self.decodeHTML(rawResult).trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
    }

    private func requestArgosBatchTranslation(for paragraphs: [String], completion: @escaping ([String]?) -> Void) {
        requestArgosBatchTranslation(paragraphs, at: 0, translated: [], completion: completion)
    }

    private func requestArgosBatchTranslation(
        _ paragraphs: [String],
        at index: Int,
        translated: [String],
        completion: @escaping ([String]?) -> Void
    ) {
        guard index < paragraphs.count else {
            completion(translated)
            return
        }

        requestArgosTranslation(for: paragraphs[index]) { [weak self] item in
            guard let self else {
                completion(nil)
                return
            }

            guard let item else {
                completion(nil)
                return
            }

            self.requestArgosBatchTranslation(paragraphs, at: index + 1, translated: translated + [item], completion: completion)
        }
    }

    private func requestArgosTranslation(for text: String, completion: @escaping (String?) -> Void) {
        guard FileManager.default.isExecutableFile(atPath: argosCliPath) else {
            NSLog("Argos CLI not found or not executable at \(argosCliPath)")
            completion(nil)
            return
        }

        workerQueue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.argosCliPath)
            process.arguments = ["--text", text, "--to", "ru"]

            var env = ProcessInfo.processInfo.environment
            env["ARGOS_PACKAGES_DIR"] = env["ARGOS_PACKAGES_DIR"] ?? "\(self.argosBasePath)/packages"
            let pythonLibPath = "\(self.argosBasePath)/python_lib"
            if let currentPythonPath = env["PYTHONPATH"], !currentPythonPath.isEmpty {
                env["PYTHONPATH"] = "\(pythonLibPath):\(currentPythonPath)"
            } else {
                env["PYTHONPATH"] = pythonLibPath
            }
            process.environment = env

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                NSLog("Argos process failed to start: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8) ?? ""
                NSLog("Argos process failed with status \(process.terminationStatus): \(errorText.prefix(240))")
                completion(nil)
                return
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty
            else {
                completion(nil)
                return
            }

            completion(output)
        }
    }

    private func requestGoogleCloudBatchTranslation(for paragraphs: [String], completion: @escaping ([String]?) -> Void) {
        guard let apiKey = googleCloudApiKey(), !apiKey.isEmpty else {
            NSLog("Google Cloud API key is missing. Set it in app menu or via GOOGLE_CLOUD_TRANSLATE_API_KEY / GOOGLE_API_KEY.")
            completion(nil)
            return
        }

        guard var components = URLComponents(string: "https://translation.googleapis.com/language/translate/v2") else {
            completion(nil)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components.url else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "q": paragraphs,
            "target": "ru",
            "format": "text"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        session.dataTask(with: request) { data, response, error in
            guard
                error == nil,
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                let data
            else {
                if let httpResponse = response as? HTTPURLResponse, let data, let body = String(data: data, encoding: .utf8) {
                    NSLog("Google Cloud translation failed with status \(httpResponse.statusCode): \(body.prefix(240))")
                } else if let error {
                    NSLog("Google Cloud translation request error: \(error.localizedDescription)")
                }
                completion(nil)
                return
            }
            completion(Self.parseGoogleCloudTranslatedTexts(from: data, expectedCount: paragraphs.count))
        }.resume()
    }

    private static func parseArgosPackageSyncPayload(from output: String) -> ArgosPackageSyncPayload? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let candidates = [trimmed] + trimmed.split(whereSeparator: \.isNewline).map(String.init).reversed()
        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else {
                continue
            }
            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let ok = root["ok"] as? Bool ?? false
            let directAfter = root["direct_after"] as? Bool ?? false
            let directAvailableCount = root["direct_available_count"] as? Int ?? 0
            let installedNow = root["installed_now"] as? Bool ?? false
            let updatedPairs = root["updated_pairs"] as? [String] ?? []
            let warnings = root["warnings"] as? [String] ?? []
            let fatalError = root["fatal_error"] as? String ?? ""
            return ArgosPackageSyncPayload(
                ok: ok,
                directAfter: directAfter,
                directAvailableCount: directAvailableCount,
                installedNow: installedNow,
                updatedPairs: updatedPairs,
                warnings: warnings,
                fatalError: fatalError
            )
        }

        return nil
    }

    private static func makeArgosPackageSyncSummary(from payload: ArgosPackageSyncPayload, stderr: String) -> String {
        var lines: [String] = []

        if !payload.ok {
            lines.append("Не удалось обновить пакеты Argos.")
            if !payload.fatalError.isEmpty {
                lines.append(payload.fatalError)
            }
            let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedStderr.isEmpty {
                lines.append("Лог: \(trimmedStderr.prefix(300))")
            }
            return lines.joined(separator: "\n")
        }

        if payload.updatedPairs.isEmpty {
            lines.append("Обновлений для установленных пакетов не найдено.")
        } else {
            lines.append("Обновлены пакеты: \(payload.updatedPairs.joined(separator: ", ")).")
        }

        if payload.directAfter {
            lines.append(payload.installedNow ? "Пакет he->ru найден и установлен." : "Пакет he->ru уже установлен.")
        } else if payload.directAvailableCount > 0 {
            lines.append("Пакет he->ru есть в индексе, но установить его не удалось.")
        } else {
            lines.append("Пакет he->ru пока отсутствует в индексе Argos.")
        }

        if !payload.warnings.isEmpty {
            lines.append("Предупреждения: \(payload.warnings.joined(separator: " | "))")
        }

        return lines.joined(separator: "\n")
    }

    private static let argosPackageSyncPythonScript = #"""
import json
import os
import re

result = {
    "ok": False,
    "direct_before": False,
    "direct_after": False,
    "direct_available_count": 0,
    "installed_now": False,
    "updated_pairs": [],
    "warnings": [],
    "fatal_error": "",
}

def version_tuple(value):
    parts = [int(x) for x in re.findall(r"\d+", str(value or ""))]
    return tuple(parts) if parts else (0,)

def best_package(packages):
    return sorted(packages, key=lambda p: version_tuple(getattr(p, "version", "0")), reverse=True)[0]

def has_direct(packages):
    for pkg in packages:
        if getattr(pkg, "from_code", "") == "he" and getattr(pkg, "to_code", "") == "ru":
            return True
    return False

try:
    import argostranslate.package as package
except Exception as exc:
    result["fatal_error"] = f"Import error: {exc}"
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(0)

packages_dir = os.environ.get("ARGOS_PACKAGES_DIR", "")
if packages_dir:
    os.makedirs(packages_dir, exist_ok=True)

try:
    package.update_package_index()
    available = package.get_available_packages()
    installed = package.get_installed_packages()
except Exception as exc:
    result["fatal_error"] = f"Package index error: {exc}"
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(0)

result["direct_before"] = has_direct(installed)

installed_by_pair = {}
for pkg in installed:
    pair = f"{getattr(pkg, 'from_code', '')}->{getattr(pkg, 'to_code', '')}"
    current = installed_by_pair.get(pair)
    if current is None or version_tuple(getattr(pkg, "version", "0")) > version_tuple(getattr(current, "version", "0")):
        installed_by_pair[pair] = pkg

for pair, current_pkg in installed_by_pair.items():
    candidates = [
        pkg for pkg in available
        if getattr(pkg, "from_code", "") == getattr(current_pkg, "from_code", "")
        and getattr(pkg, "to_code", "") == getattr(current_pkg, "to_code", "")
    ]
    if not candidates:
        continue
    latest = best_package(candidates)
    current_version = str(getattr(current_pkg, "version", "0"))
    latest_version = str(getattr(latest, "version", "0"))
    if version_tuple(latest_version) > version_tuple(current_version):
        try:
            path = latest.download()
            package.install_from_path(path)
            result["updated_pairs"].append(f"{pair} {current_version}->{latest_version}")
        except Exception as exc:
            result["warnings"].append(f"Failed to update {pair}: {exc}")

direct_candidates = [pkg for pkg in available if getattr(pkg, "from_code", "") == "he" and getattr(pkg, "to_code", "") == "ru"]
result["direct_available_count"] = len(direct_candidates)

if direct_candidates and not result["direct_before"]:
    try:
        latest_direct = best_package(direct_candidates)
        path = latest_direct.download()
        package.install_from_path(path)
        result["installed_now"] = True
    except Exception as exc:
        result["warnings"].append(f"Failed to install he->ru: {exc}")

try:
    installed_after = package.get_installed_packages()
    result["direct_after"] = has_direct(installed_after)
except Exception as exc:
    result["warnings"].append(f"Failed to verify installed packages: {exc}")
    result["direct_after"] = result["direct_before"]

result["ok"] = True
print(json.dumps(result, ensure_ascii=False))
"""#

    private static func parseBatchTranslatedTexts(from data: Data, expectedCount: Int) -> [String]? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
            let first = root.first as? [Any]
        else {
            return nil
        }

        if expectedCount == 1, let single = joinSentenceChunks(from: first) {
            return [single]
        }

        guard first.count == expectedCount else {
            return nil
        }

        var translations: [String] = []
        translations.reserveCapacity(expectedCount)

        for element in first {
            guard let elementArray = element as? [Any], let text = joinSentenceChunks(from: elementArray) else {
                return nil
            }
            translations.append(text)
        }

        return translations
    }

    private static func parseGoogleCloudTranslatedTexts(from data: Data, expectedCount: Int) -> [String]? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataObject = root["data"] as? [String: Any],
            let translations = dataObject["translations"] as? [[String: Any]],
            translations.count == expectedCount
        else {
            return nil
        }

        var result: [String] = []
        result.reserveCapacity(expectedCount)
        for item in translations {
            guard let translated = item["translatedText"] as? String else {
                return nil
            }
            result.append(decodeHTML(translated))
        }
        return result
    }

    private static func decodeHTML(_ text: String) -> String {
        guard
            let data = text.data(using: .utf8),
            let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        else {
            return text
        }
        return attributed.string
    }

    private static func extractFirstRegexMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges >= 2
        else {
            return nil
        }
        return nsText.substring(with: match.range(at: 1))
    }

    private func googleCloudApiKey() -> String? {
        let env = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_TRANSLATE_API_KEY"]
            ?? ProcessInfo.processInfo.environment["GOOGLE_TRANSLATE_API_KEY"]
            ?? ProcessInfo.processInfo.environment["GOOGLE_API_KEY"]
        let envTrimmed = env?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !envTrimmed.isEmpty {
            return envTrimmed
        }

        let defaultsTrimmed = settings.googleCloudApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return defaultsTrimmed.isEmpty ? nil : defaultsTrimmed
    }

    private func splitLongParagraph(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }

        let sentenceRegex = try? NSRegularExpression(pattern: #"(?<=[.!?])\s+"#)
        let range = NSRange(location: 0, length: (text as NSString).length)
        let matches = sentenceRegex?.matches(in: text, options: [], range: range) ?? []

        var sentences: [String] = []
        var cursor = 0
        let nsText = text as NSString

        for match in matches {
            let sentenceRange = NSRange(location: cursor, length: match.range.location - cursor)
            let sentence = nsText.substring(with: sentenceRange)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            let separator = nsText.substring(with: match.range)
            if !separator.isEmpty {
                sentences.append(separator)
            }
            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            sentences.append(nsText.substring(from: cursor))
        }

        if sentences.isEmpty {
            return hardSplit(text, maxChars: maxChars)
        }

        var chunks: [String] = []
        var current = ""
        for token in sentences {
            if current.count + token.count <= maxChars {
                current += token
                continue
            }
            if !current.isEmpty {
                chunks.append(current)
                current = ""
            }
            if token.count > maxChars {
                chunks.append(contentsOf: hardSplit(token, maxChars: maxChars))
            } else {
                current = token
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks.isEmpty ? hardSplit(text, maxChars: maxChars) : chunks
    }

    private func hardSplit(_ text: String, maxChars: Int) -> [String] {
        var parts: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxChars, limitedBy: text.endIndex) ?? text.endIndex
            parts.append(String(text[start..<end]))
            start = end
        }
        return parts
    }

    private static func joinSentenceChunks(from source: [Any]) -> String? {
        var chunks: [String] = []
        for sentence in source {
            guard
                let sentenceArray = sentence as? [Any],
                let translatedChunk = sentenceArray.first as? String
            else {
                continue
            }
            chunks.append(translatedChunk)
        }

        let joined = chunks.joined()
        return joined.isEmpty ? nil : joined
    }

    private func reassemble(
        segments: [Segment],
        paragraphs: [ParagraphItem],
        translatedByParagraph: [Int: String]
    ) -> String? {
        var output = ""
        for segment in segments {
            switch segment {
            case .separator(let separator):
                output += separator
            case .paragraph(let index):
                if let translated = translatedByParagraph[index] {
                    output += translated
                } else if paragraphs.indices.contains(index) {
                    let original = paragraphs[index].text
                    output += original
                }
            }
        }
        return output.isEmpty ? nil : output
    }

    private func shouldSkipTranslation(_ text: String) -> Bool {
        let hasCyrillic = text.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil
        return hasCyrillic && !containsLatin(text) && !containsHebrew(text)
    }

    private func containsLatin(_ text: String) -> Bool {
        text.range(of: "[A-Za-z]", options: .regularExpression) != nil
    }

    private func containsHebrew(_ text: String) -> Bool {
        text.range(of: "[\\u0590-\\u05FF]", options: .regularExpression) != nil
    }
}

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var isHandlerInstalled = false
    var onTrigger: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32) {
        installHandlerIfNeeded()

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x53544F56), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func installHandlerIfNeeded() {
        guard !isHandlerInstalled else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if hotKeyID.id == 1 {
                manager.onTrigger?()
            }
            return noErr
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &handlerRef)

        isHandlerInstalled = true
    }
}

final class LaunchAtLoginManager {
    func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Launch at login update failed: \(error.localizedDescription)")
            return false
        }
    }
}

final class SettingsWindowController: NSWindowController {
    var onHotKeyChanged: ((UInt32, UInt32) -> Void)?
    var onFontSizeChanged: ((CGFloat) -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Bool)?

    private let settings: AppSettings
    private let keyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let commandCheck = NSButton(checkboxWithTitle: "Command", target: nil, action: nil)
    private let shiftCheck = NSButton(checkboxWithTitle: "Shift", target: nil, action: nil)
    private let optionCheck = NSButton(checkboxWithTitle: "Option", target: nil, action: nil)
    private let controlCheck = NSButton(checkboxWithTitle: "Control", target: nil, action: nil)
    private let fontSlider = NSSlider(value: 22, minValue: 12, maxValue: 56, target: nil, action: nil)
    private let fontValueLabel = NSTextField(labelWithString: "22")
    private let launchCheck = NSButton(checkboxWithTitle: "Автозапуск при входе в систему", target: nil, action: nil)

    init(settings: AppSettings) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Настройки"
        window.center()
        super.init(window: window)
        setupUI()
        loadFromSettings()
    }

    required init?(coder: NSCoder) { nil }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        keyPopup.addItems(withTitles: HotKeyChoice.all.map { $0.title })
        keyPopup.target = self
        keyPopup.action = #selector(hotKeyChanged)

        [commandCheck, shiftCheck, optionCheck, controlCheck].forEach {
            $0.target = self
            $0.action = #selector(hotKeyChanged)
        }

        fontSlider.target = self
        fontSlider.action = #selector(fontSizeChanged)
        fontSlider.numberOfTickMarks = 0

        launchCheck.target = self
        launchCheck.action = #selector(launchAtLoginChanged)

        let hotKeyLabel = NSTextField(labelWithString: "Горячая клавиша")
        let fontLabel = NSTextField(labelWithString: "Размер шрифта")

        let modifiersStack = NSStackView(views: [commandCheck, shiftCheck, optionCheck, controlCheck])
        modifiersStack.orientation = .horizontal
        modifiersStack.spacing = 12

        let keyRow = NSStackView(views: [NSTextField(labelWithString: "Клавиша:"), keyPopup])
        keyRow.orientation = .horizontal
        keyRow.spacing = 8
        keyRow.alignment = .centerY

        let fontRow = NSStackView(views: [fontSlider, fontValueLabel])
        fontRow.orientation = .horizontal
        fontRow.spacing = 10
        fontRow.alignment = .centerY

        let root = NSStackView(views: [hotKeyLabel, keyRow, modifiersStack, fontLabel, fontRow, launchCheck])
        root.orientation = .vertical
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }

    private func loadFromSettings() {
        if let index = HotKeyChoice.all.firstIndex(where: { $0.keyCode == settings.hotKeyCode }) {
            keyPopup.selectItem(at: index)
        }

        commandCheck.state = (settings.hotKeyModifiers & UInt32(cmdKey)) != 0 ? .on : .off
        shiftCheck.state = (settings.hotKeyModifiers & UInt32(shiftKey)) != 0 ? .on : .off
        optionCheck.state = (settings.hotKeyModifiers & UInt32(optionKey)) != 0 ? .on : .off
        controlCheck.state = (settings.hotKeyModifiers & UInt32(controlKey)) != 0 ? .on : .off

        fontSlider.doubleValue = settings.fontSize
        fontValueLabel.stringValue = String(Int(settings.fontSize))
        launchCheck.state = settings.launchAtLogin ? .on : .off
    }

    @objc private func hotKeyChanged() {
        let selectedIndex = max(0, keyPopup.indexOfSelectedItem)
        let selectedKeyCode = HotKeyChoice.all[selectedIndex].keyCode

        var modifiers: UInt32 = 0
        if commandCheck.state == .on { modifiers |= UInt32(cmdKey) }
        if shiftCheck.state == .on { modifiers |= UInt32(shiftKey) }
        if optionCheck.state == .on { modifiers |= UInt32(optionKey) }
        if controlCheck.state == .on { modifiers |= UInt32(controlKey) }

        if modifiers == 0 {
            modifiers = UInt32(cmdKey)
            commandCheck.state = .on
        }

        settings.setHotKey(code: selectedKeyCode, modifiers: modifiers)
        onHotKeyChanged?(selectedKeyCode, modifiers)
    }

    @objc private func fontSizeChanged() {
        let newSize = CGFloat(fontSlider.doubleValue)
        settings.setFontSize(newSize)
        fontValueLabel.stringValue = String(Int(newSize.rounded()))
        onFontSizeChanged?(newSize)
    }

    @objc private func launchAtLoginChanged() {
        let desired = launchCheck.state == .on
        let success = onLaunchAtLoginChanged?(desired) ?? false
        if success {
            settings.setLaunchAtLogin(desired)
        } else {
            launchCheck.state = desired ? .off : .on
            NSSound.beep()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let overlay = OverlayController()
    private let selection = SelectionService()
    private lazy var translator = TranslationService(settings: settings)
    private let hotKey = HotKeyManager()
    private let launchAtLogin = LaunchAtLoginManager()

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var webGtxProviderItem: NSMenuItem?
    private var googleCloudProviderItem: NSMenuItem?
    private var argosProviderItem: NSMenuItem?
    private var googleCloudApiKeyMenuItem: NSMenuItem?
    private var argosPackageUpdateMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        overlay.setFontSize(settings.fontSize)

        hotKey.onTrigger = { [weak self] in
            guard let self else { return }
            self.selection.fetchSelectedText { [weak self] text in
                guard let self else { return }
                let sourceText = text ?? ""

                guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.overlay.show(text: "Не удалось получить выделенный текст.")
                    return
                }

                self.overlay.showLoading(message: "Идет перевод")

                self.translator.translateToRussian(sourceText) { translated in
                    let finalText = translated ?? sourceText
                    self.overlay.show(text: finalText)
                }
            }
        }

        hotKey.register(keyCode: settings.hotKeyCode, modifiers: settings.hotKeyModifiers)

        if settings.launchAtLogin {
            let success = launchAtLogin.setEnabled(true)
            if !success {
                settings.setLaunchAtLogin(false)
            }
        }
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let controller = SettingsWindowController(settings: settings)
            controller.onHotKeyChanged = { [weak self] keyCode, modifiers in
                self?.hotKey.register(keyCode: keyCode, modifiers: modifiers)
            }
            controller.onFontSizeChanged = { [weak self] size in
                self?.overlay.setFontSize(size)
            }
            controller.onLaunchAtLoginChanged = { [weak self] enabled in
                self?.launchAtLogin.setEnabled(enabled) ?? false
            }
            settingsWindowController = controller
        }

        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func selectWebGtxProvider() {
        settings.setTranslationProvider(.webGtx)
        updateTranslationProviderMenuState()
    }

    @objc private func selectGoogleCloudProvider() {
        settings.setTranslationProvider(.googleCloud)
        updateTranslationProviderMenuState()
    }

    @objc private func selectArgosProvider() {
        settings.setTranslationProvider(.argos)
        updateTranslationProviderMenuState()
    }

    @objc private func configureGoogleCloudApiKey() {
        let alert = NSAlert()
        alert.messageText = "Google Cloud API key"
        alert.informativeText = "Введите API key для официального Google Cloud Translation API. Ключ хранится в macOS Keychain. Можно оставить пустым, если используете переменную окружения."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Сохранить")
        alert.addButton(withTitle: "Отмена")
        alert.addButton(withTitle: "Очистить")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 24))
        input.placeholderString = "AIza..."
        input.stringValue = settings.googleCloudApiKey
        alert.accessoryView = input

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            settings.setGoogleCloudApiKey(input.stringValue)
        case .alertThirdButtonReturn:
            settings.setGoogleCloudApiKey("")
        default:
            break
        }

        updateTranslationProviderMenuState()
    }

    @objc private func checkAndUpdateArgosPackages() {
        argosPackageUpdateMenuItem?.isEnabled = false
        argosPackageUpdateMenuItem?.title = "Проверка пакетов Argos…"

        translator.checkAndUpdateArgosPackages { [weak self] result in
            guard let self else { return }

            if result.success {
                self.settings.updateArgosPackageStatus(
                    directHeRuInstalled: result.directHeRuInstalled,
                    summary: result.summary
                )
            }

            self.argosPackageUpdateMenuItem?.isEnabled = true
            self.updateTranslationProviderMenuState()

            let alert = NSAlert()
            alert.alertStyle = result.success ? .informational : .warning
            alert.messageText = result.success ? "Пакеты Argos проверены" : "Ошибка проверки Argos"
            alert.informativeText = result.summary
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func updateTranslationProviderMenuState() {
        let provider = settings.translationProvider
        webGtxProviderItem?.state = provider == .webGtx ? .on : .off
        googleCloudProviderItem?.state = provider == .googleCloud ? .on : .off
        argosProviderItem?.state = provider == .argos ? .on : .off
        let hasApiKey = !settings.googleCloudApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        googleCloudApiKeyMenuItem?.title = hasApiKey ? "Google Cloud API key… (сохранён)" : "Google Cloud API key…"
        let heRuState = settings.argosDirectHeRuInstalled ? "установлен" : "не установлен"
        argosPackageUpdateMenuItem?.title = "Проверить/обновить пакеты Argos… (he->ru: \(heRuState))"
    }

    private func makeMenuBarBadgeImage() -> NSImage? {
        let imageSize = NSSize(width: 18, height: 18)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        defer { image.unlockFocus() }
        NSGraphicsContext.current?.imageInterpolation = .high

        NSColor.black.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()

        let yaSize: CGFloat = 17
        let text = "Я" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: yaSize, weight: .black)
        ]
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (imageSize.width - textSize.width) / 2,
            y: (imageSize.height - textSize.height) / 2 - 0.2,
            width: textSize.width,
            height: textSize.height
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        text.draw(in: textRect, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()

        image.isTemplate = false
        return image
    }

    private func loadMenuBarIconFromBundle() -> NSImage? {
        guard
            let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        let targetHeight: CGFloat = 18
        let originalHeight = max(image.size.height, 1)
        let scale = targetHeight / originalHeight
        image.size = NSSize(width: image.size.width * scale, height: targetHeight)
        image.isTemplate = false
        return image
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = loadMenuBarIconFromBundle() ?? makeMenuBarBadgeImage()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.title = ""
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Настройки…", action: #selector(openSettings), keyEquivalent: ","))
        let providerRootItem = NSMenuItem(title: "Способ перевода", action: nil, keyEquivalent: "")
        let providerSubmenu = NSMenu(title: "Способ перевода")

        let webItem = NSMenuItem(title: TranslationProvider.webGtx.title, action: #selector(selectWebGtxProvider), keyEquivalent: "")
        webItem.target = self
        providerSubmenu.addItem(webItem)

        let cloudItem = NSMenuItem(title: TranslationProvider.googleCloud.title, action: #selector(selectGoogleCloudProvider), keyEquivalent: "")
        cloudItem.target = self
        providerSubmenu.addItem(cloudItem)

        let argosItem = NSMenuItem(title: TranslationProvider.argos.title, action: #selector(selectArgosProvider), keyEquivalent: "")
        argosItem.target = self
        providerSubmenu.addItem(argosItem)

        providerSubmenu.addItem(NSMenuItem.separator())
        let apiKeyItem = NSMenuItem(title: "Google Cloud API key…", action: #selector(configureGoogleCloudApiKey), keyEquivalent: "")
        apiKeyItem.target = self
        providerSubmenu.addItem(apiKeyItem)

        let argosPackagesItem = NSMenuItem(title: "Проверить/обновить пакеты Argos…", action: #selector(checkAndUpdateArgosPackages), keyEquivalent: "")
        argosPackagesItem.target = self
        providerSubmenu.addItem(argosPackagesItem)

        providerRootItem.submenu = providerSubmenu
        menu.addItem(providerRootItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu

        webGtxProviderItem = webItem
        googleCloudProviderItem = cloudItem
        argosProviderItem = argosItem
        googleCloudApiKeyMenuItem = apiKeyItem
        argosPackageUpdateMenuItem = argosPackagesItem
        updateTranslationProviderMenuState()

        statusItem = item
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
