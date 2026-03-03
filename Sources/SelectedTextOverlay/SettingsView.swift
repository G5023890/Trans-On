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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .translation: return "Translation"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .translation: return "character.bubble"
        }
    }
}

struct ArgosModelItem: Identifiable, Hashable {
    let id: String
    let path: String
    let direction: String
    let sizeText: String
    let status: String
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

    @Published var selectedSection: SettingsSection = .general
    @Published private(set) var hotKey: HotKeyBinding = .default
    @Published private(set) var fontSizePt: Int = 22
    @Published private(set) var launchAtLogin: Bool = false
    @Published var isRecording = false
    @Published var hotKeyError: String?
    @Published var launchAtLoginError: String?
    @Published var maintenanceStatusMessage: String = ""
    @Published var isRunningMaintenance = false
    @Published var cloudStatusMessage: String = ""

    @Published private(set) var argosModels: [ArgosModelItem] = []
    @Published private(set) var argosOnlineStatus: String = "Unknown"
    @Published private(set) var nllbOnlineStatus: String = "Unknown"
    @Published private(set) var heRuInstalled: Bool = false
    @Published private(set) var nllbInstalled: Bool = false
    @Published private(set) var nllbSizeText: String = "—"
    @Published private(set) var nllbModelPath: String = "~/Library/Application Support/OfflineTranslators"

    var onHotKeyChanged: ((UInt32, UInt32) -> Void)?
    var onFontSizeChanged: ((CGFloat) -> Void)?
    var onCheckAndUpdateArgos: (((@escaping (Bool, String) -> Void) -> Void))?
    var onCheckAndUpdateNLLB: (((@escaping (Bool, String) -> Void) -> Void))?
    var onRemoveArgosPackages: (((@escaping (Bool, String) -> Void) -> Void))?
    var onRemoveNLLBModel: (((@escaping (Bool, String) -> Void) -> Void))?
    var onInstallArgosPair: ((String, String, @escaping (Bool, String) -> Void) -> Void)?

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
        refreshModelState()
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

    func verifyGoogleAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        AppSettings.shared.setGoogleCloudApiKey(trimmed)
        cloudStatusMessage = trimmed.isEmpty ? "Ключ пустой." : "Ключ сохранён локально."
    }

    func runArgosUpdate() {
        guard let onCheckAndUpdateArgos else {
            maintenanceStatusMessage = "Обновление Argos недоступно."
            return
        }
        isRunningMaintenance = true
        onCheckAndUpdateArgos { [weak self] _, summary in
            guard let self else { return }
            self.isRunningMaintenance = false
            self.maintenanceStatusMessage = summary
            self.refreshModelState()
        }
    }

    func runNLLBUpdate() {
        guard let onCheckAndUpdateNLLB else {
            maintenanceStatusMessage = "Обновление NLLB недоступно."
            return
        }
        isRunningMaintenance = true
        onCheckAndUpdateNLLB { [weak self] _, summary in
            guard let self else { return }
            self.isRunningMaintenance = false
            self.maintenanceStatusMessage = summary
            self.refreshModelState()
        }
    }

    func removeArgosModel(_ item: ArgosModelItem) {
        isRunningMaintenance = true
        do {
            try FileManager.default.removeItem(atPath: item.path)
            isRunningMaintenance = false
            maintenanceStatusMessage = "Удалено: \(item.direction)"
            refreshModelState()
        } catch {
            isRunningMaintenance = false
            maintenanceStatusMessage = "Не удалось удалить \(item.direction): \(error.localizedDescription)"
        }
    }

    func installArgosPair(from: String, to: String) {
        guard let onInstallArgosPair else {
            maintenanceStatusMessage = "Установка новой пары Argos недоступна."
            return
        }
        isRunningMaintenance = true
        onInstallArgosPair(from, to) { [weak self] _, summary in
            guard let self else { return }
            self.isRunningMaintenance = false
            self.maintenanceStatusMessage = summary
            self.refreshModelState()
        }
    }

    func removeAllArgosModels() {
        guard let onRemoveArgosPackages else {
            maintenanceStatusMessage = "Удаление пакетов Argos недоступно."
            return
        }
        isRunningMaintenance = true
        onRemoveArgosPackages { [weak self] _, summary in
            guard let self else { return }
            self.isRunningMaintenance = false
            self.maintenanceStatusMessage = summary
            self.refreshModelState()
        }
    }

    func removeNLLBModel() {
        guard let onRemoveNLLBModel else {
            maintenanceStatusMessage = "Удаление NLLB недоступно."
            return
        }
        isRunningMaintenance = true
        onRemoveNLLBModel { [weak self] _, summary in
            guard let self else { return }
            self.isRunningMaintenance = false
            self.maintenanceStatusMessage = summary
            self.refreshModelState()
        }
    }

    func refreshModelState() {
        let home = NSHomeDirectory()
        let env = ProcessInfo.processInfo.environment
        let argosPackagesPath = env["ARGOS_PACKAGES_DIR"] ?? "\(home)/Library/Application Support/ArgosTranslate/packages"
        let offlineRoot = env["OFFLINE_TRANSLATORS_HOME"] ?? "\(home)/Library/Application Support/OfflineTranslators"
        let nllbPath = env["NLLB_MODEL_DIR"] ?? "\(offlineRoot)/nllb"

        nllbModelPath = offlineRoot.replacingOccurrences(of: home, with: "~")

        let fm = FileManager.default
        argosOnlineStatus = fm.isExecutableFile(atPath: "\(home)/Library/Application Support/ArgosTranslate/bin/argos-translate") ? "Available" : "Not available"

        var parsedItems: [ArgosModelItem] = []
        if let entries = try? fm.contentsOfDirectory(atPath: argosPackagesPath) {
            for entry in entries where !entry.hasPrefix(".") {
                let fullPath = (argosPackagesPath as NSString).appendingPathComponent(entry)
                var isDir = ObjCBool(false)
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }
                let parsed = Self.parseArgosPackageName(entry)
                let sizeText = Self.formatByteCount(Self.directorySizeBytes(atPath: fullPath))
                parsedItems.append(
                    ArgosModelItem(
                        id: fullPath,
                        path: fullPath,
                        direction: "\(parsed.from) → \(parsed.to)",
                        sizeText: sizeText,
                        status: "Installed"
                    )
                )
            }
        }
        argosModels = parsedItems.sorted { $0.direction < $1.direction }
        heRuInstalled = argosModels.contains { $0.direction == "he → ru" }

        let nllbModelBin = (nllbPath as NSString).appendingPathComponent("model.bin")
        nllbInstalled = fm.fileExists(atPath: nllbModelBin)
        nllbOnlineStatus = nllbInstalled ? "Installed" : "Not installed"
        nllbSizeText = Self.formatByteCount(Self.directorySizeBytes(atPath: nllbPath))
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

    private static func parseArgosPackageName(_ name: String) -> (from: String, to: String) {
        let pattern = #"translate-([a-z]{2,3})_([a-z]{2,3})-"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return ("?", "?")
        }
        let ns = name as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: name, options: [], range: range), match.numberOfRanges >= 3 else {
            return ("?", "?")
        }
        return (ns.substring(with: match.range(at: 1)), ns.substring(with: match.range(at: 2)))
    }

    private static func directorySizeBytes(atPath path: String) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
        var total: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let full = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: full),
               let size = attrs[.size] as? NSNumber {
                total += size.int64Value
            }
        }
        return total
    }

    private static func formatByteCount(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
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

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text(viewModel.hotKey.displayString)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Button("Изменить…") { viewModel.beginRecording() }
                }
                Button("Сбросить к дефолту") { viewModel.resetHotKeyToDefault() }
                if let error = viewModel.hotKeyError {
                    Text(error).foregroundStyle(.secondary)
                }
            }

            Section("Размер текста") {
                Stepper(
                    value: Binding(get: { viewModel.fontSizePt }, set: { viewModel.updateFontSize($0) }),
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
            }

            Section("Автозапуск") {
                Toggle(
                    "Запускать при входе в систему",
                    isOn: Binding(get: { viewModel.launchAtLogin }, set: { viewModel.updateLaunchAtLogin($0) })
                )
                if let launchAtLoginError = viewModel.launchAtLoginError {
                    Text(launchAtLoginError).foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Сбросить настройки") { viewModel.restoreDefaults() }
            }
        }
        .formStyle(.grouped)
    }
}

struct TranslationSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @AppStorage("translationEngine") private var translationEngineRaw: String = TranslationEngine.googleWeb.rawValue
    @AppStorage("googleCloudApiKey") private var googleCloudApiKeyText: String = ""

    private var translationEngine: TranslationEngine {
        get { TranslationEngine(rawValue: translationEngineRaw) ?? .googleWeb }
        nonmutating set { translationEngineRaw = newValue.rawValue }
    }

    var body: some View {
        Form {
            Section("Active Engine") {
                Picker("", selection: $translationEngineRaw) {
                    ForEach(TranslationEngine.allCases) { engine in
                        Text(engine.title).tag(engine.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            if translationEngine == .googleAPI {
                Section("Cloud Settings") {
                    SecureField("Google Cloud API key", text: $googleCloudApiKeyText)
                    Button("Проверить ключ") {
                        viewModel.verifyGoogleAPIKey(googleCloudApiKeyText)
                    }
                    Text(viewModel.cloudStatusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if TranslationEngine(rawValue: translationEngineRaw) == nil {
                translationEngineRaw = TranslationEngine.googleWeb.rawValue
                AppSettings.shared.setTranslationEngine(.googleWeb)
            }
            if googleCloudApiKeyText.isEmpty {
                googleCloudApiKeyText = AppSettings.shared.googleCloudApiKey
            }
            viewModel.refreshModelState()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $viewModel.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch viewModel.selectedSection {
            case .general:
                GeneralSettingsView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .translation:
                TranslationSettingsView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle("Настройки")
        .toolbarTitleDisplayMode(.inline)
        .frame(minWidth: 760, minHeight: 500)
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
        .onAppear {
            viewModel.refreshModelState()
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
