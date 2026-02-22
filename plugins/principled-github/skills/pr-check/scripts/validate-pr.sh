#!/usr/bin/env bash
# validate-pr.sh — Run PR validation checks against principled conventions.
#
# Usage: validate-pr.sh --pr-body <body> --pr-labels <labels> --branch <branch> [--strict] [--json]
#
# Checks:
#   Required (errors):
#     - PR body is not empty
#     - PR body contains a Summary section
#     - PR body contains a Test plan or Checklist section
#   Recommended (warnings, errors in --strict):
#     - PR body references at least one GitHub issue (#N)
#     - PR references a plan or proposal
#     - PR has at least one principled label
#     - Branch follows recognized convention
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed

set -euo pipefail

PR_BODY=""
PR_LABELS=""
BRANCH=""
STRICT=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
  --pr-body)
    PR_BODY="$2"
    shift 2
    ;;
  --pr-labels)
    PR_LABELS="$2"
    shift 2
    ;;
  --branch)
    BRANCH="$2"
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
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

ERRORS=0
WARNINGS=0
RESULTS=()

check() {
  local level="$1"
  local name="$2"
  local passed="$3"
  local message="$4"

  if [[ "$passed" == "true" ]]; then
    RESULTS+=("pass|${name}|${message}")
  elif [[ "$level" == "error" ]]; then
    RESULTS+=("fail|${name}|${message}")
    ERRORS=$((ERRORS + 1))
  elif [[ "$level" == "warn" ]]; then
    if $STRICT; then
      RESULTS+=("fail|${name}|${message}")
      ERRORS=$((ERRORS + 1))
    else
      RESULTS+=("warn|${name}|${message}")
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
}

# Decode body if base64 encoded
DECODED_BODY=""
if [[ -n "$PR_BODY" ]]; then
  DECODED_BODY="$(echo "$PR_BODY" | base64 -d 2> /dev/null || echo "$PR_BODY")"
fi

# Required: PR body is not empty
if [[ -z "$DECODED_BODY" || "$DECODED_BODY" == "null" ]]; then
  check "error" "body-not-empty" "false" "PR body is empty"
else
  check "error" "body-not-empty" "true" "PR body is present"
fi

# Required: Summary section
if echo "$DECODED_BODY" | grep -qiE '^#{1,3}\s*(summary|overview)'; then
  check "error" "has-summary" "true" "PR has a Summary section"
else
  check "error" "has-summary" "false" "PR is missing a Summary section"
fi

# Required: Test plan or checklist
if echo "$DECODED_BODY" | grep -qiE '^#{1,3}\s*(test plan|checklist|testing|verification)'; then
  check "error" "has-test-plan" "true" "PR has a Test plan section"
else
  check "error" "has-test-plan" "false" "PR is missing a Test plan or Checklist section"
fi

# Recommended: references at least one GitHub issue (#N) for provenance
if echo "$DECODED_BODY" | grep -qE '(Closes|Fixes|Resolves|Relates to|Part of)\s+#[0-9]+'; then
  check "warn" "references-issue" "true" "PR references a GitHub issue"
else
  check "warn" "references-issue" "false" "PR does not reference a GitHub issue (use Closes #N, Fixes #N, or Relates to #N)"
fi

# Recommended: references a plan or proposal
if echo "$DECODED_BODY" | grep -qiE '(Plan-[0-9]{3}|RFC-[0-9]{3}|proposal[[:space:]]+[0-9]{3}|plan[[:space:]]+[0-9]{3})'; then
  check "warn" "references-doc" "true" "PR references a principled document"
else
  check "warn" "references-doc" "false" "PR does not reference a plan or proposal (Plan-NNN or RFC-NNN)"
fi

# Recommended: has principled labels
HAS_PRINCIPLED_LABEL=false
if [[ -n "$PR_LABELS" ]]; then
  for prefix in "type:" "plan:" "proposal:"; do
    if [[ "$PR_LABELS" == *"${prefix}"* ]]; then
      HAS_PRINCIPLED_LABEL=true
      break
    fi
  done
fi
check "warn" "has-labels" "$HAS_PRINCIPLED_LABEL" \
  "$(if $HAS_PRINCIPLED_LABEL; then echo "PR has principled labels"; else echo "PR has no principled labels"; fi)"

# Recommended: branch naming
VALID_BRANCH=false
if [[ "$BRANCH" =~ ^(impl|feat|fix|chore|docs|refactor|test|ci)/ ]]; then
  VALID_BRANCH=true
fi
check "warn" "branch-convention" "$VALID_BRANCH" \
  "$(if $VALID_BRANCH; then echo "Branch follows naming convention"; else echo "Branch does not follow a recognized naming convention (impl/, feat/, fix/, etc.)"; fi)"

# Output results
if $JSON_OUTPUT; then
  echo "["
  first=true
  for result in "${RESULTS[@]}"; do
    IFS='|' read -r status name message <<< "$result"
    if $first; then
      first=false
    else
      echo ","
    fi
    printf '  {"status": "%s", "check": "%s", "message": "%s"}' \
      "$status" "$name" "$message"
  done
  echo ""
  echo "]"
else
  for result in "${RESULTS[@]}"; do
    IFS='|' read -r status name message <<< "$result"
    case "$status" in
    pass) echo "  PASS  ${name}: ${message}" ;;
    warn) echo "  WARN  ${name}: ${message}" ;;
    fail) echo "  FAIL  ${name}: ${message}" ;;
    esac
  done
  echo ""
  if [[ $ERRORS -gt 0 ]]; then
    echo "RESULT: FAIL (${ERRORS} error(s), ${WARNINGS} warning(s))"
  elif [[ $WARNINGS -gt 0 ]]; then
    echo "RESULT: PASS with warnings (${WARNINGS} warning(s))"
  else
    echo "RESULT: PASS"
  fi
fi

if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
exit 0
