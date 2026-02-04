#!/usr/bin/env bash
# parse-frontmatter.sh — Extract a named field from YAML frontmatter.
#
# Usage: parse-frontmatter.sh --file <path> --field <name>
#
# Reads the YAML frontmatter block (between --- delimiters) from the
# specified file and outputs the value of the named field. Outputs an
# empty string if the file has no frontmatter or the field is not found.

set -euo pipefail

FILE=""
FIELD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      FILE="$2"
      shift 2
      ;;
    --field)
      FIELD="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$FILE" || -z "$FIELD" ]]; then
  echo "Error: --file and --field are required" >&2
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo ""
  exit 0
fi

# Check that file starts with frontmatter delimiter
FIRST_LINE="$(head -n 1 "$FILE")"
if [[ "$FIRST_LINE" != "---" ]]; then
  echo ""
  exit 0
fi

# Extract frontmatter block (between first and second ---)
IN_FRONTMATTER=false
while IFS= read -r line; do
  if [[ "$line" == "---" ]]; then
    if $IN_FRONTMATTER; then
      break
    else
      IN_FRONTMATTER=true
      continue
    fi
  fi

  if $IN_FRONTMATTER; then
    # Match field: value pattern (handles quoted and unquoted values)
    if [[ "$line" =~ ^${FIELD}:[[:space:]]*(.*) ]]; then
      VALUE="${BASH_REMATCH[1]}"
      # Strip surrounding quotes if present
      VALUE="${VALUE#\"}"
      VALUE="${VALUE%\"}"
      VALUE="${VALUE#\'}"
      VALUE="${VALUE%\'}"
      echo "$VALUE"
      exit 0
    fi
  fi
done < "$FILE"

# Field not found
echo ""
exit 0
