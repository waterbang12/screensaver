import SwiftUI

/// Shows the widget on a mock home screen. It renders the same
/// WidgetLayoutView the real widget uses, at nominal 6.1" iPhone sizes.
struct WidgetPreviewView: View {
    let settings: LauncherSettings
    let theme: ResolvedTheme
    let appGroupAvailable: Bool

    @State private var size: WidgetSize = WidgetSize(rawValue: UserDefaults.standard.string(forKey: "MarginWidgetSize") ?? "") ?? .medium
    @State private var showBounds = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                PageTitle(text: "widget", theme: theme)

                ChoiceRow(title: "size", options: WidgetSize.allCases, label: { $0.rawValue }, selection: $size, theme: theme)

                TimelineView(.everyMinute) { context in
                    homeScreen(date: context.date)
                }
                .frame(maxWidth: .infinity)

                Toggle("show widget bounds", isOn: $showBounds)
                    .toggleStyle(TextToggleStyle(theme: theme))

                notes
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    // MARK: Mock home screen

    private func widget(date: Date) -> some View {
        WidgetLayoutView(family: size, settings: settings, theme: theme, date: date)
            .frame(width: size.previewSize.width, height: size.previewSize.height)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                if showBounds {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(theme.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .allowsHitTesting(false)
    }

    private func iconRow(count: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                if index > 0 { Spacer(minLength: 0) }
                AppIconPlaceholder(theme: theme)
            }
        }
    }

    @ViewBuilder
    private func homeScreen(date: Date) -> some View {
        let width = WidgetSize.medium.previewSize.width

        VStack(spacing: 24) {
            switch size {
            case .small:
                HStack(alignment: .top, spacing: 0) {
                    widget(date: date)
                    Spacer(minLength: 0)
                    VStack(spacing: 18) {
                        HStack(spacing: 18) { AppIconPlaceholder(theme: theme); AppIconPlaceholder(theme: theme) }
                        HStack(spacing: 18) { AppIconPlaceholder(theme: theme); AppIconPlaceholder(theme: theme) }
                    }
                    .frame(width: 158)
                }
                iconRow(count: 4)
            case .medium:
                widget(date: date)
                iconRow(count: 4)
            case .large:
                widget(date: date)
            }
        }
        .frame(width: width)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(theme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.divider, lineWidth: 1)
        )
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            NoteText(theme: theme, text: "Add it: long-press the home screen → Edit → Add Widget → Margin. Medium and large widgets have one tap target per shortcut; a small widget opens its first shortcut.")
            NoteText(theme: theme, text: appGroupAvailable
                ? "Sync: App Group connected. Changes reach the widget within a few seconds."
                : "Sync: App Group unavailable in this install, so the widget cannot read these settings. Long-press the widget → Edit Widget to pick a theme and type shortcuts there.")
            NoteText(theme: theme, text: "iOS decides when widgets refresh. The clock is pre-scheduled minute by minute and can lag by a few seconds.")
        }
    }
}

private struct AppIconPlaceholder: View {
    let theme: ResolvedTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.divider)
            .frame(width: 60, height: 60)
    }
}
