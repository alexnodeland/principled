#!/usr/bin/env bash
# check-db-integrity.sh — Advisory hook for direct tasks.db edits
#
# Warns when .impl/tasks.db is being edited directly instead of through
# the task-db.sh script. Advisory only — always exits 0.
#
# Input: JSON on stdin with tool_input.file_path
# Output: Warning message to stderr if tasks.db is targeted
# Exit: Always 0 (advisory)

set -euo pipefail

# Read JSON from stdin
input=$(cat)

# Extract file_path from tool input
file_path=""
if command -v jq &>/dev/null; then
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  file_path=$(echo "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' || true)
fi

# Skip if no file_path extracted
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Check if the target is tasks.db
if [[ "$file_path" == *".impl/tasks.db"* ]] || [[ "$file_path" == *"tasks.db"* ]]; then
  echo "⚠️  Advisory: Direct edit to tasks.db detected." >&2
  echo "   Use /task-open, /task-close, or task-db.sh for database operations." >&2
  echo "   Direct edits may corrupt the bead graph or bypass Git commitment." >&2
fi

# Advisory only — always allow
exit 0
