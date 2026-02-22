#!/usr/bin/env bash
# list-untriaged.sh — List open GitHub issues not yet in the principled pipeline.
#
# Usage: list-untriaged.sh [--label <filter>] [--limit <n>]
#
# An issue is "untriaged" if it:
#   1. Is open
#   2. Does not have principled lifecycle labels (proposal:*, plan:*, type:rfc, type:plan)
#   3. Does not have a principled-ingest-comment in its comments
#
# Output format (one per line):
#   <number>\t<title>
#
# Exit codes:
#   0 — success (empty output means no untriaged issues)
#   1 — error

set -euo pipefail

LABEL_FILTER=""
LIMIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --label)
    LABEL_FILTER="$2"
    shift 2
    ;;
  --limit)
    LIMIT="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

# Build gh issue list command arguments
GH_ARGS=(issue list --state open --json "number,title,labels,comments" --limit 200)

if [[ -n "$LABEL_FILTER" ]]; then
  GH_ARGS+=(--label "$LABEL_FILTER")
fi

# Fetch open issues
ISSUES_JSON="$(gh "${GH_ARGS[@]}" 2>&1)" || {
  echo "Error: failed to list issues" >&2
  exit 1
}

# Filter out already-triaged issues
# An issue is triaged if it has principled lifecycle labels OR an ingest comment
if command -v jq &> /dev/null; then
  UNTRIAGED="$(echo "$ISSUES_JSON" | jq -r '
    [.[] |
      select(
        ([.labels[].name] | any(
          startswith("proposal:") or
          startswith("plan:") or
          . == "type:rfc" or
          . == "type:plan"
        )) | not
      ) |
      select(
        ([.comments[].body // ""] | any(
          contains("principled-ingest-comment")
        )) | not
      )
    ] | .[] | "\(.number)\t\(.title)"
  ' 2> /dev/null || echo "")"
else
  # Fallback: use gh with simpler jq expressions
  UNTRIAGED="$(echo "$ISSUES_JSON" | gh api --input - \
    --jq '
      [.[] |
        select(
          ([.labels[].name] | any(
            startswith("proposal:") or
            startswith("plan:") or
            . == "type:rfc" or
            . == "type:plan"
          )) | not
        )
      ] | .[] | "\(.number)\t\(.title)"
    ' 2> /dev/null || echo "")"
fi

# Apply limit if specified
if [[ -n "$LIMIT" && -n "$UNTRIAGED" ]]; then
  UNTRIAGED="$(echo "$UNTRIAGED" | head -n "$LIMIT")"
fi

echo "$UNTRIAGED"
exit 0
