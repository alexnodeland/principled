#!/usr/bin/env bash
# check-review-checklist.sh — PostToolUse hook: advisory for gh pr review/merge commands.
#
# Receives JSON via stdin containing tool_input and tool_result.
# Emits an advisory reminder when a PR review or merge is performed
# without a review checklist. This is advisory only — it never blocks.
#
# Exit codes:
#   0 — always (advisory only)

set -euo pipefail

# Read JSON from stdin
INPUT="$(cat)"

# Extract the command that was run
COMMAND=""
if command -v jq &> /dev/null; then
  COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2> /dev/null || echo "")"
else
  COMMAND="$(echo "$INPUT" | grep -oP '"command"\s*:\s*"[^"]*"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
fi

# Only check gh pr review and gh pr merge commands
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

if [[ "$COMMAND" != *"gh pr review"* && "$COMMAND" != *"gh pr merge"* ]]; then
  exit 0
fi

# Try to extract PR number from the command
PR_NUMBER=""
PR_NUMBER="$(echo "$COMMAND" | grep -oE '[0-9]+' | head -1 || echo "")"

if [[ -z "$PR_NUMBER" ]]; then
  echo "Advisory: A PR review/merge was performed. Consider using /review-checklist to generate a spec-driven review checklist."
  exit 0
fi

# Check if a local checklist exists
if [[ -f ".review/${PR_NUMBER}-checklist.md" ]]; then
  exit 0
fi

echo "Advisory: No review checklist found for PR #${PR_NUMBER}. Consider running /review-checklist ${PR_NUMBER} to generate a spec-driven checklist before reviewing or merging."

# Always allow
exit 0
