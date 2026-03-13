import Foundation

#if canImport(Security)
import Security
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

enum TransOnControlConstants {
    static let appBundleIdentifier = "com.grigorym.TransOn"
    static let controlExtensionBundleIdentifier = "com.grigorym.TransOn.Controls"
    static let appGroupIdentifier = "group.com.grigorym.TransOn.shared"
    static let sharedDefaultsSuiteName = appGroupIdentifier
    static let controlKind = "com.grigorym.TransOn.running-control"
    static let controlIconDefaultsKey = "controlCenterIcon"
    static let menuBarDisplayModeDefaultsKey = "menuBarDisplayMode"
    static let urlScheme = "transon"
}

enum TransOnLegacyConstants {
    static let appBundleIdentifier = "com.grigorym.SelectedTextOverlay"
    static let controlExtensionBundleIdentifier = "com.grigorym.SelectedTextOverlay.Controls"
    static let appGroupIdentifier = "group.com.grigorym.SelectedTextOverlay.shared"
    static let keychainService = "com.grigorym.SelectedTextOverlay"
    static let migrationFlagKey = "transOnMigrationV1Completed"
}

enum TransOnLaunchDestination: String {
    case activate
    case settings
}

enum ControlCenterIconOption: String, CaseIterable, Identifiable {
    case translate = "translate"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .translate:
            return "Translate"
        }
    }

    var systemImageName: String {
        switch self {
        case .translate:
            return "translate"
        }
    }

    static func normalized(rawValue: String?) -> ControlCenterIconOption {
        guard let rawValue, let option = ControlCenterIconOption(rawValue: rawValue) else {
            return .translate
        }
        return option
    }
}

struct TransOnControlState: Equatable {
    let isRunning: Bool
    let statusText: String
    let icon: ControlCenterIconOption

    static func current() -> TransOnControlState {
        let isRunning = TransOnProcessStateResolver.isAppRunning()
        return TransOnControlState(
            isRunning: isRunning,
            statusText: isRunning ? "Running" : "Not Running",
            icon: TransOnSharedDefaults.shared.controlCenterIcon
        )
    }
}

enum TransOnProcessStateResolver {
    static func isAppRunning() -> Bool {
#if canImport(AppKit)
        return !NSRunningApplication
            .runningApplications(withBundleIdentifier: TransOnControlConstants.appBundleIdentifier)
            .isEmpty
#else
        return false
#endif
    }
}

final class TransOnSharedDefaults {
    static let shared = TransOnSharedDefaults()

    let userDefaults: UserDefaults

    private init() {
        userDefaults = UserDefaults(suiteName: TransOnControlConstants.sharedDefaultsSuiteName) ?? .standard
    }

    var controlCenterIcon: ControlCenterIconOption {
        ControlCenterIconOption.normalized(rawValue: userDefaults.string(forKey: TransOnControlConstants.controlIconDefaultsKey))
    }

    func setControlCenterIcon(_ icon: ControlCenterIconOption) {
        userDefaults.set(icon.rawValue, forKey: TransOnControlConstants.controlIconDefaultsKey)
    }

    var menuBarDisplayModeRaw: String {
        userDefaults.string(forKey: TransOnControlConstants.menuBarDisplayModeDefaultsKey) ?? "On"
    }

    func setMenuBarDisplayModeRaw(_ rawValue: String) {
        userDefaults.set(rawValue, forKey: TransOnControlConstants.menuBarDisplayModeDefaultsKey)
    }

    func launchDestinationForCurrentConfiguration() -> TransOnLaunchDestination {
        menuBarDisplayModeRaw == "Off" ? .settings : .activate
    }
}

#if canImport(Security)
private final class TransOnMigrationKeychainStore {
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
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }

        return false
    }
}
#endif

enum TransOnMigration {
    static func performIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: TransOnLegacyConstants.migrationFlagKey) else {
            return
        }

        migrateAppDefaults(into: defaults)
        migrateSharedDefaults()
        migrateGoogleCloudAPIKey()

        defaults.set(true, forKey: TransOnLegacyConstants.migrationFlagKey)
    }

    private static func migrateAppDefaults(into defaults: UserDefaults) {
        guard let legacyDomain = defaults.persistentDomain(forName: TransOnLegacyConstants.appBundleIdentifier) else {
            return
        }

        for (key, value) in legacyDomain where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }

    private static func migrateSharedDefaults() {
        guard
            let legacyDefaults = UserDefaults(suiteName: TransOnLegacyConstants.appGroupIdentifier),
            let legacyDomain = legacyDefaults.persistentDomain(forName: TransOnLegacyConstants.appGroupIdentifier)
        else {
            return
        }

        let newDefaults = TransOnSharedDefaults.shared.userDefaults
        for (key, value) in legacyDomain where newDefaults.object(forKey: key) == nil {
            newDefaults.set(value, forKey: key)
        }
    }

    private static func migrateGoogleCloudAPIKey() {
#if canImport(Security)
        let account = "googleCloudApiKey"
        let legacyKeychain = TransOnMigrationKeychainStore(service: TransOnLegacyConstants.keychainService)
        let newKeychain = TransOnMigrationKeychainStore(service: TransOnControlConstants.appBundleIdentifier)

        if let existing = newKeychain.read(account: account)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            return
        }

        guard let legacyValue = legacyKeychain.read(account: account)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !legacyValue.isEmpty
        else {
            return
        }

        _ = newKeychain.upsert(value: legacyValue, account: account)
#endif
    }
}

enum TransOnControlURL {
    static func makeURL(destination: TransOnLaunchDestination) -> URL {
        var components = URLComponents()
        components.scheme = TransOnControlConstants.urlScheme
        components.host = destination.rawValue
        return components.url ?? URL(string: "\(TransOnControlConstants.urlScheme)://\(destination.rawValue)")!
    }

    static func parse(_ url: URL) -> TransOnLaunchDestination? {
        guard url.scheme == TransOnControlConstants.urlScheme else {
            return nil
        }

        if let host = url.host, let destination = TransOnLaunchDestination(rawValue: host) {
            return destination
        }

        let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return TransOnLaunchDestination(rawValue: trimmedPath)
    }
}

enum TransOnControlReloader {
    static func reload() {
#if canImport(WidgetKit)
        if #available(macOS 26.0, *) {
            ControlCenter.shared.reloadControls(ofKind: TransOnControlConstants.controlKind)
        }
#endif
    }
}
