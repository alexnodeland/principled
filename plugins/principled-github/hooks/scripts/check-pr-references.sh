#!/usr/bin/env bash
# check-pr-references.sh — PostToolUse hook: advisory for gh pr create commands.
#
# Receives JSON via stdin containing tool_input and tool_result.
# Emits an advisory reminder when a PR is created without principled
# document references. This is advisory only — it never blocks.
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
  # Without jq, use the full input as the search target. This avoids JSON
  # parsing issues with escaped quotes and the grep -P flag (unavailable on
  # macOS). Slightly less precise but safe for an advisory-only hook.
  COMMAND="$INPUT"
fi

# Only check gh pr create commands
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

if [[ "$COMMAND" != *"gh pr create"* ]]; then
  exit 0
fi

# Check if the command includes principled references
HAS_REFERENCE=false
if echo "$COMMAND" | grep -qiE '(Plan-[0-9]{3,}|RFC-[0-9]{3,}|ADR-[0-9]{3,})'; then
  HAS_REFERENCE=true
fi

if ! $HAS_REFERENCE; then
  echo "Advisory: This PR was created without referencing a principled document (Plan-NNN, RFC-NNN, or ADR-NNN). Consider using /pr-describe to generate a structured PR description with document cross-references."
fi

# Always allow
exit 0
