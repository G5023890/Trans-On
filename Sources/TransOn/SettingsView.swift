import SwiftUI
import AppKit
import Carbon.HIToolbox

struct HotKeyBinding: Hashable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let `default` = HotKeyBinding(
        keyCode: UInt32(kVK_ANSI_L),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    var displayString: String {
        HotKeyFormatter.modifierSymbols(modifiers) + HotKeyFormatter.keySymbol(for: keyCode)
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case translation
    case diagnostics
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .translation: return "Translation"
        case .diagnostics: return "Diagnostics"
        case .privacy: return "Privacy"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .translation: return "globe"
        case .diagnostics: return "exclamationmark.triangle"
        case .privacy: return "lock.shield"
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case on = "On"
    case off = "Off"

    var id: String { rawValue }
}

enum HotKeyFormatter {
    private static let knownKeys: [UInt32: String] = {
        var map: [UInt32: String] = [
            UInt32(kVK_Space): "Space",
            UInt32(kVK_Return): "Return",
            UInt32(kVK_Tab): "Tab",
            UInt32(kVK_Delete): "Delete",
            UInt32(kVK_Escape): "Esc",
            UInt32(kVK_ANSI_Comma): ",",
            UInt32(kVK_ANSI_Period): ".",
            UInt32(kVK_ANSI_Slash): "/",
            UInt32(kVK_ANSI_Semicolon): ";",
            UInt32(kVK_ANSI_Quote): "'",
            UInt32(kVK_ANSI_LeftBracket): "[",
            UInt32(kVK_ANSI_RightBracket): "]",
            UInt32(kVK_ANSI_Backslash): "\\",
            UInt32(kVK_ANSI_Grave): "`",
            UInt32(kVK_ANSI_Minus): "-",
            UInt32(kVK_ANSI_Equal): "=",
            UInt32(kVK_ANSI_0): "0",
            UInt32(kVK_ANSI_1): "1",
            UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3",
            UInt32(kVK_ANSI_4): "4",
            UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6",
            UInt32(kVK_ANSI_7): "7",
            UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9"
        ]

        for choice in HotKeyChoice.all {
            map[choice.keyCode] = choice.title
        }
        return map
    }()

    static func keySymbol(for keyCode: UInt32) -> String {
        knownKeys[keyCode] ?? "Key\(keyCode)"
    }

    static func modifierSymbols(_ modifiers: UInt32) -> String {
        var symbols = ""
        if (modifiers & UInt32(controlKey)) != 0 { symbols += "⌃" }
        if (modifiers & UInt32(optionKey)) != 0 { symbols += "⌥" }
        if (modifiers & UInt32(shiftKey)) != 0 { symbols += "⇧" }
        if (modifiers & UInt32(cmdKey)) != 0 { symbols += "⌘" }
        return symbols
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @AppStorage(AppSettings.hotKeyCodeDefaultsKey) private var storedHotKeyCode: Int = Int(HotKeyBinding.default.keyCode)
    @AppStorage(AppSettings.hotKeyModifiersDefaultsKey) private var storedHotKeyModifiers: Int = Int(HotKeyBinding.default.modifiers)
    @AppStorage(AppSettings.fontSizeDefaultsKey) private var storedFontSize: Double = 22
    @AppStorage(AppSettings.launchAtLoginDefaultsKey) private var storedLaunchAtLogin: Bool = false
    @AppStorage(AppSettings.menuBarDisplayModeDefaultsKey) private var storedMenuBarDisplayMode: String = MenuBarDisplayMode.on.rawValue
    @AppStorage(TransOnControlConstants.controlIconDefaultsKey, store: TransOnSharedDefaults.shared.userDefaults)
    private var storedControlCenterIcon: String = ControlCenterIconOption.translate.rawValue

    @Published var selectedSection: SettingsSection = .general
    @Published private(set) var hotKey: HotKeyBinding = .default
    @Published private(set) var fontSizePt: Int = 22
    @Published private(set) var launchAtLogin: Bool = false
    @Published private(set) var menuBarDisplayMode: MenuBarDisplayMode = .on
    @Published private(set) var controlCenterIcon: ControlCenterIconOption = .translate
    @Published var isRecording = false
    @Published var hotKeyError: String?
    @Published var launchAtLoginError: String?
    @Published var cloudStatusMessage: String = ""
    @Published var googleCloudDiagnosticTitle: String = "No recent Google Cloud errors"
    @Published var googleCloudDiagnosticDetail: String = "When Google Cloud fails, the latest reason appears here."
    @Published var googleCloudDiagnosticUpdatedAt: String = "Not yet updated"

    var onHotKeyChanged: ((UInt32, UInt32) -> Void)?
    var onFontSizeChanged: ((CGFloat) -> Void)?
    var onMenuBarDisplayModeChanged: ((MenuBarDisplayMode) -> Void)?
    var onControlCenterIconChanged: ((ControlCenterIconOption) -> Void)?

    private let launchAtLoginManager = LaunchAtLoginManager()
    private let reservedShortcuts: Set<HotKeyBinding> = [
        HotKeyBinding(keyCode: UInt32(kVK_ANSI_Q), modifiers: UInt32(cmdKey)),
        HotKeyBinding(keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(cmdKey)),
        HotKeyBinding(keyCode: UInt32(kVK_ANSI_Comma), modifiers: UInt32(cmdKey)),
        HotKeyBinding(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey)),
        HotKeyBinding(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey))
    ]

    init() {
        hotKey = HotKeyBinding(
            keyCode: UInt32(storedHotKeyCode),
            modifiers: UInt32(storedHotKeyModifiers)
        )
        fontSizePt = Self.clampFontSize(Int(storedFontSize.rounded()))
        launchAtLogin = storedLaunchAtLogin
        menuBarDisplayMode = AppSettings.shared.menuBarDisplayMode
        controlCenterIcon = AppSettings.shared.controlCenterIcon
    }

    func beginRecording() {
        hotKeyError = nil
        isRecording = true
    }

    func cancelRecording() {
        isRecording = false
    }

    func applyRecordedHotKey(_ candidate: HotKeyBinding) {
        if let conflict = conflictMessage(for: candidate) {
            hotKeyError = conflict
            NSSound.beep()
            return
        }

        hotKeyError = nil
        hotKey = candidate
        storedHotKeyCode = Int(candidate.keyCode)
        storedHotKeyModifiers = Int(candidate.modifiers)
        AppSettings.shared.setHotKey(code: candidate.keyCode, modifiers: candidate.modifiers)
        onHotKeyChanged?(candidate.keyCode, candidate.modifiers)
        isRecording = false
    }

    func resetHotKeyToDefault() {
        applyRecordedHotKey(.default)
    }

    func updateFontSize(_ newValue: Int) {
        let clamped = Self.clampFontSize(newValue)
        fontSizePt = clamped
        storedFontSize = Double(clamped)
        AppSettings.shared.setFontSize(CGFloat(clamped))
        onFontSizeChanged?(CGFloat(clamped))
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        let success = launchAtLoginManager.setEnabled(enabled)
        if success {
            launchAtLogin = enabled
            storedLaunchAtLogin = enabled
            AppSettings.shared.setLaunchAtLogin(enabled)
        } else {
            launchAtLoginError = "Не удалось изменить настройку автозапуска."
            NSSound.beep()
        }
    }

    func updateMenuBarDisplayMode(_ mode: MenuBarDisplayMode) {
        guard menuBarDisplayMode != mode else { return }
        menuBarDisplayMode = mode
        storedMenuBarDisplayMode = mode.rawValue
        AppSettings.shared.setMenuBarDisplayMode(mode)
        onMenuBarDisplayModeChanged?(mode)
    }

    func updateControlCenterIcon(_ icon: ControlCenterIconOption) {
        guard controlCenterIcon != icon else { return }
        controlCenterIcon = icon
        storedControlCenterIcon = icon.rawValue
        AppSettings.shared.setControlCenterIcon(icon)
        onControlCenterIconChanged?(icon)
    }

    func restoreDefaults() {
        resetHotKeyToDefault()
        updateFontSize(22)
        updateLaunchAtLogin(false)
    }

    func verifyGoogleAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        AppSettings.shared.setGoogleCloudApiKey(trimmed)
        cloudStatusMessage = trimmed.isEmpty ? "Ключ пустой." : "Ключ сохранён локально."
    }

    func recordGoogleCloudSuccess() {
        googleCloudDiagnosticTitle = "Google Cloud API worked"
        googleCloudDiagnosticDetail = "The latest cloud translation completed successfully."
        googleCloudDiagnosticUpdatedAt = Self.diagnosticTimestamp()
    }

    func recordGoogleCloudFailure(_ message: String) {
        googleCloudDiagnosticTitle = "Google Cloud API failed"
        googleCloudDiagnosticDetail = message.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? "The request failed, but no additional error text was returned." : message
        googleCloudDiagnosticUpdatedAt = Self.diagnosticTimestamp()
    }

    func clearGoogleCloudDiagnostics() {
        googleCloudDiagnosticTitle = "No recent Google Cloud errors"
        googleCloudDiagnosticDetail = "When Google Cloud fails, the latest reason appears here."
        googleCloudDiagnosticUpdatedAt = "Not yet updated"
    }

    private func conflictMessage(for candidate: HotKeyBinding) -> String? {
        if candidate.modifiers == 0 {
            return "Добавьте хотя бы один модификатор (⌘, ⇧, ⌥ или ⌃)."
        }

        if reservedShortcuts.contains(candidate) {
            return "Сочетание конфликтует с системной командой приложения."
        }

        if candidate.keyCode == UInt32(kVK_Escape) {
            return "Сочетание с Esc недоступно."
        }

        return nil
    }

    private static func clampFontSize(_ value: Int) -> Int {
        min(max(value, 12), 24)
    }

    private static func diagnosticTimestamp() -> String {
        Self.diagnosticFormatter.string(from: Date())
    }

    private static let diagnosticFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

}

struct HotKeyRecorderView: NSViewRepresentable {
    var onCapture: (HotKeyBinding) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class RecorderNSView: NSView {
    var onCapture: ((HotKeyBinding) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = UInt32(event.keyCode)

        if keyCode == UInt32(kVK_Escape) {
            onCancel?()
            return
        }

        if Self.modifierOnlyKeyCodes.contains(keyCode) {
            NSSound.beep()
            return
        }

        let modifiers = event.modifierFlags.carbonModifiers
        let binding = HotKeyBinding(keyCode: keyCode, modifiers: modifiers)
        onCapture?(binding)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        keyDown(with: event)
        return true
    }

    private static let modifierOnlyKeyCodes: Set<UInt32> = [
        UInt32(kVK_Command), UInt32(kVK_RightCommand),
        UInt32(kVK_Shift), UInt32(kVK_RightShift),
        UInt32(kVK_Option), UInt32(kVK_RightOption),
        UInt32(kVK_Control), UInt32(kVK_RightControl),
        UInt32(kVK_CapsLock), UInt32(kVK_Function)
    ]
}

private extension NSEvent.ModifierFlags {
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if contains(.command) { result |= UInt32(cmdKey) }
        if contains(.shift) { result |= UInt32(shiftKey) }
        if contains(.option) { result |= UInt32(optionKey) }
        if contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}

struct HotKeyRecorderSheet: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Нажмите новую комбинацию клавиш")
                .font(.headline)
            Text("Esc — отмена")
                .foregroundStyle(.secondary)

            HotKeyRecorderView(
                onCapture: { viewModel.applyRecordedHotKey($0) },
                onCancel: { viewModel.cancelRecording() }
            )
            .frame(height: 40)

            HStack {
                Spacer()
                Button("Отмена") {
                    viewModel.cancelRecording()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 180)
    }
}

@MainActor
enum SettingsShared {
    static let viewModel = SettingsViewModel()
}

@main
struct TransOnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsViewModel: SettingsViewModel

    init() {
        TransOnMigration.performIfNeeded()
        _settingsViewModel = StateObject(wrappedValue: SettingsShared.viewModel)
    }

    var body: some Scene {
        Settings {
            PreferencesView(viewModel: settingsViewModel)
        }
    }
}
