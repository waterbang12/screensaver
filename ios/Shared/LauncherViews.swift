import SwiftUI

// Reusable building blocks used by the app's home page, the in-app widget
// preview and the real WidgetKit widget. preview/render.js mirrors these
// layouts and constants; if you change one, change the other.

enum LayoutMetrics {
    static let headerSpacing: CGFloat = 6
    static let dotSize: CGFloat = 5
    static let clockTracking: CGFloat = -0.02   // multiplied by the clock size
    static let metaTracking: CGFloat = 0.4
    static let lineHeight: CGFloat = 1.25       // approx. SF line height / font size
    static let widgetPadding: CGFloat = 16
    static let widgetSpacingScale: CGFloat = 0.6
    static let widgetColumnSpacing: CGFloat = 12
}

struct ClockText: View {
    let date: Date
    let settings: LauncherSettings
    let theme: ResolvedTheme
    let size: Double

    var body: some View {
        Text(ClockFormat.time(date, use24Hour: settings.header.use24Hour))
            .font(.system(size: size, weight: settings.typography.clockWeight.swiftUI, design: theme.fontDesign))
            .tracking(CGFloat(size) * LayoutMetrics.clockTracking)
            .monospacedDigit()
            .foregroundStyle(theme.foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

struct DateLine: View {
    let date: Date
    let settings: LauncherSettings
    let theme: ResolvedTheme

    var body: some View {
        HStack(spacing: 6) {
            if settings.header.showAccentDot {
                Circle()
                    .fill(theme.accent)
                    .frame(width: LayoutMetrics.dotSize, height: LayoutMetrics.dotSize)
            }
            Text(settings.typography.labelCase.apply(ClockFormat.date(date, style: settings.header.dateStyle)))
                .font(.system(size: settings.typography.metaSize, weight: .regular, design: theme.fontDesign))
                .tracking(LayoutMetrics.metaTracking)
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
        }
    }
}

struct MottoText: View {
    let settings: LauncherSettings
    let theme: ResolvedTheme

    var body: some View {
        Text(settings.header.motto)
            .font(.system(size: settings.typography.metaSize, weight: .regular, design: theme.fontDesign))
            .tracking(LayoutMetrics.metaTracking)
            .foregroundStyle(theme.secondary)
            .lineLimit(2)
    }
}

struct HeaderBlock: View {
    let date: Date
    let settings: LauncherSettings
    let theme: ResolvedTheme
    let clockSize: Double
    let showClock: Bool
    let showDate: Bool
    let showMotto: Bool

    var body: some View {
        VStack(alignment: settings.layout.alignment.horizontal, spacing: LayoutMetrics.headerSpacing) {
            if showClock {
                ClockText(date: date, settings: settings, theme: theme, size: clockSize)
            }
            if showDate {
                DateLine(date: date, settings: settings, theme: theme)
            }
            if showMotto && !settings.header.motto.trimmingCharacters(in: .whitespaces).isEmpty {
                MottoText(settings: settings, theme: theme)
                    .padding(.top, 2)
            }
        }
    }
}

struct ShortcutLabel: View {
    let shortcut: Shortcut
    let settings: LauncherSettings
    let theme: ResolvedTheme
    let size: Double

    var body: some View {
        Text(settings.typography.labelCase.apply(shortcut.name))
            .font(.system(size: size, weight: settings.typography.labelWeight.swiftUI, design: theme.fontDesign))
            .tracking(settings.typography.tracking)
            .foregroundStyle(theme.foreground)
            .lineLimit(1)
    }
}

struct ShortcutList: View {
    let shortcuts: [Shortcut]
    let settings: LauncherSettings
    let theme: ResolvedTheme
    let labelSize: Double
    let spacing: Double
    let launchMode: LaunchMode

    var body: some View {
        VStack(alignment: settings.layout.alignment.horizontal, spacing: spacing) {
            ForEach(shortcuts) { shortcut in
                if let url = shortcut.launchURL(mode: launchMode) {
                    Link(destination: url) {
                        ShortcutLabel(shortcut: shortcut, settings: settings, theme: theme, size: labelSize)
                    }
                } else {
                    // No valid URL: shown dimmed so it is obvious in the preview.
                    ShortcutLabel(shortcut: shortcut, settings: settings, theme: theme, size: labelSize)
                        .opacity(0.35)
                }
            }
        }
    }
}

// MARK: - Widget layouts

enum WidgetSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }

    /// Nominal size on a 6.1" iPhone (393 pt wide). Used only by previews;
    /// the real widget receives its size from iOS.
    var previewSize: CGSize {
        switch self {
        case .small: return CGSize(width: 158, height: 158)
        case .medium: return CGSize(width: 338, height: 158)
        case .large: return CGSize(width: 338, height: 354)
        }
    }

    var maxShortcuts: Int {
        switch self {
        case .small: return 1
        case .medium: return 4
        case .large: return 8
        }
    }
}

/// The content of the home-screen widget. Rendered by WidgetKit and by the
/// app's preview screen, so both always match.
struct WidgetLayoutView: View {
    let family: WidgetSize
    let settings: LauncherSettings
    let theme: ResolvedTheme
    let date: Date

    private var widget: WidgetSettings { settings.widget }
    private var spacing: Double { settings.layout.itemSpacing * LayoutMetrics.widgetSpacingScale }
    private var hasHeader: Bool { widget.showClock || widget.showDate || (widget.showMotto && !settings.header.motto.isEmpty) }
    private var alignment: TextAlign { settings.layout.alignment }

    var body: some View {
        GeometryReader { geo in
            let inner = CGSize(
                width: max(0, geo.size.width - LayoutMetrics.widgetPadding * 2),
                height: max(0, geo.size.height - LayoutMetrics.widgetPadding * 2)
            )
            content(inner: inner)
                .frame(width: inner.width, height: inner.height, alignment: alignment.frame(vertical: .top))
                .padding(LayoutMetrics.widgetPadding)
        }
        .multilineTextAlignment(alignment.text)
    }

    @ViewBuilder
    private func content(inner: CGSize) -> some View {
        switch family {
        case .small:
            smallLayout
        case .medium:
            mediumLayout(height: inner.height)
        case .large:
            largeLayout(height: inner.height)
        }
    }

    private var header: some View {
        HeaderBlock(
            date: date, settings: settings, theme: theme, clockSize: widget.clockSize,
            showClock: widget.showClock, showDate: widget.showDate, showMotto: widget.showMotto
        )
    }

    /// How many shortcut rows fit in `height`.
    private func rowsThatFit(_ height: Double) -> Int {
        let line = widget.labelSize * LayoutMetrics.lineHeight
        let rows = Int((height + spacing) / (line + spacing))
        return max(0, min(rows, family.maxShortcuts))
    }

    private func headerHeight() -> Double {
        let meta = settings.typography.metaSize * LayoutMetrics.lineHeight
        var parts: [Double] = []
        if widget.showClock { parts.append(widget.clockSize * 1.2) }
        if widget.showDate { parts.append(meta) }
        if widget.showMotto && !settings.header.motto.isEmpty { parts.append(meta + 2) }
        guard !parts.isEmpty else { return 0 }
        return parts.reduce(0, +) + Double(parts.count - 1) * LayoutMetrics.headerSpacing
    }

    private func list(count: Int) -> some View {
        ShortcutList(
            shortcuts: Array(settings.visibleShortcuts.prefix(count)),
            settings: settings, theme: theme,
            labelSize: widget.labelSize, spacing: spacing, launchMode: widget.launchMode
        )
    }

    /// Small widgets have a single tap target (iOS ignores Links in them), so
    /// this shows the header and names the shortcut a tap opens.
    private var smallLayout: some View {
        VStack(alignment: alignment.horizontal, spacing: 0) {
            if hasHeader { header }
            Spacer(minLength: 0)
            if let first = settings.visibleShortcuts.first {
                ShortcutLabel(shortcut: first, settings: settings, theme: theme, size: widget.labelSize)
            }
        }
    }

    private func mediumLayout(height: Double) -> some View {
        HStack(alignment: .top, spacing: LayoutMetrics.widgetColumnSpacing) {
            if hasHeader {
                header
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame(vertical: .top))
            }
            list(count: rowsThatFit(height))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame(vertical: hasHeader ? .bottom : .center))
        }
    }

    private func largeLayout(height: Double) -> some View {
        let headerSpace = hasHeader ? headerHeight() + 16 : 0
        return VStack(alignment: alignment.horizontal, spacing: 0) {
            if hasHeader { header }
            Spacer(minLength: hasHeader ? 16 : 0)
            list(count: rowsThatFit(height - headerSpace))
        }
    }
}
