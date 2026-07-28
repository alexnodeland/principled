#!/usr/bin/env bash
# pipeline-audit.sh — Reconcile declared pipeline state against repository reality.
#
# The guard hooks are write-time: they fire when Claude edits a document through
# Edit or Write. They are blind to `git merge`, to edits made outside a session, and
# to the passage of time. So a repository can satisfy every guard and still drift:
#
#   - Plans 005, 007 and 008 sat at status "active" long after shipping
#   - Plan-008's checkboxes were entirely unchecked while all 14 of its deliverables
#     existed on disk
#   - Plan-008 was built from RFC-008 while that proposal was still "draft", which
#     check-plan-proposal-link.sh exists specifically to prevent
#   - Two documents claimed number 009 across different branches, which
#     check-doc-numbering.sh exists specifically to prevent
#
# Every one of those had a guard written for it. None of the guards fired, because
# none of them run against the repository as a whole. This script does.
#
# Exit: 0 = consistent, 1 = at least one inconsistency found.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PARSE_FM="plugins/principled-docs/hooks/scripts/parse-frontmatter.sh"

STRICT=0
ISSUES=0
WARNINGS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --strict)
    STRICT=1
    shift
    ;;
  -h | --help)
    echo "Usage: pipeline-audit.sh [--strict]"
    echo ""
    echo "  --strict  Treat warnings as failures."
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  esac
done

field() {
  bash "$PARSE_FM" --file "$1" --field "$2" 2> /dev/null || echo ""
}

issue() {
  echo "ISSUE:   $1"
  [[ -n "${2:-}" ]] && echo "         $2"
  ISSUES=$((ISSUES + 1))
}

warn() {
  echo "WARN:    $1"
  [[ -n "${2:-}" ]] && echo "         $2"
  WARNINGS=$((WARNINGS + 1))
}

echo "Pipeline audit"
echo "=============="
echo ""

# --- 1. Duplicate document numbers within a directory ---

echo "-- Document numbering --"
for dir in docs/proposals docs/plans docs/decisions; do
  [[ -d "$dir" ]] || continue
  dupes=$(find "$dir" -name '[0-9][0-9][0-9]-*.md' -exec basename {} \; \
    | cut -d- -f1 | sort | uniq -d)
  if [[ -n "$dupes" ]]; then
    while IFS= read -r num; do
      [[ -n "$num" ]] || continue
      files=$(find "$dir" -name "${num}-*.md" -exec basename {} \; | tr '\n' ' ')
      issue "Duplicate number ${num} in ${dir}" "$files"
    done <<< "$dupes"
  fi
done
[[ "$ISSUES" -eq 0 ]] && echo "   No duplicate numbers."
echo ""

# --- 2. Plans must reference an accepted proposal ---

echo "-- Plan/proposal linkage --"
linkage_issues=0
for plan in docs/plans/[0-9][0-9][0-9]-*.md; do
  [[ -f "$plan" ]] || continue
  from_proposal="$(field "$plan" originating_proposal)"
  plan_status="$(field "$plan" status)"

  if [[ -z "$from_proposal" ]]; then
    issue "$(basename "$plan") has no originating_proposal field"
    linkage_issues=$((linkage_issues + 1))
    continue
  fi

  proposal=$(find docs/proposals -name "${from_proposal}-*.md" | head -1)
  if [[ -z "$proposal" ]]; then
    issue "$(basename "$plan") references proposal ${from_proposal}, which does not exist"
    linkage_issues=$((linkage_issues + 1))
    continue
  fi

  proposal_status="$(field "$proposal" status)"
  if [[ "$proposal_status" != "accepted" ]]; then
    issue "$(basename "$plan") (status: ${plan_status}) is built from $(basename "$proposal"), which is still '${proposal_status}'" \
      "Plans require an accepted proposal. Either accept the proposal or mark the plan as not-yet-startable."
    linkage_issues=$((linkage_issues + 1))
  fi
done
[[ "$linkage_issues" -eq 0 ]] && echo "   All plans reference accepted proposals."
echo ""

# --- 3. Plan status vs. checkbox completion ---
#
# `status` is authoritative; checkboxes are working notes that routinely lag behind
# shipped work. So a complete plan with unticked boxes is a warning, not an error —
# saying otherwise would push people to tick boxes wholesale to silence CI, which
# destroys whatever signal the boxes carried.
#
# The reverse is unambiguous and is an error: every box ticked while the status is
# still "active" means someone finished the work and forgot the one-line status
# update. That is exactly what happened to Plan-005.

echo "-- Plan status vs. checkbox completion --"
status_issues=0
for plan in docs/plans/[0-9][0-9][0-9]-*.md; do
  [[ -f "$plan" ]] || continue
  plan_status="$(field "$plan" status)"
  name="$(basename "$plan")"

  total=$(grep -cE '^[[:space:]]*- \[[ xX]\]' "$plan" 2> /dev/null || true)
  done_count=$(grep -cE '^[[:space:]]*- \[[xX]\]' "$plan" 2> /dev/null || true)
  total=${total:-0}
  done_count=${done_count:-0}

  [[ "$total" -eq 0 ]] && continue

  if [[ "$plan_status" == "complete" ]] && [[ "$done_count" -lt "$total" ]]; then
    warn "${name} is complete but only ${done_count}/${total} tasks are checked" \
      "Checkboxes are working notes and lag; status is authoritative. Tick them only if you have verified the work."
    status_issues=$((status_issues + 1))
  fi

  if [[ "$plan_status" == "active" ]] && [[ "$done_count" -eq "$total" ]]; then
    issue "${name} has all ${total} tasks checked but is still marked active" \
      "Set status to complete."
    status_issues=$((status_issues + 1))
  fi

  if [[ "$plan_status" == "active" ]] && [[ "$done_count" -eq 0 ]] && [[ "$total" -gt 0 ]]; then
    warn "${name} is active with 0/${total} tasks checked" \
      "If the work shipped, the status was never updated — verify against the repository."
    status_issues=$((status_issues + 1))
  fi
done
[[ "$status_issues" -eq 0 ]] && echo "   Plan statuses agree with checkbox state."
echo ""

# --- 4. Supersession chain integrity ---

echo "-- ADR supersession --"
chain_issues=0
for adr in docs/decisions/[0-9][0-9][0-9]-*.md; do
  [[ -f "$adr" ]] || continue
  name="$(basename "$adr")"
  supersedes="$(field "$adr" supersedes)"
  superseded_by="$(field "$adr" superseded_by)"
  adr_status="$(field "$adr" status)"

  if [[ -n "$supersedes" ]] && [[ "$supersedes" != "null" ]]; then
    target=$(find docs/decisions -name "${supersedes}-*.md" | head -1)
    if [[ -z "$target" ]]; then
      issue "${name} supersedes ${supersedes}, which does not exist"
      chain_issues=$((chain_issues + 1))
    elif [[ "$adr_status" == "accepted" ]]; then
      # Only an accepted ADR actually supersedes anything.
      target_sb="$(field "$target" superseded_by)"
      if [[ "$target_sb" != "$(field "$adr" number)" ]]; then
        issue "${name} is accepted and supersedes ${supersedes}, but $(basename "$target") does not point back" \
          "Set superseded_by on the superseded ADR."
        chain_issues=$((chain_issues + 1))
      fi
    fi
  fi

  if [[ -n "$superseded_by" ]] && [[ "$superseded_by" != "null" ]]; then
    target=$(find docs/decisions -name "${superseded_by}-*.md" | head -1)
    if [[ -z "$target" ]]; then
      issue "${name} claims to be superseded by ${superseded_by}, which does not exist"
      chain_issues=$((chain_issues + 1))
    elif [[ "$adr_status" != "superseded" ]]; then
      issue "${name} has superseded_by set but status is '${adr_status}'" \
        "Set status to superseded."
      chain_issues=$((chain_issues + 1))
    fi
  fi
done
[[ "$chain_issues" -eq 0 ]] && echo "   Supersession chains are consistent."
echo ""

# --- 5. Required frontmatter present ---

echo "-- Frontmatter completeness --"
fm_issues=0
for doc in docs/proposals/[0-9][0-9][0-9]-*.md docs/plans/[0-9][0-9][0-9]-*.md docs/decisions/[0-9][0-9][0-9]-*.md; do
  [[ -f "$doc" ]] || continue
  for required in title number status; do
    if [[ -z "$(field "$doc" "$required")" ]]; then
      issue "$(basename "$doc") is missing required frontmatter field '${required}'"
      fm_issues=$((fm_issues + 1))
    fi
  done
done
[[ "$fm_issues" -eq 0 ]] && echo "   All pipeline documents have required frontmatter."
echo ""

# --- Summary ---

echo "=============="
echo "${ISSUES} issue(s), ${WARNINGS} warning(s)."

if [[ "$ISSUES" -gt 0 ]]; then
  exit 1
fi

if [[ "$STRICT" -eq 1 ]] && [[ "$WARNINGS" -gt 0 ]]; then
  echo "Failing on warnings (--strict)."
  exit 1
fi

echo "PASS: Declared pipeline state matches the repository."
