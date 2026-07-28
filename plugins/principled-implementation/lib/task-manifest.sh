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
# Checkpoint and acceptance criteria (ADR-021):
#   task-manifest.sh --set-checkpoint --summary-text "<text>" [--session-id <id>] \
#                    [--agent-id <id>] [--phase <N>] [--pending-decisions "<a|b>"]
#   task-manifest.sh --get-checkpoint
#   task-manifest.sh --clear-checkpoint
#   task-manifest.sh --set-criteria --task-id <id> --criteria "<desc1|desc2|...>"
#   task-manifest.sh --verify-criterion --task-id <id> --criterion-index <N>
#   task-manifest.sh --list-criteria --task-id <id>
#
# The checkpoint is advisory context for a resuming session. Task state remains
# authoritative; where the two disagree, task state wins (ADR-021).
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
SESSION_ID=""
AGENT_ID=""
SUMMARY_TEXT=""
PENDING_DECISIONS=""
ACTIVE_WORKTREES=""
CRITERIA=""
CRITERION_INDEX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --init)
    OPERATION="init"
    shift
    ;;
  --add-task)
    OPERATION="add-task"
    shift
    ;;
  --get-task)
    OPERATION="get-task"
    shift
    ;;
  --get-plan-path)
    OPERATION="get-plan-path"
    shift
    ;;
  --update-status)
    OPERATION="update-status"
    shift
    ;;
  --list-tasks)
    OPERATION="list-tasks"
    shift
    ;;
  --phase-status)
    OPERATION="phase-status"
    shift
    ;;
  --summary)
    OPERATION="summary"
    shift
    ;;
  --set-checkpoint)
    OPERATION="set-checkpoint"
    shift
    ;;
  --get-checkpoint)
    OPERATION="get-checkpoint"
    shift
    ;;
  --clear-checkpoint)
    OPERATION="clear-checkpoint"
    shift
    ;;
  --set-criteria)
    OPERATION="set-criteria"
    shift
    ;;
  --verify-criterion)
    OPERATION="verify-criterion"
    shift
    ;;
  --list-criteria)
    OPERATION="list-criteria"
    shift
    ;;
  --session-id)
    SESSION_ID="$2"
    shift 2
    ;;
  --agent-id)
    AGENT_ID="$2"
    shift 2
    ;;
  --summary-text)
    SUMMARY_TEXT="$2"
    shift 2
    ;;
  --pending-decisions)
    PENDING_DECISIONS="$2"
    shift 2
    ;;
  --active-worktrees)
    ACTIVE_WORKTREES="$2"
    shift 2
    ;;
  --criteria)
    CRITERIA="$2"
    shift 2
    ;;
  --criterion-index)
    CRITERION_INDEX="$2"
    shift 2
    ;;
  --plan-path)
    PLAN_PATH="$2"
    shift 2
    ;;
  --plan-number)
    PLAN_NUMBER="$2"
    shift 2
    ;;
  --plan-title)
    PLAN_TITLE="$2"
    shift 2
    ;;
  --task-id)
    TASK_ID="$2"
    shift 2
    ;;
  --phase)
    PHASE="$2"
    shift 2
    ;;
  --description)
    DESCRIPTION="$2"
    shift 2
    ;;
  --depends-on)
    DEPENDS_ON="$2"
    shift 2
    ;;
  --bounded-contexts)
    BOUNDED_CONTEXTS="$2"
    shift 2
    ;;
  --status)
    STATUS="$2"
    shift 2
    ;;
  --branch)
    BRANCH="$2"
    shift 2
    ;;
  --check-results)
    CHECK_RESULTS="$2"
    shift 2
    ;;
  --error)
    ERROR_MSG="$2"
    shift 2
    ;;
  --force)
    FORCE=true
    shift
    ;;
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
    sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -1
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

    # Find the tasks array closing bracket and insert before it.
    # awk, not `sed -i`: BSD sed reads the argument after -i as a backup suffix,
    # so `sed -i <expr> <file>` silently misparses on stock macOS.
    TMP="$(mktemp)"
    TASKS_EMPTY="$(grep -c '"tasks": \[\]' "$MANIFEST" || true)"
    if [[ "$TASKS_EMPTY" -gt 0 ]]; then
      awk -v task="$TASK_JSON" '
        /"tasks"[[:space:]]*:[[:space:]]*\[\]/ {
          sub(/"tasks"[[:space:]]*:[[:space:]]*\[\]/, "\"tasks\": [")
          print
          print task
          print "  ]"
          next
        }
        { print }
      ' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
    else
      # Append inside the existing tasks array. Hold the previous line back so the
      # last element can take a trailing comma before the new one is written.
      awk -v task="$TASK_JSON" '
        !intasks && /"tasks"[[:space:]]*:[[:space:]]*\[/ { intasks = 1; print; next }
        intasks && /^[[:space:]]*\][[:space:]]*,?[[:space:]]*$/ {
          if (prev != "") print prev ","
          print task
          print $0
          intasks = 0
          prev = ""
          next
        }
        intasks {
          if (prev != "") print prev
          prev = $0
          next
        }
        { print }
        END { if (prev != "") print prev }
      ' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
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
    # Without jq: rewrite the matching task's fields with awk.
    # `sed -i` is unusable here — BSD sed treats the following argument as a
    # backup suffix, so the same invocation behaves differently on macOS and
    # Linux. awk with a temp file behaves identically on both.
    TMP="$(mktemp)"
    awk -v id="$TASK_ID" -v status="$STATUS" -v now="$NOW" -v branch="$BRANCH" '
      # A task object may be one line (written without jq) or several (written
      # with jq). Track whether the current object is the target either way.
      {
        line = $0

        if (index(line, "\"id\": \"" id "\"") > 0) {
          intask = 1
        }

        if (intask) {
          gsub(/"status"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"status\": \"" status "\"", line)
          gsub(/"updated_at"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"updated_at\": \"" now "\"", line)
          if (branch != "") {
            gsub(/"branch"[[:space:]]*:[[:space:]]*(null|"[^"]*")/, "\"branch\": \"" branch "\"", line)
          }
        }

        # A single-line object opens and closes on the same line; a multi-line
        # object ends at a closing brace. Either way, stop after the object ends.
        if (intask && index(line, "}") > 0) {
          intask = 0
        }

        print line
      }
    ' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
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
    sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST"
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
    echo "plan_title=$(sed -n 's/.*"title"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -1)"
    echo "total_tasks=$(grep -c '"id":' "$MANIFEST" || echo "0")"
  fi
  exit 0
fi

# ===========================================================================
# Checkpoint and acceptance criteria (ADR-021)
#
# Both are additive and optional. A manifest without them is valid, and every
# consumer must tolerate their absence.
# ===========================================================================

# Escape a value for embedding in a JSON string literal.
json_escape() {
  printf '%s' "$1" | awk '
    {
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\t/, "\\t")
      gsub(/\r/, "")
      lines[NR] = $0
    }
    END {
      out = ""
      for (i = 1; i <= NR; i++) {
        out = out (i > 1 ? "\\n" : "") lines[i]
      }
      printf "%s", out
    }
  '
}

# Remove a top-level key and its (possibly nested) value, then repair a
# dangling comma if the removed key was last. Used only on the no-jq path.
strip_top_level_key() {
  local file="$1" key="$2" tmp
  tmp="$(mktemp)"

  awk -v key="$key" '
    !inkey && $0 ~ ("^[[:space:]]*\"" key "\"[[:space:]]*:") {
      inkey = 1
      opens = gsub(/[{[]/, "&")
      closes = gsub(/[}\]]/, "&")
      depth = opens - closes
      if (depth <= 0) inkey = 0
      next
    }
    inkey {
      opens = gsub(/[{[]/, "&")
      closes = gsub(/[}\]]/, "&")
      depth += opens - closes
      if (depth <= 0) inkey = 0
      next
    }
    { print }
  ' "$file" > "$tmp"

  # If the key was the final entry, the preceding line now has a trailing comma
  # before the closing brace. Find the last content line and strip it.
  awk '
    { lines[NR] = $0 }
    END {
      last_content = 0
      for (i = NR; i >= 1; i--) {
        if (lines[i] ~ /^[[:space:]]*}[[:space:]]*$/) continue
        last_content = i
        break
      }
      if (last_content > 0) sub(/,[[:space:]]*$/, "", lines[last_content])
      for (i = 1; i <= NR; i++) print lines[i]
    }
  ' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$file"
  rm -f "$tmp"
}

# --- Operation: set-checkpoint ---
if [[ "$OPERATION" == "set-checkpoint" ]]; then
  if [[ -z "$SUMMARY_TEXT" ]]; then
    echo "Error: --set-checkpoint requires --summary-text" >&2
    exit 1
  fi

  if [[ -n "$PHASE" && ! "$PHASE" =~ ^[0-9]+$ ]]; then
    echo "Error: --phase must be a non-negative integer (got '${PHASE}')" >&2
    exit 1
  fi

  if $HAS_JQ; then
    TMP="$(mktemp)"
    DECISIONS_JSON="[]"
    if [[ -n "$PENDING_DECISIONS" ]]; then
      DECISIONS_JSON="$(printf '%s' "$PENDING_DECISIONS" | tr '|' '\n' | jq -R '.' | jq -s '.')"
    fi
    WORKTREES_JSON="[]"
    if [[ -n "$ACTIVE_WORKTREES" ]]; then
      WORKTREES_JSON="$(printf '%s' "$ACTIVE_WORKTREES" | tr ',' '\n' | jq -R '.' | jq -s '.')"
    fi

    jq --arg sid "$SESSION_ID" \
      --arg aid "$AGENT_ID" \
      --arg phase "$PHASE" \
      --arg now "$NOW" \
      --arg summary "$SUMMARY_TEXT" \
      --argjson decisions "$DECISIONS_JSON" \
      --argjson worktrees "$WORKTREES_JSON" \
      '.checkpoint = {
        session_id: $sid,
        agent_id: $aid,
        phase: (if $phase == "" then null else ($phase | tonumber) end),
        timestamp: $now,
        orchestrator_summary: $summary,
        pending_decisions: $decisions,
        environment_state: { active_worktrees: $worktrees }
      }' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  else
    strip_top_level_key "$MANIFEST" "checkpoint"

    ESC_SUMMARY="$(json_escape "$SUMMARY_TEXT")"
    ESC_SID="$(json_escape "$SESSION_ID")"
    ESC_AID="$(json_escape "$AGENT_ID")"

    DECISIONS_JSON="[]"
    if [[ -n "$PENDING_DECISIONS" ]]; then
      DECISIONS_JSON="$(printf '%s' "$PENDING_DECISIONS" | awk -F'|' '{
        out = "["
        for (i = 1; i <= NF; i++) {
          v = $i
          gsub(/\\/, "\\\\", v)
          gsub(/"/, "\\\"", v)
          out = out (i > 1 ? ", " : "") "\"" v "\""
        }
        printf "%s]", out
      }')"
    fi

    WORKTREES_JSON="[]"
    if [[ -n "$ACTIVE_WORKTREES" ]]; then
      WORKTREES_JSON="$(printf '%s' "$ACTIVE_WORKTREES" | awk -F',' '{
        out = "["
        for (i = 1; i <= NF; i++) {
          v = $i
          gsub(/^[ \t]+|[ \t]+$/, "", v)
          gsub(/"/, "\\\"", v)
          out = out (i > 1 ? ", " : "") "\"" v "\""
        }
        printf "%s]", out
      }')"
    fi

    PHASE_JSON="null"
    if [[ -n "$PHASE" ]]; then
      PHASE_JSON="$PHASE"
    fi

    # Insert as the first key so no trailing-comma repair is needed.
    TMP="$(mktemp)"
    awk -v sid="$ESC_SID" -v aid="$ESC_AID" -v phase="$PHASE_JSON" \
      -v now="$NOW" -v summary="$ESC_SUMMARY" \
      -v decisions="$DECISIONS_JSON" -v worktrees="$WORKTREES_JSON" '
      NR == 1 && /^[[:space:]]*\{[[:space:]]*$/ {
        print
        print "  \"checkpoint\": {"
        print "    \"session_id\": \"" sid "\","
        print "    \"agent_id\": \"" aid "\","
        print "    \"phase\": " phase ","
        print "    \"timestamp\": \"" now "\","
        print "    \"orchestrator_summary\": \"" summary "\","
        print "    \"pending_decisions\": " decisions ","
        print "    \"environment_state\": { \"active_worktrees\": " worktrees " }"
        print "  },"
        next
      }
      { print }
    ' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  fi

  echo "Checkpoint written at $NOW"
  exit 0
fi

# --- Operation: get-checkpoint ---
if [[ "$OPERATION" == "get-checkpoint" ]]; then
  if $HAS_JQ; then
    if [[ "$(jq -r 'has("checkpoint")' "$MANIFEST")" != "true" ]]; then
      echo "No checkpoint recorded." >&2
      exit 1
    fi
    jq -r '.checkpoint | to_entries[] | "\(.key)=\(.value | if type == "array" or type == "object" then tojson else . end)"' "$MANIFEST"
  else
    if ! grep -q '"checkpoint"' "$MANIFEST"; then
      echo "No checkpoint recorded." >&2
      exit 1
    fi
    awk '
      !inck && /^[[:space:]]*"checkpoint"[[:space:]]*:/ {
        inck = 1
        opens = gsub(/[{[]/, "&")
        closes = gsub(/[}\]]/, "&")
        depth = opens - closes
        next
      }
      inck {
        opens = gsub(/[{[]/, "&")
        closes = gsub(/[}\]]/, "&")
        line = $0
        depth += opens - closes
        if (depth <= 0) { inck = 0 }
        idx = index(line, ":")
        if (idx > 0) {
          k = substr(line, 1, idx - 1)
          v = substr(line, idx + 1)
          gsub(/^[ \t]+|[ \t]+$/, "", k)
          gsub(/^"|"$/, "", k)
          gsub(/^[ \t]+|[ \t,]+$/, "", v)
          gsub(/^"|"$/, "", v)
          if (k != "" && v != "") print k "=" v
        }
      }
    ' "$MANIFEST"
  fi
  exit 0
fi

# --- Operation: clear-checkpoint ---
if [[ "$OPERATION" == "clear-checkpoint" ]]; then
  if $HAS_JQ; then
    TMP="$(mktemp)"
    jq 'del(.checkpoint)' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  else
    strip_top_level_key "$MANIFEST" "checkpoint"
  fi
  echo "Checkpoint cleared."
  exit 0
fi

# --- Operation: set-criteria ---
if [[ "$OPERATION" == "set-criteria" ]]; then
  if [[ -z "$TASK_ID" || -z "$CRITERIA" ]]; then
    echo "Error: --set-criteria requires --task-id and --criteria" >&2
    exit 1
  fi

  if ! grep -q "\"id\": \"${TASK_ID}\"" "$MANIFEST"; then
    echo "Error: task $TASK_ID not found" >&2
    exit 1
  fi

  # Criteria arrive pipe-separated and are always written as a single line, so
  # the same insertion works for one-line and jq-formatted task objects.
  CRITERIA_JSON="$(printf '%s' "$CRITERIA" | awk -F'|' '{
    out = "["
    for (i = 1; i <= NF; i++) {
      v = $i
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      gsub(/\\/, "\\\\", v)
      gsub(/"/, "\\\"", v)
      out = out (i > 1 ? ", " : "") "{\"description\": \"" v "\", \"verified\": false, \"verified_at\": null}"
    }
    printf "%s]", out
  }')"

  if $HAS_JQ; then
    TMP="$(mktemp)"
    jq --arg id "$TASK_ID" --argjson crit "$CRITERIA_JSON" \
      '(.tasks[] | select(.id == $id)).acceptance_criteria = $crit' \
      "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  else
    TMP="$(mktemp)"
    awk -v id="$TASK_ID" -v crit="$CRITERIA_JSON" '
      {
        line = $0
        if (index(line, "\"id\": \"" id "\"") > 0) {
          if (index(line, "}") > 0) {
            # Single-line task object: splice before its closing brace.
            pos = length(line)
            while (pos > 0 && substr(line, pos, 1) != "}") pos--
            head = substr(line, 1, pos - 1)
            tail = substr(line, pos)
            sub(/[ \t]+$/, "", head)
            # Drop any existing acceptance_criteria before re-adding.
            gsub(/, "acceptance_criteria": \[[^]]*\]/, "", head)
            print head ", \"acceptance_criteria\": " crit tail
            next
          } else {
            # Multi-line task object: insert as the next field.
            print line
            print "      \"acceptance_criteria\": " crit ","
            next
          }
        }
        print line
      }
    ' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  fi

  echo "Acceptance criteria set for task $TASK_ID"
  exit 0
fi

# --- Operation: verify-criterion ---
if [[ "$OPERATION" == "verify-criterion" ]]; then
  if [[ -z "$TASK_ID" || -z "$CRITERION_INDEX" ]]; then
    echo "Error: --verify-criterion requires --task-id and --criterion-index" >&2
    exit 1
  fi

  if [[ ! "$CRITERION_INDEX" =~ ^[0-9]+$ ]]; then
    echo "Error: --criterion-index must be a non-negative integer (got '${CRITERION_INDEX}')" >&2
    exit 1
  fi

  if $HAS_JQ; then
    COUNT="$(jq -r --arg id "$TASK_ID" \
      '[.tasks[] | select(.id == $id) | .acceptance_criteria // []] | first | length' "$MANIFEST")"
    if [[ "$COUNT" == "null" || "$COUNT" == "0" ]]; then
      echo "Error: task $TASK_ID has no acceptance criteria" >&2
      exit 1
    fi
    if [[ "$CRITERION_INDEX" -ge "$COUNT" ]]; then
      echo "Error: criterion index ${CRITERION_INDEX} out of range (0..$((COUNT - 1)))" >&2
      exit 1
    fi
    TMP="$(mktemp)"
    jq --arg id "$TASK_ID" --argjson idx "$CRITERION_INDEX" --arg now "$NOW" \
      '(.tasks[] | select(.id == $id) | .acceptance_criteria[$idx]) |=
        (.verified = true | .verified_at = $now)' \
      "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  else
    if ! grep -q "\"id\": \"${TASK_ID}\"" "$MANIFEST"; then
      echo "Error: task $TASK_ID not found" >&2
      exit 1
    fi
    TMP="$(mktemp)"
    RESULT="$(awk -v id="$TASK_ID" -v want="$CRITERION_INDEX" -v now="$NOW" -v out="$TMP" '
      BEGIN { found = 0 }
      {
        line = $0
        if (index(line, "\"id\": \"" id "\"") > 0 && index(line, "acceptance_criteria") > 0) {
          # Walk the criterion objects and flip the requested one.
          n = 0
          result = ""
          rest = line
          while (1) {
            p = index(rest, "{\"description\"")
            if (p == 0) { result = result rest; break }
            q = index(substr(rest, p), "}")
            if (q == 0) { result = result rest; break }
            obj = substr(rest, p, q)
            result = result substr(rest, 1, p - 1)
            if (n == want) {
              gsub(/"verified": false/, "\"verified\": true", obj)
              gsub(/"verified_at": null/, "\"verified_at\": \"" now "\"", obj)
              found = 1
            }
            result = result obj
            rest = substr(rest, p + q)
            n++
          }
          print result > out
          next
        }
        print line > out
      }
      END { print (found ? "ok" : "notfound") }
    ' "$MANIFEST")"

    if [[ "$RESULT" != "ok" ]]; then
      rm -f "$TMP"
      echo "Error: criterion index ${CRITERION_INDEX} not found for task ${TASK_ID}" >&2
      echo "Note: without jq, criteria must be on the same line as the task id." >&2
      exit 1
    fi
    mv "$TMP" "$MANIFEST"
  fi

  echo "Criterion ${CRITERION_INDEX} verified for task $TASK_ID"
  exit 0
fi

# --- Operation: list-criteria ---
if [[ "$OPERATION" == "list-criteria" ]]; then
  if [[ -z "$TASK_ID" ]]; then
    echo "Error: --list-criteria requires --task-id" >&2
    exit 1
  fi

  if $HAS_JQ; then
    jq -r --arg id "$TASK_ID" '
      [.tasks[] | select(.id == $id) | .acceptance_criteria // []] | first // []
      | to_entries[]
      | "\(.key)|\(if .value.verified then "verified" else "pending" end)|\(.value.description)"
    ' "$MANIFEST"
  else
    awk -v id="$TASK_ID" '
      index($0, "\"id\": \"" id "\"") > 0 && index($0, "acceptance_criteria") > 0 {
        n = 0
        rest = $0
        while (1) {
          p = index(rest, "{\"description\"")
          if (p == 0) break
          q = index(substr(rest, p), "}")
          if (q == 0) break
          obj = substr(rest, p, q)

          d = obj
          sub(/.*"description": "/, "", d)
          sub(/".*/, "", d)

          state = (index(obj, "\"verified\": true") > 0) ? "verified" : "pending"
          print n "|" state "|" d

          rest = substr(rest, p + q)
          n++
        }
      }
    ' "$MANIFEST"
  fi
  exit 0
fi

echo "Error: unknown operation '$OPERATION'" >&2
exit 1
