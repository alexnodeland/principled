#!/usr/bin/env bash
# check-template-drift.sh — Verify that template copies match their canonical source.
#
# Usage: check-template-drift.sh [--plugin-root <path>]
#
# Compares every template copy against its canonical source in scaffold/templates/.
# Also checks script copies. Exits non-zero if any copy has diverged.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${1:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

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

# Template copies (canonical → copy)
compare \
  "$PLUGIN_ROOT/skills/scaffold/templates/core/proposal.md" \
  "$PLUGIN_ROOT/skills/new-proposal/templates/proposal.md"

compare \
  "$PLUGIN_ROOT/skills/scaffold/templates/core/plan.md" \
  "$PLUGIN_ROOT/skills/new-plan/templates/plan.md"

compare \
  "$PLUGIN_ROOT/skills/scaffold/templates/core/decision.md" \
  "$PLUGIN_ROOT/skills/new-adr/templates/decision.md"

compare \
  "$PLUGIN_ROOT/skills/scaffold/templates/core/architecture.md" \
  "$PLUGIN_ROOT/skills/new-architecture-doc/templates/architecture.md"

# Script copies
compare \
  "$PLUGIN_ROOT/skills/scaffold/scripts/validate-structure.sh" \
  "$PLUGIN_ROOT/skills/validate/scripts/validate-structure.sh"

compare \
  "$PLUGIN_ROOT/skills/new-proposal/scripts/next-number.sh" \
  "$PLUGIN_ROOT/skills/new-plan/scripts/next-number.sh"

compare \
  "$PLUGIN_ROOT/skills/new-proposal/scripts/next-number.sh" \
  "$PLUGIN_ROOT/skills/new-adr/scripts/next-number.sh"

echo ""
echo "Checked $CHECKED file pairs."

if [[ $DRIFTED -gt 0 ]]; then
  echo "FAIL: $DRIFTED file(s) have drifted from canonical."
  exit 1
else
  echo "PASS: All copies match their canonical source."
  exit 0
fi
