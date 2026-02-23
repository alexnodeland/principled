#!/usr/bin/env bash
# validate-worker-completion.sh — SubagentStop hook: ensure impl-worker updated manifest.
#
# Receives JSON via stdin with subagent stop context.
# Verifies that the impl-worker agent properly transitioned its task
# from in_progress to a terminal status in the manifest before finishing.
#
# Exit codes:
#   0 — allow the operation
#   2 — block (reject completion if tasks were left orphaned)

set -euo pipefail

# Read JSON from stdin
INPUT="$(cat)"

# Extract agent name from the event context
AGENT_NAME=""
if command -v jq &> /dev/null; then
  AGENT_NAME="$(echo "$INPUT" | jq -r '.agent_name // .agent // empty' 2> /dev/null || echo "")"
else
  AGENT_NAME="$(echo "$INPUT" | grep -oP '"agent_name"\s*:\s*"[^"]*"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
  if [[ -z "$AGENT_NAME" ]]; then
    AGENT_NAME="$(echo "$INPUT" | grep -oP '"agent"\s*:\s*"[^"]*"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
  fi
fi

# Only act on impl-worker agents
if [[ "$AGENT_NAME" != "impl-worker" ]]; then
  exit 0
fi

# Find the manifest
REPO_ROOT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  exit 0
fi

MANIFEST="${REPO_ROOT}/.impl/manifest.json"

# If no manifest, nothing to validate
if [[ ! -f "$MANIFEST" ]]; then
  exit 0
fi

# Check for tasks stuck in in_progress status
ORPHANED_TASKS=""
if command -v jq &> /dev/null; then
  ORPHANED_TASKS="$(jq -r '.tasks[] | select(.status == "in_progress") | .id' "$MANIFEST" 2> /dev/null || echo "")"
else
  # Fallback: grep for in_progress status
  ORPHANED_TASKS="$(grep -B5 '"status".*"in_progress"' "$MANIFEST" | grep '"id"' | grep -oP ':\s*"\K[^"]*' || echo "")"
fi

if [[ -n "$ORPHANED_TASKS" ]]; then
  TASK_LIST="$(echo "$ORPHANED_TASKS" | tr '\n' ', ' | sed 's/, $//')"
  echo "impl-worker completed but left task(s) in 'in_progress' status: ${TASK_LIST}. The worker must update task status to a terminal state (passed, failed, or abandoned) before finishing."
  exit 2
fi

# All tasks properly transitioned — allow
exit 0
