#!/usr/bin/env bash
# check-db-integrity.sh — Advisory hook for direct task storage edits
#
# Warns when task storage is edited directly instead of through task-db.sh.
# Advisory only — always exits 0.
#
# The two files carry different risk (ADR-017):
#   .principled/tasks.jsonl  source of truth; a hand edit corrupts the record
#   .impl/tasks.db           derived cache; a hand edit is silently discarded on --sync
#
# Input: JSON on stdin with tool_input.file_path
# Output: Warning message to stderr if task storage is targeted
# Exit: Always 0 (advisory)

set -euo pipefail

# Read JSON from stdin
input=$(cat)

# Extract file_path from tool input
file_path=""
if command -v jq &> /dev/null; then
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2> /dev/null || true)
else
  file_path=$(echo "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' || true)
fi

# Skip if no file_path extracted
if [[ -z "$file_path" ]]; then
  exit 0
fi

# The event log is the record. A hand edit here is a real integrity risk.
if [[ "$file_path" == *"tasks.jsonl"* ]]; then
  echo "⚠️  Advisory: Direct edit to the task event log detected." >&2
  echo "   .principled/tasks.jsonl is the source of truth for the task graph." >&2
  echo "   Use /task-open, /task-close, /task-update, or task-db.sh instead." >&2
  echo "   Hand edits can desynchronize the log from what agents have recorded." >&2
fi

# The cache is derived. A hand edit here is not dangerous, just futile.
if [[ "$file_path" == *"tasks.db"* ]]; then
  echo "⚠️  Advisory: Direct edit to the task cache detected." >&2
  echo "   .impl/tasks.db is rebuilt from .principled/tasks.jsonl, so any direct" >&2
  echo "   change is discarded on the next 'task-db.sh --sync'." >&2
  echo "   Use /task-open, /task-close, or /task-update to change the graph." >&2
fi

# Advisory only — always allow
exit 0
