#!/usr/bin/env bash
# task-db.sh — SQLite interface for the principled-tasks bead graph
#
# CANONICAL COPY: plugins/principled-tasks/skills/task-open/scripts/
# Copies: task-close, task-graph, task-audit, task-query
#
# Operations:
#   --init                    Create .impl/tasks.db with schema
#   --open                    Insert a new bead
#   --close                   Close a bead (done or abandoned)
#   --add-edge                Add a typed edge between beads
#   --get                     Retrieve a single bead by ID
#   --list                    List beads with optional filters
#   --graph                   Output bead graph (table or DOT)
#   --audit                   Run audit queries
#   --commit                  Git add and commit tasks.db
#
# Dependencies: sqlite3, git, bash 4+
# Optional: jq (for JSON output)

set -euo pipefail

DB_PATH=".impl/tasks.db"

# --- Helpers ---

die() {
  echo "ERROR: $*" >&2
  exit 1
}

check_sqlite() {
  command -v sqlite3 &> /dev/null || die "sqlite3 is required but not found. Install SQLite CLI."
}

check_db() {
  [[ -f "$DB_PATH" ]] || die "Database not found at $DB_PATH. Run with --init first."
}

generate_id() {
  # Generate a short unique ID: bead-XXXX (hex)
  local hex
  hex=$(printf '%04x' "$RANDOM")
  echo "bead-${hex}"
}

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# --- Operations ---

do_init() {
  check_sqlite
  mkdir -p "$(dirname "$DB_PATH")"

  if [[ -f "$DB_PATH" ]]; then
    echo "Database already exists at $DB_PATH"
    return 0
  fi

  sqlite3 "$DB_PATH" << 'SQL'
CREATE TABLE beads (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('open','in_progress','done','blocked','abandoned')),
  agent TEXT,
  plan TEXT,
  task_id TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  closed_at TEXT,
  discovered_from TEXT
);

CREATE TABLE bead_edges (
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('blocks','spawned_by','part_of','related_to')),
  PRIMARY KEY (from_id, to_id, kind)
);
SQL

  echo "Initialized task database at $DB_PATH"
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

  check_sqlite
  check_db

  local id
  id=$(generate_id)
  local ts
  ts=$(timestamp)

  # Escape single quotes for SQL
  local safe_title="${title//\'/\'\'}"
  local safe_notes=""
  local safe_plan="${plan//\'/\'\'}"
  local safe_agent="${agent//\'/\'\'}"
  local safe_task_id="${task_id//\'/\'\'}"
  local safe_discovered="${discovered_from//\'/\'\'}"

  sqlite3 "$DB_PATH" << SQL
INSERT INTO beads (id, title, status, agent, plan, task_id, notes, created_at, closed_at, discovered_from)
VALUES ('${id}', '${safe_title}', 'open', $([ -n "$agent" ] && echo "'${safe_agent}'" || echo "NULL"), $([ -n "$plan" ] && echo "'${safe_plan}'" || echo "NULL"), $([ -n "$task_id" ] && echo "'${safe_task_id}'" || echo "NULL"), NULL, '${ts}', NULL, $([ -n "$discovered_from" ] && echo "'${safe_discovered}'" || echo "NULL"));
SQL

  # Add blocking edge if specified
  if [[ -n "$blocks" ]]; then
    # blocks can be comma-separated
    IFS=',' read -ra block_ids <<< "$blocks"
    for bid in "${block_ids[@]}"; do
      bid=$(echo "$bid" | xargs) # trim whitespace
      sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO bead_edges (from_id, to_id, kind) VALUES ('${id}', '${bid}', 'blocks');"
    done
  fi

  # Add discovered_from edge if specified
  if [[ -n "$discovered_from" ]]; then
    sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO bead_edges (from_id, to_id, kind) VALUES ('${id}', '${discovered_from}', 'spawned_by');"
  fi

  echo "$id"
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
  [[ "$status" == "done" || "$status" == "abandoned" ]] || die "--status must be 'done' or 'abandoned'"

  check_sqlite
  check_db

  local ts
  ts=$(timestamp)
  local safe_notes="${notes//\'/\'\'}"

  sqlite3 "$DB_PATH" << SQL
UPDATE beads
SET status = '${status}',
    closed_at = '${ts}',
    notes = $([ -n "$notes" ] && echo "'${safe_notes}'" || echo "notes")
WHERE id = '${id}';
SQL

  local affected
  affected=$(sqlite3 "$DB_PATH" "SELECT changes();")
  if [[ "$affected" -eq 0 ]]; then
    die "No bead found with id '${id}'"
  fi

  echo "Closed ${id} as ${status}"
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

  check_sqlite
  check_db

  sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO bead_edges (from_id, to_id, kind) VALUES ('${from_id}', '${to_id}', '${kind}');"
  echo "Edge: ${from_id} --[${kind}]--> ${to_id}"
}

do_get() {
  local id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --id)
      id="$2"
      shift 2
      ;;
    *) die "Unknown option for --get: $1" ;;
    esac
  done

  [[ -n "$id" ]] || die "--id is required for --get"

  check_sqlite
  check_db

  sqlite3 -header -column "$DB_PATH" "SELECT * FROM beads WHERE id = '${id}';"

  local edges
  edges=$(sqlite3 -header -column "$DB_PATH" "SELECT * FROM bead_edges WHERE from_id = '${id}' OR to_id = '${id}';")
  if [[ -n "$edges" ]]; then
    echo ""
    echo "Edges:"
    echo "$edges"
  fi
}

do_list() {
  local plan="" status="" agent="" format="table"
  local where_clauses=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --plan)
      where_clauses+=("plan = '${2}'")
      shift 2
      ;;
    --status)
      where_clauses+=("status = '${2}'")
      shift 2
      ;;
    --agent)
      where_clauses+=("agent = '${2}'")
      shift 2
      ;;
    --format)
      # shellcheck disable=SC2034
      format="$2"
      shift 2
      ;;
    *) die "Unknown option for --list: $1" ;;
    esac
  done

  check_sqlite
  check_db

  local where=""
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    where="WHERE $(
      IFS=" AND "
      echo "${where_clauses[*]}"
    )"
  fi

  sqlite3 -header -column "$DB_PATH" "SELECT id, title, status, plan, agent, created_at FROM beads ${where} ORDER BY created_at DESC;"
}

do_graph() {
  local plan="" open_only="false" dot="false"
  local where_clauses=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --plan)
      where_clauses+=("plan = '${2}'")
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
    *) die "Unknown option for --graph: $1" ;;
    esac
  done

  check_sqlite
  check_db

  if [[ "$open_only" == "true" ]]; then
    where_clauses+=("status IN ('open','in_progress','blocked')")
  fi

  local where=""
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    where="WHERE $(
      IFS=" AND "
      echo "${where_clauses[*]}"
    )"
  fi

  if [[ "$dot" == "true" ]]; then
    echo "digraph beads {"
    echo "  rankdir=LR;"
    echo "  node [shape=box, style=rounded];"
    echo ""

    # Nodes
    sqlite3 "$DB_PATH" "SELECT id, title, status FROM beads ${where};" | while IFS='|' read -r id title status; do
      local color="white"
      case "$status" in
      open) color="lightyellow" ;;
      in_progress) color="lightblue" ;;
      done) color="lightgreen" ;;
      blocked) color="lightsalmon" ;;
      abandoned) color="lightgray" ;;
      esac
      printf '  "%s" [label="%s\n%s\n[%s]", fillcolor=%s, style="rounded,filled"];
' "${id}" "${id}" "${title}" "${status}" "${color}"
    done

    echo ""

    # Edges
    local edge_where=""
    if [[ -n "$where" ]]; then
      edge_where="WHERE from_id IN (SELECT id FROM beads ${where}) OR to_id IN (SELECT id FROM beads ${where})"
    fi
    sqlite3 "$DB_PATH" "SELECT from_id, to_id, kind FROM bead_edges ${edge_where};" | while IFS='|' read -r from_id to_id kind; do
      local style="solid"
      case "$kind" in
      blocks) style="bold" ;;
      spawned_by) style="dashed" ;;
      part_of) style="dotted" ;;
      related_to) style="dashed" ;;
      esac
      echo "  \"${from_id}\" -> \"${to_id}\" [label=\"${kind}\", style=${style}];"
    done

    echo "}"
  else
    echo "=== Beads ==="
    sqlite3 -header -column "$DB_PATH" "SELECT id, title, status, plan, agent FROM beads ${where} ORDER BY created_at;"

    echo ""
    echo "=== Edges ==="
    local edge_where=""
    if [[ -n "$where" ]]; then
      edge_where="WHERE from_id IN (SELECT id FROM beads ${where}) OR to_id IN (SELECT id FROM beads ${where})"
    fi
    sqlite3 -header -column "$DB_PATH" "SELECT from_id, to_id, kind FROM bead_edges ${edge_where};"
  fi
}

do_audit() {
  local plan="" agent=""
  local plan_filter="" agent_filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --plan)
      plan="$2"
      plan_filter="AND plan = '${2}'"
      shift 2
      ;;
    --agent)
      agent="$2"
      agent_filter="AND agent = '${2}'"
      shift 2
      ;;
    *) die "Unknown option for --audit: $1" ;;
    esac
  done

  check_sqlite
  check_db

  echo "=== Task Audit ==="
  echo ""

  # Summary counts
  echo "--- Status Summary ---"
  sqlite3 -header -column "$DB_PATH" "SELECT status, COUNT(*) as count FROM beads WHERE 1=1 ${plan_filter} ${agent_filter} GROUP BY status ORDER BY count DESC;"
  echo ""

  # Orphan beads (no edges at all)
  echo "--- Orphan Beads (no edges) ---"
  local orphans
  orphans=$(sqlite3 -header -column "$DB_PATH" "SELECT id, title, status FROM beads WHERE id NOT IN (SELECT from_id FROM bead_edges UNION SELECT to_id FROM bead_edges) ${plan_filter} ${agent_filter};")
  if [[ -n "$orphans" ]]; then
    echo "$orphans"
  else
    echo "(none)"
  fi
  echo ""

  # Stale in_progress (more than 24 hours)
  echo "--- Stale In-Progress (open > 24h) ---"
  local stale
  stale=$(sqlite3 -header -column "$DB_PATH" "SELECT id, title, created_at FROM beads WHERE status = 'in_progress' AND datetime(created_at) < datetime('now', '-24 hours') ${plan_filter} ${agent_filter};")
  if [[ -n "$stale" ]]; then
    echo "$stale"
  else
    echo "(none)"
  fi
  echo ""

  # Blocked chains (blocked beads and what blocks them)
  echo "--- Blocked Chains ---"
  local blocked
  blocked=$(sqlite3 -header -column "$DB_PATH" "SELECT b.id as blocked_bead, b.title, e.to_id as blocked_by, b2.status as blocker_status FROM beads b JOIN bead_edges e ON b.id = e.from_id AND e.kind = 'blocks' LEFT JOIN beads b2 ON e.to_id = b2.id WHERE b.status = 'blocked' ${plan_filter} ${agent_filter};")
  if [[ -n "$blocked" ]]; then
    echo "$blocked"
  else
    echo "(none)"
  fi
  echo ""

  # Agent workload
  echo "--- Agent Workload ---"
  sqlite3 -header -column "$DB_PATH" "SELECT agent, COUNT(*) as total, SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as done, SUM(CASE WHEN status IN ('open','in_progress') THEN 1 ELSE 0 END) as active FROM beads WHERE agent IS NOT NULL ${plan_filter} GROUP BY agent ORDER BY total DESC;"
  echo ""

  # Total counts
  local total
  total=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM beads WHERE 1=1 ${plan_filter} ${agent_filter};")
  local done_count
  done_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM beads WHERE status = 'done' ${plan_filter} ${agent_filter};")
  echo "Total beads: ${total}, Done: ${done_count}, Completion: $((done_count * 100 / (total > 0 ? total : 1)))%"
}

do_commit() {
  local message="${1:-tasks: update task graph}"

  check_db

  if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    die "Not inside a Git repository"
  fi

  git add "$DB_PATH"

  # Only commit if there are staged changes to tasks.db
  if git diff --cached --quiet -- "$DB_PATH" 2> /dev/null; then
    echo "No changes to commit"
    return 0
  fi

  git commit -m "$message"
  echo "Committed $DB_PATH"
}

# --- Main dispatch ---

main() {
  if [[ $# -eq 0 ]]; then
    die "Usage: task-db.sh <operation> [options]
Operations:
  --init                    Initialize the task database
  --open --title <t> [...]  Create a new bead
  --close --id <id> [...]   Close a bead
  --add-edge --from --to --kind  Add an edge
  --get --id <id>           Get a bead
  --list [--plan] [--status] [--agent]  List beads
  --graph [--plan] [--open] [--dot]     Visualize graph
  --audit [--plan] [--agent]            Audit health
  --commit [message]        Git commit tasks.db"
  fi

  local operation="$1"
  shift

  case "$operation" in
  --init) do_init ;;
  --open) do_open "$@" ;;
  --close) do_close "$@" ;;
  --add-edge) do_add_edge "$@" ;;
  --get) do_get "$@" ;;
  --list) do_list "$@" ;;
  --graph) do_graph "$@" ;;
  --audit) do_audit "$@" ;;
  --commit) do_commit "$@" ;;
  *) die "Unknown operation: $operation" ;;
  esac
}

main "$@"
