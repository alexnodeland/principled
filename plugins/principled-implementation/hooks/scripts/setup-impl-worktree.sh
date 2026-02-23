#!/usr/bin/env bash
# setup-impl-worktree.sh — WorktreeCreate hook: initialize task state in new worktrees.
#
# Receives JSON via stdin with worktree creation context.
# When an active .impl/manifest.json exists in the main worktree, creates
# a .impl/ directory in the new worktree with a reference to the manifest.
#
# Advisory only — never blocks worktree creation.
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

# Determine the main worktree / repository root
REPO_ROOT=""
REPO_ROOT="$(git -C "$WORKTREE_PATH" rev-parse --show-toplevel 2> /dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  exit 0
fi

# The main worktree's manifest
MAIN_MANIFEST="${REPO_ROOT}/.impl/manifest.json"

# If no active manifest, nothing to initialize
if [[ ! -f "$MAIN_MANIFEST" ]]; then
  exit 0
fi

# Create .impl/ directory in the new worktree
WORKTREE_IMPL="${WORKTREE_PATH}/.impl"
mkdir -p "$WORKTREE_IMPL"

# Write a reference file pointing to the main manifest
cat > "${WORKTREE_IMPL}/manifest-ref.json" << REFEOF
{
  "main_manifest": "${MAIN_MANIFEST}",
  "worktree_path": "${WORKTREE_PATH}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
REFEOF

echo "Advisory: Initialized .impl/ in worktree with reference to main manifest."

# Always allow
exit 0
