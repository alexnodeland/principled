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
  # Fallback: basic grep extraction
  FILE_PATH="$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"[^"]*"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
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

# For Write tool: try to extract originating_proposal from the content being written
PROPOSAL_NUM=""
if command -v jq &> /dev/null; then
  CONTENT="$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2> /dev/null || echo "")"
  if [[ -n "$CONTENT" ]]; then
    # Parse frontmatter from the content being written
    IN_FM=false
    while IFS= read -r line; do
      if [[ "$line" == "---" ]]; then
        if $IN_FM; then
          break
        else
          IN_FM=true
          continue
        fi
      fi
      if $IN_FM; then
        if [[ "$line" =~ ^originating_proposal:[[:space:]]*(.*) ]]; then
          PROPOSAL_NUM="${BASH_REMATCH[1]}"
          PROPOSAL_NUM="${PROPOSAL_NUM#\"}"
          PROPOSAL_NUM="${PROPOSAL_NUM%\"}"
          PROPOSAL_NUM="${PROPOSAL_NUM#\'}"
          PROPOSAL_NUM="${PROPOSAL_NUM%\'}"
          break
        fi
      fi
    done <<< "$CONTENT"
  fi
fi

# If we couldn't extract from content, try the file on disk (for Edit tool)
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
