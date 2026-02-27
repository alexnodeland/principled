#!/usr/bin/env bash
# async-drift-check.sh — PostToolUse hook (async): background drift check on template/script writes.
#
# Receives JSON via stdin containing the Write tool response.
# When a .sh or .md file within a plugin's skills/*/scripts/ or skills/*/templates/
# directory is written, runs the relevant plugin's check-template-drift.sh in the
# background and surfaces drift warnings.
#
# Advisory only — never blocks.
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
  # Portable sed extraction (no grep -P on macOS)
  FILE_PATH="$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi

# If we couldn't extract a file path, nothing to do
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Check if the file is a template or script within a plugin skill directory
# Pattern: plugins/<plugin-name>/skills/<skill-name>/scripts/*.sh
# Pattern: plugins/<plugin-name>/skills/<skill-name>/templates/*.md
if [[ "$FILE_PATH" != *"/plugins/"*"/skills/"* ]]; then
  exit 0
fi

# Check if it's a .sh or .md file in scripts/ or templates/
if [[ "$FILE_PATH" != *"/scripts/"*.sh && "$FILE_PATH" != *"/templates/"*.md ]]; then
  exit 0
fi

# Determine which plugin this file belongs to
# Extract plugin name from path: plugins/<plugin-name>/...
PLUGIN_NAME=""
if [[ "$FILE_PATH" =~ plugins/([^/]+)/ ]]; then
  PLUGIN_NAME="${BASH_REMATCH[1]}"
fi

if [[ -z "$PLUGIN_NAME" ]]; then
  exit 0
fi

# Find the repo root
REPO_ROOT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  exit 0
fi

# Locate the drift check script for this plugin
DRIFT_SCRIPT=""
if [[ "$PLUGIN_NAME" == "principled-docs" ]]; then
  DRIFT_SCRIPT="${REPO_ROOT}/plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh"
else
  DRIFT_SCRIPT="${REPO_ROOT}/plugins/${PLUGIN_NAME}/scripts/check-template-drift.sh"
fi

if [[ ! -f "$DRIFT_SCRIPT" ]]; then
  exit 0
fi

# Run the drift check
DRIFT_OUTPUT=""
DRIFT_EXIT=0
DRIFT_OUTPUT="$(bash "$DRIFT_SCRIPT" 2>&1)" || DRIFT_EXIT=$?

if [[ "$DRIFT_EXIT" -ne 0 ]]; then
  echo "Advisory: Template drift detected in ${PLUGIN_NAME}! Run '/propagate-templates' to sync copies." >&2
  if [[ -n "$DRIFT_OUTPUT" ]]; then
    echo "$DRIFT_OUTPUT" >&2
  fi
fi

# Always allow
exit 0
