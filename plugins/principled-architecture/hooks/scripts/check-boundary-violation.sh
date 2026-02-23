#!/usr/bin/env bash
# check-boundary-violation.sh — PostToolUse hook: advisory for module boundary violations.
#
# Receives JSON via stdin containing tool_input and tool_result.
# When a file is written in a module directory, performs a lightweight check
# for imports that violate dependency direction rules. This is advisory only
# — it never blocks.
#
# Exit codes:
#   0 — always (advisory only)

set -euo pipefail

# Read JSON from stdin
INPUT="$(cat)"

# Extract file_path from the JSON input
FILE_PATH=""
if command -v jq &> /dev/null; then
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .file_path // empty' 2> /dev/null || echo "")"
else
  # Fallback: basic grep extraction
  FILE_PATH="$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"[^"]*"' | head -1 | grep -oP ':\s*"\K[^"]*' || echo "")"
fi

# If we couldn't extract a file path, allow
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check source files
case "$FILE_PATH" in
*.ts | *.tsx | *.js | *.jsx | *.py | *.go | *.rs | *.java) ;;
*)
  exit 0
  ;;
esac

# Find repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"

# Determine if the file is in a module directory (find nearest CLAUDE.md)
FILE_DIR="$(dirname "$FILE_PATH")"
if [[ "$FILE_DIR" != /* ]]; then
  FILE_DIR="$REPO_ROOT/$FILE_DIR"
fi

MODULE_DIR=""
MODULE_TYPE=""
CHECK_DIR="$FILE_DIR"

while [[ "$CHECK_DIR" != "/" && "$CHECK_DIR" != "$REPO_ROOT" ]]; do
  if [[ -f "$CHECK_DIR/CLAUDE.md" ]]; then
    MODULE_DIR="$CHECK_DIR"
    # Parse module type
    while IFS= read -r line; do
      if [[ "$line" =~ ^##[[:space:]]+Module[[:space:]]+Type ]]; then
        while IFS= read -r next_line; do
          next_line="$(echo "$next_line" | xargs)"
          if [[ -n "$next_line" ]]; then
            MODULE_TYPE="$next_line"
            break
          fi
        done
        break
      fi
    done < "$CHECK_DIR/CLAUDE.md"
    break
  fi
  CHECK_DIR="$(dirname "$CHECK_DIR")"
done

# Not in a module directory — nothing to check
if [[ -z "$MODULE_DIR" || -z "$MODULE_TYPE" ]]; then
  exit 0
fi

# Quick check: does the file contain imports from modules it shouldn't?
# This is a lightweight heuristic — full analysis is done by /arch-drift

# Build list of forbidden module types
FORBIDDEN_TYPES=""
case "$MODULE_TYPE" in
core)
  FORBIDDEN_TYPES="app lib"
  ;;
lib)
  FORBIDDEN_TYPES="app"
  ;;
*)
  # app modules — no quick check needed for common violations
  exit 0
  ;;
esac

# Read the written file and check for suspicious imports
if [[ ! -f "$FILE_PATH" ]]; then
  # File might use absolute path
  if [[ -f "$REPO_ROOT/$FILE_PATH" ]]; then
    FILE_PATH="$REPO_ROOT/$FILE_PATH"
  else
    exit 0
  fi
fi

# Find all other modules and their types
VIOLATIONS=""
while IFS= read -r claude_file; do
  other_dir="$(dirname "$claude_file")"
  if [[ "$other_dir" == "$MODULE_DIR" ]]; then
    continue
  fi

  other_type="unknown"
  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+Module[[:space:]]+Type ]]; then
      while IFS= read -r next_line; do
        next_line="$(echo "$next_line" | xargs)"
        if [[ -n "$next_line" ]]; then
          other_type="$next_line"
          break
        fi
      done
      break
    fi
  done < "$claude_file"

  # Check if this module type is forbidden
  for ft in $FORBIDDEN_TYPES; do
    if [[ "$other_type" == "$ft" ]]; then
      other_name="$(basename "$other_dir")"
      # Check if the file references this module
      if grep -q "$other_name" "$FILE_PATH" 2> /dev/null; then
        VIOLATIONS="${VIOLATIONS}  - References ${other_name} (${other_type})\n"
      fi
    fi
  done
done < <(find "$REPO_ROOT" -name "CLAUDE.md" \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/vendor/*" \
  2> /dev/null)

if [[ -n "$VIOLATIONS" ]]; then
  REL_PATH="${FILE_PATH#"$REPO_ROOT"/}"
  echo "Advisory: Possible module boundary violation in ${REL_PATH} (${MODULE_TYPE} module):"
  echo -e "$VIOLATIONS"
  echo "Run /arch-drift for a detailed analysis."
fi

# Always allow
exit 0
