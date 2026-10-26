import Foundation

/// Reads and writes settings. Uses the App Group container when the signed
/// build has the App Group entitlement, so the widget sees the app's settings.
/// Without it, each process falls back to its own UserDefaults.
enum SettingsStorage {
    static let key = "launcherSettings.v1"

    /// The App Group id comes from the "MarginAppGroup" Info.plist key so it can
    /// be changed without touching code. A couple of common variants are tried in
    /// case a re-signing tool renamed the group.
    static let appGroupID: String? = {
        var candidates: [String] = []
        if let configured = Bundle.main.object(forInfoDictionaryKey: "MarginAppGroup") as? String, !configured.isEmpty {
            candidates.append(configured)
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            // The widget's id is "<app id>.widget"; the group is named after the app id.
            let appID = bundleID.hasSuffix(".widget") ? String(bundleID.dropLast(".widget".count)) : bundleID
            candidates.append("group.\(appID)")
        }
        candidates.append(AppConstants.fallbackAppGroup)

        return candidates.first { id in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
        }
    }()

    static var isAppGroupAvailable: Bool { appGroupID != nil }

    static var store: UserDefaults {
        if let id = appGroupID, let shared = UserDefaults(suiteName: id) {
            return shared
        }
        return .standard
    }

    static var hasStoredSettings: Bool {
        store.data(forKey: key) != nil
    }

    static func load() -> LauncherSettings {
        guard let data = store.data(forKey: key),
              let settings = try? LauncherSettings.decodeMerged(data)
        else { return .defaults }
        return settings
    }

    static func save(_ settings: LauncherSettings) {
        store.set(settings.encoded(), forKey: key)
    }
}
