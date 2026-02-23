#!/usr/bin/env bash
# check-template-drift.sh — Verify that script copies match their canonical source.
#
# Usage: check-template-drift.sh [<repo-root>]
#
# Compares every check-gh-cli.sh copy in principled-release against the
# canonical source in principled-github. This is a cross-plugin drift
# checker following the pattern established by principled-quality.
#
# Canonical sources:
#   check-gh-cli.sh — canonical in principled-github/skills/sync-issues/scripts/
#     → copies: changelog/scripts/, release-ready/scripts/,
#               release-plan/scripts/, tag-release/scripts/
#
# Exits non-zero if any copy has diverged.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
PLUGIN_ROOT="$REPO_ROOT/plugins/principled-release"

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

# Cross-plugin canonical: check-gh-cli.sh from principled-github
CANONICAL="$REPO_ROOT/plugins/principled-github/skills/sync-issues/scripts/check-gh-cli.sh"

compare \
  "$CANONICAL" \
  "$PLUGIN_ROOT/skills/changelog/scripts/check-gh-cli.sh"

compare \
  "$CANONICAL" \
  "$PLUGIN_ROOT/skills/release-ready/scripts/check-gh-cli.sh"

compare \
  "$CANONICAL" \
  "$PLUGIN_ROOT/skills/release-plan/scripts/check-gh-cli.sh"

compare \
  "$CANONICAL" \
  "$PLUGIN_ROOT/skills/tag-release/scripts/check-gh-cli.sh"

echo ""
echo "Checked $CHECKED file pairs."

if [[ $DRIFTED -gt 0 ]]; then
  echo "FAIL: $DRIFTED file(s) have drifted from canonical."
  exit 1
else
  echo "PASS: All copies match their canonical source."
  exit 0
fi
