#!/usr/bin/env bash
# find-synced-issue.sh — Search for an existing GitHub issue synced to a document.
#
# Usage: find-synced-issue.sh --doc-path <relative-path>
#
# Searches GitHub issues for the sync marker comment:
#   <!-- principled-sync: <doc-path> -->
#
# Output:
#   If found: issue number (e.g., "42")
#   If not found: empty string
#
# Exit codes:
#   0 — always (empty output means not found)

set -euo pipefail

DOC_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --doc-path)
    DOC_PATH="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$DOC_PATH" ]]; then
  echo "Error: --doc-path is required" >&2
  exit 1
fi

SYNC_MARKER="principled-sync: ${DOC_PATH}"

# Search issues for the sync marker
# Use gh api for more flexible search
ISSUE_NUMBER=""
if command -v gh &> /dev/null; then
  ISSUE_NUMBER="$(
    gh issue list \
      --state all \
      --limit 100 \
      --json number,body \
      --jq ".[] | select(.body | contains(\"${SYNC_MARKER}\")) | .number" \
      2> /dev/null \
      | head -1 \
      || echo ""
  )"
fi

echo "$ISSUE_NUMBER"
exit 0
