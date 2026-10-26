#!/usr/bin/env bash
# Wraps the unsigned build into build/Margin-unsigned.ipa for Sideloadly.
#
# The binaries get an ad-hoc signature ("-") that carries the entitlements
# file. That is not an Apple signature (it will not install as-is); it only
# records which entitlements (the App Group) the app asks for, so the
# re-signing tool can see them. Sideloadly replaces it with your Apple ID's
# signature during install.
set -euo pipefail

CONFIG="${CONFIG:-Release}"
APP="build/DerivedData/Build/Products/$CONFIG-iphoneos/Margin.app"
APPEX="$APP/PlugIns/MarginWidget.appex"
OUT="build/Margin-unsigned.ipa"

if [ ! -d "$APP" ]; then
  echo "::error::$APP not found. Run scripts/ci/build-device.sh first."
  exit 1
fi
if [ ! -d "$APPEX" ]; then
  echo "::error::Widget extension missing from $APP/PlugIns. The widget would not appear on the iPhone."
  exit 1
fi

# Sign inside-out: extension first, then the app.
codesign --force --sign - --timestamp=none --entitlements ios/Widget/MarginWidget.entitlements "$APPEX"
codesign --force --sign - --timestamp=none --entitlements ios/App/Margin.entitlements "$APP"

echo "Entitlements recorded in the app:"
codesign -d --entitlements - "$APP" 2>/dev/null || true
echo "Entitlements recorded in the widget:"
codesign -d --entitlements - "$APPEX" 2>/dev/null || true

rm -rf build/ipa "$OUT"
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
(cd build/ipa && zip -qry ../Margin-unsigned.ipa Payload)

echo "Contents:"
unzip -l "$OUT" | grep -E "Margin.app/(Margin|Info.plist)$|MarginWidget.appex/(MarginWidget|Info.plist)$" || true
ls -lh "$OUT"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Info.plist" 2>/dev/null || echo "?")
  {
    echo "## Margin-unsigned.ipa ready"
    echo
    echo "- Version: $VERSION"
    echo "- Size: $(du -h "$OUT" | cut -f1)"
    echo "- Widget extension: included (PlugIns/MarginWidget.appex)"
    echo "- Signing: none (ad-hoc placeholder). Sign and install with Sideloadly — see docs/INSTALL.md."
  } >> "$GITHUB_STEP_SUMMARY"
fi
