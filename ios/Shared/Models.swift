import Foundation

// The settings model. Its JSON shape is defined by shared/defaults.json and is
// shared with the browser preview (preview/). scripts/check.mjs verifies that
// the keys and enum values here match the JSON, so keep them in sync.

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
}

enum TextAlign: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
}

enum FontDesignChoice: String, Codable, CaseIterable, Identifiable {
    case theme, system, serif, monospaced, rounded
    var id: String { rawValue }
}

enum WeightChoice: String, Codable, CaseIterable, Identifiable {
    case ultraLight, thin, light, regular, medium, semibold, bold
    var id: String { rawValue }
}

enum LabelCase: String, Codable, CaseIterable, Identifiable {
    case none, lower, upper
    var id: String { rawValue }

    func apply(_ text: String) -> String {
        switch self {
        case .none: return text
        case .lower: return text.lowercased()
        case .upper: return text.uppercased()
        }
    }
}

enum DateStyleChoice: String, Codable, CaseIterable, Identifiable {
    case long, short, numeric
    var id: String { rawValue }
}

enum LaunchMode: String, Codable, CaseIterable, Identifiable {
    /// The widget link opens the target URL directly.
    case direct
    /// The widget opens Margin, which then opens the target URL.
    case viaApp
    var id: String { rawValue }
}

struct Shortcut: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var url: String
    var visible: Bool
}

struct Typography: Codable, Hashable {
    var fontDesign: FontDesignChoice
    var clockSize: Double
    var clockWeight: WeightChoice
    var labelSize: Double
    var labelWeight: WeightChoice
    var metaSize: Double
    var tracking: Double
    var labelCase: LabelCase
}

struct LayoutSettings: Codable, Hashable {
    var alignment: TextAlign
    var itemSpacing: Double
    var padding: Double
}

/// Hex strings ("#RRGGBB"). An empty string means "use the theme colour".
struct ColorOverrides: Codable, Hashable {
    var background: String
    var foreground: String
    var secondary: String
    var accent: String
}

struct HeaderSettings: Codable, Hashable {
    var showClock: Bool
    var use24Hour: Bool
    var showDate: Bool
    var dateStyle: DateStyleChoice
    var showMotto: Bool
    var motto: String
    var showAccentDot: Bool
}

struct WidgetSettings: Codable, Hashable {
    var showClock: Bool
    var showDate: Bool
    var showMotto: Bool
    var clockSize: Double
    var labelSize: Double
    var launchMode: LaunchMode
}

struct LauncherSettings: Codable, Hashable {
    var schemaVersion: Int
    var themeId: String
    var appearance: Appearance
    var typography: Typography
    var layout: LayoutSettings
    var colors: ColorOverrides
    var header: HeaderSettings
    var widget: WidgetSettings
    var shortcuts: [Shortcut]

    var visibleShortcuts: [Shortcut] {
        shortcuts.filter { $0.visible && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - Decoding with defaults

extension LauncherSettings {
    /// Built from shared/defaults.json (embedded at build time).
    static let defaults: LauncherSettings = {
        do {
            return try JSONDecoder().decode(LauncherSettings.self, from: Data(SharedResources.defaultsJSON.utf8))
        } catch {
            fatalError("shared/defaults.json does not match LauncherSettings: \(error)")
        }
    }()

    /// Decodes JSON that may be partial or from an older version: every missing
    /// key falls back to the default value.
    static func decodeMerged(_ data: Data) throws -> LauncherSettings {
        let base = try JSONSerialization.jsonObject(with: Data(SharedResources.defaultsJSON.utf8))
        let override = try JSONSerialization.jsonObject(with: data)
        let merged = JSONMerge.merge(base, override)
        let mergedData = try JSONSerialization.data(withJSONObject: merged)
        return try JSONDecoder().decode(LauncherSettings.self, from: mergedData)
    }

    func encoded(pretty: Bool = false) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }
}

enum JSONMerge {
    /// Deep-merges dictionaries; any other value in `override` replaces `base`.
    static func merge(_ base: Any, _ override: Any) -> Any {
        guard let b = base as? [String: Any], let o = override as? [String: Any] else {
            return override
        }
        var result = b
        for (key, value) in o {
            if let existing = b[key] {
                result[key] = merge(existing, value)
            } else {
                result[key] = value
            }
        }
        return result
    }
}

// MARK: - Shortcut URLs

enum AppConstants {
    static let urlScheme = "margin"
    static let fallbackAppGroup = "group.dev.margin.app"
}

extension Shortcut {
    var targetURL: URL? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = URL(string: trimmed), parsed.scheme != nil else { return nil }
        return parsed
    }

    func launchURL(mode: LaunchMode) -> URL? {
        guard let target = targetURL else { return nil }
        switch mode {
        case .direct:
            return target
        case .viaApp:
            var components = URLComponents()
            components.scheme = AppConstants.urlScheme
            components.host = "open"
            components.queryItems = [URLQueryItem(name: "url", value: target.absoluteString)]
            return components.url
        }
    }

    /// Extracts the target from a margin://open?url=... link.
    static func target(fromRoutedURL url: URL) -> URL? {
        guard url.scheme == AppConstants.urlScheme, url.host == "open",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "url" })?.value
        else { return nil }
        return URL(string: value)
    }
}

// MARK: - Presets

struct ShortcutPreset: Codable, Identifiable, Hashable {
    var name: String
    var url: String
    var id: String { name }
}

private struct PresetCatalog: Codable {
    var version: Int
    var presets: [ShortcutPreset]
}

enum PresetLibrary {
    static let all: [ShortcutPreset] = {
        (try? JSONDecoder().decode(PresetCatalog.self, from: Data(SharedResources.presetsJSON.utf8)))?.presets ?? []
    }()

    static func named(_ name: String) -> ShortcutPreset? {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        return all.first { $0.name.lowercased() == key }
    }
}

// MARK: - Manual shortcuts (typed into the widget's edit sheet)

enum ManualShortcutParser {
    /// Parses "Music; Notes=mobilenotes://; Work=shortcuts://run-shortcut?name=Work".
    /// Entries are separated by ";" or new lines. A bare name is looked up in the presets.
    static func parse(_ text: String) -> [Shortcut] {
        let entries = text
            .split(whereSeparator: { $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return entries.enumerated().compactMap { pair -> Shortcut? in
            let index = pair.offset
            let entry = pair.element
            if let eq = entry.firstIndex(of: "=") {
                let name = entry[..<eq].trimmingCharacters(in: .whitespaces)
                let url = entry[entry.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }
                return Shortcut(id: "manual-\(index)", name: name, url: url, visible: true)
            }
            if let preset = PresetLibrary.named(entry) {
                return Shortcut(id: "manual-\(index)", name: preset.name, url: preset.url, visible: true)
            }
            return Shortcut(id: "manual-\(index)", name: entry, url: "", visible: true)
        }
    }
}
