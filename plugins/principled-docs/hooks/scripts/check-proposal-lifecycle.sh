#!/usr/bin/env bash
# check-proposal-lifecycle.sh — PreToolUse hook: block edits to terminal proposals.
#
# Receives JSON via stdin containing tool_input.file_path.
# Blocks edits to proposals with status accepted, rejected, or superseded.
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

# If path does not contain /proposals/, this is not a proposal — allow
if [[ "$FILE_PATH" != *"/proposals/"* ]]; then
  exit 0
fi

# If file does not exist yet (new creation), allow
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Read the status from frontmatter
STATUS="$(bash "$PARSE_FRONTMATTER" --file "$FILE_PATH" --field status)"

# If status is terminal, block
case "$STATUS" in
accepted | rejected | superseded)
  # Extract the proposal number from the filename
  PROPOSAL_FILENAME="$(basename "$FILE_PATH")"
  PROPOSAL_NUM="${PROPOSAL_FILENAME%%-*}"
  echo "Cannot modify proposal ${PROPOSAL_NUM}: this proposal has reached terminal status '${STATUS}'. To propose changes, create a new proposal that supersedes it. Use /new-proposal."
  exit 2
  ;;
*)
  exit 0
  ;;
esac
