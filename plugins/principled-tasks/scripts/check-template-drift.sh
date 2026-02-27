#!/usr/bin/env bash
# check-template-drift.sh — Verify task-db.sh copies match canonical
#
# Canonical: plugins/principled-tasks/skills/task-open/scripts/task-db.sh
# Copies:    task-close, task-graph, task-audit, task-query
#
# Exit: 0 if all copies match, 1 if any drift detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

canonical="$PLUGIN_ROOT/skills/task-open/scripts/task-db.sh"
copies=(
  "$PLUGIN_ROOT/skills/task-close/scripts/task-db.sh"
  "$PLUGIN_ROOT/skills/task-graph/scripts/task-db.sh"
  "$PLUGIN_ROOT/skills/task-audit/scripts/task-db.sh"
  "$PLUGIN_ROOT/skills/task-query/scripts/task-db.sh"
)

drifted=0

echo "Checking task-db.sh drift (4 pairs)..."
echo "Canonical: skills/task-open/scripts/task-db.sh"
echo ""

for copy in "${copies[@]}"; do
  relative="${copy#"$PLUGIN_ROOT"/}"
  if [[ ! -f "$copy" ]]; then
    echo "  MISSING: $relative"
    drifted=1
  elif ! diff -q "$canonical" "$copy" &>/dev/null; then
    echo "  DRIFTED: $relative"
    drifted=1
  else
    echo "  OK: $relative"
  fi
done

echo ""
if [[ $drifted -ne 0 ]]; then
  echo "FAIL: Template drift detected. Copy canonical to drifted locations."
  exit 1
else
  echo "PASS: All copies match canonical."
  exit 0
fi
