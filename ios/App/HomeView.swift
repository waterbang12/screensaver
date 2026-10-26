import SwiftUI

/// The full-screen minimalist home page. Useful as a launcher you open from
/// the dock, and as the reference design for the widget.
struct HomeView: View {
    let settings: LauncherSettings
    let theme: ResolvedTheme

    var body: some View {
        let align = settings.layout.alignment

        VStack(alignment: align.horizontal, spacing: 0) {
            TimelineView(.everyMinute) { context in
                HeaderBlock(
                    date: context.date, settings: settings, theme: theme,
                    clockSize: settings.typography.clockSize,
                    showClock: settings.header.showClock,
                    showDate: settings.header.showDate,
                    showMotto: settings.header.showMotto
                )
            }

            Spacer(minLength: 32)

            ViewThatFits(in: .vertical) {
                list
                ScrollView(showsIndicators: false) { list }
            }
        }
        .multilineTextAlignment(align.text)
        .padding(.horizontal, settings.layout.padding)
        .padding(.top, 40)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align.frame(vertical: .top))
    }

    private var list: some View {
        ShortcutList(
            shortcuts: settings.visibleShortcuts,
            settings: settings, theme: theme,
            labelSize: settings.typography.labelSize,
            spacing: settings.layout.itemSpacing,
            launchMode: .direct
        )
        .frame(maxWidth: .infinity, alignment: settings.layout.alignment.frame(vertical: .center))
    }
}
