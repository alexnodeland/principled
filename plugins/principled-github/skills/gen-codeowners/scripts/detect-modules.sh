#!/usr/bin/env bash
# detect-modules.sh — Find module directories in the repository.
#
# Usage: detect-modules.sh [--modules-dir <path>]
#
# Scans for directories containing CLAUDE.md, docs/, or package.json
# that indicate a principled module boundary.
#
# Output: one module path per line (relative to repo root)

set -euo pipefail

MODULES_DIR=""
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --modules-dir)
    MODULES_DIR="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

# If modules-dir specified, scan only that directory
if [[ -n "$MODULES_DIR" ]]; then
  SEARCH_ROOT="$REPO_ROOT/$MODULES_DIR"
else
  SEARCH_ROOT="$REPO_ROOT"
fi

if [[ ! -d "$SEARCH_ROOT" ]]; then
  echo "Error: directory not found: $SEARCH_ROOT" >&2
  exit 1
fi

# Find directories that look like modules
# A module has at minimum one of: CLAUDE.md, docs/ directory, package.json
for dir in "$SEARCH_ROOT"/*/; do
  [[ -d "$dir" ]] || continue

  # Skip hidden directories and common non-module directories
  dirname="$(basename "$dir")"
  case "$dirname" in
  .* | node_modules | dist | build | coverage | __pycache__)
    continue
    ;;
  esac

  IS_MODULE=false

  if [[ -f "$dir/CLAUDE.md" ]]; then
    IS_MODULE=true
  elif [[ -d "$dir/docs" ]]; then
    IS_MODULE=true
  elif [[ -f "$dir/package.json" ]]; then
    IS_MODULE=true
  fi

  if $IS_MODULE; then
    # Output path relative to repo root
    REL_PATH="${dir#"$REPO_ROOT"/}"
    # Remove trailing slash
    REL_PATH="${REL_PATH%/}"
    echo "$REL_PATH"
  fi
done
