#!/usr/bin/env bash
# extract-plan-criteria.sh — Extract acceptance criteria from a DDD plan file.
#
# Usage: extract-plan-criteria.sh --plan <path> [--task <id>]
#
# Parses markdown for `- [ ]` / `- [x]` lines under Acceptance Criteria
# sections. If --task is provided, also extracts criteria from the specific
# task section.
#
# Output: One criterion per line, prefixed with [ ] or [x] to indicate status.
#
# Exit codes:
#   0 — criteria found and printed
#   1 — invalid arguments or file not found

set -euo pipefail

PLAN_PATH=""
TASK_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --plan)
    PLAN_PATH="$2"
    shift 2
    ;;
  --task)
    TASK_ID="$2"
    shift 2
    ;;
  *)
    echo "Error: Unknown argument: $1" >&2
    echo "Usage: extract-plan-criteria.sh --plan <path> [--task <id>]" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$PLAN_PATH" ]]; then
  echo "Error: --plan is required." >&2
  echo "Usage: extract-plan-criteria.sh --plan <path> [--task <id>]" >&2
  exit 1
fi

if [[ ! -f "$PLAN_PATH" ]]; then
  echo "Error: Plan file not found: $PLAN_PATH" >&2
  exit 1
fi

# Extract acceptance criteria section
# Look for lines starting with "## Acceptance Criteria" or "### Acceptance Criteria"
# and collect all `- [ ]` / `- [x]` lines until the next heading
IN_CRITERIA=false
IN_TASK=false
FOUND=false

while IFS= read -r line; do
  # Check for Acceptance Criteria heading
  if echo "$line" | grep -qiE '^#{2,4}\s+Acceptance Criteria'; then
    IN_CRITERIA=true
    continue
  fi

  # Check for task-specific section if --task was provided
  if [[ -n "$TASK_ID" ]] && echo "$line" | grep -qE "^\*\*${TASK_ID}\*\*|^-\s+\[.\]\s+\*\*${TASK_ID}\*\*"; then
    IN_TASK=true
    # Print this line if it's a checklist item
    if echo "$line" | grep -qE '^\s*-\s+\[.\]'; then
      echo "${line#"${line%%[![:space:]]*}"}"
      FOUND=true
    fi
    continue
  fi

  # If in a task section, collect sub-items until next task or heading
  if [[ "$IN_TASK" == true ]]; then
    if echo "$line" | grep -qE '^\*\*[0-9]' || echo "$line" | grep -qE '^#{2,4}\s'; then
      IN_TASK=false
    elif echo "$line" | grep -qE '^\s*-\s+\[.\]'; then
      echo "${line#"${line%%[![:space:]]*}"}"
      FOUND=true
      continue
    fi
  fi

  # If in acceptance criteria section, collect checklist items
  if [[ "$IN_CRITERIA" == true ]]; then
    # Stop at next heading
    if echo "$line" | grep -qE '^#{2,4}\s'; then
      IN_CRITERIA=false
      continue
    fi
    # Collect checklist items
    if echo "$line" | grep -qE '^\s*-\s+\[.\]'; then
      echo "${line#"${line%%[![:space:]]*}"}"
      FOUND=true
    fi
  fi
done < "$PLAN_PATH"

if [[ "$FOUND" == false ]]; then
  echo "No acceptance criteria found in $PLAN_PATH" >&2
  if [[ -n "$TASK_ID" ]]; then
    echo "(searched for task $TASK_ID)" >&2
  fi
fi

exit 0
