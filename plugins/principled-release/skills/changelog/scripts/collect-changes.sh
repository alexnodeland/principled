#!/usr/bin/env bash
# collect-changes.sh — Collect changes since a git tag and map to pipeline documents.
#
# Usage: collect-changes.sh --since <tag> [--module <path>]
#
# Traverses git log since the given tag, resolves PR references,
# and extracts pipeline document references (RFC-NNN, Plan-NNN, ADR-NNN).
#
# Output format (one per line, tab-separated):
#   <commit-hash>\t<category>\t<references>\t<subject>
#
# Categories: feature, improvement, decision, fix, uncategorized
#
# Exit codes:
#   0 — success
#   1 — error (missing arguments, invalid tag)

set -euo pipefail

SINCE_TAG=""
MODULE_PATH=""

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
  --module)
    if [[ $# -lt 2 ]]; then
      echo "Error: --module requires a value" >&2
      exit 1
    fi
    MODULE_PATH="$2"
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

# Build git log command
GIT_LOG_ARGS=(log "${SINCE_TAG}..HEAD" --format="%H%x09%s" --no-merges)

if [[ -n "$MODULE_PATH" ]]; then
  GIT_LOG_ARGS+=(-- "$MODULE_PATH")
fi

# Collect commits
COMMITS="$(git "${GIT_LOG_ARGS[@]}" 2> /dev/null)" || {
  echo "Error: failed to read git log" >&2
  exit 1
}

if [[ -z "$COMMITS" ]]; then
  exit 0
fi

# Extract pipeline references from a string
extract_refs() {
  local text="$1"
  local refs=""

  # Match RFC-NNN, Plan-NNN, ADR-NNN patterns (case-insensitive)
  while IFS= read -r match; do
    if [[ -n "$match" ]]; then
      if [[ -n "$refs" ]]; then
        refs="${refs},${match}"
      else
        refs="$match"
      fi
    fi
  done < <(echo "$text" | grep -oEi '(RFC|Plan|ADR)-[0-9]+' | sort -u)

  echo "$refs"
}

# Categorize based on references
categorize() {
  local refs="$1"

  if [[ -z "$refs" ]]; then
    echo "uncategorized"
    return
  fi

  # Check for RFC references → feature
  if echo "$refs" | grep -qiE 'RFC-[0-9]+'; then
    echo "feature"
    return
  fi

  # Check for ADR references → decision
  if echo "$refs" | grep -qiE 'ADR-[0-9]+'; then
    echo "decision"
    return
  fi

  # Check for Plan references → improvement
  if echo "$refs" | grep -qiE 'Plan-[0-9]+'; then
    echo "improvement"
    return
  fi

  echo "uncategorized"
}

# Process each commit
while IFS=$'\t' read -r hash subject; do
  [[ -z "$hash" ]] && continue

  # Collect references from commit message (full message, not just subject)
  FULL_MSG="$(git log -1 --format="%B" "$hash" 2> /dev/null || echo "$subject")"
  REFS="$(extract_refs "$FULL_MSG")"

  # Also check branch name if available from merge commits
  BRANCH_REFS=""
  MERGE_BRANCH="$(git log -1 --format="%D" "$hash" 2> /dev/null || echo "")"
  if [[ -n "$MERGE_BRANCH" ]]; then
    BRANCH_REFS="$(extract_refs "$MERGE_BRANCH")"
    if [[ -n "$BRANCH_REFS" ]]; then
      if [[ -n "$REFS" ]]; then
        REFS="${REFS},${BRANCH_REFS}"
      else
        REFS="$BRANCH_REFS"
      fi
    fi
  fi

  # Deduplicate references
  if [[ -n "$REFS" ]]; then
    REFS="$(echo "$REFS" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')"
  fi

  CATEGORY="$(categorize "$REFS")"

  printf '%s\t%s\t%s\t%s\n' "$hash" "$CATEGORY" "$REFS" "$subject"
done <<< "$COMMITS"

exit 0
