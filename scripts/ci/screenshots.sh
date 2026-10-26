#!/usr/bin/env bash
# Installs the simulator build and captures screenshots of each screen/theme.
# Needs SIM_UDID (from pick-simulator.sh) and a built Debug-iphonesimulator app.
set -euo pipefail

: "${SIM_UDID:?run pick-simulator.sh first}"
APP="build/DerivedDataSim/Build/Products/Debug-iphonesimulator/Margin.app"
BUNDLE_ID="dev.margin.app"
OUT="build/screenshots"
mkdir -p "$OUT"

[ -d "$APP/PlugIns/MarginWidget.appex" ] || { echo "::error::Simulator app or widget extension missing"; exit 1; }

# Ad-hoc sign with entitlements so the App Group works in the simulator.
codesign --force --sign - --timestamp=none --entitlements ios/Widget/MarginWidget.entitlements "$APP/PlugIns/MarginWidget.appex"
codesign --force --sign - --timestamp=none --entitlements ios/App/Margin.entitlements "$APP"

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_UDID" -b
xcrun simctl status_bar "$SIM_UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 || true
xcrun simctl install "$SIM_UDID" "$APP"

shoot() {
  local name="$1"; shift
  xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" "$@" >/dev/null
  sleep 4
  xcrun simctl io "$SIM_UDID" screenshot --type=png "$OUT/$name.png" >/dev/null
  echo "captured $name.png"
}

#        file name                 launch arguments (read through UserDefaults)
shoot 01-home-void-dark           -MarginScreen home     -MarginTheme void     -MarginAppearance dark
shoot 02-widget-medium-void       -MarginScreen widget   -MarginTheme void     -MarginAppearance dark -MarginWidgetSize medium
shoot 03-widget-large-void        -MarginScreen widget   -MarginTheme void     -MarginAppearance dark -MarginWidgetSize large
shoot 04-widget-small-void        -MarginScreen widget   -MarginTheme void     -MarginAppearance dark -MarginWidgetSize small
shoot 05-settings-void            -MarginScreen settings -MarginTheme void     -MarginAppearance dark
shoot 06-home-mono-dark           -MarginScreen home     -MarginTheme mono     -MarginAppearance dark
shoot 07-home-terminal-dark       -MarginScreen home     -MarginTheme terminal -MarginAppearance dark
shoot 08-home-washi-light         -MarginScreen home     -MarginTheme washi    -MarginAppearance light
shoot 09-widget-medium-washi      -MarginScreen widget   -MarginTheme washi    -MarginAppearance light -MarginWidgetSize medium
shoot 10-home-void-light          -MarginScreen home     -MarginTheme void     -MarginAppearance light

# Springboard with the installed app icon. Widgets cannot be placed on the
# simulator home screen from the command line, so the real widget is not shown;
# screens 02-04 render the same SwiftUI view inside the app.
xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
sleep 2
xcrun simctl io "$SIM_UDID" screenshot --type=png "$OUT/11-springboard.png" >/dev/null
echo "captured 11-springboard.png"
