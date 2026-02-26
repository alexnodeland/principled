#!/usr/bin/env bash
# list-untriaged.sh — List open GitHub issues not yet in the principled pipeline.
#
# Usage: list-untriaged.sh [--label <filter>] [--limit <n>]
#
# An issue is "untriaged" if it:
#   1. Is open
#   2. Does not have principled labels (proposal:*, plan:*, type:rfc, type:plan)
#
# Note: comment-body detection (principled-ingest-comment markers) is not possible
# via gh issue list, which does not return comment bodies. Label-based detection is
# the primary signal. Issues ingested via /ingest-issue always get lifecycle labels,
# so label-only detection is sufficient for the common case.
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
    if [[ $# -lt 2 ]]; then
      echo "Error: --label requires a value" >&2
      exit 1
    fi
    LABEL_FILTER="$2"
    shift 2
    ;;
  --limit)
    if [[ $# -lt 2 ]]; then
      echo "Error: --limit requires a value" >&2
      exit 1
    fi
    if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -eq 0 ]]; then
      echo "Error: --limit must be a positive integer" >&2
      exit 1
    fi
    LIMIT="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

# Fetch up to 500 open issues. This is a practical cap — repos with more
# should use --label to filter or run triage multiple times.
GH_ARGS=(issue list --state open --json "number,title,labels" --limit 500)

if [[ -n "$LABEL_FILTER" ]]; then
  GH_ARGS+=(--label "$LABEL_FILTER")
fi

# Filter out already-triaged issues (those with principled lifecycle labels).
# Uses jq if available, falls back to gh's built-in --jq (gojq).
JQ_FILTER='
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
'

if command -v jq &> /dev/null; then
  # Fetch issues, then filter with standalone jq
  if ! ISSUES_JSON="$(gh "${GH_ARGS[@]}" 2> /dev/null)"; then
    echo "Error: failed to list issues. Check gh auth status." >&2
    exit 1
  fi
  UNTRIAGED="$(echo "$ISSUES_JSON" | jq -r "$JQ_FILTER")" || {
    echo "Error: failed to filter issues with jq" >&2
    exit 1
  }
else
  # Fallback: use gh's built-in --jq (gojq) which works without standalone jq.
  # This avoids grep -P (unavailable on macOS) and nested JSON parsing issues.
  GH_ARGS+=(--jq "$JQ_FILTER")
  if ! UNTRIAGED="$(gh "${GH_ARGS[@]}" 2> /dev/null)"; then
    echo "Error: failed to list issues. Check gh auth status." >&2
    exit 1
  fi
fi

# Apply limit if specified
if [[ -n "$LIMIT" && -n "$UNTRIAGED" ]]; then
  UNTRIAGED="$(echo "$UNTRIAGED" | head -n "$LIMIT")"
fi

# Only print if non-empty (avoid trailing newline on empty result)
if [[ -n "$UNTRIAGED" ]]; then
  echo "$UNTRIAGED"
fi
exit 0
