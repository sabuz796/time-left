#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"

STAGE="$ROOT/build/.dmg-src"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$ROOT/build/.apps/TimeLeft.app" "$STAGE/"

(cd "$ROOT" && swift scripts/gen_bg.swift)

mkdir -p "$ROOT/dist"
hdiutil create \
  -volname "Time Left" \
  -srcfolder "$STAGE" \
  -format UDZO \
  -ov \
  "$ROOT/dist/TimeLeft.dmg"

echo "Built $ROOT/dist/TimeLeft.dmg"