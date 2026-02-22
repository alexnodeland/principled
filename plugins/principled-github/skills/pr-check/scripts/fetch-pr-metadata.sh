#!/usr/bin/env bash
# fetch-pr-metadata.sh — Fetch PR details from GitHub.
#
# Usage: fetch-pr-metadata.sh --pr <number>
#
# Output format (key=value, one per line):
#   title=<value>
#   body=<value>  (base64 encoded to preserve newlines)
#   labels=<comma-separated>
#   base=<base-branch>
#   head=<head-branch>
#   state=<OPEN|CLOSED|MERGED>
#   files_changed=<count>

set -euo pipefail

PR_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --pr)
    PR_NUMBER="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$PR_NUMBER" ]]; then
  echo "Error: --pr is required" >&2
  exit 1
fi

# Fetch PR data
PR_JSON="$(gh pr view "$PR_NUMBER" --json title,body,labels,baseRefName,headRefName,state,files 2> /dev/null || echo "")"

if [[ -z "$PR_JSON" ]]; then
  echo "Error: could not fetch PR #${PR_NUMBER}" >&2
  exit 1
fi

if command -v jq &> /dev/null; then
  TITLE="$(echo "$PR_JSON" | jq -r '.title // ""')"
  BODY="$(echo "$PR_JSON" | jq -r '.body // ""' | base64 -w 0 2> /dev/null || echo "$PR_JSON" | jq -r '.body // ""' | base64)"
  LABELS="$(echo "$PR_JSON" | jq -r '[.labels[].name] | join(",")' 2> /dev/null || echo "")"
  BASE="$(echo "$PR_JSON" | jq -r '.baseRefName // ""')"
  HEAD="$(echo "$PR_JSON" | jq -r '.headRefName // ""')"
  STATE="$(echo "$PR_JSON" | jq -r '.state // ""')"
  FILES_CHANGED="$(echo "$PR_JSON" | jq -r '.files | length' 2> /dev/null || echo "0")"
else
  TITLE="$(echo "$PR_JSON" | grep -oP '"title"\s*:\s*"\K[^"]*' | head -1 || echo "")"
  BODY="$(echo "$PR_JSON" | grep -oP '"body"\s*:\s*"\K[^"]*' | head -1 | base64 -w 0 2> /dev/null || echo "")"
  LABELS=""
  BASE=""
  HEAD=""
  STATE=""
  FILES_CHANGED="0"
fi

echo "title=${TITLE}"
echo "body=${BODY}"
echo "labels=${LABELS}"
echo "base=${BASE}"
echo "head=${HEAD}"
echo "state=${STATE}"
echo "files_changed=${FILES_CHANGED}"
