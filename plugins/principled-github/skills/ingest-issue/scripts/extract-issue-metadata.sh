#!/usr/bin/env bash
# extract-issue-metadata.sh — Fetch and parse a GitHub issue for ingestion.
#
# Usage: extract-issue-metadata.sh --number <issue-number>
#
# Fetches a GitHub issue via the gh CLI and outputs key-value pairs
# for downstream consumption.
#
# Output format (one per line):
#   title=<value>
#   number=<value>
#   author=<value>
#   created=<value>
#   state=<value>
#   labels=<comma-separated>
#   body=<issue body text>
#   comment_count=<number>
#
# Exit codes:
#   0 — success
#   1 — error (missing args, issue not found)

set -euo pipefail

NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --number)
    NUMBER="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$NUMBER" ]]; then
  echo "Error: --number is required" >&2
  exit 1
fi

# Fetch issue data via gh CLI
ISSUE_JSON=""
if command -v jq &> /dev/null; then
  ISSUE_JSON="$(gh issue view "$NUMBER" --json title,author,createdAt,state,labels,body,comments 2>&1)" || {
    echo "Error: failed to fetch issue #${NUMBER}" >&2
    exit 1
  }

  TITLE="$(echo "$ISSUE_JSON" | jq -r '.title // ""')"
  AUTHOR="$(echo "$ISSUE_JSON" | jq -r '.author.login // ""')"
  CREATED="$(echo "$ISSUE_JSON" | jq -r '.createdAt // ""' | cut -d'T' -f1)"
  STATE="$(echo "$ISSUE_JSON" | jq -r '.state // ""')"
  LABELS="$(echo "$ISSUE_JSON" | jq -r '[.labels[].name] | join(",")' 2> /dev/null || echo "")"
  BODY="$(echo "$ISSUE_JSON" | jq -r '.body // ""')"
  COMMENT_COUNT="$(echo "$ISSUE_JSON" | jq -r '.comments | length' 2> /dev/null || echo "0")"
else
  # Fallback: use gh with field selectors
  TITLE="$(gh issue view "$NUMBER" --json title --jq '.title' 2> /dev/null || echo "")"
  AUTHOR="$(gh issue view "$NUMBER" --json author --jq '.author.login' 2> /dev/null || echo "")"
  CREATED="$(gh issue view "$NUMBER" --json createdAt --jq '.createdAt' 2> /dev/null | cut -d'T' -f1 || echo "")"
  STATE="$(gh issue view "$NUMBER" --json state --jq '.state' 2> /dev/null || echo "")"
  LABELS="$(gh issue view "$NUMBER" --json labels --jq '[.labels[].name] | join(",")' 2> /dev/null || echo "")"
  BODY="$(gh issue view "$NUMBER" --json body --jq '.body' 2> /dev/null || echo "")"
  COMMENT_COUNT="$(gh issue view "$NUMBER" --json comments --jq '.comments | length' 2> /dev/null || echo "0")"
fi

if [[ -z "$TITLE" ]]; then
  echo "Error: could not fetch issue #${NUMBER}" >&2
  exit 1
fi

echo "title=${TITLE}"
echo "number=${NUMBER}"
echo "author=${AUTHOR}"
echo "created=${CREATED}"
echo "state=${STATE}"
echo "labels=${LABELS}"
echo "comment_count=${COMMENT_COUNT}"
# Body is output last, prefixed, so multiline content doesn't break parsing
echo "body<<BODY_EOF"
echo "$BODY"
echo "BODY_EOF"
