#!/usr/bin/env bash
# check-release-readiness.sh — PostToolUse hook: advisory for git tag commands.
#
# Receives JSON via stdin containing tool_input and tool_result.
# Emits an advisory reminder when a git tag command is detected
# without a prior readiness check. This is advisory only — it never blocks.
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

# Only check git tag commands
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

if [[ "$COMMAND" != *"git tag"* ]]; then
  exit 0
fi

# Skip if this is a listing or deletion command
if [[ "$COMMAND" == *"git tag -l"* ]] || [[ "$COMMAND" == *"git tag --list"* ]] || [[ "$COMMAND" == *"git tag -d"* ]] || [[ "$COMMAND" == *"git tag --delete"* ]]; then
  exit 0
fi

echo "Advisory: A git tag command was detected. Consider running /release-ready before tagging to verify that all referenced pipeline documents are in terminal status."

# Always allow
exit 0
