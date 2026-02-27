#!/usr/bin/env bash
# check-adr-supersession.sh — PostToolUse hook: validate ADR supersession chain integrity.
#
# Receives JSON via stdin containing tool_input.file_path.
# When an ADR file has a superseded_by field set, validates that:
# 1. The referenced superseding ADR exists
# 2. The superseding ADR has status accepted
# 3. No circular supersession chains exist
#
# Advisory only — never blocks.
#
# Exit codes:
#   0 — allow the operation (always)

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
  # Portable sed extraction (no grep -P on macOS)
  FILE_PATH="$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

# If we couldn't extract a file path, nothing to do
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# If path does not contain /decisions/, not an ADR
if [[ "$FILE_PATH" != *"/decisions/"* ]]; then
  exit 0
fi

# Only check files matching NNN-*.md
FILENAME="$(basename "$FILE_PATH")"
if [[ ! "$FILENAME" =~ ^[0-9]{3}-.+\.md$ ]]; then
  exit 0
fi

# If file doesn't exist, nothing to validate
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Extract superseded_by field
SUPERSEDED_BY="$(bash "$PARSE_FRONTMATTER" --file "$FILE_PATH" --field superseded_by)"

# If no supersession, nothing to validate
if [[ -z "$SUPERSEDED_BY" || "$SUPERSEDED_BY" == "null" ]]; then
  exit 0
fi

# Determine the decisions directory
DECISIONS_DIR="$(dirname "$FILE_PATH")"

# Zero-pad the superseding ADR number
PADDED_NUM="$(printf "%03d" "$SUPERSEDED_BY" 2> /dev/null || echo "$SUPERSEDED_BY")"

# Find the superseding ADR file
SUPERSEDING_FILE=""
for f in "$DECISIONS_DIR"/"${PADDED_NUM}"-*.md; do
  if [[ -f "$f" ]]; then
    SUPERSEDING_FILE="$f"
    break
  fi
done

if [[ -z "$SUPERSEDING_FILE" ]]; then
  echo "Advisory: ADR '${FILENAME}' references superseding ADR ${PADDED_NUM}, but that ADR does not exist in $(basename "$DECISIONS_DIR")/." >&2
  exit 0
fi

# Check that the superseding ADR has status accepted
SUPERSEDING_STATUS="$(bash "$PARSE_FRONTMATTER" --file "$SUPERSEDING_FILE" --field status)"
if [[ "$SUPERSEDING_STATUS" != "accepted" ]]; then
  echo "Advisory: ADR '${FILENAME}' is superseded by ADR ${PADDED_NUM}, but ADR ${PADDED_NUM} has status '${SUPERSEDING_STATUS}', not 'accepted'." >&2
  exit 0
fi

# Check for circular chains (A superseded_by B, B superseded_by A)
SUPERSEDING_SUPERSEDED_BY="$(bash "$PARSE_FRONTMATTER" --file "$SUPERSEDING_FILE" --field superseded_by)"
ADR_NUM="${FILENAME%%-*}"
if [[ "$SUPERSEDING_SUPERSEDED_BY" == "$ADR_NUM" ]]; then
  echo "Advisory: Circular supersession chain detected! ADR ${ADR_NUM} superseded_by ${PADDED_NUM}, and ADR ${PADDED_NUM} superseded_by ${ADR_NUM}." >&2
  exit 0
fi

# All checks passed
exit 0
