#!/usr/bin/env bats
# Tests for plugins/principled-agent/lib/agent-memory.sh
#
# Memory is a document, not an event log (ADR-020), which means the risky operations
# are the ones that rewrite a file in place: metric updates must not disturb the
# knowledge body, and a reset must not disturb it either. The size budget is advisory
# by design, so these tests also pin down that it warns without ever failing or
# truncating — a budget that silently dropped content would be worse than no budget.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  LIB="${REPO_ROOT}/plugins/principled-agent/lib/agent-memory.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  cd "$WORK" || return 1
  git init -q -b main .
  git config user.email test@example.com
  git config user.name "Test"
  # See tests/task-db.bats: fsmonitor/auto-gc daemons inherit bats' stdout and
  # prevent it from ever seeing EOF, hanging the run after all tests pass.
  git config core.fsmonitor false
  git config gc.auto 0
  bash "$LIB" --init > /dev/null
  MEM=".agents/memory/agents/impl-worker.md"
  make_nojq_path
}

# Build a PATH that genuinely lacks jq. Trimming to /usr/bin:/bin does not work,
# because jq lives in /usr/bin on macOS.
make_nojq_path() {
  NOJQ_BIN="${BATS_TEST_TMPDIR}/nojq-bin"
  [[ -d "$NOJQ_BIN" ]] && return 0
  mkdir -p "$NOJQ_BIN"
  local tool src
  for tool in bash sh cat grep sed head tail cut awk tr sort uniq wc find xargs \
    basename dirname date git ls mkdir rm mv cp touch printf env test expr mktemp; do
    src="$(command -v "$tool" 2> /dev/null || true)"
    [[ -n "$src" ]] && ln -sf "$src" "${NOJQ_BIN}/${tool}"
  done
}

run_without_jq() {
  env -i "PATH=${NOJQ_BIN}" "HOME=${HOME}" bash "$LIB" "$@"
}

# --- Scaffold ---

@test "init creates the registry, global memory, and per-agent files" {
  [ -f .agents/registry.json ]
  [ -f .agents/memory/global.md ]
  [ -f .agents/memory/agents/impl-worker.md ]
  [ -d .agents/retrospectives ]
}

@test "init seeds memory only for agents the registry marks memory:true" {
  [ -f .agents/memory/agents/impl-worker.md ]
  [ -f .agents/memory/agents/issue-ingester.md ]
  [ -f .agents/memory/agents/pr-reviewer.md ]
  # Deterministic auditors learn nothing, so they get no file.
  [ ! -f .agents/memory/agents/module-auditor.md ]
  [ ! -f .agents/memory/agents/boundary-checker.md ]
}

@test "init is idempotent and never overwrites existing knowledge" {
  printf -- '- a hard-won fact\n' >> "$MEM"
  run bash "$LIB" --init
  [ "$status" -eq 0 ]
  grep -q 'a hard-won fact' "$MEM"
}

@test "memory files carry parseable frontmatter" {
  [ "$(head -1 "$MEM")" = "---" ]
  run bash "$LIB" --show --agent impl-worker --frontmatter-only
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'agent_id: "impl-worker"'
}

# --- Metrics ---

@test "update-metrics computes a running success rate" {
  bash "$LIB" --update-metrics --agent impl-worker --session --tasks 4 --succeeded 3
  run bash "$LIB" --show --agent impl-worker --frontmatter-only
  echo "$output" | grep -q 'success_rate: 0.75'
  echo "$output" | grep -q 'total_tasks: 4'
  echo "$output" | grep -q 'session_count: 1'
}

@test "success rate accumulates across sessions rather than being overwritten" {
  bash "$LIB" --update-metrics --agent impl-worker --session --tasks 4 --succeeded 3
  bash "$LIB" --update-metrics --agent impl-worker --session --tasks 4 --succeeded 4
  run bash "$LIB" --show --agent impl-worker --frontmatter-only
  # 3 of 4, then 4 of 4, is 7 of 8 — not the 1.0 of the latest run alone.
  echo "$output" | grep -q 'success_rate: 0.88'
  echo "$output" | grep -q 'total_tasks: 8'
  echo "$output" | grep -q 'session_count: 2'
}

@test "updating metrics leaves the knowledge body untouched" {
  printf -- '- macOS ships bash 3.2, so no `declare -A`.\n' >> "$MEM"
  bash "$LIB" --update-metrics --agent impl-worker --session --tasks 2 --succeeded 1
  grep -q 'macOS ships bash 3.2' "$MEM"
  grep -q '## Known Patterns' "$MEM"
}

@test "non-numeric metric arguments are rejected" {
  run bash "$LIB" --update-metrics --agent impl-worker --tasks abc
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'non-negative integers'
}

@test "more successes than tasks is rejected" {
  run bash "$LIB" --update-metrics --agent impl-worker --tasks 1 --succeeded 5
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'cannot exceed'
}

@test "operating on an unknown agent fails loudly" {
  run bash "$LIB" --update-metrics --agent no-such-agent --session
  [ "$status" -eq 1 ]
}

# --- Forks ---

@test "reset-metrics zeroes counters but preserves knowledge" {
  printf -- '- knowledge that must survive a fork\n' >> "$MEM"
  bash "$LIB" --update-metrics --agent impl-worker --session --tasks 9 --succeeded 9
  bash "$LIB" --reset-metrics --agent impl-worker
  run bash "$LIB" --show --agent impl-worker --frontmatter-only
  echo "$output" | grep -q 'session_count: 0'
  echo "$output" | grep -q 'total_tasks: 0'
  echo "$output" | grep -q 'success_rate: 0.0'
  # The whole point: the codebase knowledge still applies in the fork.
  grep -q 'knowledge that must survive a fork' "$MEM"
}

@test "reset-metrics with no agent resets every memory-bearing agent" {
  bash "$LIB" --update-metrics --agent impl-worker --session --tasks 3 --succeeded 3
  bash "$LIB" --update-metrics --agent pr-reviewer --session --tasks 3 --succeeded 3
  bash "$LIB" --reset-metrics
  run bash "$LIB" --show --agent impl-worker --frontmatter-only
  echo "$output" | grep -q 'total_tasks: 0'
  run bash "$LIB" --show --agent pr-reviewer --frontmatter-only
  echo "$output" | grep -q 'total_tasks: 0'
}

# --- Size budget ---

@test "a memory file under budget reports OK" {
  run bash "$LIB" --check --agent impl-worker
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^OK: impl-worker'
}

@test "exceeding the soft budget warns without failing" {
  # ~200 lines of ~52 bytes clears 8192 while staying well under the 16384 hard limit.
  awk 'BEGIN { for (i = 0; i < 200; i++) print "- a durable fact about this codebase worth keeping." }' >> "$MEM"
  run bash "$LIB" --check --agent impl-worker
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'soft budget'
}

@test "exceeding the hard budget still only warns" {
  awk 'BEGIN { for (i = 0; i < 400; i++) print "- a durable fact about this codebase worth keeping." }' >> "$MEM"
  run bash "$LIB" --check --agent impl-worker
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'over the 16384 byte budget'
}

@test "an oversized memory file is never truncated" {
  awk 'BEGIN { for (i = 0; i < 400; i++) print "- padding" }' >> "$MEM"
  printf -- '- THE LAST LINE MUST SURVIVE\n' >> "$MEM"
  before="$(wc -c < "$MEM")"
  bash "$LIB" --check --agent impl-worker
  after="$(wc -c < "$MEM")"
  [ "$before" -eq "$after" ]
  # Truncation would drop the tail first, so assert on the tail specifically.
  grep -q 'THE LAST LINE MUST SURVIVE' "$MEM"
}

# --- Structural integrity ---

@test "a missing memory file for a registered agent is an error" {
  rm .agents/memory/agents/issue-ingester.md
  run bash "$LIB" --check
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'ERROR: issue-ingester'
}

@test "an agent_id that disagrees with the filename is an error" {
  sed 's/agent_id: "pr-reviewer"/agent_id: "someone-else"/' .agents/memory/agents/pr-reviewer.md > tmp
  mv tmp .agents/memory/agents/pr-reviewer.md
  run bash "$LIB" --check --agent pr-reviewer
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "expected 'pr-reviewer'"
}

@test "missing frontmatter is an error" {
  printf 'no frontmatter here\n' > "$MEM"
  run bash "$LIB" --check --agent impl-worker
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'missing YAML frontmatter'
}

# --- Output formats ---

@test "json format is honored rather than silently ignored" {
  run bash "$LIB" --list --format json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"agents"'
  echo "$output" | grep -q '"id": "impl-worker"'
}

@test "unknown format is rejected" {
  run bash "$LIB" --list --format yaml
  [ "$status" -eq 1 ]
}

@test "an unknown argument exits non-zero rather than being ignored" {
  run bash "$LIB" --list --bogus-flag
  [ "$status" -eq 1 ]
}

@test "no operation exits non-zero with usage" {
  run bash "$LIB"
  [ "$status" -eq 1 ]
}

# --- Without jq ---
# The repository documents jq as optional, so the fallback paths must actually work.

@test "list works without jq" {
  run run_without_jq --list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'impl-worker'
}

@test "check works without jq" {
  run run_without_jq --check
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'OK: impl-worker'
}

@test "update-metrics works without jq" {
  run run_without_jq --update-metrics --agent impl-worker --session --tasks 2 --succeeded 1
  [ "$status" -eq 0 ]
  run bash "$LIB" --show --agent impl-worker --frontmatter-only
  echo "$output" | grep -q 'success_rate: 0.50'
}

@test "the registry is read identically with and without jq" {
  with_jq="$(bash "$LIB" --list | awk 'NR > 1 { print $1 }' | sort)"
  without_jq="$(run_without_jq --list | awk 'NR > 1 { print $1 }' | sort)"
  [ "$with_jq" = "$without_jq" ]
}
