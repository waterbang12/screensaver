# Margin

A minimalist iPhone home screen, in the spirit of Blank Spaces, Dumbify and Nothing OS: black space, a thin clock, and your apps as plain words.

Margin has two parts:

- **A SwiftUI app** where you design the look (themes, typography, spacing, colours, shortcuts). It also works as a full-screen text launcher you can keep in your dock.
- **A WidgetKit widget** (small, medium, large) that puts the clock and text shortcuts on your real home screen.

You can build and install it entirely from **Windows**: design in a browser preview, compile on GitHub's free macOS runners, and install with Sideloadly and a free Apple ID.

> **What Margin is not.** iOS does not let third-party apps replace the home screen (SpringBoard). Margin gives you a widget plus an app. To get the "blank" look, hide icons from the home screen with iOS's own tools (move them to the App Library, hide pages) and keep the Margin widget.

---

## Contents

1. [What you get](#what-you-get)
2. [Quick start on Windows](#quick-start-on-windows)
3. [Design preview in the browser](#design-preview-in-the-browser)
4. [Build the IPA in the cloud](#build-the-ipa-in-the-cloud)
5. [Install on your iPhone](#install-on-your-iphone)
6. [Using the app and widget](#using-the-app-and-widget)
7. [iOS limits you should know](#ios-limits-you-should-know)
8. [Project layout](#project-layout)
9. [Customising the code](#customising-the-code)
10. [Troubleshooting](#troubleshooting)

---

## What you get

| | |
|---|---|
| Themes | **Void** (pure black, default), **Monochrome** (graphite), **Terminal** (green phosphor, monospaced), **Washi** (warm paper and sumi ink, serif). Each has a light and dark version. |
| Appearance | Follow the system, or always light or always dark |
| Typography | Typeface (system, serif, monospaced, rounded, or the theme's own), clock size and weight, label size and weight, small text size, letter spacing, case |
| Layout | Leading, centre or trailing alignment; spacing; side margin |
| Clock and text | Clock (12/24-hour), date (three styles), accent dot, optional motto |
| Shortcuts | Any number of name + URL pairs, which you can reorder, hide or show. Includes 21 presets. |
| Widget | Small, medium and large sizes; separate clock and label sizes; option to open apps directly or through Margin |
| Colours | Override background, text, secondary and accent colours with a colour picker |
| Sync | App and widget share settings through an App Group. When the App Group isn't available, the widget can be set up from its own Edit Widget sheet. |
| Import/export | Settings are a single JSON document, the same in the app and in the browser preview |

---

## Quick start on Windows

Requirements (all free):

- [Node.js](https://nodejs.org/) 22.2 or newer. Only the preview and the checks need it. There are no npm packages to install.
- [Git](https://git-scm.com/download/win) and a GitHub account
- [Sideloadly](https://sideloadly.io/), plus Apple's **iTunes** and **iCloud for Windows** (see [docs/INSTALL.md](docs/INSTALL.md))

```powershell
# 1. Open the live design preview (opens your browser)
powershell -ExecutionPolicy Bypass -File scripts\preview.ps1

# 2. Run the local checks (JSON vs Swift model, colours, constants, syntax)
powershell -ExecutionPolicy Bypass -File scripts\check.ps1

# 3. Push to GitHub. The build workflow produces Margin-unsigned.ipa
git init -b main
git add .
git commit -m "Margin"
git remote add origin https://github.com/<you>/margin.git
git push -u origin main
```

If you prefer npm: `npm run preview`, `npm run check`.

---

## Design preview in the browser

`scripts\preview.ps1` starts a small local server (no dependencies) at http://localhost:5173 and opens it.

- **iPhone mockup** (393 × 852 pt, the size of an iPhone 15 or 16) with two views: **home screen** (wallpaper, widget, app icon placeholders, dock) and **app** (Margin's own launcher page)
- **Widget sizes**: S, M and L in the mockup, plus an actual-size strip with all three. **Compare themes** shows one medium widget per theme.
- **Every setting** from the iOS app, with the same ranges and options. The option lists come from the Swift enums, so the two can't disagree.
- **Instant updates** while you drag sliders or type. When you edit files in `preview/`, `shared/` or `ios/Shared/`, the page reloads by itself within about 0.2 s and keeps your settings.
- **Copy JSON / Import**: move a design between the browser and the iPhone app (Settings → Data).
- URL shortcuts for comparisons: `?view=app&size=large&theme=washi&appearance=light&freeze=1`

> **It's an approximation.** The browser draws the layout with web stand-in fonts (Inter, Newsreader, JetBrains Mono and Nunito instead of SF Pro, New York, SF Mono and SF Rounded) and estimates iOS text metrics. Spacing, sizes, colours and layout logic match the Swift code, and `scripts/check.mjs` verifies the shared constants. Glyph shapes, line heights and truncation can still differ by a few points. For pixel-accurate iOS rendering, run the **simulator screenshots** workflow or look at your phone.

### Why not SwiftUI-CrossPreview?

I evaluated [SwiftUI-CrossPreview](https://github.com/EhsanAzish80/SwiftUI-CrossPreview). It's a VS Code extension that parses SwiftUI source with tree-sitter and draws an HTML approximation. It **doesn't run any Swift code**, so views whose content comes from data (our settings, themes, `ForEach` over shortcuts, computed properties, `GeometryReader` maths, WidgetKit types) can't be shown with real values. It can still give you a rough structural sketch of simple static views, so it's an optional extra. Details and setup are in [docs/PREVIEW.md](docs/PREVIEW.md).

---

## Build the IPA in the cloud

Two workflows live in `.github/workflows/`:

### `ios-build.yml`: unsigned IPA (runs on every push to `main`, on pull requests, and manually)

1. **checks** (Ubuntu): `sync-shared.mjs --check` and `check.mjs`
2. **build** (macOS 15):
   - picks the newest stable Xcode on the runner
   - installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) and generates `Margin.xcodeproj` from `project.yml`
   - runs `xcodebuild` for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO`, so **no Apple account or certificate is needed**
   - confirms the widget extension is embedded, then records the App Group entitlements with an ad-hoc signature
   - uploads **`Margin-unsigned-ipa`** (the IPA) and **`build-logs`**

When compilation fails, the job writes the first compiler errors into the run's **Summary** page and adds them as annotations. The full log is in the `build-logs` artifact.

### `ios-simulator.yml`: tests and screenshots (manual)

Open **Actions → iOS simulator → Run workflow**. The job:

- picks an available iPhone simulator on the newest iOS 17+ runtime the runner actually has (it doesn't hard-code a device name, so GitHub image updates don't break it)
- builds the app and tests, boots the simulator and sets the status bar to 9:41
- installs the app and captures 11 screenshots: home, widget S/M/L and settings in different themes, plus SpringBoard
- runs the unit tests (settings decoding, themes, URL routing, parser, formats)
- uploads **`screenshots`** and **`simulator-logs`** (including the `.xcresult`)

There's one limitation: no command-line tool can place a widget on the simulator's home screen. The widget screenshots show the **same SwiftUI view** (`WidgetLayoutView`) rendered inside the app's Widget tab.

### Pinning Xcode

Both workflows use `xcode-version: latest-stable`. If a future Xcode breaks the build, change it to a version on the runner image, for example `'16.4'`. The [runner image list](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md) shows which versions are installed.

---

## Install on your iPhone

The full step-by-step guide is in **[docs/INSTALL.md](docs/INSTALL.md)**. In short:

1. GitHub → **Actions** → latest green **iOS build** run → download **Margin-unsigned-ipa** and unzip it to get `Margin-unsigned.ipa`.
2. Connect the iPhone by USB → open Sideloadly → drop in the IPA → enter your Apple ID → **Start**.
3. On the iPhone, turn on **Developer Mode** (iOS 16+) and **trust** your Apple ID under Settings → General → VPN & Device Management.
4. Long-press the home screen → **Edit → Add Widget** → **Margin**.
5. With a free Apple ID the install **expires after 7 days**. Re-install with Sideloadly (your settings are kept), or turn on Sideloadly's auto-refresh.

---

## Using the app and widget

**App tabs** (text tab bar at the bottom):

- **home**: the full-screen launcher. Tap a word to open that app.
- **widget**: the widget on a mock home screen, in S/M/L, using the real widget view code. It also shows whether the App Group sync is working.
- **settings**: everything listed above, plus Data: copy or paste settings JSON, refresh widgets, reset.

**Shortcut URLs.** iOS has no official API for launching other apps by name. Margin opens URL schemes such as `music://`, `mobilenotes://` and `spotify://`. These are community-known, not documented by Apple, and can change between iOS versions. **For any app without a scheme**, make a Shortcut in Apple's Shortcuts app with the action *Open App → (the app)*, name it (for example `Camera`), and use:

```
shortcuts://run-shortcut?name=Camera
```

The Shortcuts app opens for a moment, then the target app opens. The `Camera` and `Phone` presets work this way.

**Widget edit sheet** (long-press the widget → Edit Widget):

- *Theme*: use the app's theme or override it for this widget, so you can have several widgets with different themes
- *Shortcuts (optional)*: type `Music; Notes; Work=shortcuts://run-shortcut?name=Work`. Bare names are looked up in the presets. This list replaces the app's list for that widget, which is the fallback when App Group sync isn't available.

---

## iOS limits you should know

| Limit | What Margin does |
|---|---|
| Apps can't replace SpringBoard or hide other apps' icons | You hide icons with iOS (App Library, hidden pages). Margin provides the widget and a launcher app. |
| **Small widgets have one tap target** (iOS ignores `Link`s inside them) | A small widget shows the clock and date. Tapping it opens your **first** visible shortcut, and its name is shown at the bottom. |
| Medium and large widgets support a `Link` per row | Medium shows up to 4 shortcuts, large up to 8. Rows that don't fit at your chosen size are left out. |
| Widgets are static snapshots. iOS decides when to refresh them (reload budget). | The clock is a pre-built timeline of 120 one-minute entries. Entries inside a timeline don't use up the reload budget. iOS can still deliver a minute a few seconds late. With the clock off, the widget refreshes at midnight. |
| Opening other apps from a widget | By default the widget link opens the target URL directly. If your iOS version opens Margin instead, switch **tap opens → via margin**: the widget opens Margin, which opens the target (you'll see Margin flash briefly). |
| Undocumented URL schemes | Presets are best-effort. Use the Shortcuts trick for anything that doesn't open. |
| App Groups and free-Apple-ID re-signing | Whether Sideloadly keeps a working App Group with a free account isn't guaranteed. Margin detects this and tells you. The widget then works from its own Edit Widget settings. See [docs/INSTALL.md](docs/INSTALL.md#app-groups-and-the-widget). |
| Free Apple ID signing expires after 7 days. Limits: 3 sideloaded apps and 10 App IDs per week. | Margin uses 2 App IDs per install (app + widget). Re-installing over the existing app keeps your settings. |
| Custom fonts | The app uses Apple's system font designs (SF, New York, SF Mono, SF Rounded), so no font files are bundled. |

---

## Project layout

```
project.yml                  XcodeGen spec → Margin.xcodeproj (generated in CI)
shared/
  themes.json                the four themes (single source of truth)
  defaults.json              default settings = settings JSON schema
  presets.json               shortcut URL presets
ios/
  Shared/                    compiled into app, widget and tests
    Models.swift             settings model, JSON merge, URLs, presets, parser
    Theme.swift              theme loading/resolution, Color(hex:)
    Storage.swift            App Group detection + persistence
    Formatting.swift         clock/date formats
    LauncherViews.swift      reusable views: clock, date, list, WidgetLayoutView
    Generated/SharedResources.swift   shared/*.json embedded (generated)
  App/                       SwiftUI app: Home, Widget preview, Settings, controls
  Widget/                    WidgetKit extension + configuration intent
  Tests/                     XCTest unit tests (run in the simulator workflow)
preview/                     browser design preview (vanilla JS, no build step)
  render.js                  mirrors LauncherViews.swift
  app.js                     controls, mockup, import/export
  generated/shared-data.js   shared/*.json + Swift enums (generated)
scripts/
  preview.ps1 / preview-server.mjs   live preview server
  check.ps1 / check.mjs              local consistency checks
  sync-shared.mjs                    regenerates the two generated files
  make-icon.mjs                      draws the app icon PNG
  ci/                                build, package, simulator and screenshot scripts
.github/workflows/           ios-build.yml, ios-simulator.yml
docs/                        INSTALL.md, PREVIEW.md
```

**How the preview and the app stay consistent**

- Themes, defaults and presets exist only in `shared/*.json`. `sync-shared.mjs` embeds them in Swift and in the preview.
- The preview's option lists are extracted from the Swift enums.
- `check.mjs` fails if `defaults.json`/`themes.json` don't match the Swift `Codable` structs, if a layout constant differs between `LauncherViews.swift` and `render.js`, or if the App Group id differs between files.
- Settings JSON exported from either side imports into the other.

---

## Customising the code

- **Add a theme**: add it to `shared/themes.json`, add a matching case to `ThemeOption` in `ios/Widget/MarginWidget.swift`, then run `node scripts/sync-shared.mjs`. The check enforces text contrast of at least 7:1.
- **Change defaults**: edit `shared/defaults.json` and run the sync.
- **Add a setting**: add the field to the Swift struct in `Models.swift`, add it to `defaults.json`, add a control in `SettingsView.swift` and in `preview/app.js`, and use it in `LauncherViews.swift` and `render.js`.
- **Bundle id / App Group**: they're `dev.margin.app`, `dev.margin.app.widget` and `group.dev.margin.app`. To change them, edit `project.yml` (both `PRODUCT_BUNDLE_IDENTIFIER`s and both `MarginAppGroup`s), both `.entitlements` files, `AppConstants.fallbackAppGroup`, and `BUNDLE_ID` in `scripts/ci/screenshots.sh`. `check.mjs` verifies the group id matches everywhere.
- **App icon**: edit `scripts/make-icon.mjs` and run `node scripts/make-icon.mjs`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `check.mjs`: "Generated files out of date" | `node scripts/sync-shared.mjs`, then commit the result |
| CI build fails | Open the failed run's **Summary**: the first compiler errors are listed there, and the full log is in **build-logs** |
| CI fails after a GitHub image update | Pin `xcode-version` (see above) |
| Preview shows "static", not "live" | You opened `preview/index.html` directly. Use `scripts\preview.ps1` for auto-reload. Everything else works from the file. |
| Widget doesn't appear in the gallery | See [docs/INSTALL.md](docs/INSTALL.md#verify-the-widget). Usually: open the Margin app once, make sure Sideloadly didn't remove extensions, and restart the phone. |
| Widget shows default shortcuts, not yours | The App Group isn't working in this install (Margin → widget tab says so). Use Edit Widget → Shortcuts. |
| A shortcut does nothing | That URL scheme isn't valid on your iOS version. Use the Shortcuts `run-shortcut` method. |

---

## Verification status

- **Checked on Windows**: JSON and Swift model consistency, enum values, colour contrast, App Group consistency, layout-constant parity, JS syntax, Swift bracket balance, YAML validity, shell script syntax, and the browser preview rendering (checked with headless Chrome).
- **Not checked yet**: Swift compilation, the unit tests, simulator screenshots, and the install on a device. These need the GitHub Actions macOS runners or an iPhone. Run the two workflows after pushing.

License: MIT.
