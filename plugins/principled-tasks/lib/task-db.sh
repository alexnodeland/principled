#!/usr/bin/env bash
# task-db.sh — task graph interface for the principled-tasks plugin
#
# SINGLE COPY. Referenced by every skill via ${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh
# (see ADR-018). There are no duplicate copies to keep in sync.
#
# Storage model (ADR-017):
#   .principled/tasks.jsonl  — append-only event log. Source of truth. Committed to Git.
#   .impl/tasks.db           — SQLite cache derived from the log. Gitignored. Disposable.
#
# Every mutation appends one event to the log, then applies it to the cache. State is
# the deterministic fold of the log, so the cache can be rebuilt at any time with
# --sync and any two clones that have the same log agree on the same state.
#
# Operations:
#   --init                    Create the event log and cache
#   --sync                    Rebuild the cache from the event log
#   --open                    Append an "open" event for a new task
#   --update                  Append an "update" event (status/notes/agent)
#   --close                   Append a "close" event (done or abandoned)
#   --add-edge                Append an "edge" event between two tasks
#   --get                     Retrieve a single task by ID
#   --list                    List tasks with optional filters
#   --graph                   Output the task graph (table or DOT)
#   --audit                   Run audit queries
#   --commit                  Git add and commit the event log
#
# Dependencies: sqlite3 (3.38+, for JSON functions), git, bash 3.2+ (stock macOS bash)
# jq is NOT required: JSON is built with sqlite3's json_object() and read with
# json_extract(), so encoding and escaping are handled by sqlite3 itself.

set -euo pipefail

LOG_PATH=".principled/tasks.jsonl"
DB_PATH=".impl/tasks.db"

# ASCII unit separator. JSON text never contains a raw control character, so this is
# always safe as an .import column delimiter (a literal "|" is not — it appears in
# task titles and silently splits the line into two columns).
readonly IMPORT_SEP='\x1f'

VALID_STATUSES="open in_progress done blocked abandoned"
VALID_EDGE_KINDS="blocks spawned_by part_of related_to"

# --- Helpers ---

die() {
  echo "ERROR: $*" >&2
  exit 1
}

check_sqlite() {
  command -v sqlite3 &> /dev/null || die "sqlite3 is required but not found. Install the SQLite CLI."
  local ver
  ver=$(sqlite3 --version | cut -d' ' -f1)
  local major minor
  major=${ver%%.*}
  minor=$(echo "$ver" | cut -d. -f2)
  if [[ "$major" -lt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -lt 38 ]]; }; then
    die "sqlite3 ${ver} is too old; 3.38+ is required for JSON support."
  fi
}

# Escape a value for interpolation inside a single-quoted SQL literal.
#
# The quote character is held in a variable rather than written as \' inline: bash 3.2
# (the only bash macOS ships) expands "${var//\'/\'\'}" to backslash-quote pairs rather
# than doubled quotes, which produces malformed SQL. Substituting through $q behaves
# identically on 3.2 and 5.x.
sql_escape() {
  local q="'"
  printf '%s' "${1//$q/$q$q}"
}

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Build one JSON object from alternating key/value arguments. Delegates all escaping
# to sqlite3's json_object(), so titles containing quotes, backslashes, pipes or
# newlines round-trip correctly.
json_event() {
  local args=() k v
  while [[ $# -gt 0 ]]; do
    k="$1"
    v="$2"
    shift 2
    args+=("'$(sql_escape "$k")'" "'$(sql_escape "$v")'")
  done
  local joined
  joined=$(
    IFS=,
    echo "${args[*]}"
  )
  sqlite3 :memory: "SELECT json_object(${joined});"
}

append_event() {
  mkdir -p "$(dirname "$LOG_PATH")"
  json_event "$@" >> "$LOG_PATH"
  # Callers apply the same change to the cache directly, so record that the cache has
  # consumed this event. A full re-fold after every write would make writing N tasks
  # O(N^2); the recorded count is what lets check_db tell "we just wrote this" apart
  # from "someone else appended events behind our back".
  if [[ -f "$DB_PATH" ]]; then
    set_cached_line_count "$(log_line_count)"
  fi
  return 0
}

# Generate a collision-resistant task ID. Hashes title, timestamp, PID and $RANDOM,
# then checks the existing log. A bare 4-hex-digit $RANDOM has only 65536 values and
# collides at ~300 tasks by the birthday bound, which is well within range for a
# plugin whose stated purpose is coordinating parallel agents.
generate_id() {
  local title="$1" attempt=0 candidate hash
  while [[ $attempt -lt 10 ]]; do
    hash=$(printf '%s|%s|%s|%s|%s' "$title" "$(timestamp)" "$$" "$RANDOM" "$attempt" |
      shasum -a 256 | cut -c1-8)
    candidate="task-${hash}"
    if [[ ! -f "$LOG_PATH" ]] || ! grep -q "\"id\":\"${candidate}\"" "$LOG_PATH" 2> /dev/null; then
      echo "$candidate"
      return 0
    fi
    attempt=$((attempt + 1))
  done
  die "Could not generate a unique task ID after 10 attempts"
}

validate_status() {
  local s="$1"
  for valid in $VALID_STATUSES; do
    [[ "$s" == "$valid" ]] && return 0
  done
  die "Invalid status '$s'. Must be one of: ${VALID_STATUSES// /, }"
}

validate_edge_kind() {
  local k="$1"
  for valid in $VALID_EDGE_KINDS; do
    [[ "$k" == "$valid" ]] && return 0
  done
  die "Invalid edge kind '$k'. Must be one of: ${VALID_EDGE_KINDS// /, }"
}

create_schema() {
  sqlite3 "$DB_PATH" << 'SQL'
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('open','in_progress','done','blocked','abandoned')),
  agent TEXT,
  plan TEXT,
  task_id TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  closed_at TEXT,
  discovered_from TEXT
);

CREATE TABLE IF NOT EXISTS task_edges (
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('blocks','spawned_by','part_of','related_to')),
  PRIMARY KEY (from_id, to_id, kind)
);

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_plan ON tasks(plan);
SQL
}

log_line_count() {
  if [[ -f "$LOG_PATH" ]]; then
    # Trim whitespace: wc pads its output on macOS.
    wc -l < "$LOG_PATH" | tr -d '[:space:]'
  else
    echo 0
  fi
}

cached_line_count() {
  sqlite3 "$DB_PATH" "SELECT value FROM meta WHERE key = 'log_lines';" 2> /dev/null || echo ""
}

set_cached_line_count() {
  sqlite3 "$DB_PATH" "INSERT INTO meta (key, value) VALUES ('log_lines', '$1')
    ON CONFLICT(key) DO UPDATE SET value = excluded.value;"
}

# Rebuild the cache by folding the event log in order. Idempotent: running it twice
# yields the same state, and deleting the cache loses nothing.
rebuild_cache() {
  check_sqlite
  mkdir -p "$(dirname "$DB_PATH")"
  rm -f "$DB_PATH"
  create_schema

  if [[ ! -f "$LOG_PATH" ]]; then
    set_cached_line_count 0
    return 0
  fi

  sqlite3 "$DB_PATH" << SQL
CREATE TEMP TABLE raw(line TEXT);
.separator "${IMPORT_SEP}" "\n"
.import ${LOG_PATH} raw

INSERT OR REPLACE INTO tasks (id, title, status, agent, plan, task_id, notes, created_at, discovered_from)
SELECT
  json_extract(line, '\$.id'),
  json_extract(line, '\$.title'),
  'open',
  NULLIF(json_extract(line, '\$.agent'), ''),
  NULLIF(json_extract(line, '\$.plan'), ''),
  NULLIF(json_extract(line, '\$.task_id'), ''),
  NULL,
  json_extract(line, '\$.ts'),
  NULLIF(json_extract(line, '\$.discovered_from'), '')
FROM raw WHERE json_extract(line, '\$.op') = 'open';

UPDATE tasks SET
  status = COALESCE((SELECT NULLIF(json_extract(line, '\$.status'), '') FROM raw
    WHERE json_extract(line, '\$.op') IN ('update','close')
      AND json_extract(line, '\$.id') = tasks.id
    ORDER BY rowid DESC LIMIT 1), status),
  notes = COALESCE((SELECT NULLIF(json_extract(line, '\$.notes'), '') FROM raw
    WHERE json_extract(line, '\$.op') IN ('update','close')
      AND json_extract(line, '\$.id') = tasks.id
      AND NULLIF(json_extract(line, '\$.notes'), '') IS NOT NULL
    ORDER BY rowid DESC LIMIT 1), notes),
  agent = COALESCE((SELECT NULLIF(json_extract(line, '\$.agent'), '') FROM raw
    WHERE json_extract(line, '\$.op') = 'update'
      AND json_extract(line, '\$.id') = tasks.id
      AND NULLIF(json_extract(line, '\$.agent'), '') IS NOT NULL
    ORDER BY rowid DESC LIMIT 1), agent),
  updated_at = (SELECT json_extract(line, '\$.ts') FROM raw
    WHERE json_extract(line, '\$.op') IN ('update','close')
      AND json_extract(line, '\$.id') = tasks.id
    ORDER BY rowid DESC LIMIT 1),
  closed_at = (SELECT json_extract(line, '\$.ts') FROM raw
    WHERE json_extract(line, '\$.op') = 'close'
      AND json_extract(line, '\$.id') = tasks.id
    ORDER BY rowid DESC LIMIT 1);

INSERT OR IGNORE INTO task_edges (from_id, to_id, kind)
SELECT
  json_extract(line, '\$.from_id'),
  json_extract(line, '\$.to_id'),
  json_extract(line, '\$.kind')
FROM raw WHERE json_extract(line, '\$.op') = 'edge';

DROP TABLE raw;
SQL

  set_cached_line_count "$(log_line_count)"
}

# Ensure the cache exists and reflects the log. Rebuilds when the cache is missing or
# when the log has events the cache has not folded, so a fresh clone, a pulled branch,
# or a merge from another agent just works.
#
# The check compares recorded event counts rather than file mtimes: mtime has
# one-second granularity on many filesystems, so a write and a subsequent external
# append within the same second are indistinguishable.
check_db() {
  check_sqlite
  mkdir -p "$(dirname "$DB_PATH")"

  if [[ ! -f "$DB_PATH" ]]; then
    rebuild_cache
    return 0
  fi

  local actual cached
  actual=$(log_line_count)
  cached=$(cached_line_count)

  if [[ "$cached" != "$actual" ]]; then
    rebuild_cache
  fi
}

# Join WHERE clauses with " AND ". Clauses are passed as positional arguments rather
# than by nameref, because `local -n` requires bash 4.3 and macOS ships bash 3.2.
#
# The obvious-looking `IFS=" AND "; echo "${arr[*]}"` does NOT work: IFS is a set of
# single characters, not a delimiter string, so array elements get joined by a single
# space and the result is invalid SQL. That produced a hard failure on any two-filter
# query (e.g. --plan X --status open).
join_where() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  local out="$1"
  shift
  local clause
  for clause in "$@"; do
    out="${out} AND ${clause}"
  done
  printf 'WHERE %s' "$out"
}

# --- Operations ---

# Register a union merge driver for the event log. Without this, two agents that each
# append a task on their own branch produce a merge conflict at the end of the file;
# with it, git keeps both sides' lines, which is exactly the right semantics for an
# append-only log and is what makes parallel agent branches merge cleanly.
ensure_merge_driver() {
  local attributes=".gitattributes"
  local rule="${LOG_PATH} merge=union"

  git rev-parse --is-inside-work-tree &> /dev/null || return 0

  if [[ -f "$attributes" ]] && grep -qF "$rule" "$attributes"; then
    return 0
  fi

  if [[ -f "$attributes" ]] && [[ -n "$(tail -c 1 "$attributes")" ]]; then
    echo "" >> "$attributes"
  fi
  echo "$rule" >> "$attributes"
  echo "Registered union merge driver for $LOG_PATH in $attributes"
}

do_init() {
  check_sqlite
  mkdir -p "$(dirname "$LOG_PATH")" "$(dirname "$DB_PATH")"
  if [[ ! -f "$LOG_PATH" ]]; then
    : > "$LOG_PATH"
    echo "Initialized task event log at $LOG_PATH"
  else
    echo "Event log already exists at $LOG_PATH"
  fi
  ensure_merge_driver
  rebuild_cache
  echo "Built task cache at $DB_PATH"
}

do_sync() {
  rebuild_cache
  local count
  count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks;")
  echo "Rebuilt $DB_PATH from $LOG_PATH (${count} tasks)"
}

do_open() {
  local title="" plan="" blocks="" discovered_from="" agent="" task_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --title)
      title="$2"
      shift 2
      ;;
    --plan)
      plan="$2"
      shift 2
      ;;
    --blocks)
      blocks="$2"
      shift 2
      ;;
    --discovered-from)
      discovered_from="$2"
      shift 2
      ;;
    --agent)
      agent="$2"
      shift 2
      ;;
    --task-id)
      task_id="$2"
      shift 2
      ;;
    *) die "Unknown option for --open: $1" ;;
    esac
  done

  [[ -n "$title" ]] || die "--title is required for --open"

  check_db

  local id ts
  id=$(generate_id "$title")
  ts=$(timestamp)

  append_event op open id "$id" title "$title" ts "$ts" \
    plan "$plan" agent "$agent" task_id "$task_id" discovered_from "$discovered_from"

  sqlite3 "$DB_PATH" "INSERT INTO tasks
    (id, title, status, agent, plan, task_id, notes, created_at, discovered_from)
    VALUES ('$(sql_escape "$id")', '$(sql_escape "$title")', 'open',
      $(sql_nullable "$agent"), $(sql_nullable "$plan"), $(sql_nullable "$task_id"),
      NULL, '${ts}', $(sql_nullable "$discovered_from"));"

  if [[ -n "$blocks" ]]; then
    local block_ids bid
    IFS=',' read -ra block_ids <<< "$blocks"
    for bid in "${block_ids[@]}"; do
      bid=$(echo "$bid" | xargs)
      if [[ -n "$bid" ]]; then
        append_event op edge from_id "$id" to_id "$bid" kind blocks ts "$ts"
        insert_edge "$id" "$bid" blocks
      fi
    done
  fi

  if [[ -n "$discovered_from" ]]; then
    append_event op edge from_id "$id" to_id "$discovered_from" kind spawned_by ts "$ts"
    insert_edge "$id" "$discovered_from" spawned_by
  fi

  echo "$id"
}

# Render a value as a quoted SQL literal, or NULL when empty.
sql_nullable() {
  if [[ -z "$1" ]]; then
    printf 'NULL'
  else
    printf "'%s'" "$(sql_escape "$1")"
  fi
}

insert_edge() {
  sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO task_edges (from_id, to_id, kind)
    VALUES ('$(sql_escape "$1")', '$(sql_escape "$2")', '$(sql_escape "$3")');"
}

do_update() {
  local id="" status="" notes="" agent=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --id)
      id="$2"
      shift 2
      ;;
    --status)
      status="$2"
      shift 2
      ;;
    --notes)
      notes="$2"
      shift 2
      ;;
    --agent)
      agent="$2"
      shift 2
      ;;
    *) die "Unknown option for --update: $1" ;;
    esac
  done

  [[ -n "$id" ]] || die "--id is required for --update"
  [[ -n "$status" || -n "$notes" || -n "$agent" ]] ||
    die "--update requires at least one of --status, --notes, --agent"
  [[ -n "$status" ]] && validate_status "$status"

  check_db
  assert_task_exists "$id"

  local ts
  ts=$(timestamp)
  append_event op update id "$id" status "$status" notes "$notes" agent "$agent" ts "$ts"

  local sets
  sets="updated_at = '${ts}'"
  [[ -n "$status" ]] && sets="${sets}, status = '$(sql_escape "$status")'"
  [[ -n "$notes" ]] && sets="${sets}, notes = '$(sql_escape "$notes")'"
  [[ -n "$agent" ]] && sets="${sets}, agent = '$(sql_escape "$agent")'"
  sqlite3 "$DB_PATH" "UPDATE tasks SET ${sets} WHERE id = '$(sql_escape "$id")';"

  echo "Updated ${id}${status:+ to ${status}}"
}

do_close() {
  local id="" notes="" status="done"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --id)
      id="$2"
      shift 2
      ;;
    --notes)
      notes="$2"
      shift 2
      ;;
    --status)
      status="$2"
      shift 2
      ;;
    *) die "Unknown option for --close: $1" ;;
    esac
  done

  [[ -n "$id" ]] || die "--id is required for --close"
  [[ "$status" == "done" || "$status" == "abandoned" ]] ||
    die "--status must be 'done' or 'abandoned' for --close"

  check_db
  assert_task_exists "$id"

  local ts
  ts=$(timestamp)
  append_event op close id "$id" status "$status" notes "$notes" ts "$ts"

  local sets
  sets="status = '$(sql_escape "$status")', closed_at = '${ts}', updated_at = '${ts}'"
  [[ -n "$notes" ]] && sets="${sets}, notes = '$(sql_escape "$notes")'"
  sqlite3 "$DB_PATH" "UPDATE tasks SET ${sets} WHERE id = '$(sql_escape "$id")';"

  echo "Closed ${id} as ${status}"
}

assert_task_exists() {
  local id esc found
  id="$1"
  esc=$(sql_escape "$id")
  found=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE id = '${esc}';")
  [[ "$found" -gt 0 ]] || die "No task found with id '${id}'"
}

do_add_edge() {
  local from_id="" to_id="" kind=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --from)
      from_id="$2"
      shift 2
      ;;
    --to)
      to_id="$2"
      shift 2
      ;;
    --kind)
      kind="$2"
      shift 2
      ;;
    *) die "Unknown option for --add-edge: $1" ;;
    esac
  done

  [[ -n "$from_id" ]] || die "--from is required for --add-edge"
  [[ -n "$to_id" ]] || die "--to is required for --add-edge"
  [[ -n "$kind" ]] || die "--kind is required for --add-edge"
  validate_edge_kind "$kind"

  check_db
  assert_task_exists "$from_id"
  assert_task_exists "$to_id"

  append_event op edge from_id "$from_id" to_id "$to_id" kind "$kind" ts "$(timestamp)"
  insert_edge "$from_id" "$to_id" "$kind"
  echo "Edge: ${from_id} --[${kind}]--> ${to_id}"
}

do_get() {
  local id="" format="table"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --id)
      id="$2"
      shift 2
      ;;
    --format)
      format="$2"
      shift 2
      ;;
    *) die "Unknown option for --get: $1" ;;
    esac
  done

  [[ -n "$id" ]] || die "--id is required for --get"

  check_db
  local esc
  esc=$(sql_escape "$id")
  assert_task_exists "$id"

  if [[ "$format" == "json" ]]; then
    sqlite3 "$DB_PATH" "SELECT json_object(
      'id', id, 'title', title, 'status', status, 'agent', agent, 'plan', plan,
      'task_id', task_id, 'notes', notes, 'created_at', created_at,
      'updated_at', updated_at, 'closed_at', closed_at,
      'discovered_from', discovered_from,
      'edges', (SELECT json_group_array(json_object('from', from_id, 'to', to_id, 'kind', kind))
                FROM task_edges WHERE from_id = tasks.id OR to_id = tasks.id)
    ) FROM tasks WHERE id = '${esc}';"
    return 0
  fi

  sqlite3 -header -column "$DB_PATH" "SELECT * FROM tasks WHERE id = '${esc}';"

  local edges
  edges=$(sqlite3 -header -column "$DB_PATH" "SELECT * FROM task_edges WHERE from_id = '${esc}' OR to_id = '${esc}';")
  if [[ -n "$edges" ]]; then
    echo ""
    echo "Edges:"
    echo "$edges"
  fi
}

do_list() {
  local format="table"
  local where_clauses=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --plan)
      where_clauses+=("plan = '$(sql_escape "$2")'")
      shift 2
      ;;
    --status)
      validate_status "$2"
      where_clauses+=("status = '$(sql_escape "$2")'")
      shift 2
      ;;
    --agent)
      where_clauses+=("agent = '$(sql_escape "$2")'")
      shift 2
      ;;
    --format)
      format="$2"
      shift 2
      ;;
    *) die "Unknown option for --list: $1" ;;
    esac
  done

  check_db

  local where=""
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    where=$(join_where "${where_clauses[@]}")
  fi

  case "$format" in
  json)
    sqlite3 "$DB_PATH" "SELECT json_group_array(json_object(
        'id', id, 'title', title, 'status', status, 'plan', plan,
        'agent', agent, 'created_at', created_at))
      FROM (SELECT * FROM tasks ${where} ORDER BY created_at DESC);"
    ;;
  table)
    sqlite3 -header -column "$DB_PATH" \
      "SELECT id, title, status, plan, agent, created_at FROM tasks ${where} ORDER BY created_at DESC;"
    ;;
  *) die "Unknown --format '${format}'. Must be 'table' or 'json'." ;;
  esac
}

do_graph() {
  local open_only="false" dot="false"
  local where_clauses=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --plan)
      where_clauses+=("plan = '$(sql_escape "$2")'")
      shift 2
      ;;
    --status)
      validate_status "$2"
      where_clauses+=("status = '$(sql_escape "$2")'")
      shift 2
      ;;
    --open)
      open_only="true"
      shift
      ;;
    --dot)
      dot="true"
      shift
      ;;
    --format)
      [[ "$2" == "dot" ]] && dot="true"
      shift 2
      ;;
    *) die "Unknown option for --graph: $1" ;;
    esac
  done

  check_db

  if [[ "$open_only" == "true" ]]; then
    where_clauses+=("status IN ('open','in_progress','blocked')")
  fi

  local where="" edge_where=""
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    where=$(join_where "${where_clauses[@]}")
  fi
  if [[ -n "$where" ]]; then
    edge_where="WHERE from_id IN (SELECT id FROM tasks ${where}) OR to_id IN (SELECT id FROM tasks ${where})"
  fi

  if [[ "$dot" == "true" ]]; then
    echo "digraph tasks {"
    echo "  rankdir=LR;"
    echo "  node [shape=box, style=rounded];"
    echo ""

    local id title status color
    while IFS='|' read -r id title status; do
      [[ -z "$id" ]] && continue
      case "$status" in
      open) color="lightyellow" ;;
      in_progress) color="lightblue" ;;
      done) color="lightgreen" ;;
      blocked) color="lightsalmon" ;;
      abandoned) color="lightgray" ;;
      *) color="white" ;;
      esac
      # Escape double quotes in titles so the DOT label stays well-formed.
      title="${title//\"/\\\"}"
      printf '  "%s" [label="%s\\n%s\\n[%s]", fillcolor=%s, style="rounded,filled"];\n' \
        "$id" "$id" "$title" "$status" "$color"
    done < <(sqlite3 "$DB_PATH" "SELECT id, title, status FROM tasks ${where};")

    echo ""

    local from_id to_id kind style
    while IFS='|' read -r from_id to_id kind; do
      [[ -z "$from_id" ]] && continue
      case "$kind" in
      blocks) style="bold" ;;
      spawned_by) style="dashed" ;;
      part_of) style="dotted" ;;
      *) style="solid" ;;
      esac
      printf '  "%s" -> "%s" [label="%s", style=%s];\n' "$from_id" "$to_id" "$kind" "$style"
    done < <(sqlite3 "$DB_PATH" "SELECT from_id, to_id, kind FROM task_edges ${edge_where};")

    echo "}"
  else
    echo "=== Tasks ==="
    sqlite3 -header -column "$DB_PATH" "SELECT id, title, status, plan, agent FROM tasks ${where} ORDER BY created_at;"
    echo ""
    echo "=== Edges ==="
    sqlite3 -header -column "$DB_PATH" "SELECT from_id, to_id, kind FROM task_edges ${edge_where};"
  fi
}

do_audit() {
  # Two parallel filter lists. The Blocked Chains query joins tasks to itself, so a
  # bare "plan = ..." there is an ambiguous column reference; it needs the alias.
  local filters=() qualified=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --plan)
      filters+=("plan = '$(sql_escape "$2")'")
      qualified+=("t.plan = '$(sql_escape "$2")'")
      shift 2
      ;;
    --agent)
      filters+=("agent = '$(sql_escape "$2")'")
      qualified+=("t.agent = '$(sql_escape "$2")'")
      shift 2
      ;;
    *) die "Unknown option for --audit: $1" ;;
    esac
  done

  check_db

  local f="" fq="" i
  if [[ ${#filters[@]} -gt 0 ]]; then
    for ((i = 0; i < ${#filters[@]}; i++)); do
      f="${f} AND ${filters[i]}"
      fq="${fq} AND ${qualified[i]}"
    done
  fi

  echo "=== Task Audit ==="
  echo ""

  echo "--- Status Summary ---"
  sqlite3 -header -column "$DB_PATH" \
    "SELECT status, COUNT(*) as count FROM tasks WHERE 1=1 ${f} GROUP BY status ORDER BY count DESC;"
  echo ""

  echo "--- Orphan Tasks (no edges) ---"
  local orphans
  orphans=$(sqlite3 -header -column "$DB_PATH" \
    "SELECT id, title, status FROM tasks WHERE id NOT IN (SELECT from_id FROM task_edges UNION SELECT to_id FROM task_edges) ${f};")
  echo "${orphans:-(none)}"
  echo ""

  echo "--- Stale In-Progress (open > 24h) ---"
  local stale
  stale=$(sqlite3 -header -column "$DB_PATH" \
    "SELECT id, title, created_at FROM tasks WHERE status = 'in_progress' AND datetime(created_at) < datetime('now', '-24 hours') ${f};")
  echo "${stale:-(none)}"
  echo ""

  echo "--- Blocked Chains ---"
  local blocked
  blocked=$(sqlite3 -header -column "$DB_PATH" \
    "SELECT t.id as blocked_task, t.title, e.to_id as blocked_by, t2.status as blocker_status
     FROM tasks t
     JOIN task_edges e ON t.id = e.from_id AND e.kind = 'blocks'
     LEFT JOIN tasks t2 ON e.to_id = t2.id
     WHERE t.status = 'blocked' ${fq};")
  echo "${blocked:-(none)}"
  echo ""

  echo "--- Agent Workload ---"
  sqlite3 -header -column "$DB_PATH" \
    "SELECT agent, COUNT(*) as total,
      SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as done,
      SUM(CASE WHEN status IN ('open','in_progress') THEN 1 ELSE 0 END) as active
     FROM tasks WHERE agent IS NOT NULL ${f} GROUP BY agent ORDER BY total DESC;"
  echo ""

  local total done_count pct
  total=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE 1=1 ${f};")
  done_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE status = 'done' ${f};")
  if [[ "$total" -gt 0 ]]; then
    pct=$((done_count * 100 / total))
  else
    pct=0
  fi
  echo "Total tasks: ${total}, Done: ${done_count}, Completion: ${pct}%"
}

do_commit() {
  local message="${1:-tasks: update task graph}"

  if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    die "Not inside a Git repository"
  fi

  [[ -f "$LOG_PATH" ]] || die "No event log at $LOG_PATH. Run --init first."

  # Commit the event log, never the cache. The cache lives under .impl/, which is
  # gitignored; `git add` on an ignored path fails, so committing it never worked.
  git add "$LOG_PATH"

  if git diff --cached --quiet -- "$LOG_PATH" 2> /dev/null; then
    echo "No changes to commit"
    return 0
  fi

  git commit -m "$message"
  echo "Committed $LOG_PATH"
}

usage() {
  cat << 'USAGE'
Usage: task-db.sh <operation> [options]

Operations:
  --init                                Initialize the event log and cache
  --sync                                Rebuild the cache from the event log
  --open --title <t> [--plan <p>] [--agent <a>] [--blocks <ids>] [--discovered-from <id>]
  --update --id <id> [--status <s>] [--notes <n>] [--agent <a>]
  --close --id <id> [--status done|abandoned] [--notes <n>]
  --add-edge --from <id> --to <id> --kind <blocks|spawned_by|part_of|related_to>
  --get --id <id> [--format table|json]
  --list [--plan <p>] [--status <s>] [--agent <a>] [--format table|json]
  --graph [--plan <p>] [--status <s>] [--open] [--dot]
  --audit [--plan <p>] [--agent <a>]
  --commit [message]                    Git commit the event log

Storage:
  .principled/tasks.jsonl   append-only event log (source of truth, committed)
  .impl/tasks.db            SQLite cache (derived, gitignored, rebuild with --sync)
USAGE
}

# --- Main dispatch ---

main() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  local operation="$1"
  shift

  case "$operation" in
  --init) do_init ;;
  --sync) do_sync ;;
  --open) do_open "$@" ;;
  --update) do_update "$@" ;;
  --close) do_close "$@" ;;
  --add-edge) do_add_edge "$@" ;;
  --get) do_get "$@" ;;
  --list) do_list "$@" ;;
  --graph) do_graph "$@" ;;
  --audit) do_audit "$@" ;;
  --commit) do_commit "$@" ;;
  --help | -h) usage ;;
  *)
    usage
    die "Unknown operation: $operation"
    ;;
  esac
}

main "$@"
