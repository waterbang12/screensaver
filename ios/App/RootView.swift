import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, widget, settings
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var store: SettingsStore
    @Environment(\.colorScheme) private var systemScheme

    // `-MarginScreen widget` selects the starting tab (used for screenshots).
    @State private var tab: AppTab = AppTab(rawValue: UserDefaults.standard.string(forKey: "MarginScreen") ?? "") ?? .home

    var body: some View {
        let settings = store.settings
        let theme = settings.resolvedTheme(system: systemScheme)

        ZStack {
            theme.background.ignoresSafeArea()

            switch tab {
            case .home:
                HomeView(settings: settings, theme: theme)
            case .widget:
                WidgetPreviewView(settings: settings, theme: theme, appGroupAvailable: store.appGroupAvailable)
            case .settings:
                SettingsView(theme: theme)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(selection: $tab, theme: theme, design: theme.fontDesign)
        }
        .preferredColorScheme(settings.appearance == .system ? nil : theme.colorScheme)
        .tint(theme.foreground)
    }
}

/// Text-only tab bar.
struct TabBar: View {
    @Binding var selection: AppTab
    let theme: ResolvedTheme
    let design: Font.Design

    var body: some View {
        HStack(spacing: 32) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .regular, design: design))
                            .tracking(0.6)
                            .foregroundStyle(selection == tab ? theme.foreground : theme.secondary)
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 4, height: 4)
                            .opacity(selection == tab ? 1 : 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .background(theme.background)
    }
}
