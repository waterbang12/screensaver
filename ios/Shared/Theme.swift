import SwiftUI

// Themes come from shared/themes.json (embedded at build time), the same file
// the browser preview reads.

struct Palette: Codable, Hashable {
    var background: String
    var foreground: String
    var secondary: String
    var accent: String
    var divider: String
}

struct ThemeDefinition: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String
    var fontDesign: FontDesignChoice
    var dark: Palette
    var light: Palette

    func palette(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? dark : light
    }
}

private struct ThemeCatalog: Codable {
    var version: Int
    var themes: [ThemeDefinition]
}

enum ThemeLibrary {
    static let all: [ThemeDefinition] = {
        let decoded = try? JSONDecoder().decode(ThemeCatalog.self, from: Data(SharedResources.themesJSON.utf8))
        let themes = decoded?.themes ?? []
        return themes.isEmpty ? [fallback] : themes
    }()

    static func theme(id: String) -> ThemeDefinition {
        all.first { $0.id == id } ?? all[0]
    }

    static let fallback = ThemeDefinition(
        id: "void", name: "Void", description: "", fontDesign: .system,
        dark: Palette(background: "#000000", foreground: "#FFFFFF", secondary: "#8A8A8A", accent: "#D71921", divider: "#1C1C1C"),
        light: Palette(background: "#FFFFFF", foreground: "#000000", secondary: "#707070", accent: "#D71921", divider: "#E8E8E8")
    )
}

/// Final colours and font design after applying appearance and user overrides.
struct ResolvedTheme {
    let background: Color
    let foreground: Color
    let secondary: Color
    let accent: Color
    let divider: Color
    let fontDesign: Font.Design
    let colorScheme: ColorScheme
}

extension LauncherSettings {
    func colorScheme(system: ColorScheme) -> ColorScheme {
        switch appearance {
        case .system: return system
        case .light: return .light
        case .dark: return .dark
        }
    }

    func resolvedTheme(system: ColorScheme) -> ResolvedTheme {
        let definition = ThemeLibrary.theme(id: themeId)
        let scheme = colorScheme(system: system)
        let palette = definition.palette(for: scheme)

        func pick(_ override: String, _ base: String) -> Color {
            Color(hex: override) ?? Color(hex: base) ?? (scheme == .dark ? .white : .black)
        }

        let design = typography.fontDesign == .theme ? definition.fontDesign : typography.fontDesign
        return ResolvedTheme(
            background: pick(colors.background, palette.background),
            foreground: pick(colors.foreground, palette.foreground),
            secondary: pick(colors.secondary, palette.secondary),
            accent: pick(colors.accent, palette.accent),
            divider: Color(hex: palette.divider) ?? .gray,
            fontDesign: design.swiftUI,
            colorScheme: scheme
        )
    }
}

extension FontDesignChoice {
    var swiftUI: Font.Design {
        switch self {
        case .theme, .system: return .default
        case .serif: return .serif
        case .monospaced: return .monospaced
        case .rounded: return .rounded
        }
    }
}

extension WeightChoice {
    var swiftUI: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension TextAlign {
    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var text: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    func frame(vertical: VerticalAlignment) -> Alignment {
        Alignment(horizontal: horizontal, vertical: vertical)
    }
}

extension Color {
    /// Parses "#RRGGBB" or "#RRGGBBAA". Returns nil for empty or invalid input.
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8, let number = UInt64(value, radix: 16) else { return nil }

        let r, g, b, a: Double
        if value.count == 6 {
            r = Double((number >> 16) & 0xFF) / 255
            g = Double((number >> 8) & 0xFF) / 255
            b = Double(number & 0xFF) / 255
            a = 1
        } else {
            r = Double((number >> 24) & 0xFF) / 255
            g = Double((number >> 16) & 0xFF) / 255
            b = Double((number >> 8) & 0xFF) / 255
            a = Double(number & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
