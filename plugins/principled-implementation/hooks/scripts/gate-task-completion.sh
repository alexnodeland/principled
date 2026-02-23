#!/usr/bin/env bash
# gate-task-completion.sh — TaskCompleted hook: enforce quality checks before task completion.
#
# Receives JSON via stdin with task completion context.
# When agent teams are active, verifies that quality checks have been run
# and passed for a task before it can be marked complete.
#
# Only active when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is set.
#
# Exit codes:
#   0 — allow the operation
#   2 — block (reject completion if checks haven't passed)

set -euo pipefail

# If agent teams are not enabled, always allow (this hook is a no-op)
if [[ -z "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ]]; then
  exit 0
fi

# Read JSON from stdin
INPUT="$(cat)"

# Extract task_id from the event context
TASK_ID=""
if command -v jq &> /dev/null; then
  TASK_ID="$(echo "$INPUT" | jq -r '.task_id // .tool_input.task_id // empty' 2> /dev/null || echo "")"
else
  TASK_ID="$(echo "$INPUT" | grep -oP '"task_id"\s*:\s*"[^"]*"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
fi

# If we couldn't extract a task ID, allow (can't validate without it)
if [[ -z "$TASK_ID" ]]; then
  exit 0
fi

# Find the manifest
REPO_ROOT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  exit 0
fi

MANIFEST="${REPO_ROOT}/.impl/manifest.json"

# If no manifest, allow (not in an orchestrated context)
if [[ ! -f "$MANIFEST" ]]; then
  exit 0
fi

# Look up the task in the manifest
TASK_STATUS=""

if command -v jq &> /dev/null; then
  TASK_STATUS="$(jq -r --arg id "$TASK_ID" '.tasks[] | select(.id == $id) | .status' "$MANIFEST" 2> /dev/null || echo "")"
else
  # Fallback: basic grep. Look for the task block and extract status.
  TASK_BLOCK="$(grep -A20 "\"id\".*\"${TASK_ID}\"" "$MANIFEST" || echo "")"
  if [[ -n "$TASK_BLOCK" ]]; then
    TASK_STATUS="$(echo "$TASK_BLOCK" | grep '"status"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
  fi
fi

# If task not found in manifest, allow (may be a non-implementation task)
if [[ -z "$TASK_STATUS" ]]; then
  exit 0
fi

# Check if the task has passed validation
if [[ "$TASK_STATUS" == "passed" || "$TASK_STATUS" == "merged" ]]; then
  exit 0
fi

# If status is not passed/merged, checks haven't completed successfully
echo "Cannot mark task ${TASK_ID} as complete: status is '${TASK_STATUS}'. Quality checks must pass (status must be 'passed') before task completion. Run /check-impl --task ${TASK_ID}."
exit 2
