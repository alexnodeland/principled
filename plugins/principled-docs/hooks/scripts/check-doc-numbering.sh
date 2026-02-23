#!/usr/bin/env bash
# check-doc-numbering.sh — PreToolUse hook: block duplicate document numbers.
#
# Receives JSON via stdin containing tool_input.file_path.
# Blocks creation of pipeline documents (proposals, plans, decisions) when
# another file with the same NNN prefix already exists in the directory.
# Re-writing the same file is allowed.
#
# Exit codes:
#   0 — allow the operation
#   2 — block the operation

set -euo pipefail

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

# Check if path is in a pipeline document directory
if [[ "$FILE_PATH" != *"/proposals/"* && "$FILE_PATH" != *"/plans/"* && "$FILE_PATH" != *"/decisions/"* ]]; then
  exit 0
fi

# Only check files matching the NNN-*.md naming pattern
FILENAME="$(basename "$FILE_PATH")"
if [[ ! "$FILENAME" =~ ^([0-9]{3})-.+\.md$ ]]; then
  exit 0
fi

NUMBER="${BASH_REMATCH[1]}"
DIR="$(dirname "$FILE_PATH")"

# If the directory doesn't exist yet, this is the first file — allow
if [[ ! -d "$DIR" ]]; then
  exit 0
fi

# Scan for other files with the same number prefix
for f in "$DIR"/"${NUMBER}"-*.md; do
  # Skip if glob didn't match anything
  if [[ ! -f "$f" ]]; then
    continue
  fi

  # If the match is the same file being written, allow (re-write)
  MATCH_BASENAME="$(basename "$f")"
  if [[ "$MATCH_BASENAME" == "$FILENAME" ]]; then
    continue
  fi

  # A different file with the same number exists — block
  echo "Cannot write '${FILENAME}': number ${NUMBER} is already used by '${MATCH_BASENAME}' in $(basename "$DIR")/. Use the next available number."
  exit 2
done

# No duplicates found — allow
exit 0
