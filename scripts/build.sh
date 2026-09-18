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
  -o "$APP/Contents/MacOS/TimeLeft"
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

echo "Built $APP"