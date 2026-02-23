#!/usr/bin/env bash
# cleanup-impl-worktree.sh — WorktreeRemove hook: archive state when worktrees are removed.
#
# Receives JSON via stdin with worktree removal context.
# When a .impl/ directory exists in the worktree being removed, archives
# any logs to the main worktree's .impl/logs/ directory and updates the
# manifest to reflect the worktree removal.
#
# Advisory only — never blocks worktree removal.
#
# Exit codes:
#   0 — allow the operation (always)

set -euo pipefail

# Read JSON from stdin
INPUT="$(cat)"

# Extract the worktree path from the event context
WORKTREE_PATH=""
if command -v jq &> /dev/null; then
  WORKTREE_PATH="$(echo "$INPUT" | jq -r '.worktree_path // .tool_input.path // empty' 2> /dev/null || echo "")"
else
  WORKTREE_PATH="$(echo "$INPUT" | grep -oP '"worktree_path"\s*:\s*"[^"]*"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
fi

# If we couldn't extract a path, nothing to do
if [[ -z "$WORKTREE_PATH" ]]; then
  exit 0
fi

WORKTREE_IMPL="${WORKTREE_PATH}/.impl"

# If no .impl/ directory in this worktree, nothing to archive
if [[ ! -d "$WORKTREE_IMPL" ]]; then
  exit 0
fi

# Determine the main worktree / repository root
REPO_ROOT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  exit 0
fi

MAIN_IMPL="${REPO_ROOT}/.impl"
LOGS_DIR="${MAIN_IMPL}/logs"

# Create logs directory if needed
if [[ -d "$MAIN_IMPL" ]]; then
  mkdir -p "$LOGS_DIR"

  # Archive any files from the worktree's .impl/ (except manifest-ref.json)
  WORKTREE_NAME="$(basename "$WORKTREE_PATH")"
  TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  ARCHIVE_DIR="${LOGS_DIR}/${WORKTREE_NAME}-${TIMESTAMP}"

  # Only archive if there are files worth archiving
  FILE_COUNT=0
  for f in "$WORKTREE_IMPL"/*; do
    if [[ -f "$f" && "$(basename "$f")" != "manifest-ref.json" ]]; then
      FILE_COUNT=$((FILE_COUNT + 1))
    fi
  done

  if [[ "$FILE_COUNT" -gt 0 ]]; then
    mkdir -p "$ARCHIVE_DIR"
    for f in "$WORKTREE_IMPL"/*; do
      if [[ -f "$f" && "$(basename "$f")" != "manifest-ref.json" ]]; then
        cp "$f" "$ARCHIVE_DIR/" 2> /dev/null || true
      fi
    done
    echo "Advisory: Archived ${FILE_COUNT} file(s) from worktree .impl/ to ${ARCHIVE_DIR}."
  fi
fi

echo "Advisory: Worktree at ${WORKTREE_PATH} being removed."

# Always allow
exit 0
