#!/usr/bin/env bash
# check-template-drift.sh — Verify that script copies match their canonical source.
#
# Usage: check-template-drift.sh [<repo-root>]
#
# This plugin currently has no duplicated scripts or templates that require
# drift checking. This script is a placeholder that maintains the consistent
# plugin structure expected by CI and /propagate-templates.
#
# If shared scripts are added in the future (e.g., scan-modules.sh copies
# in consuming skills), add compare() calls here.
#
# Exits non-zero if any copy has diverged.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PLUGIN_ROOT="$REPO_ROOT/plugins/principled-architecture"

DRIFTED=0
CHECKED=0

compare() {
  local canonical="$1"
  local copy="$2"
  CHECKED=$((CHECKED + 1))

  if [[ ! -f "$canonical" ]]; then
    echo "ERROR: Canonical file not found: $canonical"
    DRIFTED=$((DRIFTED + 1))
    return
  fi

  if [[ ! -f "$copy" ]]; then
    echo "ERROR: Copy not found: $copy"
    DRIFTED=$((DRIFTED + 1))
    return
  fi

  if ! diff -q "$canonical" "$copy" > /dev/null 2>&1; then
    echo "DRIFT: Copy has diverged from canonical."
    echo "  Canonical: $canonical"
    echo "  Copy:      $copy"
    echo "  Fix: run /propagate-templates"
    DRIFTED=$((DRIFTED + 1))
  fi
}

# No duplicated scripts or templates in v0.1.0.
# Add compare() calls here when shared scripts are introduced.

echo ""
echo "Checked $CHECKED file pairs."

if [[ $DRIFTED -gt 0 ]]; then
  echo "FAIL: $DRIFTED file(s) have drifted from canonical."
  exit 1
else
  echo "PASS: All copies match their canonical source (no pairs to check in v0.1.0)."
  exit 0
fi
