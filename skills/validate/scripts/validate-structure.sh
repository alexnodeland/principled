#!/usr/bin/env bash
# validate-structure.sh — Validate module documentation structure.
#
# Usage:
#   validate-structure.sh --module-path <path> --type core|lib|app [--strict] [--json]
#   validate-structure.sh --root [--strict] [--json]
#   validate-structure.sh --on-write <file-path>
#
# Checks that the expected documentation structure exists for a given
# module type. Reports missing directories, missing files, and
# placeholder-only content.

set -euo pipefail

MODULE_PATH=""
MODULE_TYPE=""
STRICT=false
JSON_OUTPUT=false
ROOT_MODE=false
ON_WRITE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --module-path)
      MODULE_PATH="$2"
      shift 2
      ;;
    --type)
      MODULE_TYPE="$2"
      shift 2
      ;;
    --strict)
      STRICT=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --root)
      ROOT_MODE=true
      shift
      ;;
    --on-write)
      ON_WRITE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Counters
PRESENT=0
MISSING=0
PLACEHOLDER=0
TOTAL=0
STATUS="pass"
RESULTS=()

check_dir() {
  local dir="$1"
  local label="$2"
  TOTAL=$((TOTAL + 1))

  if [[ -d "$dir" ]]; then
    local count
    count=$(find "$dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l)
    PRESENT=$((PRESENT + 1))
    RESULTS+=("present|${label}|exists (${count} files)")
  else
    MISSING=$((MISSING + 1))
    STATUS="fail"
    RESULTS+=("missing|${label}|MISSING")
  fi
}

check_file() {
  local file="$1"
  local label="$2"
  TOTAL=$((TOTAL + 1))

  if [[ -f "$file" ]]; then
    # Check if file is placeholder-only (contains only TODO markers and template structure)
    local content_lines
    content_lines=$(grep -cvE '^\s*$|^\s*#|^\s*TODO|^\s*<!--|^\s*-->|^\s*\|.*TODO|^---' "$file" 2>/dev/null || echo "0")
    if [[ "$content_lines" -eq 0 ]]; then
      PLACEHOLDER=$((PLACEHOLDER + 1))
      if $STRICT; then
        STATUS="fail"
      fi
      RESULTS+=("placeholder|${label}|placeholder only")
    else
      PRESENT=$((PRESENT + 1))
      RESULTS+=("present|${label}|exists")
    fi
  else
    MISSING=$((MISSING + 1))
    STATUS="fail"
    RESULTS+=("missing|${label}|MISSING")
  fi
}

# --- On-write mode: lightweight advisory check ---
if [[ -n "$ON_WRITE" ]]; then
  # Determine which module the file belongs to
  FILE_PATH="$ON_WRITE"

  # Try to find the module root by looking for a docs/ directory ancestor
  CURRENT="$(dirname "$FILE_PATH")"
  MODULE_ROOT=""
  while [[ "$CURRENT" != "/" && "$CURRENT" != "." ]]; do
    if [[ -d "$CURRENT/docs" && ( -f "$CURRENT/README.md" || -f "$CURRENT/CLAUDE.md" ) ]]; then
      MODULE_ROOT="$CURRENT"
      break
    fi
    CURRENT="$(dirname "$CURRENT")"
  done

  if [[ -z "$MODULE_ROOT" ]]; then
    # File is not inside a known module
    exit 0
  fi

  # Quick check for basic structure
  WARNINGS=()
  [[ ! -d "$MODULE_ROOT/docs/proposals" ]] && WARNINGS+=("docs/proposals/ directory missing")
  [[ ! -d "$MODULE_ROOT/docs/plans" ]] && WARNINGS+=("docs/plans/ directory missing")
  [[ ! -d "$MODULE_ROOT/docs/decisions" ]] && WARNINGS+=("docs/decisions/ directory missing")
  [[ ! -d "$MODULE_ROOT/docs/architecture" ]] && WARNINGS+=("docs/architecture/ directory missing")
  [[ ! -f "$MODULE_ROOT/README.md" ]] && WARNINGS+=("README.md missing")
  [[ ! -f "$MODULE_ROOT/CLAUDE.md" ]] && WARNINGS+=("CLAUDE.md missing")

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "Advisory: Module at $MODULE_ROOT has incomplete documentation structure:"
    for w in "${WARNINGS[@]}"; do
      echo "  - $w"
    done
  fi
  exit 0
fi

# --- Root mode ---
if $ROOT_MODE; then
  if [[ -z "$MODULE_PATH" ]]; then
    MODULE_PATH="."
  fi

  LABEL="Root docs"

  check_dir "$MODULE_PATH/docs/proposals" "docs/proposals/"
  check_dir "$MODULE_PATH/docs/plans" "docs/plans/"
  check_dir "$MODULE_PATH/docs/decisions" "docs/decisions/"
  check_dir "$MODULE_PATH/docs/architecture" "docs/architecture/"

  if $JSON_OUTPUT; then
    echo "{"
    echo "  \"scope\": \"root\","
    echo "  \"path\": \"$MODULE_PATH\","
    echo "  \"status\": \"$STATUS\","
    echo "  \"present\": $PRESENT,"
    echo "  \"missing\": $MISSING,"
    echo "  \"placeholder\": $PLACEHOLDER,"
    echo "  \"components\": ["
    for i in "${!RESULTS[@]}"; do
      IFS='|' read -r state label detail <<< "${RESULTS[$i]}"
      COMMA=""
      [[ $i -lt $((${#RESULTS[@]} - 1)) ]] && COMMA=","
      echo "    {\"state\": \"$state\", \"label\": \"$label\", \"detail\": \"$detail\"}${COMMA}"
    done
    echo "  ]"
    echo "}"
  else
    echo "$LABEL"
    printf '%.0s─' {1..40}
    echo ""
    for result in "${RESULTS[@]}"; do
      IFS='|' read -r state label detail <<< "$result"
      case "$state" in
        present)    echo "✓ $label  $detail" ;;
        missing)    echo "✗ $label  $detail" ;;
        placeholder) echo "~ $label  $detail" ;;
      esac
    done
    printf '%.0s─' {1..40}
    echo ""
    echo "Result: $(echo "$STATUS" | tr '[:lower:]' '[:upper:]') ($MISSING missing, $PLACEHOLDER placeholder)"
  fi

  [[ "$STATUS" == "pass" ]] && exit 0 || exit 1
fi

# --- Module mode ---
if [[ -z "$MODULE_PATH" ]]; then
  echo "Error: --module-path is required (or use --root)" >&2
  exit 1
fi

if [[ -z "$MODULE_TYPE" ]]; then
  # Try to detect from CLAUDE.md
  if [[ -f "$MODULE_PATH/CLAUDE.md" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    if [[ -f "$PLUGIN_ROOT/../hooks/scripts/parse-frontmatter.sh" ]]; then
      # Can't use frontmatter for CLAUDE.md module type; parse manually
      true
    fi
    # Look for "## Module Type" section
    MODULE_TYPE=$(awk '/^## Module Type/{getline; gsub(/^[[:space:]]+|[[:space:]]+$/,""); if ($0 != "") print; exit}' "$MODULE_PATH/CLAUDE.md" 2>/dev/null || echo "")
  fi
  if [[ -z "$MODULE_TYPE" ]]; then
    echo "Error: --type is required (could not detect module type)" >&2
    exit 1
  fi
fi

MODULE_NAME="$(basename "$MODULE_PATH")"

# Core directories (all module types)
check_dir "$MODULE_PATH/docs/proposals" "docs/proposals/"
check_dir "$MODULE_PATH/docs/plans" "docs/plans/"
check_dir "$MODULE_PATH/docs/decisions" "docs/decisions/"
check_dir "$MODULE_PATH/docs/architecture" "docs/architecture/"

# Core files
check_file "$MODULE_PATH/README.md" "README.md"
check_file "$MODULE_PATH/CONTRIBUTING.md" "CONTRIBUTING.md"
check_file "$MODULE_PATH/CLAUDE.md" "CLAUDE.md"

# Lib extensions
if [[ "$MODULE_TYPE" == "lib" ]]; then
  check_dir "$MODULE_PATH/docs/examples" "docs/examples/"
  check_file "$MODULE_PATH/INTERFACE.md" "INTERFACE.md"
fi

# App extensions
if [[ "$MODULE_TYPE" == "app" ]]; then
  check_dir "$MODULE_PATH/docs/runbooks" "docs/runbooks/"
  check_dir "$MODULE_PATH/docs/integration" "docs/integration/"
  check_dir "$MODULE_PATH/docs/config" "docs/config/"
fi

# Output
if $JSON_OUTPUT; then
  echo "{"
  echo "  \"module\": \"$MODULE_NAME\","
  echo "  \"path\": \"$MODULE_PATH\","
  echo "  \"type\": \"$MODULE_TYPE\","
  echo "  \"status\": \"$STATUS\","
  echo "  \"present\": $PRESENT,"
  echo "  \"missing\": $MISSING,"
  echo "  \"placeholder\": $PLACEHOLDER,"
  echo "  \"components\": ["
  for i in "${!RESULTS[@]}"; do
    IFS='|' read -r state label detail <<< "${RESULTS[$i]}"
    COMMA=""
    [[ $i -lt $((${#RESULTS[@]} - 1)) ]] && COMMA=","
    echo "    {\"state\": \"$state\", \"label\": \"$label\", \"detail\": \"$detail\"}${COMMA}"
  done
  echo "  ]"
  echo "}"
else
  echo "Module: $MODULE_PATH ($MODULE_TYPE)"
  printf '%.0s─' {1..40}
  echo ""
  for result in "${RESULTS[@]}"; do
    IFS='|' read -r state label detail <<< "$result"
    case "$state" in
      present)    echo "✓ $label  $detail" ;;
      missing)    echo "✗ $label  $detail" ;;
      placeholder) echo "~ $label  $detail" ;;
    esac
  done
  printf '%.0s─' {1..40}
  echo ""
  echo "Result: $(echo "$STATUS" | tr '[:lower:]' '[:upper:]') ($MISSING missing, $PLACEHOLDER placeholder)"
fi

[[ "$STATUS" == "pass" ]] && exit 0 || exit 1
