#!/usr/bin/env bash
# scan-modules.sh — Discover modules via CLAUDE.md files and extract module type.
#
# Usage: scan-modules.sh [--module <path>] [--root <path>]
#
# Finds all CLAUDE.md files (per ADR-003), parses the "## Module Type"
# section, and outputs a tab-separated module inventory.
#
# Output format (one per line, tab-separated):
#   <module-path>\t<module-type>\t<module-name>
#
# module-name is the last component of the module path, or the repo name
# for the root module.
#
# Exit codes:
#   0 — success (empty output means no modules found)
#   1 — error

set -euo pipefail

MODULE_PATH=""
ROOT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --module)
    if [[ $# -lt 2 ]]; then
      echo "Error: --module requires a value" >&2
      exit 1
    fi
    MODULE_PATH="$2"
    shift 2
    ;;
  --root)
    if [[ $# -lt 2 ]]; then
      echo "Error: --root requires a value" >&2
      exit 1
    fi
    ROOT_PATH="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

# Default root to repo root or current directory
if [[ -z "$ROOT_PATH" ]]; then
  ROOT_PATH="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
fi

# Parse module type from CLAUDE.md
parse_module_type() {
  local claude_md="$1"
  local module_type="unknown"

  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+Module[[:space:]]+Type ]]; then
      # Read the next non-empty line
      while IFS= read -r next_line; do
        next_line="$(echo "$next_line" | xargs)"
        if [[ -n "$next_line" ]]; then
          module_type="$next_line"
          break
        fi
      done
      break
    fi
  done < "$claude_md"

  echo "$module_type"
}

# Process a single module
process_module() {
  local module_dir="$1"
  local claude_md="${module_dir}/CLAUDE.md"

  if [[ ! -f "$claude_md" ]]; then
    return
  fi

  local module_type
  module_type="$(parse_module_type "$claude_md")"

  # Derive module name from path
  local module_name
  if [[ "$module_dir" == "$ROOT_PATH" ]] || [[ "$module_dir" == "." ]]; then
    module_name="$(basename "$ROOT_PATH")"
  else
    module_name="$(basename "$module_dir")"
  fi

  # Make path relative to repo root for cleaner output
  local rel_path
  if [[ "$module_dir" == "$ROOT_PATH" ]]; then
    rel_path="."
  else
    rel_path="${module_dir#"$ROOT_PATH"/}"
  fi

  printf '%s\t%s\t%s\n' "$rel_path" "$module_type" "$module_name"
}

# If a specific module is requested, only process that one
if [[ -n "$MODULE_PATH" ]]; then
  if [[ ! -d "$MODULE_PATH" ]]; then
    echo "Error: module directory not found: $MODULE_PATH" >&2
    exit 1
  fi
  process_module "$MODULE_PATH"
  exit 0
fi

# Process root first if it has a CLAUDE.md
if [[ -f "${ROOT_PATH}/CLAUDE.md" ]]; then
  process_module "$ROOT_PATH"
fi

# Find nested modules (skip root, node_modules, .git, vendor)
while IFS= read -r claude_file; do
  module_dir="$(dirname "$claude_file")"

  # Skip the root (already processed)
  if [[ "$module_dir" == "$ROOT_PATH" ]] || [[ "$module_dir" == "." ]]; then
    continue
  fi

  process_module "$module_dir"
done < <(find "$ROOT_PATH" -name "CLAUDE.md" \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/vendor/*" \
  2> /dev/null | sort)

exit 0
