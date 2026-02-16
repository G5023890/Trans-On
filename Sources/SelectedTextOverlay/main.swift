import AppKit
import Carbon.HIToolbox
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

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private let hotKeyCodeKey = "hotKeyCode"
    private let hotKeyModifiersKey = "hotKeyModifiers"
    private let fontSizeKey = "fontSize"
    private let launchAtLoginKey = "launchAtLogin"

    private(set) var hotKeyCode: UInt32
    private(set) var hotKeyModifiers: UInt32
    private(set) var fontSize: CGFloat
    private(set) var launchAtLogin: Bool

    private init() {
        let defaultCode = UInt32(kVK_ANSI_P)
        let defaultModifiers = UInt32(cmdKey | shiftKey)

        let storedCode = defaults.object(forKey: hotKeyCodeKey) as? Int
        let storedModifiers = defaults.object(forKey: hotKeyModifiersKey) as? Int
        let storedFont = defaults.object(forKey: fontSizeKey) as? Double

        hotKeyCode = UInt32(storedCode ?? Int(defaultCode))
        hotKeyModifiers = UInt32(storedModifiers ?? Int(defaultModifiers))
        fontSize = CGFloat(storedFont ?? 22)
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
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

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func updateText(_ text: String) {
        textView.string = text
        textView.scrollToBeginningOfDocument(nil)
        window?.makeFirstResponder(textView)
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
    private let session = URLSession(configuration: .ephemeral)

    func translateToRussian(_ text: String, completion: @escaping (String?) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(nil)
            return
        }

        if containsCyrillic(trimmed) {
            completion(trimmed)
            return
        }

        guard var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single") else {
            completion(nil)
            return
        }

        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: "ru"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: trimmed)
        ]

        guard let url = components.url else {
            completion(nil)
            return
        }

        session.dataTask(with: url) { data, _, error in
            let translated: String?
            if error != nil || data == nil {
                translated = nil
            } else {
                translated = Self.parseTranslatedText(from: data!)
            }

            DispatchQueue.main.async {
                completion(translated)
            }
        }.resume()
    }

    private static func parseTranslatedText(from data: Data) -> String? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
            let sentences = root.first as? [Any]
        else {
            return nil
        }

        var chunks: [String] = []
        for sentence in sentences {
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

    private func containsCyrillic(_ text: String) -> Bool {
        text.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil
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
    private let translator = TranslationService()
    private let hotKey = HotKeyManager()
    private let launchAtLogin = LaunchAtLoginManager()

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        overlay.setFontSize(settings.fontSize)

        hotKey.onTrigger = { [weak self] in
            self?.selection.fetchSelectedText { text in
                guard let self else { return }
                let sourceText = text ?? ""

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

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "⌘Я"
            button.image = nil
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Настройки…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu

        statusItem = item
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
