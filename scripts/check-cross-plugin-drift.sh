#!/usr/bin/env bash
# check-cross-plugin-drift.sh — Verify shared code copied ACROSS plugins matches.
#
# ADR-018 moved same-plugin shared code into each plugin's lib/, so drift within a
# plugin is now impossible rather than merely detected. Cross-plugin sharing is the
# one case that idea does not cover: ${CLAUDE_PLUGIN_ROOT} resolves to one plugin, and
# principled-github, principled-quality and principled-release install independently,
# so a script all four need genuinely has to exist four times.
#
# That is the entire remaining surface: check-gh-cli.sh, canonical in
# principled-github/lib/, vendored into the other three. Fifteen copies became four.
#
# This replaces three separate per-plugin drift checkers. Consolidating matters: the
# old per-plugin checkers each carried a hand-maintained list of copies, and at least
# one of them silently omitted a copy that had already diverged while reporting
# "PASS: All copies match canonical."
#
# Exits non-zero if any copy has diverged.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

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
    echo "MISSING: Copy not found: $copy"
    DRIFTED=$((DRIFTED + 1))
    return
  fi

  if ! diff -q "$canonical" "$copy" > /dev/null 2>&1; then
    echo "DRIFT: Copy has diverged from canonical."
    echo "  Canonical: $canonical"
    echo "  Copy:      $copy"
    diff "$canonical" "$copy" || true
    DRIFTED=$((DRIFTED + 1))
    return
  fi

  echo "  OK: ${copy#"$REPO_ROOT"/}"
}

CANONICAL="plugins/principled-github/lib/check-gh-cli.sh"

echo "Checking cross-plugin drift..."
echo "Canonical: ${CANONICAL}"
echo ""

compare "$CANONICAL" "plugins/principled-quality/lib/check-gh-cli.sh"
compare "$CANONICAL" "plugins/principled-release/lib/check-gh-cli.sh"
compare "$CANONICAL" "plugins/principled-agent/lib/check-gh-cli.sh"

echo ""
echo "Checked ${CHECKED} file pair(s)."

if [[ "$DRIFTED" -gt 0 ]]; then
  echo "FAIL: ${DRIFTED} file(s) have drifted from canonical."
  echo ""
  echo "Fix: copy ${CANONICAL} over the diverged file(s)."
  exit 1
fi

echo "PASS: All cross-plugin copies match their canonical source."
