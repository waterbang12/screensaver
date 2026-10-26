import SwiftUI
import UIKit
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject private var store: SettingsStore
    let theme: ResolvedTheme

    @State private var message: String?
    @State private var confirmReset = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 40) {
                PageTitle(text: "settings", theme: theme)
                themeSection
                typographySection
                layoutSection
                headerSection
                shortcutsSection
                widgetSection
                colorsSection
                dataSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog("Reset all settings to defaults?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { store.reset() }
        }
    }

    // MARK: Theme

    private var themeSection: some View {
        SettingsSection("Theme", theme: theme) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemeLibrary.all) { definition in
                        ThemeCard(definition: definition, scheme: theme.colorScheme, selected: store.settings.themeId == definition.id, theme: theme) {
                            store.settings.themeId = definition.id
                        }
                    }
                }
            }
            ChoiceRow(title: "appearance", options: Appearance.allCases, label: { $0.rawValue }, selection: $store.settings.appearance, theme: theme)
        }
    }

    // MARK: Typography

    private var typographySection: some View {
        SettingsSection("Typography", theme: theme) {
            ChoiceRow(title: "typeface", options: FontDesignChoice.allCases, label: { $0.rawValue }, selection: $store.settings.typography.fontDesign, theme: theme)
            SliderRow(title: "clock size", value: $store.settings.typography.clockSize, range: 32...120, step: 1, theme: theme)
            ChoiceRow(title: "clock weight", options: WeightChoice.allCases, label: { $0.rawValue }, selection: $store.settings.typography.clockWeight, theme: theme)
            SliderRow(title: "label size", value: $store.settings.typography.labelSize, range: 14...44, step: 1, theme: theme)
            ChoiceRow(title: "label weight", options: WeightChoice.allCases, label: { $0.rawValue }, selection: $store.settings.typography.labelWeight, theme: theme)
            SliderRow(title: "small text size", value: $store.settings.typography.metaSize, range: 10...20, step: 1, theme: theme)
            SliderRow(title: "letter spacing", value: $store.settings.typography.tracking, range: -1...4, step: 0.1, theme: theme)
            ChoiceRow(title: "case", options: LabelCase.allCases, label: { $0.rawValue }, selection: $store.settings.typography.labelCase, theme: theme)
        }
    }

    // MARK: Layout

    private var layoutSection: some View {
        SettingsSection("Layout", theme: theme) {
            ChoiceRow(title: "alignment", options: TextAlign.allCases, label: { $0.rawValue }, selection: $store.settings.layout.alignment, theme: theme)
            SliderRow(title: "spacing", value: $store.settings.layout.itemSpacing, range: 4...40, step: 1, theme: theme)
            SliderRow(title: "side margin", value: $store.settings.layout.padding, range: 12...56, step: 1, theme: theme)
        }
    }

    // MARK: Header

    private var headerSection: some View {
        SettingsSection("Clock & text", theme: theme) {
            Toggle("clock", isOn: $store.settings.header.showClock).toggleStyle(TextToggleStyle(theme: theme))
            Toggle("24-hour", isOn: $store.settings.header.use24Hour).toggleStyle(TextToggleStyle(theme: theme))
            Toggle("date", isOn: $store.settings.header.showDate).toggleStyle(TextToggleStyle(theme: theme))
            ChoiceRow(title: "date style", options: DateStyleChoice.allCases, label: { $0.rawValue }, selection: $store.settings.header.dateStyle, theme: theme)
            Toggle("accent dot", isOn: $store.settings.header.showAccentDot).toggleStyle(TextToggleStyle(theme: theme))
            Toggle("motto", isOn: $store.settings.header.showMotto).toggleStyle(TextToggleStyle(theme: theme))
            ThemedTextField(placeholder: "a line for yourself", text: $store.settings.header.motto, theme: theme, monospaced: false)
        }
    }

    // MARK: Shortcuts

    private var shortcutsSection: some View {
        SettingsSection("Shortcuts", theme: theme) {
            NoteText(theme: theme, text: "Tap the dot to show or hide. URL schemes are unofficial and can change between iOS versions. For any app without one, make a Shortcut that opens it and use shortcuts://run-shortcut?name=Name.")

            ForEach($store.settings.shortcuts) { $shortcut in
                ShortcutEditorRow(
                    shortcut: $shortcut, theme: theme,
                    moveUp: { store.moveShortcut(id: shortcut.id, by: -1) },
                    moveDown: { store.moveShortcut(id: shortcut.id, by: 1) },
                    delete: { store.deleteShortcut(id: shortcut.id) }
                )
            }

            HStack(spacing: 24) {
                Menu {
                    ForEach(PresetLibrary.all) { preset in
                        Button("\(preset.name)  ·  \(preset.url)") {
                            store.addShortcut(name: preset.name, url: preset.url)
                        }
                    }
                } label: {
                    Text("+ preset")
                        .font(.system(size: 15, design: theme.fontDesign))
                        .foregroundStyle(theme.foreground)
                }
                Button {
                    store.addShortcut(name: "New", url: "")
                } label: {
                    Text("+ blank")
                        .font(.system(size: 15, design: theme.fontDesign))
                        .foregroundStyle(theme.foreground)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Widget

    private var widgetSection: some View {
        SettingsSection("Widget", theme: theme) {
            Toggle("clock", isOn: $store.settings.widget.showClock).toggleStyle(TextToggleStyle(theme: theme))
            Toggle("date", isOn: $store.settings.widget.showDate).toggleStyle(TextToggleStyle(theme: theme))
            Toggle("motto", isOn: $store.settings.widget.showMotto).toggleStyle(TextToggleStyle(theme: theme))
            SliderRow(title: "clock size", value: $store.settings.widget.clockSize, range: 20...72, step: 1, theme: theme)
            SliderRow(title: "label size", value: $store.settings.widget.labelSize, range: 11...30, step: 1, theme: theme)
            ChoiceRow(title: "tap opens", options: LaunchMode.allCases, label: { $0 == .direct ? "app directly" : "via margin" }, selection: $store.settings.widget.launchMode, theme: theme)
            NoteText(theme: theme, text: "If tapping a widget shortcut opens Margin instead of the target app, choose “via margin”: the widget opens Margin, which then opens the app.")
        }
    }

    // MARK: Colors

    private var colorsSection: some View {
        SettingsSection("Colour overrides", theme: theme) {
            ColorOverrideRow(title: "background", hex: $store.settings.colors.background, fallback: theme.background, theme: theme)
            ColorOverrideRow(title: "text", hex: $store.settings.colors.foreground, fallback: theme.foreground, theme: theme)
            ColorOverrideRow(title: "secondary", hex: $store.settings.colors.secondary, fallback: theme.secondary, theme: theme)
            ColorOverrideRow(title: "accent", hex: $store.settings.colors.accent, fallback: theme.accent, theme: theme)
        }
    }

    // MARK: Data

    private var dataSection: some View {
        SettingsSection("Data", theme: theme) {
            NoteText(theme: theme, text: store.appGroupAvailable
                ? "App Group connected — the widget reads these settings."
                : "App Group unavailable in this install. The widget shows defaults; set it up from its own Edit Widget sheet.")
            TextActionButton(title: "copy settings as JSON", theme: theme) {
                UIPasteboard.general.string = store.exportJSON()
                message = "Copied."
            }
            TextActionButton(title: "paste settings from clipboard", theme: theme) {
                guard let text = UIPasteboard.general.string else {
                    message = "Clipboard is empty."
                    return
                }
                do {
                    try store.importJSON(text)
                    message = "Imported."
                } catch {
                    message = "That clipboard text is not valid Margin settings JSON."
                }
            }
            TextActionButton(title: "refresh widgets", theme: theme) {
                store.flush()
                WidgetCenter.shared.reloadAllTimelines()
                message = "Widgets asked to reload."
            }
            TextActionButton(title: "reset to defaults", theme: theme, destructive: true) {
                confirmReset = true
            }
            if let message {
                NoteText(theme: theme, text: message)
            }
        }
    }
}

// MARK: - Rows

private struct ThemeCard: View {
    let definition: ThemeDefinition
    let scheme: ColorScheme
    let selected: Bool
    let theme: ResolvedTheme
    let action: () -> Void

    var body: some View {
        let palette = definition.palette(for: scheme)
        let foreground = Color(hex: palette.foreground) ?? .white
        let secondary = Color(hex: palette.secondary) ?? .gray
        let design = definition.fontDesign.swiftUI

        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text("09:41")
                    .font(.system(size: 28, weight: .thin, design: design))
                    .foregroundStyle(foreground)
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: palette.accent) ?? .red).frame(width: 4, height: 4)
                    Text(definition.name.lowercased())
                        .font(.system(size: 12, design: design))
                        .foregroundStyle(secondary)
                }
                Spacer(minLength: 0)
                Text("music\nnotes")
                    .font(.system(size: 12, weight: .light, design: design))
                    .foregroundStyle(foreground)
            }
            .padding(14)
            .frame(width: 118, height: 124, alignment: .topLeading)
            .background(Color(hex: palette.background) ?? .black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? theme.foreground : theme.divider, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(definition.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ShortcutEditorRow: View {
    @Binding var shortcut: Shortcut
    let theme: ResolvedTheme
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    shortcut.visible.toggle()
                } label: {
                    Circle()
                        .fill(shortcut.visible ? theme.foreground : Color.clear)
                        .overlay(Circle().stroke(theme.secondary, lineWidth: 1))
                        .frame(width: 10, height: 10)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(shortcut.visible ? "Visible" : "Hidden")

                TextField("name", text: $shortcut.name)
                    .font(.system(size: 18, weight: .light, design: theme.fontDesign))
                    .foregroundStyle(shortcut.visible ? theme.foreground : theme.secondary)

                IconButton(systemName: "arrow.up", theme: theme, action: moveUp)
                IconButton(systemName: "arrow.down", theme: theme, action: moveDown)
                IconButton(systemName: "xmark", theme: theme, action: delete)
            }
            ThemedTextField(placeholder: "url scheme, e.g. music://", text: $shortcut.url, theme: theme, monospaced: true)
                .padding(.leading, 34)
            Rectangle().fill(theme.divider).frame(height: 1).padding(.top, 6)
        }
    }
}

private struct IconButton: View {
    let systemName: String
    let theme: ResolvedTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(theme.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String
    let theme: ResolvedTheme
    let monospaced: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(theme.secondary.opacity(0.6)))
            .font(.system(size: monospaced ? 13 : 15, design: monospaced ? .monospaced : theme.fontDesign))
            .foregroundStyle(monospaced ? theme.secondary : theme.foreground)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(monospaced ? .URL : .default)
    }
}

private struct ColorOverrideRow: View {
    let title: String
    @Binding var hex: String
    let fallback: Color
    let theme: ResolvedTheme

    var body: some View {
        HStack(spacing: 12) {
            ColorPicker(selection: Binding(
                get: { Color(hex: hex) ?? fallback },
                set: { hex = $0.hexString }
            ), supportsOpacity: false) {
                RowLabel(text: title, theme: theme)
            }
            if !hex.isEmpty {
                Button("reset") { hex = "" }
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.secondary)
                    .buttonStyle(.plain)
            }
        }
    }
}
