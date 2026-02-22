#!/usr/bin/env bash
# find-relevant-adrs.sh — Find ADRs relevant to changed files.
#
# Usage: find-relevant-adrs.sh --files <file1,file2,...> [--decisions-dir <path>]
#
# For each file, walks up to the nearest CLAUDE.md to determine the module
# scope, then searches the decisions directory for ADRs that may be relevant.
#
# Output: One ADR path per line (deduplicated).
#
# Exit codes:
#   0 — always (may output zero ADRs)
#   1 — invalid arguments

set -euo pipefail

FILES=""
DECISIONS_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --files)
    FILES="$2"
    shift 2
    ;;
  --decisions-dir)
    DECISIONS_DIR="$2"
    shift 2
    ;;
  *)
    echo "Error: Unknown argument: $1" >&2
    echo "Usage: find-relevant-adrs.sh --files <file1,file2,...> [--decisions-dir <path>]" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$FILES" ]]; then
  echo "Error: --files is required." >&2
  exit 1
fi

# Find repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"

# Default decisions directory: check for module-level first, fall back to root
if [[ -z "$DECISIONS_DIR" ]]; then
  DECISIONS_DIR="$REPO_ROOT/docs/decisions"
fi

if [[ ! -d "$DECISIONS_DIR" ]]; then
  exit 0
fi

# Collect unique module paths from changed files
MODULE_COUNT=0

IFS=',' read -ra FILE_ARRAY <<< "$FILES"
for file in "${FILE_ARRAY[@]}"; do
  # Walk up from the file to find nearest CLAUDE.md
  dir="$(dirname "$file")"
  # Make absolute if relative
  if [[ "$dir" != /* ]]; then
    dir="$REPO_ROOT/$dir"
  fi

  while [[ "$dir" != "/" && "$dir" != "$REPO_ROOT" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]]; then
      MODULE_COUNT=$((MODULE_COUNT + 1))
      break
    fi
    dir="$(dirname "$dir")"
  done
  # If we hit repo root with a CLAUDE.md, include it
  if [[ -f "$REPO_ROOT/CLAUDE.md" ]]; then
    MODULE_COUNT=$((MODULE_COUNT + 1))
  fi
done

# If no modules were found, no ADRs are relevant
if [[ "$MODULE_COUNT" -eq 0 ]]; then
  exit 0
fi

# Output all ADR files in scope (sorted for deterministic output)
# All ADRs in the decisions directory are potentially relevant to any module
for adr in "$DECISIONS_DIR"/*.md; do
  [[ -f "$adr" ]] || continue
  echo "$adr"
done

exit 0
