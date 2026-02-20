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

    @Published private(set) var hotKey: HotKeyBinding = .default
    @Published private(set) var fontSizePt: Int = 22
    @Published private(set) var launchAtLogin: Bool = false
    @Published var isRecording = false
    @Published var hotKeyError: String?
    @Published var launchAtLoginError: String?

    var onHotKeyChanged: ((UInt32, UInt32) -> Void)?
    var onFontSizeChanged: ((CGFloat) -> Void)?

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

    func restoreDefaults() {
        resetHotKeyToDefault()
        updateFontSize(22)
        updateLaunchAtLogin(false)
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

private struct CloseShortcutBridge: View {
    var body: some View {
        Button(action: {
            NSApp.keyWindow?.performClose(nil)
        }, label: {
            EmptyView()
        })
        .keyboardShortcut("w", modifiers: .command)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}

private struct HotKeyRecorderSheet: View {
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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.35))
            )

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

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Горячая клавиша") {
                HStack {
                    Text(viewModel.hotKey.displayString)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Button("Изменить…") {
                        viewModel.beginRecording()
                    }
                    .buttonStyle(.borderless)
                }

                Button("Сбросить к дефолту") {
                    viewModel.resetHotKeyToDefault()
                }
                .buttonStyle(.borderless)

                Text("Открывает окно перевода выделенного текста")
                    .foregroundStyle(.secondary)

                if let error = viewModel.hotKeyError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section("Размер шрифта текста") {
                Stepper(
                    value: Binding(
                        get: { viewModel.fontSizePt },
                        set: { viewModel.updateFontSize($0) }
                    ),
                    in: 12...24
                ) {
                    HStack {
                        Text("Размер")
                        Spacer()
                        Text("\(viewModel.fontSizePt) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Пример: Привет, мир")
                    .font(.system(size: CGFloat(viewModel.fontSizePt), weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("Поведение") {
                Toggle(
                    "Запускать при входе в систему",
                    isOn: Binding(
                        get: { viewModel.launchAtLogin },
                        set: { viewModel.updateLaunchAtLogin($0) }
                    )
                )

                if let launchAtLoginError = viewModel.launchAtLoginError {
                    Text(launchAtLoginError)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Восстановить по умолчанию") {
                    viewModel.restoreDefaults()
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 6)
        .background(CloseShortcutBridge())
        .frame(minWidth: 520, minHeight: 430)
        .sheet(isPresented: Binding(
            get: { viewModel.isRecording },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelRecording()
                }
            }
        )) {
            HotKeyRecorderSheet(viewModel: viewModel)
        }
    }
}

@MainActor
enum SettingsShared {
    static let viewModel = SettingsViewModel()
}

@main
struct TransOnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsViewModel = SettingsShared.viewModel

    var body: some Scene {
        Settings {
            SettingsView(viewModel: settingsViewModel)
        }
    }
}
