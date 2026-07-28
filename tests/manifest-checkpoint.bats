#!/usr/bin/env bats
# Tests for the checkpoint and acceptance-criteria operations in
# plugins/principled-implementation/lib/task-manifest.sh (ADR-021).
#
# Two classes of risk are covered.
#
# First, the new fields are additive and optional, so the failure mode is a consumer
# that breaks when they are present or absent. These tests assert both shapes stay
# valid JSON and that absence is never an error.
#
# Second, the no-jq fallback edits JSON with text tools. It previously used `sed -i`,
# which is not portable: BSD sed reads the following argument as a backup suffix, so
# `sed -i <expr> <file>` misparses on stock macOS and the fallback failed outright for
# the second task onward and for every status update. The regression tests below pin
# that down, since the repository documents jq as optional and CI runs on macOS.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  LIB="${REPO_ROOT}/plugins/principled-implementation/lib/task-manifest.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  cd "$WORK" || return 1
  git init -q -b main .
  git config user.email test@example.com
  git config user.name "Test"
  git config core.fsmonitor false
  git config gc.auto 0
  bash "$LIB" --init --plan-path docs/plans/008-x.md --plan-number 008 --plan-title "X" > /dev/null
  make_nojq_path
}

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

nojq() {
  env -i "PATH=${NOJQ_BIN}" "HOME=${HOME}" bash "$LIB" "$@"
}

# Validate with the real jq, which stays available to the test itself even when the
# script under test was run without it.
assert_valid_json() {
  run jq . .impl/manifest.json
  [ "$status" -eq 0 ]
}

# --- Backward compatibility ---

@test "a fresh manifest has no checkpoint and that is not an error" {
  run jq 'has("checkpoint")' .impl/manifest.json
  [ "$output" = "false" ]
}

@test "reading an absent checkpoint fails cleanly rather than crashing" {
  run bash "$LIB" --get-checkpoint
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'No checkpoint recorded'
}

@test "existing operations still work once a checkpoint is present" {
  bash "$LIB" --add-task --task-id 1.1 --phase 1 --description "first" > /dev/null
  bash "$LIB" --set-checkpoint --summary-text "mid-run" > /dev/null
  run bash "$LIB" --list-tasks
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '1.1'
  run bash "$LIB" --summary
  [ "$status" -eq 0 ]
}

# --- Checkpoint ---

@test "set-checkpoint records the orchestrator summary verbatim" {
  bash "$LIB" --set-checkpoint --session-id sess-abc --agent-id impl-worker --phase 2 \
    --summary-text 'task-2b failed twice on the same fixture collision — change approach, do not retry.' > /dev/null
  assert_valid_json
  run bash "$LIB" --get-checkpoint
  echo "$output" | grep -q 'change approach, do not retry'
  echo "$output" | grep -q 'session_id=sess-abc'
  echo "$output" | grep -q 'phase=2'
}

@test "a summary containing quotes stays valid JSON" {
  bash "$LIB" --set-checkpoint --summary-text 'the "test suite" failed on a \ backslash' > /dev/null
  assert_valid_json
  run jq -r '.checkpoint.orchestrator_summary' .impl/manifest.json
  echo "$output" | grep -q 'test suite'
}

@test "pending decisions and worktrees round-trip as arrays" {
  bash "$LIB" --set-checkpoint --summary-text "s" \
    --pending-decisions 'envelope vs flat|naming' \
    --active-worktrees 'task-2a,task-2b' > /dev/null
  assert_valid_json
  run jq -r '.checkpoint.pending_decisions | length' .impl/manifest.json
  [ "$output" = "2" ]
  run jq -r '.checkpoint.environment_state.active_worktrees | length' .impl/manifest.json
  [ "$output" = "2" ]
}

@test "writing a checkpoint twice replaces rather than duplicates it" {
  bash "$LIB" --set-checkpoint --summary-text "first" > /dev/null
  bash "$LIB" --set-checkpoint --summary-text "second" > /dev/null
  assert_valid_json
  run jq -r '.checkpoint.orchestrator_summary' .impl/manifest.json
  [ "$output" = "second" ]
  [ "$(grep -c '"checkpoint"' .impl/manifest.json)" -eq 1 ]
}

@test "clear-checkpoint removes it and leaves the manifest valid" {
  bash "$LIB" --set-checkpoint --summary-text "s" > /dev/null
  bash "$LIB" --clear-checkpoint > /dev/null
  assert_valid_json
  run jq 'has("checkpoint")' .impl/manifest.json
  [ "$output" = "false" ]
}

@test "set-checkpoint requires a summary" {
  run bash "$LIB" --set-checkpoint --session-id x
  [ "$status" -eq 1 ]
}

@test "a non-numeric phase is rejected" {
  run bash "$LIB" --set-checkpoint --summary-text "s" --phase two
  [ "$status" -eq 1 ]
}

# --- Acceptance criteria ---

@test "criteria are stored unverified and listed in order" {
  bash "$LIB" --add-task --task-id 2.1 --phase 2 --description "auth" > /dev/null
  bash "$LIB" --set-criteria --task-id 2.1 --criteria "rejects 401|passes valid|tests cover" > /dev/null
  assert_valid_json
  run bash "$LIB" --list-criteria --task-id 2.1
  echo "$output" | grep -q '^0|pending|rejects 401'
  echo "$output" | grep -q '^2|pending|tests cover'
}

@test "verifying a criterion flips only that one and stamps a time" {
  bash "$LIB" --add-task --task-id 2.1 --phase 2 --description "auth" > /dev/null
  bash "$LIB" --set-criteria --task-id 2.1 --criteria "a|b|c" > /dev/null
  bash "$LIB" --verify-criterion --task-id 2.1 --criterion-index 1 > /dev/null
  assert_valid_json
  run jq -c '[.tasks[] | select(.id=="2.1") | .acceptance_criteria[].verified]' .impl/manifest.json
  [ "$output" = "[false,true,false]" ]
  run jq -r '[.tasks[] | select(.id=="2.1") | .acceptance_criteria[1].verified_at]|first' .impl/manifest.json
  [ "$output" != "null" ]
}

@test "an out-of-range criterion index is rejected" {
  bash "$LIB" --add-task --task-id 2.1 --phase 2 --description "auth" > /dev/null
  bash "$LIB" --set-criteria --task-id 2.1 --criteria "a|b" > /dev/null
  run bash "$LIB" --verify-criterion --task-id 2.1 --criterion-index 9
  [ "$status" -eq 1 ]
}

@test "setting criteria on an unknown task fails loudly" {
  run bash "$LIB" --set-criteria --task-id nope --criteria "a"
  [ "$status" -eq 1 ]
}

@test "criteria do not disturb other tasks" {
  bash "$LIB" --add-task --task-id 2.1 --phase 2 --description "auth" > /dev/null
  bash "$LIB" --add-task --task-id 2.2 --phase 2 --description "other" > /dev/null
  bash "$LIB" --set-criteria --task-id 2.1 --criteria "a|b" > /dev/null
  assert_valid_json
  run jq -r '[.tasks[] | select(.id=="2.2") | .acceptance_criteria // "none"] | first' .impl/manifest.json
  [ "$output" = "none" ]
}

@test "a task without criteria lists nothing rather than failing" {
  bash "$LIB" --add-task --task-id 2.1 --phase 2 --description "auth" > /dev/null
  run bash "$LIB" --list-criteria --task-id 2.1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- Portability regressions (the `sed -i` bug) ---

@test "a second task can be added without jq" {
  nojq --add-task --task-id 1.1 --phase 1 --description "first" > /dev/null
  run nojq --add-task --task-id 1.2 --phase 1 --description "second"
  [ "$status" -eq 0 ]
  assert_valid_json
  run jq -r '.tasks | length' .impl/manifest.json
  [ "$output" = "2" ]
}

@test "status updates work without jq and touch only the target task" {
  nojq --add-task --task-id 1.1 --phase 1 --description "first" > /dev/null
  nojq --add-task --task-id 1.2 --phase 1 --description "second" > /dev/null
  run nojq --update-status --task-id 1.1 --status merged --branch impl/x
  [ "$status" -eq 0 ]
  assert_valid_json
  run jq -r '[.tasks[] | select(.id=="1.1") | .status] | first' .impl/manifest.json
  [ "$output" = "merged" ]
  run jq -r '[.tasks[] | select(.id=="1.2") | .status] | first' .impl/manifest.json
  [ "$output" = "pending" ]
}

# --- Without jq ---

@test "checkpoint round-trips without jq" {
  run nojq --set-checkpoint --session-id sess-x --agent-id impl-worker --phase 3 \
    --summary-text 'phase 2 done; task-3a blocked on review'
  [ "$status" -eq 0 ]
  assert_valid_json
  run nojq --get-checkpoint
  echo "$output" | grep -q 'task-3a blocked on review'
  echo "$output" | grep -q 'session_id=sess-x'
}

@test "overwriting a checkpoint without jq leaves exactly one" {
  nojq --set-checkpoint --summary-text "first" > /dev/null
  nojq --set-checkpoint --summary-text "second" > /dev/null
  assert_valid_json
  [ "$(grep -c '"checkpoint"' .impl/manifest.json)" -eq 1 ]
  run jq -r '.checkpoint.orchestrator_summary' .impl/manifest.json
  [ "$output" = "second" ]
}

@test "clearing a checkpoint without jq leaves the manifest valid" {
  nojq --set-checkpoint --summary-text "s" > /dev/null
  run nojq --clear-checkpoint
  [ "$status" -eq 0 ]
  assert_valid_json
  run jq 'has("checkpoint")' .impl/manifest.json
  [ "$output" = "false" ]
}

@test "criteria round-trip without jq" {
  nojq --add-task --task-id 2.1 --phase 2 --description "auth" > /dev/null
  run nojq --set-criteria --task-id 2.1 --criteria "rejects 401|passes valid"
  [ "$status" -eq 0 ]
  assert_valid_json
  run nojq --verify-criterion --task-id 2.1 --criterion-index 0
  [ "$status" -eq 0 ]
  assert_valid_json
  run nojq --list-criteria --task-id 2.1
  echo "$output" | grep -q '^0|verified|rejects 401'
  echo "$output" | grep -q '^1|pending|passes valid'
}

@test "a checkpoint written without jq is readable with jq, and vice versa" {
  nojq --set-checkpoint --session-id sess-x --summary-text 'written without jq' > /dev/null
  run bash "$LIB" --get-checkpoint
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'written without jq'

  bash "$LIB" --set-checkpoint --session-id sess-y --summary-text 'written with jq' > /dev/null
  run nojq --get-checkpoint
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'written with jq'
}
