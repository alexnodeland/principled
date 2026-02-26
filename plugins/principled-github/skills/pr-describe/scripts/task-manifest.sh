#!/usr/bin/env bash
# task-manifest.sh — Read and manage the task manifest for DDD plan execution.
#
# This is a subset of the principled-implementation task-manifest.sh,
# providing read-only operations needed for PR description generation.
#
# Usage:
#   task-manifest.sh --get-task --task-id <id>
#   task-manifest.sh --get-plan-path
#   task-manifest.sh --list-tasks [--phase <N>]
#
# Reads from .impl/manifest.json in the current directory or ancestors.

set -euo pipefail

MANIFEST=""
ACTION=""
TASK_ID=""
PHASE=""

# Find manifest file by walking up directories
find_manifest() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.impl/manifest.json" ]]; then
      echo "$dir/.impl/manifest.json"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --get-task)
    ACTION="get-task"
    shift
    ;;
  --get-plan-path)
    ACTION="get-plan-path"
    shift
    ;;
  --list-tasks)
    ACTION="list-tasks"
    shift
    ;;
  --task-id)
    TASK_ID="$2"
    shift 2
    ;;
  --phase)
    PHASE="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

MANIFEST="$(find_manifest 2> /dev/null || echo "")"
if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
  echo "Error: no .impl/manifest.json found" >&2
  exit 1
fi

case "$ACTION" in
get-plan-path)
  if command -v jq &> /dev/null; then
    jq -r '.plan_path // empty' "$MANIFEST"
  else
    # sed fallback avoids grep -P which is unavailable on macOS
    sed -n 's/.*"plan_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -1
  fi
  ;;
get-task)
  if [[ -z "$TASK_ID" ]]; then
    echo "Error: --task-id is required for --get-task" >&2
    exit 1
  fi
  if command -v jq &> /dev/null; then
    jq -r --arg id "$TASK_ID" \
      '.tasks[] | select(.id == $id) | "id=\(.id)\nphase=\(.phase)\ndescription=\(.description)\nstatus=\(.status)\nbounded_contexts=\(.bounded_contexts // "" | if type == "array" then join(",") else . end)\ndepends_on=\(.depends_on // "" | if type == "array" then join(",") else . end)"' \
      "$MANIFEST"
  else
    # Basic grep fallback — limited but functional
    grep -A 20 "\"id\"[[:space:]]*:[[:space:]]*\"${TASK_ID}\"" "$MANIFEST" \
      | head -20
  fi
  ;;
list-tasks)
  if command -v jq &> /dev/null; then
    if [[ -n "$PHASE" ]]; then
      jq -r --arg p "$PHASE" \
        '.tasks[] | select(.phase == ($p | tonumber)) | "\(.id): \(.description) [\(.status)]"' \
        "$MANIFEST"
    else
      jq -r '.tasks[] | "\(.id): \(.description) [\(.status)]"' "$MANIFEST"
    fi
  else
    # sed fallback avoids grep -P which is unavailable on macOS
    sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST"
  fi
  ;;
*)
  echo "Error: specify --get-task, --get-plan-path, or --list-tasks" >&2
  exit 1
  ;;
esac
