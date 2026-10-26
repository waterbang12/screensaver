import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Configuration intent
//
// Lets you pick a theme and, optionally, type shortcuts straight into the
// widget's edit sheet (long-press the widget > Edit Widget). The typed list is
// the fallback for installs where the App Group does not work, because then
// the widget cannot read the app's settings.

enum ThemeOption: String, AppEnum {
    case app, void, mono, terminal, washi

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Theme"
    static var caseDisplayRepresentations: [ThemeOption: DisplayRepresentation] = [
        .app: "Same as app",
        .void: "Void",
        .mono: "Monochrome",
        .terminal: "Terminal",
        .washi: "Washi",
    ]
}

struct MarginWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Margin"
    static var description = IntentDescription("A clock and text-only shortcuts.")

    @Parameter(title: "Theme", default: .app)
    var theme: ThemeOption

    @Parameter(title: "Shortcuts (optional)", description: "Overrides the app's list. Example: Music; Notes; Work=shortcuts://run-shortcut?name=Work")
    var manualShortcuts: String?
}

// MARK: - Timeline

struct MarginEntry: TimelineEntry {
    let date: Date
    let settings: LauncherSettings
}

struct MarginProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MarginEntry {
        MarginEntry(date: Date(), settings: .defaults)
    }

    func snapshot(for configuration: MarginWidgetIntent, in context: Context) async -> MarginEntry {
        MarginEntry(date: Date(), settings: resolve(configuration))
    }

    func timeline(for configuration: MarginWidgetIntent, in context: Context) async -> Timeline<MarginEntry> {
        let settings = resolve(configuration)
        let calendar = Calendar.current
        let now = Date()

        // Clock shown: one entry per minute for two hours. Entries inside one
        // timeline do not count against WidgetKit's reload budget, but iOS may
        // still delay some of them by a few seconds.
        guard settings.widget.showClock else {
            // Date only: refresh at the next midnight.
            let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
            return Timeline(entries: [MarginEntry(date: now, settings: settings)], policy: .after(midnight))
        }

        let start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        let entries = (0..<120).compactMap { offset -> MarginEntry? in
            guard let date = calendar.date(byAdding: .minute, value: offset, to: start) else { return nil }
            return MarginEntry(date: date, settings: settings)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func resolve(_ configuration: MarginWidgetIntent) -> LauncherSettings {
        var settings = SettingsStorage.load()
        if configuration.theme != .app {
            settings.themeId = configuration.theme.rawValue
        }
        if let manual = configuration.manualShortcuts,
           !manual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.shortcuts = ManualShortcutParser.parse(manual)
        }
        return settings
    }
}

// MARK: - Views

struct MarginWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var systemScheme
    let entry: MarginEntry

    private var size: WidgetSize {
        switch family {
        case .systemSmall: return .small
        case .systemLarge: return .large
        default: return .medium
        }
    }

    var body: some View {
        let theme = entry.settings.resolvedTheme(system: systemScheme)
        let firstURL = entry.settings.visibleShortcuts.first?.launchURL(mode: entry.settings.widget.launchMode)

        WidgetLayoutView(family: size, settings: entry.settings, theme: theme, date: entry.date)
            .containerBackground(for: .widget) { theme.background }
            // Small widgets only support one tap target.
            .widgetURL(size == .small ? firstURL : nil)
    }
}

struct MarginWidget: Widget {
    let kind = "MarginWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MarginWidgetIntent.self, provider: MarginProvider()) { entry in
            MarginWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Margin")
        .description("A clock and text-only app shortcuts.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct MarginWidgetBundle: WidgetBundle {
    var body: some Widget {
        MarginWidget()
    }
}
