#!/usr/bin/env bash
# check-plan-proposal-link.sh — PreToolUse hook: block plans without an accepted proposal.
#
# Receives JSON via stdin containing tool_input.file_path.
# Blocks creation/modification of plan files whose originating_proposal
# field is missing or references a proposal that is not accepted.
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
  # Fallback: portable sed extraction (no grep -P on macOS)
  FILE_PATH="$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

# If we couldn't extract a file path, allow
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# If path does not contain /plans/, this is not a plan — allow
if [[ "$FILE_PATH" != *"/plans/"* ]]; then
  exit 0
fi

# Only check files matching the NNN-*.md naming pattern
FILENAME="$(basename "$FILE_PATH")"
if [[ ! "$FILENAME" =~ ^[0-9]{3}-.+\.md$ ]]; then
  exit 0
fi

# Extract originating_proposal from Write content, Edit new_string, or file on disk
PROPOSAL_NUM=""

# Helper: parse a field from a full document (with --- delimiters)
parse_field_inline() {
  local content="$1"
  local field="$2"
  local in_fm=false
  local value=""

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if $in_fm; then
        break
      else
        in_fm=true
        continue
      fi
    fi
    if $in_fm; then
      if [[ "$line" =~ ^${field}:[[:space:]]*(.*) ]]; then
        value="${BASH_REMATCH[1]}"
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        # Strip trailing whitespace
        value="${value%"${value##*[! ]}"}"
        break
      fi
    fi
  done <<< "$content"

  echo "$value"
}

# Helper: extract a field from a raw text snippet (no frontmatter delimiters required)
extract_field_from_snippet() {
  local snippet="$1"
  local field="$2"
  local value=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^${field}:[[:space:]]*(.*) ]]; then
      value="${BASH_REMATCH[1]}"
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"
      # Strip trailing whitespace
      value="${value%"${value##*[! ]}"}"
      break
    fi
  done <<< "$snippet"

  echo "$value"
}

CONTENT=""
NEW_STRING=""
if command -v jq &> /dev/null; then
  CONTENT="$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2> /dev/null || echo "")"
  NEW_STRING="$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2> /dev/null || echo "")"
else
  # Portable fallback for Edit tool new_string
  NEW_STRING="$(echo "$INPUT" | sed -n 's/.*"new_string"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

# Try Write tool content first
if [[ -n "$CONTENT" ]]; then
  PROPOSAL_NUM="$(parse_field_inline "$CONTENT" "originating_proposal")"
fi

# Try Edit tool new_string — if it contains originating_proposal, use that
# Edit new_string is a raw snippet without frontmatter delimiters
if [[ -z "$PROPOSAL_NUM" && -n "$NEW_STRING" ]]; then
  EDIT_PROPOSAL="$(extract_field_from_snippet "$NEW_STRING" "originating_proposal")"
  if [[ -n "$EDIT_PROPOSAL" ]]; then
    PROPOSAL_NUM="$EDIT_PROPOSAL"
  fi
fi

# Fall back to file on disk
if [[ -z "$PROPOSAL_NUM" && -f "$FILE_PATH" ]]; then
  PROPOSAL_NUM="$(bash "$PARSE_FRONTMATTER" --file "$FILE_PATH" --field originating_proposal)"
fi

# If originating_proposal is empty or null, block
if [[ -z "$PROPOSAL_NUM" || "$PROPOSAL_NUM" == "null" ]]; then
  echo "Cannot write plan: missing originating_proposal in frontmatter. Plans must reference an accepted proposal. Use /new-plan --from-proposal NNN."
  exit 2
fi

# Zero-pad the proposal number to 3 digits
PADDED_NUM="$(printf "%03d" "$PROPOSAL_NUM" 2> /dev/null || echo "$PROPOSAL_NUM")"

# Find the proposal file in the same scope
PLAN_DIR="$(dirname "$FILE_PATH")"
PROPOSALS_DIR="${PLAN_DIR%/plans*}/proposals"

# Look for the proposal file
PROPOSAL_FILE=""
if [[ -d "$PROPOSALS_DIR" ]]; then
  for f in "$PROPOSALS_DIR"/"${PADDED_NUM}"-*.md; do
    if [[ -f "$f" ]]; then
      PROPOSAL_FILE="$f"
      break
    fi
  done
fi

# If proposal file doesn't exist, block
if [[ -z "$PROPOSAL_FILE" ]]; then
  echo "Cannot write plan: proposal ${PADDED_NUM} not found in ${PROPOSALS_DIR}/. Create and accept the proposal first."
  exit 2
fi

# Check the proposal's status
PROPOSAL_STATUS="$(bash "$PARSE_FRONTMATTER" --file "$PROPOSAL_FILE" --field status)"

if [[ "$PROPOSAL_STATUS" != "accepted" ]]; then
  echo "Cannot write plan: proposal ${PADDED_NUM} has status '${PROPOSAL_STATUS}', not 'accepted'. The originating proposal must be accepted before creating a plan."
  exit 2
fi

# Proposal exists and is accepted — allow
exit 0
