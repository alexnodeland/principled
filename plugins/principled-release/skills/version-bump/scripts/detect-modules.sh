#!/usr/bin/env bash
# detect-modules.sh — Detect modules and their version manifest files.
#
# Usage: detect-modules.sh [--module <path>] [--root <path>]
#
# Finds modules via CLAUDE.md files (ADR-003), then locates their version
# manifest files (package.json, Cargo.toml, pyproject.toml, VERSION, etc.).
#
# Output format (one per line, tab-separated):
#   <module-path>\t<module-type>\t<manifest-file>\t<current-version>
#
# If no manifest is found, manifest-file and current-version are "-".
#
# Exit codes:
#   0 — success (empty output means no modules found)
#   1 — error

set -euo pipefail

MODULE_PATH=""
ROOT_PATH="."

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

# Extract version from a manifest file
extract_version() {
  local manifest="$1"
  local version=""

  case "$(basename "$manifest")" in
  package.json | plugin.json)
    if command -v jq &> /dev/null; then
      version="$(jq -r '.version // empty' "$manifest" 2> /dev/null || echo "")"
    else
      version="$(grep -oP '"version"\s*:\s*"\K[^"]*' "$manifest" | head -1 || echo "")"
    fi
    ;;
  Cargo.toml | pyproject.toml)
    version="$(grep -oP '^version\s*=\s*"\K[^"]*' "$manifest" | head -1 || echo "")"
    ;;
  VERSION)
    version="$(head -1 "$manifest" | xargs)"
    ;;
  esac

  echo "$version"
}

# Find version manifest in a directory
find_manifest() {
  local dir="$1"
  local manifests=("package.json" "Cargo.toml" "pyproject.toml" "VERSION")

  # Also check .claude-plugin/plugin.json
  if [[ -f "${dir}/.claude-plugin/plugin.json" ]]; then
    echo "${dir}/.claude-plugin/plugin.json"
    return
  fi

  for manifest in "${manifests[@]}"; do
    if [[ -f "${dir}/${manifest}" ]]; then
      echo "${dir}/${manifest}"
      return
    fi
  done

  echo ""
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

  local manifest
  manifest="$(find_manifest "$module_dir")"

  if [[ -n "$manifest" ]]; then
    local version
    version="$(extract_version "$manifest")"
    printf '%s\t%s\t%s\t%s\n' "$module_dir" "$module_type" "$manifest" "${version:-0.0.0}"
  else
    printf '%s\t%s\t%s\t%s\n' "$module_dir" "$module_type" "-" "-"
  fi
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

# Otherwise, find all modules under root
# Process root first if it has a CLAUDE.md
if [[ -f "${ROOT_PATH}/CLAUDE.md" ]]; then
  process_module "$ROOT_PATH"
fi

# Then find nested modules (skip root, skip node_modules and .git)
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
