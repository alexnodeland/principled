#!/usr/bin/env bash
# parse-plan.sh — Extract metadata and tasks from a DDD implementation plan.
#
# Usage:
#   parse-plan.sh --file <path> --metadata    # Extract frontmatter as key=value
#   parse-plan.sh --file <path> --tasks       # Extract phases/tasks as pipe-delimited
#   parse-plan.sh --file <path> --task-ids    # List task IDs only
#
# Output (--tasks):
#   <phase>|<task-id>|<description>|<depends-on>|<bounded-contexts>
#
# Exit codes:
#   0 — success
#   1 — error (file not found, parse failure)

set -euo pipefail

FILE=""
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      FILE="$2"
      shift 2
      ;;
    --metadata)
      MODE="metadata"
      shift
      ;;
    --tasks)
      MODE="tasks"
      shift
      ;;
    --task-ids)
      MODE="task-ids"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$FILE" || -z "$MODE" ]]; then
  echo "Error: --file and a mode (--metadata, --tasks, or --task-ids) are required" >&2
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "Error: File not found: $FILE" >&2
  exit 1
fi

# --- Frontmatter extraction ---
extract_frontmatter_field() {
  local file="$1"
  local field="$2"
  local in_frontmatter=false

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if $in_frontmatter; then
        break
      else
        in_frontmatter=true
        continue
      fi
    fi

    if $in_frontmatter; then
      if [[ "$line" =~ ^${field}:[[:space:]]*(.*) ]]; then
        local value="${BASH_REMATCH[1]}"
        # Strip surrounding quotes
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        echo "$value"
        return 0
      fi
    fi
  done < "$file"

  echo ""
  return 0
}

# --- Mode: metadata ---
if [[ "$MODE" == "metadata" ]]; then
  echo "title=$(extract_frontmatter_field "$FILE" "title")"
  echo "number=$(extract_frontmatter_field "$FILE" "number")"
  echo "status=$(extract_frontmatter_field "$FILE" "status")"
  echo "originating_proposal=$(extract_frontmatter_field "$FILE" "originating_proposal")"
  echo "author=$(extract_frontmatter_field "$FILE" "author")"
  echo "created=$(extract_frontmatter_field "$FILE" "created")"
  exit 0
fi

# --- Mode: tasks / task-ids ---
# Parse phase headers and task lines from the plan body

CURRENT_PHASE=""
CURRENT_DEPENDS=""
CURRENT_BCS=""

# Skip frontmatter
PAST_FRONTMATTER=false
FRONTMATTER_COUNT=0

while IFS= read -r line; do
  # Track frontmatter delimiters
  if [[ "$line" == "---" ]]; then
    FRONTMATTER_COUNT=$((FRONTMATTER_COUNT + 1))
    if [[ $FRONTMATTER_COUNT -ge 2 ]]; then
      PAST_FRONTMATTER=true
    fi
    continue
  fi

  if ! $PAST_FRONTMATTER; then
    continue
  fi

  # Match phase headers: ### Phase N: Title (BC-X, BC-Y)
  if [[ "$line" =~ ^###[[:space:]]+Phase[[:space:]]+([0-9]+):[[:space:]]*(.*) ]]; then
    CURRENT_PHASE="${BASH_REMATCH[1]}"
    local_title="${BASH_REMATCH[2]}"
    CURRENT_DEPENDS="none"

    # Extract bounded contexts from parentheses
    if [[ "$local_title" =~ \(([^\)]+)\) ]]; then
      CURRENT_BCS="${BASH_REMATCH[1]}"
      # Normalize: remove spaces after commas
      CURRENT_BCS="$(echo "$CURRENT_BCS" | sed 's/, */,/g')"
    else
      CURRENT_BCS=""
    fi
    continue
  fi

  # Match dependency lines: **Depends on:** Phase N or Depends on: Phase N
  if [[ "$line" =~ [Dd]epends[[:space:]]+on:[[:space:]]*(.*) ]]; then
    dep_text="${BASH_REMATCH[1]}"
    # Remove markdown bold markers
    dep_text="${dep_text//\*\*/}"
    # Extract phase numbers
    deps=""
    while [[ "$dep_text" =~ [Pp]hase[[:space:]]+([0-9]+) ]]; do
      if [[ -n "$deps" ]]; then
        deps="$deps,$deps_num"
      fi
      deps_num="${BASH_REMATCH[1]}"
      if [[ -z "$deps" ]]; then
        deps="$deps_num"
      else
        deps="$deps,$deps_num"
      fi
      dep_text="${dep_text#*"${BASH_REMATCH[0]}"}"
    done
    if [[ -n "$deps" ]]; then
      CURRENT_DEPENDS="$deps"
    fi
    continue
  fi

  # Match task lines: - [ ] **N.M** description or - [x] **N.M** description
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+\[([[:space:]x])\][[:space:]]+\*\*([0-9]+\.[0-9]+)\*\*[[:space:]]+(.*) ]]; then
    TASK_ID="${BASH_REMATCH[2]}"
    TASK_DESC="${BASH_REMATCH[3]}"

    if [[ "$MODE" == "task-ids" ]]; then
      echo "$TASK_ID"
    else
      echo "${CURRENT_PHASE}|${TASK_ID}|${TASK_DESC}|${CURRENT_DEPENDS}|${CURRENT_BCS}"
    fi
    continue
  fi
done < "$FILE"

exit 0
