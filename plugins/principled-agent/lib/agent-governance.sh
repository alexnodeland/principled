#!/usr/bin/env bash
# agent-governance.sh — Mechanical enforcement of the agent governance constraints
# (ADR-022).
#
# The constraints exist for the case where no human is watching, so "the agent should
# check" is unfalsifiable exactly when it matters. Each check here is something a script
# can answer, not something an agent is asked to remember.
#
# Usage:
#   agent-governance.sh --check-halt
#   agent-governance.sh --halt "<reason>"
#   agent-governance.sh --resume
#   agent-governance.sh --count-blocked
#   agent-governance.sh --count-in-flight
#   agent-governance.sh --can-dispatch [--blocked-budget N] [--pr-budget N]
#   agent-governance.sh --status [--format table|json]
#
# Exit codes:
#   0 — permitted (or the queried condition is clear)
#   1 — usage or environment error
#   3 — refused by a governance constraint; the reason is printed to stdout
#
# Exit 3 is deliberately distinct from 1: a refusal is a successful, expected answer,
# and a caller must be able to tell "you may not" from "I could not tell".
#
# GitHub-dependent counts degrade rather than fail. When `gh` is missing or
# unauthenticated the count is reported as unknown, and --can-dispatch says so instead
# of silently treating unknown as zero — an unknown budget must never read as headroom.
#
# Constraints: bash 3.2 (stock macOS), jq optional, no GNU-only tooling.

set -euo pipefail

DEFAULT_BLOCKED_BUDGET=5
DEFAULT_PR_BUDGET=5

OPERATION=""
REASON=""
ROOT_PATH=""
FORMAT="table"
BLOCKED_BUDGET="$DEFAULT_BLOCKED_BUDGET"
PR_BUDGET="$DEFAULT_PR_BUDGET"

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --check-halt)
    OPERATION="check-halt"
    shift
    ;;
  --halt)
    OPERATION="halt"
    if [[ $# -ge 2 && "$2" != --* ]]; then
      REASON="$2"
      shift 2
    else
      shift
    fi
    ;;
  --resume)
    OPERATION="resume"
    shift
    ;;
  --count-blocked)
    OPERATION="count-blocked"
    shift
    ;;
  --count-in-flight)
    OPERATION="count-in-flight"
    shift
    ;;
  --can-dispatch)
    OPERATION="can-dispatch"
    shift
    ;;
  --status)
    OPERATION="status"
    shift
    ;;
  --blocked-budget)
    [[ $# -ge 2 ]] || {
      echo "Error: --blocked-budget requires a value" >&2
      exit 1
    }
    BLOCKED_BUDGET="$2"
    shift 2
    ;;
  --pr-budget)
    [[ $# -ge 2 ]] || {
      echo "Error: --pr-budget requires a value" >&2
      exit 1
    }
    PR_BUDGET="$2"
    shift 2
    ;;
  --format)
    [[ $# -ge 2 ]] || {
      echo "Error: --format requires a value" >&2
      exit 1
    }
    FORMAT="$2"
    shift 2
    ;;
  --root)
    [[ $# -ge 2 ]] || {
      echo "Error: --root requires a value" >&2
      exit 1
    }
    ROOT_PATH="$2"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Error: unknown argument '$1'" >&2
    usage >&2
    exit 1
    ;;
  esac
done

if [[ -z "$OPERATION" ]]; then
  echo "Error: no operation specified" >&2
  usage >&2
  exit 1
fi

for budget in "$BLOCKED_BUDGET" "$PR_BUDGET"; do
  if [[ ! "$budget" =~ ^[0-9]+$ ]]; then
    echo "Error: budgets must be non-negative integers (got '${budget}')" >&2
    exit 1
  fi
done

if [[ -z "$ROOT_PATH" ]]; then
  ROOT_PATH="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
fi

AGENTS_DIR="${ROOT_PATH}/.agents"
HALT_FILE="${AGENTS_DIR}/HALT"

# --- GitHub availability ---------------------------------------------------
# Never fail on a missing gh: these scripts run inside orchestration loops where an
# unavailable CLI must produce a clear answer, not a stack trace.
gh_available() {
  command -v gh &> /dev/null && gh auth status &> /dev/null
}

# Count open issues carrying a label. Prints an integer, or "unknown".
count_open_issues_with_label() {
  local label="$1"
  if ! gh_available; then
    echo "unknown"
    return 0
  fi
  local out
  out="$(gh issue list --state open --label "$label" --limit 200 --json number 2> /dev/null || echo "")"
  if [[ -z "$out" ]]; then
    echo "unknown"
    return 0
  fi
  if command -v jq &> /dev/null; then
    echo "$out" | jq 'length'
  else
    # Each entry contributes exactly one "number" key.
    printf '%s' "$out" | tr ',' '\n' | grep -c '"number"' || echo 0
  fi
}

# Count open PRs that are agent-authored, by label.
count_in_flight_prs() {
  if ! gh_available; then
    echo "unknown"
    return 0
  fi
  local out
  out="$(gh pr list --state open --label agent-authored --limit 200 --json number 2> /dev/null || echo "")"
  if [[ -z "$out" ]]; then
    echo "unknown"
    return 0
  fi
  if command -v jq &> /dev/null; then
    echo "$out" | jq 'length'
  else
    printf '%s' "$out" | tr ',' '\n' | grep -c '"number"' || echo 0
  fi
}

halt_reason() {
  if [[ -s "$HALT_FILE" ]]; then
    head -20 "$HALT_FILE"
  else
    echo "(no reason recorded)"
  fi
}

# --- Operation: check-halt -------------------------------------------------
if [[ "$OPERATION" == "check-halt" ]]; then
  if [[ -f "$HALT_FILE" ]]; then
    echo "HALTED"
    echo "File: ${HALT_FILE}"
    echo "Reason: $(halt_reason)"
    echo ""
    echo "Clear it with: agent-governance.sh --resume"
    exit 3
  fi
  echo "OK: no halt in effect."
  exit 0
fi

# --- Operation: halt -------------------------------------------------------
if [[ "$OPERATION" == "halt" ]]; then
  mkdir -p "$AGENTS_DIR"
  if [[ -z "$REASON" ]]; then
    REASON="Halted manually; no reason given."
  fi
  printf '%s\n' "$REASON" > "$HALT_FILE"
  echo "Halt engaged. All dispatch will refuse; orchestration pauses at the next phase boundary."
  echo "File: ${HALT_FILE}"
  echo "Reason: ${REASON}"
  echo ""
  echo "Commit it so the halt is visible to everyone: git add .agents/HALT"
  exit 0
fi

# --- Operation: resume -----------------------------------------------------
if [[ "$OPERATION" == "resume" ]]; then
  if [[ ! -f "$HALT_FILE" ]]; then
    echo "No halt in effect; nothing to clear."
    exit 0
  fi
  echo "Clearing halt. Previous reason: $(halt_reason)"
  rm -f "$HALT_FILE"
  echo "Halt cleared. Commit the removal: git add -A .agents/"
  exit 0
fi

# --- Operation: count-blocked ----------------------------------------------
if [[ "$OPERATION" == "count-blocked" ]]; then
  count_open_issues_with_label "agent-blocked"
  exit 0
fi

# --- Operation: count-in-flight --------------------------------------------
if [[ "$OPERATION" == "count-in-flight" ]]; then
  count_in_flight_prs
  exit 0
fi

# --- Operation: can-dispatch -----------------------------------------------
# The single gate every dispatch passes through. Checks the halt switch first
# because it is the only one that works without network access.
if [[ "$OPERATION" == "can-dispatch" ]]; then
  if [[ -f "$HALT_FILE" ]]; then
    echo "REFUSED: halt switch engaged."
    echo "File: ${HALT_FILE}"
    echo "Reason: $(halt_reason)"
    echo ""
    echo "Clear it with: agent-governance.sh --resume"
    exit 3
  fi

  BLOCKED="$(count_open_issues_with_label "agent-blocked")"
  IN_FLIGHT="$(count_in_flight_prs)"

  if [[ "$BLOCKED" == "unknown" || "$IN_FLIGHT" == "unknown" ]]; then
    echo "REFUSED: cannot verify governance budgets."
    echo "The gh CLI is unavailable or unauthenticated, so open agent-blocked issues"
    echo "and in-flight agent PRs could not be counted."
    echo ""
    echo "An unverifiable budget is not headroom. Authenticate with 'gh auth login',"
    echo "or dispatch with --local, which needs no GitHub access."
    exit 3
  fi

  if [[ "$BLOCKED" -ge "$BLOCKED_BUDGET" ]]; then
    echo "REFUSED: ${BLOCKED} open agent-blocked issue(s), budget is ${BLOCKED_BUDGET}."
    echo ""
    echo "Blockers accumulating faster than they are triaged is a systemic signal, not"
    echo "queue depth. Triage the existing blockers before dispatching more work."
    exit 3
  fi

  if [[ "$IN_FLIGHT" -ge "$PR_BUDGET" ]]; then
    echo "REFUSED: ${IN_FLIGHT} in-flight agent PR(s), budget is ${PR_BUDGET}."
    echo ""
    echo "Review capacity is the binding constraint (ADR-022). Opening more PRs than"
    echo "reviewers can absorb turns the human gate into a rubber stamp."
    exit 3
  fi

  echo "OK: dispatch permitted."
  echo "  agent-blocked issues: ${BLOCKED}/${BLOCKED_BUDGET}"
  echo "  in-flight agent PRs:  ${IN_FLIGHT}/${PR_BUDGET}"
  exit 0
fi

# --- Operation: status -----------------------------------------------------
if [[ "$OPERATION" == "status" ]]; then
  case "$FORMAT" in
  table | json) ;;
  *)
    echo "Error: unknown format '${FORMAT}' (expected table or json)" >&2
    exit 1
    ;;
  esac

  HALTED="false"
  HALT_TEXT=""
  if [[ -f "$HALT_FILE" ]]; then
    HALTED="true"
    HALT_TEXT="$(halt_reason | head -1)"
  fi
  BLOCKED="$(count_open_issues_with_label "agent-blocked")"
  IN_FLIGHT="$(count_in_flight_prs)"

  if [[ "$FORMAT" == "json" ]]; then
    esc_halt="$(printf '%s' "$HALT_TEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    printf '{\n'
    printf '  "halted": %s,\n' "$HALTED"
    printf '  "halt_reason": "%s",\n' "$esc_halt"
    if [[ "$BLOCKED" == "unknown" ]]; then
      printf '  "agent_blocked_issues": null,\n'
    else
      printf '  "agent_blocked_issues": %s,\n' "$BLOCKED"
    fi
    if [[ "$IN_FLIGHT" == "unknown" ]]; then
      printf '  "in_flight_prs": null,\n'
    else
      printf '  "in_flight_prs": %s,\n' "$IN_FLIGHT"
    fi
    printf '  "blocked_budget": %s,\n' "$BLOCKED_BUDGET"
    printf '  "pr_budget": %s\n' "$PR_BUDGET"
    printf '}\n'
  else
    printf '%-24s %s\n' "Halted:" "$HALTED"
    if [[ "$HALTED" == "true" ]]; then
      printf '%-24s %s\n' "Halt reason:" "$HALT_TEXT"
    fi
    printf '%-24s %s/%s\n' "agent-blocked issues:" "$BLOCKED" "$BLOCKED_BUDGET"
    printf '%-24s %s/%s\n' "In-flight agent PRs:" "$IN_FLIGHT" "$PR_BUDGET"
    if [[ "$BLOCKED" == "unknown" || "$IN_FLIGHT" == "unknown" ]]; then
      printf '\n%s\n' "Note: 'unknown' means gh is unavailable or unauthenticated."
      printf '%s\n' "Dispatch refuses on an unknown budget rather than assuming headroom."
    fi
  fi
  exit 0
fi

echo "Error: unhandled operation '$OPERATION'" >&2
exit 1
