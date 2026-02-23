#!/usr/bin/env bash
# detect-changes.sh — Compare architecture doc content against actual codebase state.
#
# Usage: detect-changes.sh --doc <path> [--root <path>]
#
# Reads an architecture document and compares its module references against
# the actual modules discovered via CLAUDE.md files. Reports discrepancies.
#
# Output format (one per line, tab-separated):
#   <type>\t<detail>\t<suggestion>
#
# Types:
#   missing_module  — doc references a module that doesn't exist
#   new_module      — module exists but is not mentioned in the doc
#   type_mismatch   — doc references a module type that doesn't match CLAUDE.md
#
# Exit codes:
#   0 — always (reporting tool, not a gate)
#   1 — script error

set -euo pipefail

DOC_PATH=""
ROOT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --doc)
    if [[ $# -lt 2 ]]; then
      echo "Error: --doc requires a value" >&2
      exit 1
    fi
    DOC_PATH="$2"
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

if [[ -z "$DOC_PATH" ]]; then
  echo "Error: --doc is required" >&2
  exit 1
fi

if [[ ! -f "$DOC_PATH" ]]; then
  echo "Error: document not found: $DOC_PATH" >&2
  exit 1
fi

if [[ -z "$ROOT_PATH" ]]; then
  ROOT_PATH="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
fi

# Build module inventory
declare -A ACTUAL_MODULES

while IFS= read -r claude_file; do
  mod_dir="$(dirname "$claude_file")"
  mod_type="unknown"

  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+Module[[:space:]]+Type ]]; then
      while IFS= read -r next_line; do
        next_line="$(echo "$next_line" | xargs)"
        if [[ -n "$next_line" ]]; then
          mod_type="$next_line"
          break
        fi
      done
      break
    fi
  done < "$claude_file"

  local_path="${mod_dir#"$ROOT_PATH"/}"
  if [[ "$mod_dir" == "$ROOT_PATH" ]]; then
    local_path="."
  fi
  ACTUAL_MODULES["$local_path"]="$mod_type"
done < <(find "$ROOT_PATH" -name "CLAUDE.md" \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/vendor/*" \
  2> /dev/null)

# Read the architecture doc
DOC_CONTENT="$(cat "$DOC_PATH")"

# Track which actual modules are referenced in the doc
declare -A REFERENCED_MODULES

# Check each actual module against the doc
for mod_path in "${!ACTUAL_MODULES[@]}"; do
  if [[ "$mod_path" == "." ]]; then
    continue
  fi

  mod_name="$(basename "$mod_path")"

  # Check if module path or name appears in the doc
  if echo "$DOC_CONTENT" | grep -q "$mod_path" 2> /dev/null \
    || echo "$DOC_CONTENT" | grep -q "$mod_name" 2> /dev/null; then
    REFERENCED_MODULES["$mod_path"]=1
  else
    printf '%s\t%s\t%s\n' \
      "new_module" \
      "${mod_path} (${ACTUAL_MODULES[$mod_path]})" \
      "Add reference to ${mod_path} in the architecture doc"
  fi
done

# Check for module references in the doc that don't match actual modules
# Look for path-like references (dir/subdir patterns)
while IFS= read -r path_ref; do
  # Skip empty and common non-module paths
  if [[ -z "$path_ref" ]] || [[ "$path_ref" == "docs/"* ]] || [[ "$path_ref" == ".github/"* ]]; then
    continue
  fi

  # Check if this referenced path exists as a module
  found=false
  for mod_path in "${!ACTUAL_MODULES[@]}"; do
    if [[ "$mod_path" == "$path_ref"* ]] || [[ "$path_ref" == "$mod_path"* ]]; then
      found=true
      break
    fi
  done

  if [[ "$found" == false ]] && [[ -n "$path_ref" ]]; then
    # Check if the path exists at all
    if [[ ! -d "${ROOT_PATH}/${path_ref}" ]]; then
      printf '%s\t%s\t%s\n' \
        "missing_module" \
        "${path_ref}" \
        "Remove or update reference — directory no longer exists"
    fi
  fi
done < <(grep -oP '`[a-zA-Z][a-zA-Z0-9_-]*/[a-zA-Z0-9_/-]+`' "$DOC_PATH" 2> /dev/null \
  | sed 's/`//g' | sort -u || echo "")

exit 0
