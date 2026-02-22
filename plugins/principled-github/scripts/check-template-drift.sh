#!/usr/bin/env bash
# check-template-drift.sh — Verify that script copies match their canonical source.
#
# Usage: check-template-drift.sh [<plugin-root>]
#
# Compares every script copy against its canonical source.
# Exits non-zero if any copy has diverged.
#
# Canonical sources:
#   check-gh-cli.sh — canonical in sync-issues/scripts/
#     → copies: sync-labels/scripts/, pr-check/scripts/, gh-scaffold/scripts/,
#               ingest-issue/scripts/, triage/scripts/, pr-describe/scripts/
#
#   extract-doc-metadata.sh — canonical in sync-issues/scripts/
#     (no copies — single location)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"

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
    echo "DRIFT: $copy differs from $canonical"
    DRIFTED=$((DRIFTED + 1))
  fi
}

# Script copies: check-gh-cli.sh (canonical in sync-issues)
compare \
  "$PLUGIN_ROOT/skills/sync-issues/scripts/check-gh-cli.sh" \
  "$PLUGIN_ROOT/skills/sync-labels/scripts/check-gh-cli.sh"

compare \
  "$PLUGIN_ROOT/skills/sync-issues/scripts/check-gh-cli.sh" \
  "$PLUGIN_ROOT/skills/pr-check/scripts/check-gh-cli.sh"

compare \
  "$PLUGIN_ROOT/skills/sync-issues/scripts/check-gh-cli.sh" \
  "$PLUGIN_ROOT/skills/gh-scaffold/scripts/check-gh-cli.sh"

compare \
  "$PLUGIN_ROOT/skills/sync-issues/scripts/check-gh-cli.sh" \
  "$PLUGIN_ROOT/skills/ingest-issue/scripts/check-gh-cli.sh"

compare \
  "$PLUGIN_ROOT/skills/sync-issues/scripts/check-gh-cli.sh" \
  "$PLUGIN_ROOT/skills/triage/scripts/check-gh-cli.sh"

compare \
  "$PLUGIN_ROOT/skills/sync-issues/scripts/check-gh-cli.sh" \
  "$PLUGIN_ROOT/skills/pr-describe/scripts/check-gh-cli.sh"

echo ""
echo "Checked $CHECKED file pairs."

if [[ $DRIFTED -gt 0 ]]; then
  echo "FAIL: $DRIFTED file(s) have drifted from canonical."
  exit 1
else
  echo "PASS: All copies match their canonical source."
  exit 0
fi
