#!/usr/bin/env bash
# check-template-drift.sh — Verify that script/template copies match canonical.
#
# Usage: check-template-drift.sh [<plugin-root>]
#
# Compares every script and template copy against its canonical source.
# Exits non-zero if any copy has diverged.

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
    echo "DRIFT: Copy has diverged from canonical."
    echo "  Canonical: $canonical"
    echo "  Copy:      $copy"
    echo "  Fix: run /propagate-templates"
    DRIFTED=$((DRIFTED + 1))
  fi
}

# Script copies: parse-plan.sh (canonical in decompose)
compare \
  "$PLUGIN_ROOT/skills/decompose/scripts/parse-plan.sh" \
  "$PLUGIN_ROOT/skills/orchestrate/scripts/parse-plan.sh"

# Script copies: task-manifest.sh (canonical in decompose)
compare \
  "$PLUGIN_ROOT/skills/decompose/scripts/task-manifest.sh" \
  "$PLUGIN_ROOT/skills/spawn/scripts/task-manifest.sh"

compare \
  "$PLUGIN_ROOT/skills/decompose/scripts/task-manifest.sh" \
  "$PLUGIN_ROOT/skills/check-impl/scripts/task-manifest.sh"

compare \
  "$PLUGIN_ROOT/skills/decompose/scripts/task-manifest.sh" \
  "$PLUGIN_ROOT/skills/merge-work/scripts/task-manifest.sh"

compare \
  "$PLUGIN_ROOT/skills/decompose/scripts/task-manifest.sh" \
  "$PLUGIN_ROOT/skills/orchestrate/scripts/task-manifest.sh"

# Script copies: run-checks.sh (canonical in check-impl)
compare \
  "$PLUGIN_ROOT/skills/check-impl/scripts/run-checks.sh" \
  "$PLUGIN_ROOT/skills/orchestrate/scripts/run-checks.sh"

# Template copies: claude-task.md (canonical in spawn)
compare \
  "$PLUGIN_ROOT/skills/spawn/templates/claude-task.md" \
  "$PLUGIN_ROOT/skills/orchestrate/templates/claude-task.md"

echo ""
echo "Checked $CHECKED file pairs."

if [[ $DRIFTED -gt 0 ]]; then
  echo "FAIL: $DRIFTED file(s) have drifted from canonical."
  exit 1
else
  echo "PASS: All copies match their canonical source."
  exit 0
fi
