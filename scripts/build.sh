#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$(xcrun --show-sdk-path)"
APP="$ROOT/build/.apps/TimeLeft.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc \
  -target arm64-apple-macos13.0 \
  -sdk "$SDK" \
  "$ROOT"/YearPassing/*.swift \
  -o /tmp/TimeLeft-arm64
swiftc \
  -target x86_64-apple-macos13.0 \
  -sdk "$SDK" \
  "$ROOT"/YearPassing/*.swift \
  -o /tmp/TimeLeft-x86_64
lipo -create /tmp/TimeLeft-arm64 /tmp/TimeLeft-x86_64 \
  -output "$APP/Contents/MacOS/TimeLeft"
rm -f /tmp/TimeLeft-arm64 /tmp/TimeLeft-x86_64
cp "$ROOT/YearPassing/Info.plist" "$APP/Contents/Info.plist"

ICONSET="$ROOT/build/AppIcon.iconset"
rm -rf "$ICONSET"
swiftc \
  -target arm64-apple-macos13.0 \
  -sdk "$SDK" \
  "$ROOT/scripts/gen_icon.swift" \
  "$ROOT/YearPassing/TimeCalculations.swift" \
  -o /tmp/gen_icon
/tmp/gen_icon "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Re-sign ad-hoc AFTER all bundle contents are final (icon etc.) so the
# signature isn't stale. Required on Apple Silicon and avoids odd
# Gatekeeper errors on unsigned apps.
codesign --force --deep -s - "$APP"

echo "Built $APP"