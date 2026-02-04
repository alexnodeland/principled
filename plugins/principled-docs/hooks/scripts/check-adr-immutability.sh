#!/usr/bin/env bash
# check-adr-immutability.sh — PreToolUse hook: block edits to accepted ADRs.
#
# Receives JSON via stdin containing tool_input.file_path.
# Blocks edits to ADRs with status accepted, deprecated, or superseded,
# with one exception: updates limited to the superseded_by field are allowed.
#
# Exit codes:
#   0 — allow the operation
#   2 — block the operation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSE_FRONTMATTER="$SCRIPT_DIR/parse-frontmatter.sh"

# Read JSON from stdin
INPUT="$(cat)"

# Extract file_path from the JSON input
# Try tool_input.file_path first, fall back to file_path
FILE_PATH=""
if command -v jq &> /dev/null; then
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .file_path // empty' 2> /dev/null || echo "")"
else
  # Fallback: basic grep extraction
  FILE_PATH="$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"[^"]*"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
fi

# If we couldn't extract a file path, allow
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# If path does not contain /decisions/, this is not an ADR — allow
if [[ "$FILE_PATH" != *"/decisions/"* ]]; then
  exit 0
fi

# If file does not exist yet (new creation), allow
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Read the status from frontmatter
STATUS="$(bash "$PARSE_FRONTMATTER" --file "$FILE_PATH" --field status)"

# If status is not a protected state, allow
case "$STATUS" in
accepted | deprecated | superseded) ;;
*)
  exit 0
  ;;
esac

# Protected state — check if the edit is limited to superseded_by
# Extract the new content / edit content from the input
NEW_CONTENT=""
OLD_STRING=""
NEW_STRING=""

if command -v jq &> /dev/null; then
  NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2> /dev/null || echo "")"
  OLD_STRING="$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' 2> /dev/null || echo "")"
  NEW_STRING="$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2> /dev/null || echo "")"
fi

# For Edit tool: check if old_string and new_string only differ in superseded_by
if [[ -n "$OLD_STRING" && -n "$NEW_STRING" ]]; then
  # Check if the change is limited to the superseded_by field
  OLD_STRIPPED="$(echo "$OLD_STRING" | grep -v 'superseded_by')"
  NEW_STRIPPED="$(echo "$NEW_STRING" | grep -v 'superseded_by')"
  if [[ "$OLD_STRIPPED" == "$NEW_STRIPPED" ]]; then
    # The only difference is in superseded_by lines — allow
    exit 0
  fi
fi

# For Write tool: check if the only change vs. current file is superseded_by
if [[ -n "$NEW_CONTENT" && -z "$OLD_STRING" ]]; then
  CURRENT_CONTENT="$(cat "$FILE_PATH")"
  CURRENT_STRIPPED="$(echo "$CURRENT_CONTENT" | grep -v 'superseded_by')"
  NEW_STRIPPED="$(echo "$NEW_CONTENT" | grep -v 'superseded_by')"
  if [[ "$CURRENT_STRIPPED" == "$NEW_STRIPPED" ]]; then
    # The only difference is superseded_by — allow
    exit 0
  fi
fi

# Extract the ADR number from the filename for the error message
ADR_FILENAME="$(basename "$FILE_PATH")"
ADR_NUM="${ADR_FILENAME%%-*}"

echo "Cannot modify ADR-${ADR_NUM}: this record has been ${STATUS} and is immutable. The only permitted change is setting superseded_by when a new ADR supersedes this one. To change this decision, create a new ADR. Use /new-adr."
exit 2
