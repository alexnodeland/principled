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
#   files=<comma-separated file paths>

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
  FILES="$(echo "$PR_JSON" | jq -r '[.files[].path] | join(",")' 2> /dev/null || echo "")"
else
  # Fallback: use gh's built-in --jq (gojq) for field extraction,
  # avoiding grep -P which is unavailable on macOS.
  TITLE="$(gh pr view "$PR_NUMBER" --json title --jq '.title' 2> /dev/null || echo "")"
  BODY_RAW="$(gh pr view "$PR_NUMBER" --json body --jq '.body' 2> /dev/null || echo "")"
  BODY="$(echo "$BODY_RAW" | base64 -w 0 2> /dev/null || echo "$BODY_RAW" | base64)"
  LABELS="$(gh pr view "$PR_NUMBER" --json labels --jq '[.labels[].name] | join(",")' 2> /dev/null || echo "")"
  BASE="$(gh pr view "$PR_NUMBER" --json baseRefName --jq '.baseRefName' 2> /dev/null || echo "")"
  HEAD="$(gh pr view "$PR_NUMBER" --json headRefName --jq '.headRefName' 2> /dev/null || echo "")"
  STATE="$(gh pr view "$PR_NUMBER" --json state --jq '.state' 2> /dev/null || echo "")"
  FILES_CHANGED="$(gh pr view "$PR_NUMBER" --json files --jq '.files | length' 2> /dev/null || echo "0")"
  FILES="$(gh pr view "$PR_NUMBER" --json files --jq '[.files[].path] | join(",")' 2> /dev/null || echo "")"
fi

echo "title=${TITLE}"
echo "body=${BODY}"
echo "labels=${LABELS}"
echo "base=${BASE}"
echo "head=${HEAD}"
echo "state=${STATE}"
echo "files_changed=${FILES_CHANGED}"
echo "files=${FILES}"
