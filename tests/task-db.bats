#!/usr/bin/env bats
# Tests for plugins/principled-tasks/lib/task-db.sh
#
# Covers the behaviours that were silently broken before ADR-017 was revised:
# multi-filter queries, JSON output, --commit against a gitignored path, ID collision
# resistance, and the claim that the cache is fully derived from the event log.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  LIB="${REPO_ROOT}/plugins/principled-tasks/lib/task-db.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  cd "$WORK" || return 1
  git init -q -b main .
  git config user.email test@example.com
  git config user.name "Test"
  # Keep git from spawning detached helpers in the test repository. With
  # core.fsmonitor enabled globally, every `git init` here starts an
  # `fsmonitor--daemon --detach` that inherits bats' stdout; bats then never sees EOF
  # and hangs after the final test, despite every test having passed. Auto-gc
  # daemonizes the same way.
  git config core.fsmonitor false
  git config gc.auto 0
  printf '.impl/\n' > .gitignore
  git add -A && git commit -qm init
  bash "$LIB" --init > /dev/null
}

task_count() {
  sqlite3 .impl/tasks.db "SELECT COUNT(*) FROM tasks;"
}

# --- Initialization ---

@test "init creates the event log and the derived cache" {
  [ -f .principled/tasks.jsonl ]
  [ -f .impl/tasks.db ]
}

@test "init registers the union merge driver" {
  grep -q '.principled/tasks.jsonl merge=union' .gitattributes
}

@test "init is idempotent" {
  bash "$LIB" --open --title "keep me" > /dev/null
  run bash "$LIB" --init
  [ "$status" -eq 0 ]
  [ "$(task_count)" -eq 1 ]
}

# --- Storage model ---

@test "the cache is gitignored and the log is not" {
  run git check-ignore -q .impl/tasks.db
  [ "$status" -eq 0 ]
  run git check-ignore -q .principled/tasks.jsonl
  [ "$status" -ne 0 ]
}

@test "deleting the cache loses nothing" {
  bash "$LIB" --open --title "alpha" --plan 007 > /dev/null
  bash "$LIB" --open --title "beta" --plan 007 > /dev/null
  local before
  before=$(sqlite3 .impl/tasks.db "SELECT id,title,status FROM tasks ORDER BY id;")

  rm -rf .impl
  bash "$LIB" --sync > /dev/null

  local after
  after=$(sqlite3 .impl/tasks.db "SELECT id,title,status FROM tasks ORDER BY id;")
  [ "$before" = "$after" ]
}

@test "rebuilding from the log preserves edges" {
  local a b
  a=$(bash "$LIB" --open --title "first")
  b=$(bash "$LIB" --open --title "second" --blocks "$a")
  rm -rf .impl
  bash "$LIB" --sync > /dev/null
  run sqlite3 .impl/tasks.db "SELECT kind FROM task_edges WHERE from_id='${b}' AND to_id='${a}';"
  [ "$output" = "blocks" ]
}

@test "cache is rebuilt automatically when the log is newer" {
  bash "$LIB" --open --title "original" > /dev/null
  # Simulate pulling a branch: append to the log behind the library's back.
  printf '{"op":"open","id":"task-deadbeef","title":"pulled","ts":"2026-01-01T00:00:00Z","plan":"","agent":"","task_id":"","discovered_from":""}\n' >> .principled/tasks.jsonl
  run bash "$LIB" --list --format json
  [[ "$output" == *"pulled"* ]]
}

# --- Query correctness ---

@test "two filters combine with AND instead of producing invalid SQL" {
  bash "$LIB" --open --title "match" --plan 007 --agent alpha > /dev/null
  bash "$LIB" --open --title "wrong plan" --plan 008 --agent alpha > /dev/null
  run bash "$LIB" --list --plan 007 --status open
  [ "$status" -eq 0 ]
  [[ "$output" == *"match"* ]]
  [[ "$output" != *"wrong plan"* ]]
}

@test "three filters combine correctly" {
  bash "$LIB" --open --title "target" --plan 007 --agent alpha > /dev/null
  bash "$LIB" --open --title "other agent" --plan 007 --agent beta > /dev/null
  run bash "$LIB" --list --plan 007 --status open --agent alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"target"* ]]
  [[ "$output" != *"other agent"* ]]
}

@test "audit accepts filters without ambiguous column errors" {
  local a b
  a=$(bash "$LIB" --open --title "blocker" --plan 007)
  b=$(bash "$LIB" --open --title "blocked one" --plan 007 --blocks "$a")
  bash "$LIB" --update --id "$b" --status blocked > /dev/null
  run bash "$LIB" --audit --plan 007 --agent alpha
  [ "$status" -eq 0 ]
  [[ "$output" != *"ambiguous"* ]]
  [[ "$output" != *"Error"* ]]
}

@test "json format is honored rather than silently ignored" {
  bash "$LIB" --open --title "as json" --plan 009 > /dev/null
  run bash "$LIB" --list --plan 009 --format json
  [ "$status" -eq 0 ]
  [[ "$output" == \[* ]]
  [[ "$output" == *'"title":"as json"'* ]]
}

@test "unknown format is rejected" {
  run bash "$LIB" --list --format yaml
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown --format"* ]]
}

# --- Data integrity ---

@test "titles with quotes, pipes and dollar signs round-trip intact" {
  local nasty='a|b "quoted" and '"'"'single'"'"' $VAR'
  bash "$LIB" --open --title "$nasty" --plan 007 > /dev/null
  run sqlite3 .impl/tasks.db "SELECT title FROM tasks;"
  [ "$output" = "$nasty" ]
}

@test "a title containing a pipe does not split into two columns on rebuild" {
  bash "$LIB" --open --title "left|right" > /dev/null
  rm -rf .impl
  bash "$LIB" --sync > /dev/null
  run sqlite3 .impl/tasks.db "SELECT title FROM tasks;"
  [ "$output" = "left|right" ]
}

@test "generated ids are wide enough to resist collision" {
  local id
  id=$(bash "$LIB" --open --title "check id width")
  [[ "$id" =~ ^task-[0-9a-f]{8}$ ]]
}

@test "many tasks in one run produce no duplicate ids" {
  local i
  for i in $(seq 1 40); do
    bash "$LIB" --open --title "task number $i" > /dev/null
  done
  local total unique
  total=$(sqlite3 .impl/tasks.db "SELECT COUNT(*) FROM tasks;")
  unique=$(sqlite3 .impl/tasks.db "SELECT COUNT(DISTINCT id) FROM tasks;")
  [ "$total" -eq 40 ]
  [ "$unique" -eq 40 ]
}

# --- Lifecycle ---

@test "update applies status, notes and agent" {
  local id
  id=$(bash "$LIB" --open --title "lifecycle")
  bash "$LIB" --update --id "$id" --status in_progress --notes "started" --agent worker > /dev/null
  run sqlite3 .impl/tasks.db "SELECT status||'/'||notes||'/'||agent FROM tasks WHERE id='${id}';"
  [ "$output" = "in_progress/started/worker" ]
}

@test "close sets closed_at and final status" {
  local id
  id=$(bash "$LIB" --open --title "to close")
  bash "$LIB" --close --id "$id" --notes "done deal" > /dev/null
  run sqlite3 .impl/tasks.db "SELECT status FROM tasks WHERE id='${id}';"
  [ "$output" = "done" ]
  run sqlite3 .impl/tasks.db "SELECT closed_at IS NOT NULL FROM tasks WHERE id='${id}';"
  [ "$output" = "1" ]
}

@test "the most recent update wins when folding the log" {
  local id
  id=$(bash "$LIB" --open --title "multi update")
  bash "$LIB" --update --id "$id" --status in_progress > /dev/null
  bash "$LIB" --update --id "$id" --status blocked > /dev/null
  rm -rf .impl && bash "$LIB" --sync > /dev/null
  run sqlite3 .impl/tasks.db "SELECT status FROM tasks WHERE id='${id}';"
  [ "$output" = "blocked" ]
}

# --- Error handling ---

@test "operating on an unknown id fails loudly" {
  run bash "$LIB" --update --id task-nonexistent --status open
  [ "$status" -ne 0 ]
  [[ "$output" == *"No task found"* ]]
}

@test "invalid status is rejected" {
  local id
  id=$(bash "$LIB" --open --title "status check")
  run bash "$LIB" --update --id "$id" --status not_a_status
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid status"* ]]
}

@test "invalid edge kind is rejected" {
  local a b
  a=$(bash "$LIB" --open --title "edge a")
  b=$(bash "$LIB" --open --title "edge b")
  run bash "$LIB" --add-edge --from "$a" --to "$b" --kind sometimes_maybe
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid edge kind"* ]]
}

@test "edges to unknown tasks are rejected" {
  local a
  a=$(bash "$LIB" --open --title "real task")
  run bash "$LIB" --add-edge --from "$a" --to task-ghost --kind blocks
  [ "$status" -ne 0 ]
}

@test "unknown operation exits non-zero with usage" {
  run bash "$LIB" --frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "no arguments exits non-zero" {
  run bash "$LIB"
  [ "$status" -ne 0 ]
}

# --- Git integration ---

@test "commit stages the log rather than the ignored cache" {
  bash "$LIB" --open --title "committed task" > /dev/null
  run bash "$LIB" --commit "tasks: add committed task"
  [ "$status" -eq 0 ]
  run git log --oneline -1 --name-only
  [[ "$output" == *".principled/tasks.jsonl"* ]]
  [[ "$output" != *"tasks.db"* ]]
}

@test "commit is a no-op when nothing changed" {
  bash "$LIB" --open --title "once" > /dev/null
  bash "$LIB" --commit "first" > /dev/null
  run bash "$LIB" --commit "second"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No changes to commit"* ]]
}

@test "parallel branches merge without conflict and keep both sides' tasks" {
  bash "$LIB" --commit "baseline" > /dev/null || true
  git add -A && git commit -qm "baseline" || true

  git checkout -qb agent-a
  bash "$LIB" --open --title "agent A work" > /dev/null
  bash "$LIB" --commit "tasks: agent A" > /dev/null

  git checkout -q main
  git checkout -qb agent-b
  bash "$LIB" --open --title "agent B work" > /dev/null
  bash "$LIB" --commit "tasks: agent B" > /dev/null

  git checkout -q main
  run git merge agent-a --no-edit
  [ "$status" -eq 0 ]
  run git merge agent-b --no-edit
  [ "$status" -eq 0 ]

  run grep -c '<<<<<<<' .principled/tasks.jsonl
  [ "$output" = "0" ]

  bash "$LIB" --sync > /dev/null
  run sqlite3 .impl/tasks.db "SELECT COUNT(*) FROM tasks WHERE title LIKE 'agent % work';"
  [ "$output" = "2" ]
}
