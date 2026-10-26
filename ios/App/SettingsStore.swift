import Foundation
import SwiftUI
import WidgetKit

/// Owns the editable settings, saves them (debounced) and asks WidgetKit to
/// reload the widget after each change.
final class SettingsStore: ObservableObject {
    @Published var settings: LauncherSettings {
        didSet { if settings != oldValue { scheduleSave() } }
    }

    let appGroupAvailable: Bool
    private var pendingSave: DispatchWorkItem?

    init() {
        settings = SettingsStorage.load()
        appGroupAvailable = SettingsStorage.isAppGroupAvailable
        applyLaunchArguments()
    }

    /// Launch arguments used by the simulator screenshot workflow, e.g.
    /// `-MarginTheme terminal -MarginAppearance light`.
    private func applyLaunchArguments() {
        let args = UserDefaults.standard
        if let theme = args.string(forKey: "MarginTheme"), ThemeLibrary.all.contains(where: { $0.id == theme }) {
            settings.themeId = theme
        }
        if let raw = args.string(forKey: "MarginAppearance"), let appearance = Appearance(rawValue: raw) {
            settings.appearance = appearance
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let snapshot = settings
        let work = DispatchWorkItem {
            SettingsStorage.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Saves immediately (called when the app goes to the background).
    func flush() {
        guard let work = pendingSave else { return }
        work.cancel()
        pendingSave = nil
        SettingsStorage.save(settings)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reset() {
        settings = .defaults
    }

    func exportJSON() -> String {
        String(data: settings.encoded(pretty: true), encoding: .utf8) ?? "{}"
    }

    func importJSON(_ text: String) throws {
        settings = try LauncherSettings.decodeMerged(Data(text.utf8))
    }

    // MARK: Shortcuts

    func addShortcut(name: String, url: String) {
        settings.shortcuts.append(Shortcut(id: UUID().uuidString, name: name, url: url, visible: true))
    }

    func deleteShortcut(id: String) {
        settings.shortcuts.removeAll { $0.id == id }
    }

    func moveShortcut(id: String, by offset: Int) {
        guard let index = settings.shortcuts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard settings.shortcuts.indices.contains(target) else { return }
        settings.shortcuts.swapAt(index, target)
    }
}
