#!/usr/bin/env bash
# Builds Margin.app + MarginWidget.appex for real iPhones (arm64) without code
# signing. Usable in CI and on any Mac with Xcode + XcodeGen.
set -uo pipefail

CONFIG="${CONFIG:-Release}"
DERIVED="build/DerivedData"
LOG="build/logs/xcodebuild-device.log"
mkdir -p build/logs

echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "iOS SDK: $(xcrun --sdk iphoneos --show-sdk-version)"

[ -d Margin.xcodeproj ] || xcodegen generate

# CODE_SIGNING_ALLOWED=NO: no certificate or Apple account needed to compile.
# The entitlements (App Group) are applied afterwards by package-ipa.sh.
xcodebuild \
  -project Margin.xcodeproj \
  -scheme Margin \
  -configuration "$CONFIG" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build 2>&1 | tee "$LOG" | { if command -v xcbeautify >/dev/null; then xcbeautify --renderer github-actions; else cat; fi; }
status=${PIPESTATUS[0]}

if [ "$status" -ne 0 ]; then
  echo "::error title=iOS build failed::xcodebuild exited with $status. See the step summary or the build-logs artifact."
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "## iOS build failed"
      echo
      echo "First compiler errors:"
      echo
      echo '```'
      grep -E "(error:|fatal error:|ld: |\*\* BUILD FAILED)" "$LOG" | sed "s|$PWD/||" | sort -u | head -40
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  exit "$status"
fi

echo "Build succeeded: $DERIVED/Build/Products/$CONFIG-iphoneos/Margin.app"
