#!/bin/bash
# Build + run the app from the build folder — no install to /Applications.
# For quick edit-test cycles. Launch-at-Login toggle behaves oddly from here;
# test it on the /Applications copy instead.
# NOTE: plain `open` may hand off to an installed copy with the same bundle id.
# If your edits seem to have no effect, you launched /Applications, not this.
# Use `open -n` to force a separate instance.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
open "$ROOT/build/.apps/TimeLeft.app"
echo "Running TimeLeft from build/.apps/ (not installed)"
