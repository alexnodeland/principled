#!/usr/bin/env bash
# check-readiness.sh — Check that referenced pipeline documents are in terminal status.
#
# Usage: check-readiness.sh --since <tag> [--strict] [--docs-dir <path>]
#
# Collects pipeline references from commits since the given tag, reads the
# frontmatter status of each referenced document, and reports pass/fail.
#
# Terminal statuses:
#   Proposals: accepted, rejected, superseded
#   Plans: complete, abandoned
#   ADRs: accepted, deprecated, superseded
#
# Non-terminal (blocking in --strict mode):
#   Proposals: draft, in-review
#   Plans: active
#   ADRs: proposed
#
# Output format (one per line):
#   <status>\t<doc-type>\t<number>\t<title>\t<doc-status>
#
# Where <status> is PASS, WARN, or FAIL.
#
# Exit codes:
#   0 — all checks pass (or warnings only without --strict)
#   1 — error (missing arguments, invalid tag)
#   2 — readiness check failed (--strict mode with non-terminal documents)

set -euo pipefail

SINCE_TAG=""
STRICT=false
DOCS_DIR="docs"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --since)
    if [[ $# -lt 2 ]]; then
      echo "Error: --since requires a value" >&2
      exit 1
    fi
    SINCE_TAG="$2"
    shift 2
    ;;
  --strict)
    STRICT=true
    shift
    ;;
  --docs-dir)
    if [[ $# -lt 2 ]]; then
      echo "Error: --docs-dir requires a value" >&2
      exit 1
    fi
    DOCS_DIR="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$SINCE_TAG" ]]; then
  echo "Error: --since <tag> is required" >&2
  exit 1
fi

# Verify the tag exists
if ! git rev-parse "$SINCE_TAG" > /dev/null 2>&1; then
  echo "Error: tag '$SINCE_TAG' not found" >&2
  exit 1
fi

# Collect all pipeline references from commits since the tag
REFS=""
while IFS= read -r msg; do
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ -n "$REFS" ]]; then
      REFS="${REFS}"$'\n'"${ref}"
    else
      REFS="$ref"
    fi
  done < <(echo "$msg" | grep -oEi '(RFC|Plan|ADR)-[0-9]+' || true)
done < <(git log "${SINCE_TAG}..HEAD" --format="%B" 2> /dev/null)

if [[ -z "$REFS" ]]; then
  echo "No pipeline references found in commits since $SINCE_TAG."
  exit 0
fi

# Deduplicate
REFS="$(echo "$REFS" | tr '[:lower:]' '[:upper:]' | sort -u)"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Parse frontmatter field from a file
parse_field() {
  local file="$1"
  local field="$2"
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
        local value="${BASH_REMATCH[1]}"
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        echo "$value"
        return
      fi
    fi
  done < "$file"

  echo ""
}

# Check each reference
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue

  DOC_TYPE=""
  DOC_DIR=""
  DOC_NUM=""

  if [[ "$ref" =~ ^RFC-([0-9]+)$ ]]; then
    DOC_TYPE="proposal"
    DOC_DIR="${DOCS_DIR}/proposals"
    DOC_NUM="${BASH_REMATCH[1]}"
  elif [[ "$ref" =~ ^PLAN-([0-9]+)$ ]]; then
    DOC_TYPE="plan"
    DOC_DIR="${DOCS_DIR}/plans"
    DOC_NUM="${BASH_REMATCH[1]}"
  elif [[ "$ref" =~ ^ADR-([0-9]+)$ ]]; then
    DOC_TYPE="decision"
    DOC_DIR="${DOCS_DIR}/decisions"
    DOC_NUM="${BASH_REMATCH[1]}"
  else
    continue
  fi

  # Zero-pad to 3 digits for file lookup
  PADDED_NUM="$(printf '%03d' "$DOC_NUM")"

  # Find the document file
  DOC_FILE=""
  for f in "${DOC_DIR}/${PADDED_NUM}-"*.md; do
    if [[ -f "$f" ]]; then
      DOC_FILE="$f"
      break
    fi
  done

  if [[ -z "$DOC_FILE" ]]; then
    printf 'WARN\t%s\t%s\t(document not found)\t-\n' "$DOC_TYPE" "$ref"
    WARN_COUNT=$((WARN_COUNT + 1))
    continue
  fi

  TITLE="$(parse_field "$DOC_FILE" "title")"
  STATUS="$(parse_field "$DOC_FILE" "status")"

  # Check if status is terminal
  IS_TERMINAL=false
  case "$DOC_TYPE" in
  proposal)
    case "$STATUS" in
    accepted | rejected | superseded) IS_TERMINAL=true ;;
    esac
    ;;
  plan)
    case "$STATUS" in
    complete | abandoned) IS_TERMINAL=true ;;
    esac
    ;;
  decision)
    case "$STATUS" in
    accepted | deprecated | superseded) IS_TERMINAL=true ;;
    esac
    ;;
  esac

  if $IS_TERMINAL; then
    printf 'PASS\t%s\t%s\t%s\t%s\n' "$DOC_TYPE" "$ref" "$TITLE" "$STATUS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    if $STRICT; then
      printf 'FAIL\t%s\t%s\t%s\t%s\n' "$DOC_TYPE" "$ref" "$TITLE" "$STATUS"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    else
      printf 'WARN\t%s\t%s\t%s\t%s\n' "$DOC_TYPE" "$ref" "$TITLE" "$STATUS"
      WARN_COUNT=$((WARN_COUNT + 1))
    fi
  fi
done <<< "$REFS"

echo ""
echo "Summary: ${PASS_COUNT} passed, ${WARN_COUNT} warnings, ${FAIL_COUNT} failed"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 2
fi

exit 0
