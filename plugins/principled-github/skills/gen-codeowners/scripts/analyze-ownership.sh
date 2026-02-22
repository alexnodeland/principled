#!/usr/bin/env bash
# analyze-ownership.sh — Determine code ownership from git history.
#
# Usage: analyze-ownership.sh --module <module-path> [--limit <N>]
#
# Analyzes git shortlog for the given module path and returns
# the top contributors sorted by commit count.
#
# Output format (one per line):
#   <commit-count> <email> <name>

set -euo pipefail

MODULE=""
LIMIT=3

while [[ $# -gt 0 ]]; do
  case "$1" in
  --module)
    MODULE="$2"
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

if [[ -z "$MODULE" ]]; then
  echo "Error: --module is required" >&2
  exit 1
fi

if [[ ! -d "$MODULE" ]]; then
  echo "Error: module directory not found: $MODULE" >&2
  exit 1
fi

# Get top contributors by commit count
# Format: count<TAB>name <email>
git shortlog -sne --no-merges -- "$MODULE" 2> /dev/null \
  | head -"$LIMIT" \
  | while IFS=$'\t' read -r count author; do
    # Extract email from "Name <email>" format
    email=""
    name="$author"
    if [[ "$author" =~ \<([^>]+)\> ]]; then
      email="${BASH_REMATCH[1]}"
      name="${author%% <*}"
      # Trim leading/trailing whitespace from name
      name="$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    fi
    echo "${count} ${email} ${name}"
  done

exit 0
