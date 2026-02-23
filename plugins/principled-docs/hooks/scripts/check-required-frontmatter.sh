#!/usr/bin/env bash
# check-required-frontmatter.sh — PreToolUse hook: block documents with invalid frontmatter.
#
# Receives JSON via stdin containing tool_input.file_path and optionally
# tool_input.content (for Write) or tool_input.old_string/new_string (for Edit).
# Validates that pipeline documents have required frontmatter fields with valid values.
#
# Document types and required fields:
#   proposals: status in (draft, in-review, accepted, rejected, superseded)
#   plans:     status in (active, complete, abandoned); originating_proposal present
#   decisions: status in (proposed, accepted, deprecated, superseded)
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

# Determine document type from path
DOC_TYPE=""
if [[ "$FILE_PATH" == *"/proposals/"* ]]; then
  DOC_TYPE="proposal"
elif [[ "$FILE_PATH" == *"/plans/"* ]]; then
  DOC_TYPE="plan"
elif [[ "$FILE_PATH" == *"/decisions/"* ]]; then
  DOC_TYPE="decision"
fi

# If not a pipeline document, allow
if [[ -z "$DOC_TYPE" ]]; then
  exit 0
fi

# Only check files matching the NNN-*.md naming pattern
FILENAME="$(basename "$FILE_PATH")"
if [[ ! "$FILENAME" =~ ^[0-9]{3}-.+\.md$ ]]; then
  exit 0
fi

# Extract frontmatter from the content being written (Write tool)
# or from the file on disk (Edit tool)
CONTENT=""
if command -v jq &> /dev/null; then
  CONTENT="$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2> /dev/null || echo "")"
fi

# parse_field extracts a frontmatter field value from content string
parse_field() {
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
        break
      fi
    fi
  done <<< "$content"

  echo "$value"
}

# Get the status field
STATUS=""
if [[ -n "$CONTENT" ]]; then
  STATUS="$(parse_field "$CONTENT" "status")"
else
  # For Edit tool, read from file on disk. If file doesn't exist, allow (new file).
  if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
  fi
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PARSE_FRONTMATTER="$SCRIPT_DIR/parse-frontmatter.sh"
  STATUS="$(bash "$PARSE_FRONTMATTER" --file "$FILE_PATH" --field status)"
fi

ERRORS=""

# Validate status by document type
case "$DOC_TYPE" in
proposal)
  case "$STATUS" in
  draft | in-review | accepted | rejected | superseded) ;;
  "")
    ERRORS="missing 'status' field"
    ;;
  *)
    ERRORS="invalid status '${STATUS}' (must be: draft, in-review, accepted, rejected, superseded)"
    ;;
  esac
  ;;
plan)
  case "$STATUS" in
  active | complete | abandoned) ;;
  "")
    ERRORS="missing 'status' field"
    ;;
  *)
    ERRORS="invalid status '${STATUS}' (must be: active, complete, abandoned)"
    ;;
  esac

  # Plans also require originating_proposal
  ORIG_PROPOSAL=""
  if [[ -n "$CONTENT" ]]; then
    ORIG_PROPOSAL="$(parse_field "$CONTENT" "originating_proposal")"
  elif [[ -f "$FILE_PATH" ]]; then
    ORIG_PROPOSAL="$(bash "$PARSE_FRONTMATTER" --file "$FILE_PATH" --field originating_proposal)"
  fi
  if [[ -z "$ORIG_PROPOSAL" || "$ORIG_PROPOSAL" == "null" ]]; then
    if [[ -n "$ERRORS" ]]; then
      ERRORS="${ERRORS}; missing 'originating_proposal' field"
    else
      ERRORS="missing 'originating_proposal' field"
    fi
  fi
  ;;
decision)
  case "$STATUS" in
  proposed | accepted | deprecated | superseded) ;;
  "")
    ERRORS="missing 'status' field"
    ;;
  *)
    ERRORS="invalid status '${STATUS}' (must be: proposed, accepted, deprecated, superseded)"
    ;;
  esac
  ;;
esac

if [[ -n "$ERRORS" ]]; then
  echo "Cannot write ${DOC_TYPE} '${FILENAME}': ${ERRORS}. Check your frontmatter."
  exit 2
fi

exit 0
