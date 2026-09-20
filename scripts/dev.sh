#!/bin/bash
# Build + run the app from the build folder — no install to /Applications.
# For quick edit-test cycles. Launch-at-Login toggle behaves oddly from here;
# test it on the /Applications copy instead.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
open "$ROOT/build/.apps/TimeLeft.app"
echo "Running TimeLeft from build/.apps/ (not installed)"
