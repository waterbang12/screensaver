import SwiftUI
import UIKit

// Small, text-first controls styled from the active theme.

struct PageTitle: View {
    let text: String
    let theme: ResolvedTheme

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .thin, design: theme.fontDesign))
            .tracking(-0.5)
            .foregroundStyle(theme.foreground)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let theme: ResolvedTheme
    let content: Content

    init(_ title: String, theme: ResolvedTheme, @ViewBuilder content: () -> Content) {
        self.title = title
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(theme.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RowLabel: View {
    let text: String
    let theme: ResolvedTheme

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .regular, design: theme.fontDesign))
            .foregroundStyle(theme.foreground)
    }
}

struct NoteText: View {
    let theme: ResolvedTheme
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular, design: theme.fontDesign))
            .foregroundStyle(theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A row of text options; the selected one is bright with an accent underline.
struct ChoiceRow<T: Hashable>: View {
    let title: String
    let options: [T]
    let label: (T) -> String
    @Binding var selection: T
    let theme: ResolvedTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RowLabel(text: title, theme: theme)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(options, id: \.self) { option in
                        let selected = option == selection
                        Button {
                            selection = option
                        } label: {
                            Text(label(option))
                                .font(.system(size: 14, weight: .regular, design: theme.fontDesign))
                                .foregroundStyle(selected ? theme.foreground : theme.secondary)
                                .padding(.bottom, 5)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(theme.accent)
                                        .frame(height: 1)
                                        .opacity(selected ? 1 : 0)
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let theme: ResolvedTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                RowLabel(text: title, theme: theme)
                Spacer()
                Text(step < 1 ? String(format: "%.1f", value) : String(Int(value.rounded())))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .tint(theme.foreground)
        }
    }
}

struct TextToggleStyle: ToggleStyle {
    let theme: ResolvedTheme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                configuration.label
                    .font(.system(size: 15, weight: .regular, design: theme.fontDesign))
                    .foregroundStyle(theme.foreground)
                Spacer()
                Text(configuration.isOn ? "on" : "off")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(configuration.isOn ? theme.foreground : theme.secondary)
                Circle()
                    .fill(configuration.isOn ? theme.accent : Color.clear)
                    .overlay(Circle().stroke(configuration.isOn ? theme.accent : theme.secondary, lineWidth: 1))
                    .frame(width: 9, height: 9)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TextActionButton: View {
    let title: String
    let theme: ResolvedTheme
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .regular, design: theme.fontDesign))
                    .foregroundStyle(destructive ? theme.accent : theme.foreground)
                Spacer()
                Text("→")
                    .foregroundStyle(theme.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    /// "#RRGGBB" in sRGB, used to store ColorPicker choices.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((max(0, min(1, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }
}
