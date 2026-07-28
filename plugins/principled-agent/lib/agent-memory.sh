#!/usr/bin/env bash
# agent-memory.sh — Agent identity and memory interface (ADR-020)
#
# Memory is a markdown document with YAML frontmatter, one file per agent,
# committed to git and revised in place. Frontmatter carries queryable metadata;
# the body carries knowledge the model reads directly.
#
# Usage:
#   agent-memory.sh --init [--root <path>]
#   agent-memory.sh --path --agent <id>
#   agent-memory.sh --show --agent <id> [--body-only|--frontmatter-only]
#   agent-memory.sh --list [--format table|json]
#   agent-memory.sh --update-metrics --agent <id> [--session] [--tasks N] [--succeeded N]
#   agent-memory.sh --reset-metrics [--agent <id>]
#   agent-memory.sh --check [--agent <id>]
#
# Exit codes:
#   0 — success
#   1 — error (unknown agent, malformed input, missing scaffold)
#
# Constraints: bash 3.2 (stock macOS), jq optional, no GNU-only tooling.

set -euo pipefail

# --- Size budget (RFC-011) -------------------------------------------------
# Memory competes with the task description for context. These are advisory
# thresholds, never enforced by truncation.
SOFT_LIMIT_BYTES=8192
HARD_LIMIT_BYTES=16384

# --- Locate the repository root --------------------------------------------
ROOT_PATH=""
OPERATION=""
AGENT_ID=""
FORMAT="table"
SHOW_MODE="full"
ADD_SESSION=false
ADD_TASKS=""
ADD_SUCCEEDED=""

usage() {
  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --init)
    OPERATION="init"
    shift
    ;;
  --path)
    OPERATION="path"
    shift
    ;;
  --show)
    OPERATION="show"
    shift
    ;;
  --list)
    OPERATION="list"
    shift
    ;;
  --update-metrics)
    OPERATION="update-metrics"
    shift
    ;;
  --reset-metrics)
    OPERATION="reset-metrics"
    shift
    ;;
  --check)
    OPERATION="check"
    shift
    ;;
  --agent)
    [[ $# -ge 2 ]] || {
      echo "Error: --agent requires a value" >&2
      exit 1
    }
    AGENT_ID="$2"
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
  --format)
    [[ $# -ge 2 ]] || {
      echo "Error: --format requires a value" >&2
      exit 1
    }
    FORMAT="$2"
    shift 2
    ;;
  --body-only)
    SHOW_MODE="body"
    shift
    ;;
  --frontmatter-only)
    SHOW_MODE="frontmatter"
    shift
    ;;
  --session)
    ADD_SESSION=true
    shift
    ;;
  --tasks)
    [[ $# -ge 2 ]] || {
      echo "Error: --tasks requires a value" >&2
      exit 1
    }
    ADD_TASKS="$2"
    shift 2
    ;;
  --succeeded)
    [[ $# -ge 2 ]] || {
      echo "Error: --succeeded requires a value" >&2
      exit 1
    }
    ADD_SUCCEEDED="$2"
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

if [[ -z "$ROOT_PATH" ]]; then
  ROOT_PATH="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
fi

AGENTS_DIR="${ROOT_PATH}/.agents"
REGISTRY="${AGENTS_DIR}/registry.json"
MEMORY_DIR="${AGENTS_DIR}/memory"
AGENT_MEMORY_DIR="${MEMORY_DIR}/agents"
RETRO_DIR="${AGENTS_DIR}/retrospectives"

HAS_JQ=false
if command -v jq &> /dev/null; then
  HAS_JQ=true
fi

TODAY="$(date -u +%Y-%m-%d)"

# --- Frontmatter helpers ---------------------------------------------------
# Read a single frontmatter field. Prints the value, or nothing if absent.
fm_get() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  awk -v k="$key" '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm {
      idx = index($0, ":")
      if (idx > 0) {
        f = substr($0, 1, idx - 1)
        v = substr($0, idx + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", f)
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        gsub(/^"|"$/, "", v)
        if (f == k) { print v; exit }
      }
    }
  ' "$file"
}

# Print everything after the closing frontmatter delimiter.
fm_body() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if [[ "$(head -1 "$file")" != "---" ]]; then
    cat "$file"
    return 0
  fi
  awk '
    NR == 1 { next }
    !done && /^---[[:space:]]*$/ { done = 1; next }
    done { print }
  ' "$file"
}

# Print the frontmatter block including delimiters.
fm_header() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk '
    NR == 1 && /^---[[:space:]]*$/ { print; infm = 1; next }
    infm { print }
    infm && /^---[[:space:]]*$/ { exit }
  ' "$file"
}

agent_memory_path() {
  echo "${AGENT_MEMORY_DIR}/$1.md"
}

# Ids of every agent the registry marks memory:true.
# Role of an agent, from the registry. This is the routing key: it is populated for
# every agent and stable, unlike `specializations` which nothing writes (#37).
agent_role() {
  [[ -f "$REGISTRY" ]] || return 0
  if $HAS_JQ; then
    jq -r --arg id "$1" '.agents[] | select(.id == $id) | .role' "$REGISTRY" 2> /dev/null
  else
    awk -v want="$1" '
      /"id"[[:space:]]*:/ {
        line = $0
        sub(/.*"id"[[:space:]]*:[[:space:]]*"/, "", line)
        sub(/".*/, "", line)
        current = line
      }
      current == want && /"role"[[:space:]]*:/ {
        line = $0
        sub(/.*"role"[[:space:]]*:[[:space:]]*"/, "", line)
        sub(/".*/, "", line)
        print line
        exit
      }
    ' "$REGISTRY"
  fi
}

registry_agent_ids() {
  [[ -f "$REGISTRY" ]] || return 0
  if $HAS_JQ; then
    jq -r '.agents[] | select(.memory == true) | .id' "$REGISTRY"
  else
    # Pair each id with the memory flag that follows it on the same object line-run.
    awk '
      /"id"[[:space:]]*:/ {
        line = $0
        sub(/.*"id"[[:space:]]*:[[:space:]]*"/, "", line)
        sub(/".*/, "", line)
        current = line
      }
      /"memory"[[:space:]]*:[[:space:]]*true/ { if (current != "") { print current; current = "" } }
    ' "$REGISTRY"
  fi
}

require_scaffold() {
  if [[ ! -d "$AGENTS_DIR" ]]; then
    echo "Error: .agents/ not found at ${AGENTS_DIR}" >&2
    echo "Run: agent-memory.sh --init" >&2
    exit 1
  fi
}

file_size_bytes() {
  # wc -c is portable; awk strips the leading whitespace BSD wc emits.
  wc -c < "$1" | awk '{print $1}'
}

# Bytes an agent actually receives at spawn: global memory plus its own file.
#
# The budget exists to bound CONTEXT, and injection delivers both files
# (inject-agent-memory.sh). Measuring the agent file alone understated the real
# payload by the whole size of global.md — 55% of it in this repository — so a
# file could sit comfortably "under budget" while the agent received far more.
effective_payload_bytes() {
  local agent_file="$1" total=0
  if [[ -f "${MEMORY_DIR}/global.md" ]]; then
    total=$(($(file_size_bytes "${MEMORY_DIR}/global.md")))
  fi
  if [[ -f "$agent_file" ]]; then
    total=$((total + $(file_size_bytes "$agent_file")))
  fi
  echo "$total"
}

# --- Operation: init -------------------------------------------------------
if [[ "$OPERATION" == "init" ]]; then
  mkdir -p "$AGENT_MEMORY_DIR" "$RETRO_DIR"

  if [[ ! -f "$REGISTRY" ]]; then
    cat > "$REGISTRY" << 'EOF'
{
  "version": 1,
  "agents": [
    {
      "id": "impl-worker",
      "plugin": "principled-implementation",
      "role": "worker",
      "memory": true,
      "rationale": "Primary beneficiary — implementation patterns and codebase knowledge"
    },
    {
      "id": "issue-ingester",
      "plugin": "principled-github",
      "role": "triage",
      "memory": true,
      "rationale": "Triage and classification patterns accumulate"
    },
    {
      "id": "pr-reviewer",
      "plugin": "principled-quality",
      "role": "reviewer",
      "memory": true,
      "rationale": "Learns recurring review themes"
    },
    {
      "id": "module-auditor",
      "plugin": "principled-docs",
      "role": "auditor",
      "memory": false,
      "rationale": "Runs a deterministic script; nothing to learn"
    },
    {
      "id": "decision-auditor",
      "plugin": "principled-docs",
      "role": "auditor",
      "memory": false,
      "rationale": "Checks supersession chains deterministically"
    },
    {
      "id": "boundary-checker",
      "plugin": "principled-architecture",
      "role": "auditor",
      "memory": false,
      "rationale": "Scans imports against fixed rules"
    }
  ]
}
EOF
    echo "Created ${REGISTRY}"
  else
    echo "Registry already exists: ${REGISTRY}"
  fi

  if [[ ! -f "${MEMORY_DIR}/global.md" ]]; then
    cat > "${MEMORY_DIR}/global.md" << EOF
---
scope: global
last_updated: ${TODAY}
---

# Global Agent Memory

Knowledge that applies to every agent in this repository. Keep this curated: every
byte here is injected into every agent's context.

## Conventions

<!-- Add repository-wide facts agents should not have to rediscover. -->
EOF
    echo "Created ${MEMORY_DIR}/global.md"
  fi

  # Seed a memory file for each registered agent that carries memory.
  created=0
  for id in $(registry_agent_ids); do
    mem_file="$(agent_memory_path "$id")"
    if [[ ! -f "$mem_file" ]]; then
      cat > "$mem_file" << EOF
---
agent_id: "${id}"
role: worker
last_updated: ${TODAY}
session_count: 0
total_tasks: 0
success_rate: 0.0
specializations: []
---

# ${id} — Accumulated Knowledge

## Known Patterns

<!-- Durable facts about this codebase that this agent should not relearn. -->

## Pitfalls

<!-- Mistakes made before, and what to do instead. -->
EOF
      created=$((created + 1))
    fi
  done
  echo "Seeded ${created} agent memory file(s) in ${AGENT_MEMORY_DIR}"
  echo "Initialized .agents/ at ${AGENTS_DIR}"
  exit 0
fi

# --- Operation: path -------------------------------------------------------
if [[ "$OPERATION" == "path" ]]; then
  [[ -n "$AGENT_ID" ]] || {
    echo "Error: --path requires --agent" >&2
    exit 1
  }
  agent_memory_path "$AGENT_ID"
  exit 0
fi

# --- Operation: show -------------------------------------------------------
if [[ "$OPERATION" == "show" ]]; then
  require_scaffold
  [[ -n "$AGENT_ID" ]] || {
    echo "Error: --show requires --agent" >&2
    exit 1
  }
  mem_file="$(agent_memory_path "$AGENT_ID")"
  if [[ ! -f "$mem_file" ]]; then
    echo "Error: no memory file for agent '${AGENT_ID}' at ${mem_file}" >&2
    exit 1
  fi
  case "$SHOW_MODE" in
  body) fm_body "$mem_file" ;;
  frontmatter) fm_header "$mem_file" ;;
  *) cat "$mem_file" ;;
  esac
  exit 0
fi

# --- Operation: list -------------------------------------------------------
if [[ "$OPERATION" == "list" ]]; then
  require_scaffold
  case "$FORMAT" in
  table | json) ;;
  *)
    echo "Error: unknown format '${FORMAT}' (expected table or json)" >&2
    exit 1
    ;;
  esac

  if [[ "$FORMAT" == "json" ]]; then
    printf '{\n  "agents": [\n'
    first=true
    for id in $(registry_agent_ids); do
      mem_file="$(agent_memory_path "$id")"
      if [[ -f "$mem_file" ]]; then
        size="$(file_size_bytes "$mem_file")"
        sessions="$(fm_get "$mem_file" session_count)"
        tasks="$(fm_get "$mem_file" total_tasks)"
        rate="$(fm_get "$mem_file" success_rate)"
        updated="$(fm_get "$mem_file" last_updated)"
      else
        size=0
        sessions=0
        tasks=0
        rate=0.0
        updated=""
      fi
      $first || printf ',\n'
      first=false
      printf '    {"id": "%s", "bytes": %s, "session_count": %s, "total_tasks": %s, "success_rate": %s, "last_updated": "%s"}' \
        "$id" "${size:-0}" "${sessions:-0}" "${tasks:-0}" "${rate:-0.0}" "${updated:-}"
    done
    printf '\n  ]\n}\n'
  else
    printf '%-18s %-10s %8s %9s %7s %9s  %s\n' "AGENT" "ROLE" "BYTES" "SESSIONS" "TASKS" "SUCCESS" "UPDATED"
    for id in $(registry_agent_ids); do
      mem_file="$(agent_memory_path "$id")"
      if [[ -f "$mem_file" ]]; then
        printf '%-18s %-10s %8s %9s %7s %9s  %s\n' \
          "$id" \
          "$(agent_role "$id")" \
          "$(file_size_bytes "$mem_file")" \
          "$(fm_get "$mem_file" session_count)" \
          "$(fm_get "$mem_file" total_tasks)" \
          "$(fm_get "$mem_file" success_rate)" \
          "$(fm_get "$mem_file" last_updated)"
      else
        printf '%-18s %-10s %8s %9s %7s %9s  %s\n' "$id" "$(agent_role "$id")" "-" "-" "-" "-" "(no memory file)"
      fi
    done
  fi
  exit 0
fi

# --- Rewrite frontmatter metrics, preserving the body ----------------------
# Only the metric fields are script-owned (ADR-020); everything else in the
# frontmatter is passed through untouched.
write_metrics() {
  local file="$1" sessions="$2" tasks="$3" rate="$4"
  local tmp
  tmp="$(mktemp)"

  awk -v sessions="$sessions" -v tasks="$tasks" -v rate="$rate" -v today="$TODAY" '
    NR == 1 && /^---[[:space:]]*$/ { print; infm = 1; next }
    infm && /^---[[:space:]]*$/ {
      infm = 0
      if (!seen_sessions) print "session_count: " sessions
      if (!seen_tasks) print "total_tasks: " tasks
      if (!seen_rate) print "success_rate: " rate
      if (!seen_updated) print "last_updated: " today
      print
      next
    }
    infm {
      if ($0 ~ /^session_count:/) { print "session_count: " sessions; seen_sessions = 1; next }
      if ($0 ~ /^total_tasks:/)   { print "total_tasks: " tasks;      seen_tasks = 1; next }
      if ($0 ~ /^success_rate:/)  { print "success_rate: " rate;      seen_rate = 1; next }
      if ($0 ~ /^last_updated:/)  { print "last_updated: " today;     seen_updated = 1; next }
      print
      next
    }
    { print }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
}

# --- Operation: update-metrics ---------------------------------------------
if [[ "$OPERATION" == "update-metrics" ]]; then
  require_scaffold
  [[ -n "$AGENT_ID" ]] || {
    echo "Error: --update-metrics requires --agent" >&2
    exit 1
  }
  mem_file="$(agent_memory_path "$AGENT_ID")"
  if [[ ! -f "$mem_file" ]]; then
    echo "Error: no memory file for agent '${AGENT_ID}'" >&2
    exit 1
  fi

  for value in "$ADD_TASKS" "$ADD_SUCCEEDED"; do
    if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then
      echo "Error: --tasks and --succeeded require non-negative integers (got '${value}')" >&2
      exit 1
    fi
  done

  cur_sessions="$(fm_get "$mem_file" session_count)"
  cur_sessions="${cur_sessions:-0}"
  cur_tasks="$(fm_get "$mem_file" total_tasks)"
  cur_tasks="${cur_tasks:-0}"
  cur_rate="$(fm_get "$mem_file" success_rate)"
  cur_rate="${cur_rate:-0.0}"

  new_sessions="$cur_sessions"
  $ADD_SESSION && new_sessions=$((cur_sessions + 1))

  added_tasks="${ADD_TASKS:-0}"
  added_ok="${ADD_SUCCEEDED:-0}"
  if [[ "$added_ok" -gt "$added_tasks" ]]; then
    echo "Error: --succeeded (${added_ok}) cannot exceed --tasks (${added_tasks})" >&2
    exit 1
  fi

  new_tasks=$((cur_tasks + added_tasks))

  # Recompute the rate from prior successes plus new ones. Integer bash cannot
  # do this, so awk carries the float.
  new_rate="$(awk -v ct="$cur_tasks" -v cr="$cur_rate" -v at="$added_tasks" -v ao="$added_ok" '
    BEGIN {
      prior_ok = ct * cr
      total = ct + at
      if (total <= 0) { printf "0.0"; exit }
      printf "%.2f", (prior_ok + ao) / total
    }')"

  write_metrics "$mem_file" "$new_sessions" "$new_tasks" "$new_rate"
  echo "Updated ${AGENT_ID}: sessions=${new_sessions} tasks=${new_tasks} success_rate=${new_rate}"
  exit 0
fi

# --- Operation: reset-metrics ----------------------------------------------
# Fork support (RFC-011): knowledge transfers, performance history does not.
if [[ "$OPERATION" == "reset-metrics" ]]; then
  require_scaffold
  if [[ -n "$AGENT_ID" ]]; then
    targets="$AGENT_ID"
  else
    targets="$(registry_agent_ids)"
  fi

  reset_count=0
  for id in $targets; do
    mem_file="$(agent_memory_path "$id")"
    [[ -f "$mem_file" ]] || continue
    write_metrics "$mem_file" 0 0 "0.0"
    reset_count=$((reset_count + 1))
  done
  echo "Reset metrics for ${reset_count} agent(s). Knowledge bodies left intact."
  exit 0
fi

# --- Operation: check ------------------------------------------------------
# Validates structure and reports against the size budget. Reports problems on
# stdout and exits 1 only on genuine structural errors, never on size.
if [[ "$OPERATION" == "check" ]]; then
  require_scaffold
  if [[ -n "$AGENT_ID" ]]; then
    targets="$AGENT_ID"
  else
    targets="$(registry_agent_ids)"
  fi

  errors=0

  # Global memory is checked first and unconditionally. It is injected into every
  # memory-bearing agent, which makes it the highest-blast-radius file in the
  # system — and it was previously never validated at all, because this loop
  # iterates the registry and global.md has no registry entry.
  global_file="${MEMORY_DIR}/global.md"
  if [[ ! -f "$global_file" ]]; then
    echo "ERROR: global: no file at ${global_file}"
    errors=$((errors + 1))
  elif [[ "$(head -1 "$global_file")" != "---" ]]; then
    echo "ERROR: global: missing YAML frontmatter"
    errors=$((errors + 1))
  else
    global_size="$(file_size_bytes "$global_file")"
    if [[ "$global_size" -gt "$SOFT_LIMIT_BYTES" ]]; then
      echo "WARN: global: ${global_size} bytes, over the ${SOFT_LIMIT_BYTES} byte soft budget."
      echo "      This file is injected into EVERY memory-bearing agent, so a byte here"
      echo "      costs a byte in every agent's context. Synthesize it down."
    else
      echo "OK: global: ${global_size} bytes (injected into every agent)"
    fi
  fi

  for id in $targets; do
    mem_file="$(agent_memory_path "$id")"
    if [[ ! -f "$mem_file" ]]; then
      echo "ERROR: ${id}: registry says memory=true but no file at ${mem_file}"
      errors=$((errors + 1))
      continue
    fi

    if [[ "$(head -1 "$mem_file")" != "---" ]]; then
      echo "ERROR: ${id}: missing YAML frontmatter"
      errors=$((errors + 1))
      continue
    fi

    declared="$(fm_get "$mem_file" agent_id)"
    if [[ "$declared" != "$id" ]]; then
      echo "ERROR: ${id}: frontmatter agent_id is '${declared}', expected '${id}'"
      errors=$((errors + 1))
    fi

    # Budget the payload the agent actually receives — global plus its own file —
    # not the agent file alone. The budget bounds context, and injection delivers
    # both.
    size="$(file_size_bytes "$mem_file")"
    payload="$(effective_payload_bytes "$mem_file")"
    if [[ "$payload" -gt "$HARD_LIMIT_BYTES" ]]; then
      echo "WARN: ${id}: ${payload} bytes injected (${size} own + global), over the ${HARD_LIMIT_BYTES} byte budget."
      echo "      Every byte is injected at spawn. Synthesize it down; do not truncate."
    elif [[ "$payload" -gt "$SOFT_LIMIT_BYTES" ]]; then
      echo "WARN: ${id}: ${payload} bytes injected (${size} own + global), over the ${SOFT_LIMIT_BYTES} byte soft budget."
      echo "      Consider synthesizing accumulated notes into fewer, denser statements."
    else
      echo "OK: ${id}: ${payload} bytes injected (${size} own + global)"
    fi
  done

  if [[ "$errors" -gt 0 ]]; then
    echo "${errors} structural error(s) found." >&2
    exit 1
  fi
  exit 0
fi

echo "Error: no operation specified" >&2
usage >&2
exit 1
