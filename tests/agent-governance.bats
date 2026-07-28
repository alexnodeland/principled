#!/usr/bin/env bats
# Tests for plugins/principled-agent/lib/agent-governance.sh (ADR-022).
#
# These constraints exist for the case where nobody is watching, which is exactly when a
# silent failure would go unnoticed. Two properties matter more than the rest and are
# tested hardest:
#
#   1. Refusal is distinguishable from error. Exit 3 means "you may not"; exit 1 means
#      "I could not tell". A caller that conflates them either ignores a real refusal or
#      halts on a transient fault.
#   2. Unknown budgets fail CLOSED. If gh cannot be reached, the counts are unknown, and
#      unknown must never read as headroom — that inversion would silently disable the
#      whole safety layer precisely when the environment is already misbehaving.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  LIB="${REPO_ROOT}/plugins/principled-agent/lib/agent-governance.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  cd "$WORK" || return 1
  git init -q -b main .
  git config user.email test@example.com
  git config user.name "Test"
  git config core.fsmonitor false
  git config gc.auto 0
  make_gh_stub
}

# A stub gh whose counts are driven by environment variables, so budget arithmetic can
# be tested without a network or a real repository.
make_gh_stub() {
  STUB_BIN="${BATS_TEST_TMPDIR}/stub-bin"
  mkdir -p "$STUB_BIN"
  cat > "${STUB_BIN}/gh" << 'STUB'
#!/usr/bin/env bash
if [ "$1" = "auth" ]; then exit 0; fi
n=0
case "$1" in
  issue) n="${STUB_BLOCKED:-0}" ;;
  pr) n="${STUB_PRS:-0}" ;;
esac
out="["
i=0
while [ "$i" -lt "$n" ]; do
  [ "$i" -gt 0 ] && out="${out},"
  out="${out}{\"number\":$((i + 1))}"
  i=$((i + 1))
done
echo "${out}]"
STUB
  chmod +x "${STUB_BIN}/gh"
}

with_gh() {
  PATH="${STUB_BIN}:${PATH}" "$@"
}

# A PATH with neither gh nor jq, for the degradation tests.
make_bare_path() {
  BARE_BIN="${BATS_TEST_TMPDIR}/bare-bin"
  [[ -d "$BARE_BIN" ]] && return 0
  mkdir -p "$BARE_BIN"
  local tool src
  for tool in bash sh cat grep sed head tail awk tr wc git mkdir rm mv printf env test expr; do
    src="$(command -v "$tool" 2> /dev/null || true)"
    [[ -n "$src" ]] && ln -sf "$src" "${BARE_BIN}/${tool}"
  done
}

# --- Halt switch ---

@test "no halt reports clear and exits 0" {
  run bash "$LIB" --check-halt
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "no halt in effect"
}

@test "engaging the halt writes the reason to .agents/HALT" {
  bash "$LIB" --halt "CI is broken"
  [ -f .agents/HALT ]
  grep -q "CI is broken" .agents/HALT
}

@test "an engaged halt exits 3 and prints the reason and path" {
  bash "$LIB" --halt "CI is broken" > /dev/null
  run bash "$LIB" --check-halt
  [ "$status" -eq 3 ]
  echo "$output" | grep -q "HALTED"
  echo "$output" | grep -q "CI is broken"
  # A halt nobody can locate is a halt that gets worked around.
  echo "$output" | grep -q ".agents/HALT"
}

@test "halting without a reason still records something" {
  bash "$LIB" --halt > /dev/null
  [ -s .agents/HALT ]
  run bash "$LIB" --check-halt
  [ "$status" -eq 3 ]
}

@test "resume clears the halt" {
  bash "$LIB" --halt "temporary" > /dev/null
  bash "$LIB" --resume
  [ ! -f .agents/HALT ]
  run bash "$LIB" --check-halt
  [ "$status" -eq 0 ]
}

@test "resume with no halt is a no-op rather than an error" {
  run bash "$LIB" --resume
  [ "$status" -eq 0 ]
}

@test "the halt switch works with no gh and no jq at all" {
  make_bare_path
  run env -i "PATH=${BARE_BIN}" "HOME=${HOME}" bash "$LIB" --halt "no tooling"
  [ "$status" -eq 0 ]
  run env -i "PATH=${BARE_BIN}" "HOME=${HOME}" bash "$LIB" --check-halt
  [ "$status" -eq 3 ]
}

# --- The dispatch gate ---

@test "dispatch is permitted when halted-off and both budgets have room" {
  run with_gh env STUB_BLOCKED=1 STUB_PRS=2 bash "$LIB" --can-dispatch
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "dispatch permitted"
}

@test "the halt switch refuses dispatch before any budget is consulted" {
  bash "$LIB" --halt "stop everything" > /dev/null
  # Budgets are wide open; the halt must still win.
  run with_gh env STUB_BLOCKED=0 STUB_PRS=0 bash "$LIB" --can-dispatch
  [ "$status" -eq 3 ]
  echo "$output" | grep -q "halt switch engaged"
}

@test "reaching the blocked-issue budget refuses dispatch" {
  run with_gh env STUB_BLOCKED=5 STUB_PRS=0 bash "$LIB" --can-dispatch
  [ "$status" -eq 3 ]
  echo "$output" | grep -q "agent-blocked issue"
}

@test "reaching the in-flight PR budget refuses dispatch" {
  run with_gh env STUB_BLOCKED=0 STUB_PRS=5 bash "$LIB" --can-dispatch
  [ "$status" -eq 3 ]
  echo "$output" | grep -q "in-flight agent PR"
}

@test "the budget boundary is inclusive" {
  # 4 of 5 proceeds; 5 of 5 refuses. Off-by-one here would let the cap be exceeded.
  run with_gh env STUB_BLOCKED=4 STUB_PRS=4 bash "$LIB" --can-dispatch
  [ "$status" -eq 0 ]
  run with_gh env STUB_BLOCKED=5 STUB_PRS=4 bash "$LIB" --can-dispatch
  [ "$status" -eq 3 ]
}

@test "budgets can be raised explicitly" {
  run with_gh env STUB_BLOCKED=8 STUB_PRS=8 bash "$LIB" --can-dispatch --blocked-budget 10 --pr-budget 10
  [ "$status" -eq 0 ]
}

@test "a non-numeric budget is rejected" {
  run bash "$LIB" --can-dispatch --pr-budget many
  [ "$status" -eq 1 ]
}

# --- Failing closed ---

@test "dispatch refuses when budgets cannot be verified" {
  make_bare_path
  run env -i "PATH=${BARE_BIN}" "HOME=${HOME}" bash "$LIB" --can-dispatch
  # Unknown must never read as headroom.
  [ "$status" -eq 3 ]
  echo "$output" | grep -q "cannot verify governance budgets"
}

@test "an unverifiable budget is reported as unknown, not as zero" {
  make_bare_path
  run env -i "PATH=${BARE_BIN}" "HOME=${HOME}" bash "$LIB" --status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "unknown"
  # Reporting 0 would imply full headroom, inverting the safety property.
  ! echo "$output" | grep -q "0/5"
}

@test "refusal (exit 3) is distinguishable from error (exit 1)" {
  bash "$LIB" --halt "refused" > /dev/null
  run bash "$LIB" --can-dispatch
  [ "$status" -eq 3 ]
  run bash "$LIB" --bogus-operation
  [ "$status" -eq 1 ]
}

# --- Status reporting ---

@test "status reports halt state and both budgets" {
  run with_gh env STUB_BLOCKED=2 STUB_PRS=1 bash "$LIB" --status
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "2/5"
  echo "$output" | grep -q "1/5"
}

@test "status json is valid and carries null for unknown counts" {
  make_bare_path
  run env -i "PATH=${BARE_BIN}" "HOME=${HOME}" bash "$LIB" --status --format json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.agent_blocked_issues == null' > /dev/null
  echo "$output" | jq -e '.in_flight_prs == null' > /dev/null
}

@test "status json escapes a halt reason containing quotes" {
  bash "$LIB" --halt 'the "test suite" broke' > /dev/null
  run with_gh env STUB_BLOCKED=0 STUB_PRS=0 bash "$LIB" --status --format json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.halted == true' > /dev/null
  echo "$output" | jq -e '.halt_reason | contains("test suite")' > /dev/null
}

@test "counts work without jq, via the grep fallback" {
  make_bare_path
  # gh present, jq absent: the fallback counts JSON objects with grep.
  run env -i "PATH=${STUB_BIN}:${BARE_BIN}" "HOME=${HOME}" STUB_BLOCKED=3 bash "$LIB" --count-blocked
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "unknown format is rejected" {
  run bash "$LIB" --status --format yaml
  [ "$status" -eq 1 ]
}

@test "no operation exits non-zero with usage" {
  run bash "$LIB"
  [ "$status" -eq 1 ]
}
