#!/usr/bin/env bash
# check-boundaries.sh — Check module boundary violations via import analysis.
#
# Usage: check-boundaries.sh --module <path> --type <module-type> [--root <path>]
#
# Scans source files in the given module for import/require/from statements,
# checks import paths against dependency direction rules, and reports violations.
#
# Dependency direction rules (ADR-014):
#   app  → can depend on lib, core
#   lib  → can depend on core
#   core → no internal module dependencies
#
# Output format (one per line, tab-separated):
#   <severity>\t<file>\t<line>\t<imported-module>\t<imported-type>\t<rule>
#
# Exit codes:
#   0 — no error-severity violations found (or advisory mode)
#   2 — error-severity violations found (when used with strict checking)
#   1 — script error

set -euo pipefail

MODULE_PATH=""
MODULE_TYPE=""
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
  --type)
    if [[ $# -lt 2 ]]; then
      echo "Error: --type requires a value" >&2
      exit 1
    fi
    MODULE_TYPE="$2"
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

if [[ -z "$MODULE_PATH" ]]; then
  echo "Error: --module is required" >&2
  exit 1
fi

if [[ -z "$MODULE_TYPE" ]]; then
  echo "Error: --type is required" >&2
  exit 1
fi

if [[ -z "$ROOT_PATH" ]]; then
  ROOT_PATH="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
fi

# Build a map of all modules and their types
declare -A MODULE_TYPES

while IFS= read -r claude_file; do
  mod_dir="$(dirname "$claude_file")"
  # Parse module type
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

  # Store relative path
  local_path="${mod_dir#"$ROOT_PATH"/}"
  if [[ "$mod_dir" == "$ROOT_PATH" ]]; then
    local_path="."
  fi
  MODULE_TYPES["$local_path"]="$mod_type"
done < <(find "$ROOT_PATH" -name "CLAUDE.md" \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/vendor/*" \
  2> /dev/null)

# Check if a dependency is allowed
# Returns 0 if allowed, 1 if violation
check_dependency() {
  local from_type="$1"
  local to_type="$2"

  case "$from_type" in
  app)
    # app can depend on lib and core
    if [[ "$to_type" == "lib" || "$to_type" == "core" ]]; then
      return 0
    fi
    return 1
    ;;
  lib)
    # lib can depend on core only (by default)
    if [[ "$to_type" == "core" ]]; then
      return 0
    fi
    return 1
    ;;
  core)
    # core cannot depend on any internal module
    return 1
    ;;
  *)
    # Unknown type — allow (don't flag what we don't understand)
    return 0
    ;;
  esac
}

# Determine severity based on violation type
get_severity() {
  local from_type="$1"
  local to_type="$2"

  # core importing from app/lib is always an error
  if [[ "$from_type" == "core" ]]; then
    echo "error"
    return
  fi

  # lib importing from app is an error
  if [[ "$from_type" == "lib" && "$to_type" == "app" ]]; then
    echo "error"
    return
  fi

  # Other cases are warnings
  echo "warning"
}

VIOLATIONS=0
ERROR_VIOLATIONS=0

# Make module path relative
REL_MODULE="${MODULE_PATH#"$ROOT_PATH"/}"

# Scan source files for import statements
while IFS= read -r source_file; do
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Extract imported paths from various import syntaxes
    imported_path=""

    # JavaScript/TypeScript: import ... from '...'
    if echo "$line" | grep -qE "^\s*(import|export)\s+.*\s+from\s+['\"]"; then
      imported_path="$(echo "$line" | grep -oP "from\s+['\"]\\K[^'\"]*" || echo "")"
    # JavaScript: require('...')
    elif echo "$line" | grep -qE "require\s*\(\s*['\"]"; then
      imported_path="$(echo "$line" | grep -oP "require\s*\(\s*['\"]\\K[^'\"]*" || echo "")"
    # Python: from ... import ...
    elif echo "$line" | grep -qE "^\s*from\s+\S+\s+import"; then
      imported_path="$(echo "$line" | grep -oP "^\s*from\s+\\K\S+" || echo "")"
    # Python: import ...
    elif echo "$line" | grep -qE "^\s*import\s+\S+"; then
      imported_path="$(echo "$line" | grep -oP "^\s*import\s+\\K\S+" || echo "")"
    # Go: import "..."
    elif echo "$line" | grep -qE '^\s*"[^"]+"\s*$' || echo "$line" | grep -qE 'import\s+"'; then
      imported_path="$(echo "$line" | grep -oP '"\\K[^"]+' || echo "")"
    fi

    if [[ -z "$imported_path" ]]; then
      continue
    fi

    # Check if the import path matches any known module
    for mod_path in "${!MODULE_TYPES[@]}"; do
      # Skip self
      if [[ "$mod_path" == "$REL_MODULE" ]] || [[ "$mod_path" == "." ]]; then
        continue
      fi

      # Check if the import references this module
      if [[ "$imported_path" == *"$mod_path"* ]] || [[ "$imported_path" == *"$(basename "$mod_path")"* && "$mod_path" != "." ]]; then
        target_type="${MODULE_TYPES[$mod_path]}"

        if ! check_dependency "$MODULE_TYPE" "$target_type"; then
          severity="$(get_severity "$MODULE_TYPE" "$target_type")"
          rule="${MODULE_TYPE} cannot depend on ${target_type}"
          rel_file="${source_file#"$ROOT_PATH"/}"
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$severity" "$rel_file" "$line_num" "$mod_path" "$target_type" "$rule"
          VIOLATIONS=$((VIOLATIONS + 1))
          if [[ "$severity" == "error" ]]; then
            ERROR_VIOLATIONS=$((ERROR_VIOLATIONS + 1))
          fi
        fi
      fi
    done
  done < "$source_file"
done < <(find "$MODULE_PATH" -type f \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/vendor/*" \
  -not -path "*/__pycache__/*" \
  2> /dev/null)

if [[ $ERROR_VIOLATIONS -gt 0 ]]; then
  exit 2
fi

exit 0
