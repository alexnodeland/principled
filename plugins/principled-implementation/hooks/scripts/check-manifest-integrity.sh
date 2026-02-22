#!/usr/bin/env bash
# check-manifest-integrity.sh — PreToolUse hook: advisory warning for manifest edits.
#
# Receives JSON via stdin containing tool_input.file_path.
# Emits an advisory warning when the task manifest is being edited directly.
# This is advisory only — it never blocks. The manifest may need manual
# editing for recovery from corrupted state.
#
# Exit codes:
#   0 — allow the operation (always)

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

# If path matches the task manifest, emit advisory
if [[ "$FILE_PATH" == *"/.impl/manifest.json" || "$FILE_PATH" == ".impl/manifest.json" ]]; then
  echo "Advisory: Editing manifest.json directly may corrupt orchestration state. Use /decompose, /spawn, /check-impl, or /merge-work to manage the manifest."
fi

# Always allow
exit 0
