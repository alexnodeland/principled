#!/usr/bin/env bash
# analyze-branch.sh — Analyze branch changes for PR description generation.
#
# Usage: analyze-branch.sh [--branch <name>] [--base <base-branch>]
#
# Output format (sections separated by blank lines):
#   files_changed=<count>
#   insertions=<count>
#   deletions=<count>
#   commits=<count>
#   ---FILES---
#   <list of changed files>
#   ---COMMITS---
#   <list of commit messages>

set -euo pipefail

BRANCH=""
BASE="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --branch)
    BRANCH="$2"
    shift 2
    ;;
  --base)
    BASE="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

# Default to current branch
if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null || echo "")"
fi

if [[ -z "$BRANCH" ]]; then
  echo "Error: could not determine current branch" >&2
  exit 1
fi

# Determine merge base
MERGE_BASE="$(git merge-base "$BASE" "$BRANCH" 2> /dev/null || echo "")"
if [[ -z "$MERGE_BASE" ]]; then
  # If no merge base found, compare against base directly
  MERGE_BASE="$BASE"
fi

# File statistics
FILES_CHANGED="$(git diff --name-only "$MERGE_BASE...$BRANCH" 2> /dev/null | wc -l | tr -d ' ')"
INSERTIONS="$(git diff --numstat "$MERGE_BASE...$BRANCH" 2> /dev/null | awk '{s+=$1} END {print s+0}')"
DELETIONS="$(git diff --numstat "$MERGE_BASE...$BRANCH" 2> /dev/null | awk '{s+=$2} END {print s+0}')"

# Commit count
COMMITS="$(git rev-list --count "$MERGE_BASE...$BRANCH" 2> /dev/null || echo "0")"

echo "files_changed=$FILES_CHANGED"
echo "insertions=$INSERTIONS"
echo "deletions=$DELETIONS"
echo "commits=$COMMITS"
echo "---FILES---"
git diff --name-only "$MERGE_BASE...$BRANCH" 2> /dev/null || true
echo "---COMMITS---"
git log --oneline "$MERGE_BASE...$BRANCH" 2> /dev/null || true
