#!/bin/bash
# Self-check for the calendar + timer math. No test framework, no dependency —
# swiftc compiles the pure file plus the checks, then runs it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$(xcrun --show-sdk-path)"

swiftc \
  -sdk "$SDK" \
  -parse-as-library \
  "$ROOT/YearPassing/TimeCalculations.swift" \
  "$ROOT/tests/TimeCalculationsTests.swift" \
  -o /tmp/TimeLeftTests

/tmp/TimeLeftTests
