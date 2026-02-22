#!/usr/bin/env bash
# extract-doc-metadata.sh — Extract metadata from a principled document.
#
# Usage: extract-doc-metadata.sh --file <path>
#
# Reads YAML frontmatter from a principled proposal or plan document
# and outputs key-value pairs for downstream consumption.
#
# Output format (one per line):
#   title=<value>
#   number=<value>
#   status=<value>
#   author=<value>
#   type=<proposal|plan>
#   excerpt=<first paragraph of body>

set -euo pipefail

FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --file)
    FILE="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$FILE" ]]; then
  echo "Error: --file is required" >&2
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "Error: file not found: $FILE" >&2
  exit 1
fi

# Determine document type from path
DOC_TYPE="unknown"
if [[ "$FILE" == *"/proposals/"* ]]; then
  DOC_TYPE="proposal"
elif [[ "$FILE" == *"/plans/"* ]]; then
  DOC_TYPE="plan"
fi

# Parse frontmatter fields
parse_field() {
  local field="$1"
  local value=""
  local in_frontmatter=false

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if $in_frontmatter; then
        break
      else
        in_frontmatter=true
        continue
      fi
    fi

    if $in_frontmatter; then
      if [[ "$line" =~ ^${field}:[[:space:]]*(.*) ]]; then
        value="${BASH_REMATCH[1]}"
        # Strip surrounding quotes
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        break
      fi
    fi
  done < "$FILE"

  echo "$value"
}

TITLE="$(parse_field "title")"
NUMBER="$(parse_field "number")"
STATUS="$(parse_field "status")"
AUTHOR="$(parse_field "author")"

# Extract first non-empty paragraph after frontmatter as excerpt
EXCERPT=""
PAST_FRONTMATTER=false
FOUND_HEADING=false
while IFS= read -r line; do
  if [[ "$line" == "---" ]]; then
    if $PAST_FRONTMATTER; then
      PAST_FRONTMATTER=true
      continue
    fi
    PAST_FRONTMATTER=true
    continue
  fi

  if $PAST_FRONTMATTER; then
    # Skip headings
    if [[ "$line" =~ ^#+ ]]; then
      FOUND_HEADING=true
      continue
    fi
    # After first heading, take first non-empty line as excerpt
    if $FOUND_HEADING && [[ -n "$line" ]]; then
      EXCERPT="$line"
      break
    fi
  fi
done < "$FILE"

# Truncate excerpt to 200 chars
if [[ ${#EXCERPT} -gt 200 ]]; then
  EXCERPT="${EXCERPT:0:197}..."
fi

echo "title=$TITLE"
echo "number=$NUMBER"
echo "status=$STATUS"
echo "author=$AUTHOR"
echo "type=$DOC_TYPE"
echo "excerpt=$EXCERPT"
