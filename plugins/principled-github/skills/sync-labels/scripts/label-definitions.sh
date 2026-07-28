#!/usr/bin/env bash
# label-definitions.sh — Canonical label taxonomy for principled workflows.
#
# Usage:
#   label-definitions.sh --list          Output all label definitions
#   label-definitions.sh --json          Output as JSON array
#   label-definitions.sh --group <name>  Output labels for a specific group
#
# Each label definition: name|color|description

set -euo pipefail

ACTION=""
GROUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --list)
    ACTION="list"
    shift
    ;;
  --json)
    ACTION="json"
    shift
    ;;
  --group)
    ACTION="group"
    GROUP="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  ACTION="list"
fi

# Label definitions: name|color|description
LABELS=(
  # Proposal lifecycle
  "proposal:draft|0E8A16|Proposal in draft state"
  "proposal:in-review|FBCA04|Proposal under review"
  "proposal:accepted|006B75|Proposal accepted"
  "proposal:rejected|B60205|Proposal rejected"
  "proposal:superseded|5319E7|Proposal superseded by a newer proposal"

  # Plan lifecycle
  "plan:active|0E8A16|Plan actively executing"
  "plan:complete|006B75|Plan completed"
  "plan:abandoned|B60205|Plan abandoned"

  # Document type
  "type:rfc|C5DEF5|Proposal / RFC document"
  "type:plan|BFD4F2|DDD Implementation Plan"

  # Agent workforce (ADR-022). These are load-bearing, not decorative:
  # agent-blocked is counted against the dispatch budget, and agent-authored is
  # how in-flight agent PRs are counted for the review-capacity circuit breaker.
  "agent-ready|1D76DB|Issue is understood well enough to hand to an agent"
  "agent-blocked|D93F0B|Agent could not proceed; counts against the dispatch budget"
  "agent-authored|8250DF|Opened by an agent; counts against the in-flight PR budget"
)

case "$ACTION" in
list)
  for label in "${LABELS[@]}"; do
    IFS='|' read -r name color description <<< "$label"
    echo "${name}|${color}|${description}"
  done
  ;;
json)
  echo "["
  first=true
  for label in "${LABELS[@]}"; do
    IFS='|' read -r name color description <<< "$label"
    if $first; then
      first=false
    else
      echo ","
    fi
    printf '  {"name": "%s", "color": "%s", "description": "%s"}' \
      "$name" "$color" "$description"
  done
  echo ""
  echo "]"
  ;;
group)
  if [[ -z "$GROUP" ]]; then
    echo "Error: --group requires a group name" >&2
    exit 1
  fi
  for label in "${LABELS[@]}"; do
    IFS='|' read -r name color description <<< "$label"
    if [[ "$name" == "${GROUP}:"* ]]; then
      echo "${name}|${color}|${description}"
    fi
  done
  ;;
esac
