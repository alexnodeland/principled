#!/usr/bin/env bash
# check-agent-governance.sh — Advisory guard for the agent contributor protocol
# (ADR-022).
#
# Fires after a Bash command. Watches for the two governance constraints that are
# violated by a command rather than by a file edit:
#
#   1. An agent PR opened without --draft. Promotion to ready-for-review is a human act.
#   2. An agent approving or merging a PR. An agent that can approve its own work removes
#      the only reliable check on a non-deterministic system.
#
# It also surfaces an engaged halt switch when a dispatch-shaped command is run, since a
# halt that goes unnoticed is a halt that gets worked around.
#
# Advisory only — always exits 0. The blocking enforcement lives where it can be
# authoritative: branch protection on the GitHub side, and --can-dispatch before a run
# starts. A PostToolUse hook fires after the command has already run, so blocking here
# would be theatre.
#
# Input: JSON on stdin with tool_input.command
# Output: Warnings to stderr
# Exit: Always 0 (advisory)

set -euo pipefail

input=$(cat 2> /dev/null || true)

command_text=""
if command -v jq &> /dev/null; then
  command_text=$(echo "$input" | jq -r '.tool_input.command // empty' 2> /dev/null || true)
else
  command_text=$(echo "$input" \
    | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//' \
    | sed 's/"$//' || true)
fi

if [[ -z "$command_text" ]]; then
  exit 0
fi

case "$command_text" in
*gh\ pr* | *gh\ issue* | *agent-dispatch*) ;;
*) exit 0 ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
HALT_FILE="${REPO_ROOT}/.agents/HALT"

# --- Halt switch awareness -------------------------------------------------
if [[ -f "$HALT_FILE" ]]; then
  case "$command_text" in
  *agent-dispatch* | *"gh workflow run"*)
    echo "⚠️  Advisory: the halt switch is engaged, but a dispatch command was run." >&2
    echo "   File: ${HALT_FILE}" >&2
    if [[ -s "$HALT_FILE" ]]; then
      echo "   Reason: $(head -1 "$HALT_FILE")" >&2
    fi
    echo "   Clear it deliberately with 'agent-governance.sh --resume' rather than" >&2
    echo "   working around it — the switch exists to stop a run nobody is watching." >&2
    ;;
  esac
fi

# --- Draft PR constraint ---------------------------------------------------
case "$command_text" in
*"gh pr create"*)
  if [[ "$command_text" != *"--draft"* ]]; then
    echo "⚠️  Advisory: 'gh pr create' without --draft." >&2
    echo "   Agents open draft PRs; promotion to ready-for-review is a human act" >&2
    echo "   (ADR-022). If a human is opening this PR, carry on." >&2
  fi
  if [[ "$command_text" != *"agent-authored"* ]]; then
    echo "⚠️  Advisory: agent PRs should carry the 'agent-authored' label." >&2
    echo "   The in-flight PR budget is counted by that label, so an unlabelled agent PR" >&2
    echo "   is invisible to the review-capacity circuit breaker." >&2
  fi
  ;;
esac

# --- Self-approval and merge constraints -----------------------------------
case "$command_text" in
*"gh pr review"*)
  case "$command_text" in
  *--approve*)
    echo "⚠️  Advisory: 'gh pr review --approve' detected." >&2
    echo "   Agents must not approve PRs, including their own (ADR-022). Approval is" >&2
    echo "   the human gate that makes autonomous execution safe to run at all." >&2
    ;;
  esac
  ;;
esac

case "$command_text" in
*"gh pr merge"*)
  echo "⚠️  Advisory: 'gh pr merge' detected." >&2
  echo "   No agent mode auto-merges (ADR-022). Merging is a human act; branch" >&2
  echo "   protection should be enforcing this independently." >&2
  ;;
esac

# --- Ready-for-review promotion --------------------------------------------
case "$command_text" in
*"gh pr ready"*)
  echo "⚠️  Advisory: 'gh pr ready' promotes a draft PR to ready-for-review." >&2
  echo "   That is a human decision under the contributor protocol (ADR-022)." >&2
  ;;
esac

exit 0
