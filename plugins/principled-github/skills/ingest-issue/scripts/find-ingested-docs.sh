#!/usr/bin/env bash
# find-ingested-docs.sh — Search for existing principled docs linked to a GitHub issue.
#
# Usage: find-ingested-docs.sh --issue <issue-number> [--docs-dir <path>]
#
# Searches proposal and plan files for the ingest marker comment:
#   <!-- principled-ingested-from: #<issue-number> -->
#
# Output format (one per line):
#   <type>:<path>
#   e.g., proposal:docs/proposals/003-my-feature.md
#         plan:docs/plans/002-my-feature.md
#
# Exit codes:
#   0 — always (empty output means not found)

set -euo pipefail

ISSUE_NUMBER=""
DOCS_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --issue)
    ISSUE_NUMBER="$2"
    shift 2
    ;;
  --docs-dir)
    DOCS_DIR="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$ISSUE_NUMBER" ]]; then
  echo "Error: --issue is required" >&2
  exit 1
fi

# Default to repo root docs/
if [[ -z "$DOCS_DIR" ]]; then
  DOCS_DIR="docs"
fi

MARKER="principled-ingested-from: #${ISSUE_NUMBER}"

# Search proposals
if [[ -d "${DOCS_DIR}/proposals" ]]; then
  for file in "${DOCS_DIR}/proposals/"*.md; do
    [[ -e "$file" ]] || continue
    if grep -q "$MARKER" "$file" 2> /dev/null; then
      echo "proposal:${file}"
    fi
  done
fi

# Search plans
if [[ -d "${DOCS_DIR}/plans" ]]; then
  for file in "${DOCS_DIR}/plans/"*.md; do
    [[ -e "$file" ]] || continue
    if grep -q "$MARKER" "$file" 2> /dev/null; then
      echo "plan:${file}"
    fi
  done
fi

exit 0
