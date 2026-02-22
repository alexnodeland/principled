#!/usr/bin/env bash
# map-files-to-modules.sh — Map file paths to their principled modules.
#
# Usage: map-files-to-modules.sh --files <file1,file2,...>
#
# For each file, walks up the directory tree to find the nearest CLAUDE.md.
# Extracts the module type from that CLAUDE.md. Outputs a tab-separated
# mapping: file_path<TAB>module_path<TAB>module_type
#
# Exit codes:
#   0 — always
#   1 — invalid arguments

set -euo pipefail

FILES=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --files)
      FILES="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      echo "Usage: map-files-to-modules.sh --files <file1,file2,...>" >&2
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

# Extract module type from a CLAUDE.md file
extract_module_type() {
  local claude_md="$1"
  local module_type=""

  # Look for "## Module Type" section and extract the next non-empty line
  local in_section=false
  while IFS= read -r line; do
    if echo "$line" | grep -qiE '^##\s+Module Type'; then
      in_section=true
      continue
    fi
    if [[ "$in_section" == true ]]; then
      # Skip empty lines
      if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
        continue
      fi
      # Stop at next heading
      if echo "$line" | grep -qE '^#'; then
        break
      fi
      module_type="$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
      break
    fi
  done < "$claude_md"

  echo "$module_type"
}

IFS=',' read -ra FILE_ARRAY <<< "$FILES"
for file in "${FILE_ARRAY[@]}"; do
  # Walk up from the file to find nearest CLAUDE.md
  dir="$(dirname "$file")"
  # Make absolute if relative
  if [[ "$dir" != /* ]]; then
    dir="$REPO_ROOT/$dir"
  fi

  module_path=""
  module_type="unknown"

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]]; then
      module_path="$dir"
      module_type="$(extract_module_type "$dir/CLAUDE.md")"
      break
    fi
    dir="$(dirname "$dir")"
  done

  # Make module_path relative to repo root for cleaner output
  if [[ -n "$module_path" ]]; then
    module_path="${module_path#"$REPO_ROOT"/}"
    if [[ "$module_path" == "$REPO_ROOT" ]]; then
      module_path="."
    fi
  else
    module_path="(no module)"
  fi

  printf '%s\t%s\t%s\n' "$file" "$module_path" "$module_type"
done

exit 0
