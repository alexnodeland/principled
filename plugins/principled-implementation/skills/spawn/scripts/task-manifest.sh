#!/usr/bin/env bash
# task-manifest.sh — CRUD operations for the task manifest.
#
# Usage:
#   task-manifest.sh --init --plan-path <path> --plan-number <num> --plan-title "<title>"
#   task-manifest.sh --add-task --task-id <id> --phase <N> --description "<desc>" \
#                    [--depends-on "<phases>"] [--bounded-contexts "<BCs>"]
#   task-manifest.sh --get-task --task-id <id>
#   task-manifest.sh --get-plan-path
#   task-manifest.sh --update-status --task-id <id> --status <status> \
#                    [--branch <name>] [--check-results "<text>"] [--error "<text>"]
#   task-manifest.sh --list-tasks [--phase <N>] [--status <status>]
#   task-manifest.sh --phase-status --phase <N>
#   task-manifest.sh --summary
#
# Manifest location: .impl/manifest.json
#
# Valid statuses:
#   pending, in_progress, validating, passed, failed, merged, abandoned, conflict
#
# Exit codes:
#   0 — success
#   1 — error

set -euo pipefail

MANIFEST=".impl/manifest.json"

# --- Argument parsing ---
OPERATION=""
PLAN_PATH=""
PLAN_NUMBER=""
PLAN_TITLE=""
TASK_ID=""
PHASE=""
DESCRIPTION=""
DEPENDS_ON="none"
BOUNDED_CONTEXTS=""
STATUS=""
BRANCH=""
CHECK_RESULTS=""
ERROR_MSG=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --init) OPERATION="init"; shift ;;
    --add-task) OPERATION="add-task"; shift ;;
    --get-task) OPERATION="get-task"; shift ;;
    --get-plan-path) OPERATION="get-plan-path"; shift ;;
    --update-status) OPERATION="update-status"; shift ;;
    --list-tasks) OPERATION="list-tasks"; shift ;;
    --phase-status) OPERATION="phase-status"; shift ;;
    --summary) OPERATION="summary"; shift ;;
    --plan-path) PLAN_PATH="$2"; shift 2 ;;
    --plan-number) PLAN_NUMBER="$2"; shift 2 ;;
    --plan-title) PLAN_TITLE="$2"; shift 2 ;;
    --task-id) TASK_ID="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --depends-on) DEPENDS_ON="$2"; shift 2 ;;
    --bounded-contexts) BOUNDED_CONTEXTS="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --check-results) CHECK_RESULTS="$2"; shift 2 ;;
    --error) ERROR_MSG="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$OPERATION" ]]; then
  echo "Error: an operation is required (--init, --add-task, --get-task, etc.)" >&2
  exit 1
fi

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- Helper: check jq availability ---
HAS_JQ=false
if command -v jq &> /dev/null; then
  HAS_JQ=true
fi

# --- Helper: validate status ---
validate_status() {
  local s="$1"
  case "$s" in
    pending | in_progress | validating | passed | failed | merged | abandoned | conflict) ;;
    *)
      echo "Error: invalid status '$s'. Valid: pending, in_progress, validating, passed, failed, merged, abandoned, conflict" >&2
      exit 1
      ;;
  esac
}

# --- Operation: init ---
if [[ "$OPERATION" == "init" ]]; then
  if [[ -z "$PLAN_PATH" || -z "$PLAN_NUMBER" || -z "$PLAN_TITLE" ]]; then
    echo "Error: --init requires --plan-path, --plan-number, and --plan-title" >&2
    exit 1
  fi

  if [[ -f "$MANIFEST" ]] && ! $FORCE; then
    echo "Error: manifest already exists at $MANIFEST. Use --force to overwrite." >&2
    exit 1
  fi

  mkdir -p "$(dirname "$MANIFEST")"

  if $HAS_JQ; then
    jq -n \
      --arg path "$PLAN_PATH" \
      --arg number "$PLAN_NUMBER" \
      --arg title "$PLAN_TITLE" \
      --arg now "$NOW" \
      '{
        version: "1.0.0",
        plan: {
          path: $path,
          number: $number,
          title: $title,
          decomposed_at: $now
        },
        phases: [],
        tasks: []
      }' > "$MANIFEST"
  else
    cat > "$MANIFEST" << EOF
{
  "version": "1.0.0",
  "plan": {
    "path": "${PLAN_PATH}",
    "number": "${PLAN_NUMBER}",
    "title": "${PLAN_TITLE}",
    "decomposed_at": "${NOW}"
  },
  "phases": [],
  "tasks": []
}
EOF
  fi

  echo "Manifest initialized at $MANIFEST"
  exit 0
fi

# --- All other operations require existing manifest ---
if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: manifest not found at $MANIFEST. Run --init first." >&2
  exit 1
fi

# --- Operation: get-plan-path ---
if [[ "$OPERATION" == "get-plan-path" ]]; then
  if $HAS_JQ; then
    jq -r '.plan.path' "$MANIFEST"
  else
    grep -oP '"path"\s*:\s*"\K[^"]*' "$MANIFEST" | head -1
  fi
  exit 0
fi

# --- Operation: add-task ---
if [[ "$OPERATION" == "add-task" ]]; then
  if [[ -z "$TASK_ID" || -z "$PHASE" || -z "$DESCRIPTION" ]]; then
    echo "Error: --add-task requires --task-id, --phase, and --description" >&2
    exit 1
  fi

  if $HAS_JQ; then
    # Check if phase exists, add if not
    PHASE_EXISTS="$(jq --arg p "$PHASE" '[.phases[] | select(.number == ($p | tonumber))] | length' "$MANIFEST")"
    if [[ "$PHASE_EXISTS" == "0" ]]; then
      PHASE_DEPS="[]"
      if [[ "$DEPENDS_ON" != "none" && -n "$DEPENDS_ON" ]]; then
        PHASE_DEPS="$(echo "$DEPENDS_ON" | tr ',' '\n' | jq -R 'tonumber' | jq -s '.')"
      fi
      BCS_ARRAY="[]"
      if [[ -n "$BOUNDED_CONTEXTS" ]]; then
        BCS_ARRAY="$(echo "$BOUNDED_CONTEXTS" | tr ',' '\n' | jq -R '.' | jq -s '.')"
      fi
      TMP="$(mktemp)"
      jq --arg p "$PHASE" --argjson deps "$PHASE_DEPS" --argjson bcs "$BCS_ARRAY" \
        '.phases += [{"number": ($p | tonumber), "depends_on": $deps, "bounded_contexts": $bcs}]' \
        "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
    fi

    # Add task
    TMP="$(mktemp)"
    BCS_ARRAY="[]"
    if [[ -n "$BOUNDED_CONTEXTS" ]]; then
      BCS_ARRAY="$(echo "$BOUNDED_CONTEXTS" | tr ',' '\n' | jq -R '.' | jq -s '.')"
    fi
    jq --arg id "$TASK_ID" --arg phase "$PHASE" --arg desc "$DESCRIPTION" \
       --argjson bcs "$BCS_ARRAY" --arg now "$NOW" \
      '.tasks += [{
        "id": $id,
        "phase": ($phase | tonumber),
        "description": $desc,
        "bounded_contexts": $bcs,
        "status": "pending",
        "branch": null,
        "check_results": null,
        "error": null,
        "retries": 0,
        "created_at": $now,
        "updated_at": $now
      }]' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  else
    # Without jq: append task using sed-based JSON manipulation
    # This is a simplified approach for the known schema
    TASK_JSON="    {\"id\": \"${TASK_ID}\", \"phase\": ${PHASE}, \"description\": \"${DESCRIPTION}\", \"bounded_contexts\": [\"${BOUNDED_CONTEXTS}\"], \"status\": \"pending\", \"branch\": null, \"check_results\": null, \"error\": null, \"retries\": 0, \"created_at\": \"${NOW}\", \"updated_at\": \"${NOW}\"}"

    # Find the tasks array closing bracket and insert before it
    TMP="$(mktemp)"
    TASKS_EMPTY="$(grep -c '"tasks": \[\]' "$MANIFEST" || true)"
    if [[ "$TASKS_EMPTY" -gt 0 ]]; then
      sed "s|\"tasks\": \[\]|\"tasks\": [\n${TASK_JSON}\n  ]|" "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
    else
      # Insert before the last ] in the tasks array
      sed -i "/\"tasks\":/,/\]/ { /\]/ i\\
,\\
${TASK_JSON}
}" "$MANIFEST"
    fi
  fi

  echo "Added task $TASK_ID to phase $PHASE"
  exit 0
fi

# --- Operation: get-task ---
if [[ "$OPERATION" == "get-task" ]]; then
  if [[ -z "$TASK_ID" ]]; then
    echo "Error: --get-task requires --task-id" >&2
    exit 1
  fi

  if $HAS_JQ; then
    TASK="$(jq --arg id "$TASK_ID" '.tasks[] | select(.id == $id)' "$MANIFEST")"
    if [[ -z "$TASK" ]]; then
      echo "Error: task $TASK_ID not found" >&2
      exit 1
    fi
    # Output as key=value pairs
    echo "$TASK" | jq -r 'to_entries[] | "\(.key)=\(.value)"'
  else
    # Fallback: grep for the task ID and extract fields
    FOUND=false
    while IFS= read -r line; do
      if [[ "$line" == *"\"id\": \"${TASK_ID}\""* ]]; then
        FOUND=true
      fi
      if $FOUND; then
        # Extract key-value pairs from JSON lines
        if [[ "$line" =~ \"([a-z_]+)\":[[:space:]]*(.*) ]]; then
          key="${BASH_REMATCH[1]}"
          val="${BASH_REMATCH[2]}"
          val="${val%,}"
          val="${val#\"}"
          val="${val%\"}"
          echo "${key}=${val}"
        fi
        if [[ "$line" == *"}"* ]]; then
          break
        fi
      fi
    done < "$MANIFEST"
    if ! $FOUND; then
      echo "Error: task $TASK_ID not found" >&2
      exit 1
    fi
  fi
  exit 0
fi

# --- Operation: update-status ---
if [[ "$OPERATION" == "update-status" ]]; then
  if [[ -z "$TASK_ID" || -z "$STATUS" ]]; then
    echo "Error: --update-status requires --task-id and --status" >&2
    exit 1
  fi

  validate_status "$STATUS"

  if $HAS_JQ; then
    TMP="$(mktemp)"
    UPDATE_EXPR=".status = \"$STATUS\" | .updated_at = \"$NOW\""
    if [[ -n "$BRANCH" ]]; then
      UPDATE_EXPR="$UPDATE_EXPR | .branch = \"$BRANCH\""
    fi
    if [[ -n "$CHECK_RESULTS" ]]; then
      UPDATE_EXPR="$UPDATE_EXPR | .check_results = \"$CHECK_RESULTS\""
    fi
    if [[ -n "$ERROR_MSG" ]]; then
      UPDATE_EXPR="$UPDATE_EXPR | .error = \"$ERROR_MSG\""
    fi
    if [[ "$STATUS" == "in_progress" ]]; then
      # Increment retries if transitioning from failed
      CURRENT_STATUS="$(jq -r --arg id "$TASK_ID" '.tasks[] | select(.id == $id) | .status' "$MANIFEST")"
      if [[ "$CURRENT_STATUS" == "failed" ]]; then
        UPDATE_EXPR="$UPDATE_EXPR | .retries = (.retries + 1)"
      fi
    fi

    jq --arg id "$TASK_ID" \
      "(.tasks[] | select(.id == \$id)) |= ($UPDATE_EXPR)" \
      "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  else
    # Without jq: use sed to update the status field
    TMP="$(mktemp)"
    sed "s|\"id\": \"${TASK_ID}\",|\"id\": \"${TASK_ID}\", \"__UPDATING__\": true,|" "$MANIFEST" > "$TMP"
    sed -i "/__UPDATING__/,/}/ s|\"status\": \"[^\"]*\"|\"status\": \"${STATUS}\"|" "$TMP"
    sed -i "/__UPDATING__/,/}/ s|\"updated_at\": \"[^\"]*\"|\"updated_at\": \"${NOW}\"|" "$TMP"
    if [[ -n "$BRANCH" ]]; then
      sed -i "/__UPDATING__/,/}/ s|\"branch\": [^,]*|\"branch\": \"${BRANCH}\"|" "$TMP"
    fi
    sed -i "s|\"__UPDATING__\": true, ||" "$TMP"
    mv "$TMP" "$MANIFEST"
  fi

  echo "Task $TASK_ID status updated to $STATUS"
  exit 0
fi

# --- Operation: list-tasks ---
if [[ "$OPERATION" == "list-tasks" ]]; then
  if $HAS_JQ; then
    FILTER=".tasks[]"
    if [[ -n "$PHASE" ]]; then
      FILTER="$FILTER | select(.phase == ($PHASE | tonumber))"
    fi
    if [[ -n "$STATUS" ]]; then
      FILTER="$FILTER | select(.status == \"$STATUS\")"
    fi
    jq -r --arg phase "${PHASE:-}" --arg status "${STATUS:-}" \
      "[${FILTER}] | .[] | \"\(.id)|\(.phase)|\(.status)|\(.description)\"" \
      "$MANIFEST"
  else
    # Fallback: basic listing
    grep -oP '"id": "\K[^"]*' "$MANIFEST"
  fi
  exit 0
fi

# --- Operation: phase-status ---
if [[ "$OPERATION" == "phase-status" ]]; then
  if [[ -z "$PHASE" ]]; then
    echo "Error: --phase-status requires --phase" >&2
    exit 1
  fi

  if $HAS_JQ; then
    jq -r --arg p "$PHASE" '
      .tasks | map(select(.phase == ($p | tonumber))) |
      {
        phase: ($p | tonumber),
        total: length,
        pending: map(select(.status == "pending")) | length,
        in_progress: map(select(.status == "in_progress")) | length,
        validating: map(select(.status == "validating")) | length,
        passed: map(select(.status == "passed")) | length,
        failed: map(select(.status == "failed")) | length,
        merged: map(select(.status == "merged")) | length,
        abandoned: map(select(.status == "abandoned")) | length,
        conflict: map(select(.status == "conflict")) | length
      } | to_entries[] | "\(.key)=\(.value)"
    ' "$MANIFEST"
  else
    echo "phase=$PHASE"
    echo "total=$(grep -c "\"phase\": ${PHASE}" "$MANIFEST" || echo "0")"
  fi
  exit 0
fi

# --- Operation: summary ---
if [[ "$OPERATION" == "summary" ]]; then
  if $HAS_JQ; then
    jq -r '
      {
        plan_title: .plan.title,
        plan_number: .plan.number,
        total_phases: (.phases | length),
        total_tasks: (.tasks | length),
        pending: [.tasks[] | select(.status == "pending")] | length,
        in_progress: [.tasks[] | select(.status == "in_progress")] | length,
        validating: [.tasks[] | select(.status == "validating")] | length,
        passed: [.tasks[] | select(.status == "passed")] | length,
        failed: [.tasks[] | select(.status == "failed")] | length,
        merged: [.tasks[] | select(.status == "merged")] | length,
        abandoned: [.tasks[] | select(.status == "abandoned")] | length,
        conflict: [.tasks[] | select(.status == "conflict")] | length
      } | to_entries[] | "\(.key)=\(.value)"
    ' "$MANIFEST"
  else
    echo "plan_title=$(grep -oP '"title"\s*:\s*"\K[^"]*' "$MANIFEST" | head -1)"
    echo "total_tasks=$(grep -c '"id":' "$MANIFEST" || echo "0")"
  fi
  exit 0
fi

echo "Error: unknown operation '$OPERATION'" >&2
exit 1
