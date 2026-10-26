# Previewing SwiftUI from Windows

## Summary

| Option | Shows our real UI? | Use it for |
|---|---|---|
| **Margin browser preview** (`scripts\preview.ps1`) | Close approximation with real settings, themes and layout logic | Day-to-day design work |
| **Simulator screenshots** (`ios-simulator.yml`) | Yes: real iOS rendering | Checking the final result |
| **SwiftUI-CrossPreview** (VS Code extension) | No: only a structural sketch | Optional, glancing at static view code |

## SwiftUI-CrossPreview: findings

Repository: https://github.com/EhsanAzish80/SwiftUI-CrossPreview (MIT, VS Code extension). Assessed October 2026.

**How it works.** It parses `.swift` files with tree-sitter-swift into a view tree and draws that as HTML/CSS in a VS Code webview. It updates about 300 ms after you stop typing. It doesn't need a Swift toolchain and runs on Windows.

**What it can't do**, according to its README:

- It doesn't execute code: "SwiftUI logic doesn't run". `@State` and `@Binding` appear as badges only.
- Button actions, navigation and animations don't run.
- Environment values, custom shapes and Canvas are on its roadmap, so they aren't supported yet.
- It doesn't mention WidgetKit.

**What that means for Margin.** Almost everything on screen here comes from data:

- `HeaderBlock`, `ShortcutList` and `WidgetLayoutView` read their text, sizes, weights, colours and alignment from `LauncherSettings`, which is decoded from JSON at runtime.
- The shortcut list is a `ForEach` over user data, and the widget computes how many rows fit with `GeometryReader` arithmetic.
- Colours come from `Color(hex:)` on theme strings, and the widget uses `containerBackground`, `widgetURL` and `AppIntentConfiguration`.

A static parser can't resolve any of this. CrossPreview would show empty or placeholder text with default fonts and colours. **It can't preview our components meaningfully**, so Margin uses its own browser preview instead.

**If you want it anyway**, for example to sketch a new static view:

1. VS Code → Extensions (`Ctrl+Shift+X`) → search **SwiftUI CrossPreview** → Install.
2. Open a `.swift` file containing a SwiftUI `View`.
3. `Ctrl+Shift+P` → **SwiftUI CrossPreview: Open Preview**.

It doesn't conflict with anything in this repository.

## Margin browser preview: how fidelity is kept

- **Same data**: `shared/themes.json`, `defaults.json` and `presets.json` are the only copies. `scripts/sync-shared.mjs` generates `ios/Shared/Generated/SharedResources.swift` and `preview/generated/shared-data.js` from them.
- **Same options**: the preview's choice lists are extracted from the Swift enums in `Models.swift`.
- **Same layout**: `preview/render.js` follows `ios/Shared/LauncherViews.swift` view by view (`HeaderBlock`, `DateLine`, `ShortcutList`, `WidgetLayoutView` small/medium/large, `HomeView`, `TabBar`), with the same `LayoutMetrics` constants. `scripts/check.mjs` fails if any constant differs.
- **Same sizes**: 1 CSS px = 1 pt. The phone screen is 393 × 852 pt and the widgets are 158², 338 × 158 and 338 × 354 pt (6.1″ iPhone).

**Known differences** from iOS:

- Fonts: Inter, Newsreader, JetBrains Mono and Nunito stand in for SF Pro, New York, SF Mono and SF Rounded. On a Mac or iPhone browser, the real Apple fonts are used.
- Text metrics: SwiftUI line heights are approximated as 1.2× font size, and the widget row count uses the same 1.25× estimate as Swift.
- `minimumScaleFactor`: SwiftUI shrinks an over-long clock, while the browser lets it overflow.
- Real widget sizes vary by iPhone model, and iOS can add its own margins in StandBy or tinted modes.
- Date words follow your browser's locale. On the phone they follow the iPhone's locale.

## Live editing workflow

```
scripts\preview.ps1          # opens http://localhost:5173
```

- Drag sliders or edit fields: the update is instant.
- Edit `preview/*.js|css|html`: the page reloads.
- Edit `shared/*.json` or `ios/Shared/*.swift`: the server re-runs the sync, then the page reloads.
- Settings persist in the browser's localStorage across reloads. Use **Reset** to clear them.
