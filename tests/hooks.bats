#!/usr/bin/env bats
# Tests for the enforcement hooks in every plugin.
#
# Guards default to allow and only block when they can positively confirm a
# violation. That is the right default, but it means a broken guard fails open and
# silent — a regression in frontmatter parsing or JSON extraction turns every guard
# into a no-op with no visible symptom. These tests pin the behaviour down.
#
# Each guard is exercised four ways: the allow case, the block case, malformed input,
# and with jq removed from PATH. The last matters because the repository documents jq
# as optional, and the grep fallbacks were PCRE-only (`grep -oP`) until recently —
# syntax stock macOS grep does not support, so the "fallback" silently extracted
# nothing and every guard allowed everything.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  DOCS_HOOKS="${REPO_ROOT}/plugins/principled-docs/hooks/scripts"
  IMPL_HOOKS="${REPO_ROOT}/plugins/principled-implementation/hooks/scripts"
  GH_HOOKS="${REPO_ROOT}/plugins/principled-github/hooks/scripts"
  QUAL_HOOKS="${REPO_ROOT}/plugins/principled-quality/hooks/scripts"
  REL_HOOKS="${REPO_ROOT}/plugins/principled-release/hooks/scripts"
  ARCH_HOOKS="${REPO_ROOT}/plugins/principled-architecture/hooks/scripts"
  TASK_HOOKS="${REPO_ROOT}/plugins/principled-tasks/hooks/scripts"
  cd "$REPO_ROOT" || return 1
  make_nojq_path
}

# Build a PATH that genuinely lacks jq.
#
# Trimming PATH to /usr/bin:/bin does NOT work: jq is installed at /usr/bin/jq on
# macOS, so `command -v jq` still succeeds and the hook takes the jq branch. The
# fallback path then goes untested, which is exactly how PCRE-only `grep -oP`
# fallbacks survived in five plugins. Instead, build a directory of symlinks to the
# tools hooks legitimately need, deliberately excluding jq, and point PATH at it.
make_nojq_path() {
  NOJQ_BIN="${BATS_TEST_TMPDIR}/nojq-bin"
  [[ -d "$NOJQ_BIN" ]] && return 0
  mkdir -p "$NOJQ_BIN"
  local tool src
  for tool in bash sh cat grep sed head tail cut awk tr sort uniq wc find xargs \
    basename dirname date git ls mkdir rm touch printf env test expr; do
    src="$(command -v "$tool" 2> /dev/null || true)"
    [[ -n "$src" ]] && ln -sf "$src" "${NOJQ_BIN}/${tool}"
  done
}

# Run a hook with jq genuinely absent, exercising the grep/sed fallback path.
run_without_jq() {
  local script="$1" payload="$2"
  echo "$payload" | env -i "PATH=${NOJQ_BIN}" HOME="$HOME" bash "$script"
}

# --- ADR immutability guard ---

@test "adr guard blocks edits to an accepted ADR" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"docs/decisions/001-frontmatter-parsing-strategy.md\"}}' | bash '${DOCS_HOOKS}/check-adr-immutability.sh'"
  [ "$status" -eq 2 ]
}

@test "adr guard allows edits to a non-decision file" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"CLAUDE.md\"}}' | bash '${DOCS_HOOKS}/check-adr-immutability.sh'"
  [ "$status" -eq 0 ]
}

@test "adr guard blocks an accepted ADR without jq" {
  run run_without_jq "${DOCS_HOOKS}/check-adr-immutability.sh" \
    '{"tool_input":{"file_path":"docs/decisions/001-frontmatter-parsing-strategy.md"}}'
  [ "$status" -eq 2 ]
}

@test "adr guard allows on malformed json rather than crashing" {
  run bash -c "echo 'not json at all' | bash '${DOCS_HOOKS}/check-adr-immutability.sh'"
  [ "$status" -eq 0 ]
}

@test "adr guard allows on empty input" {
  run bash -c "echo '' | bash '${DOCS_HOOKS}/check-adr-immutability.sh'"
  [ "$status" -eq 0 ]
}

# --- Proposal lifecycle guard ---

@test "proposal guard blocks edits to an accepted proposal" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"docs/proposals/000-principled-docs.md\"}}' | bash '${DOCS_HOOKS}/check-proposal-lifecycle.sh'"
  [ "$status" -eq 2 ]
}

@test "proposal guard blocks an accepted proposal without jq" {
  run run_without_jq "${DOCS_HOOKS}/check-proposal-lifecycle.sh" \
    '{"tool_input":{"file_path":"docs/proposals/000-principled-docs.md"}}'
  [ "$status" -eq 2 ]
}

@test "proposal guard allows a non-proposal file" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"README.md\"}}' | bash '${DOCS_HOOKS}/check-proposal-lifecycle.sh'"
  [ "$status" -eq 0 ]
}

@test "proposal guard allows on malformed json" {
  run bash -c "echo '{{{' | bash '${DOCS_HOOKS}/check-proposal-lifecycle.sh'"
  [ "$status" -eq 0 ]
}

# --- Frontmatter, numbering, plan-proposal link guards ---

@test "frontmatter guard allows a valid pipeline document" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"docs/decisions/001-frontmatter-parsing-strategy.md\"}}' | bash '${DOCS_HOOKS}/check-required-frontmatter.sh'"
  [ "$status" -eq 0 ]
}

@test "frontmatter guard allows a non-pipeline file" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"justfile\"}}' | bash '${DOCS_HOOKS}/check-required-frontmatter.sh'"
  [ "$status" -eq 0 ]
}

@test "numbering guard allows a file outside the pipeline directories" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"README.md\"}}' | bash '${DOCS_HOOKS}/check-doc-numbering.sh'"
  [ "$status" -eq 0 ]
}

@test "plan-proposal guard allows a non-plan file" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"README.md\"}}' | bash '${DOCS_HOOKS}/check-plan-proposal-link.sh'"
  [ "$status" -eq 0 ]
}

@test "guards do not crash when file_path points at a nonexistent file" {
  local script
  for script in check-adr-immutability check-proposal-lifecycle check-required-frontmatter check-doc-numbering check-plan-proposal-link; do
    run bash -c "echo '{\"tool_input\":{\"file_path\":\"docs/decisions/999-nope.md\"}}' | bash '${DOCS_HOOKS}/${script}.sh'"
    [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
  done
}

# --- Advisory hooks: always exit 0, never block ---

@test "manifest integrity advisory always allows" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\".impl/manifest.json\"}}' | bash '${IMPL_HOOKS}/check-manifest-integrity.sh'"
  [ "$status" -eq 0 ]
}

@test "manifest integrity advisory warns on a direct manifest edit" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\".impl/manifest.json\"}}' | bash '${IMPL_HOOKS}/check-manifest-integrity.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"manifest"* ]]
}

@test "manifest integrity advisory still warns without jq" {
  run run_without_jq "${IMPL_HOOKS}/check-manifest-integrity.sh" '{"tool_input":{"file_path":".impl/manifest.json"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"manifest"* ]]
}

@test "pr reference advisory always allows" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"gh pr create --title x\"}}' | bash '${GH_HOOKS}/check-pr-references.sh'"
  [ "$status" -eq 0 ]
}

@test "pr reference advisory warns without jq" {
  run run_without_jq "${GH_HOOKS}/check-pr-references.sh" '{"tool_input":{"command":"gh pr create --title x"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"RFC"* || "$output" == *"proposal"* || "$output" == *"Plan"* || "$output" == *"principled"* ]]
}

@test "review checklist advisory always allows" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"gh pr review 42\"}}' | bash '${QUAL_HOOKS}/check-review-checklist.sh'"
  [ "$status" -eq 0 ]
}

@test "review checklist advisory warns without jq" {
  run run_without_jq "${QUAL_HOOKS}/check-review-checklist.sh" '{"tool_input":{"command":"gh pr review 42"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"checklist"* ]]
}

@test "release readiness advisory always allows" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"git tag v1.0.0\"}}' | bash '${REL_HOOKS}/check-release-readiness.sh'"
  [ "$status" -eq 0 ]
}

@test "release readiness advisory warns without jq" {
  run run_without_jq "${REL_HOOKS}/check-release-readiness.sh" '{"tool_input":{"command":"git tag v1.0.0"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"release"* || "$output" == *"ready"* ]]
}

@test "release readiness advisory ignores git tag -l and -d" {
  run bash -c "echo '{\"tool_input\":{\"command\":\"git tag -l\"}}' | bash '${REL_HOOKS}/check-release-readiness.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"release-ready"* ]]
}

@test "boundary violation advisory always allows" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"src/index.ts\"}}' | bash '${ARCH_HOOKS}/check-boundary-violation.sh'"
  [ "$status" -eq 0 ]
}

@test "boundary violation advisory runs without jq" {
  run run_without_jq "${ARCH_HOOKS}/check-boundary-violation.sh" '{"tool_input":{"file_path":"src/index.ts"}}'
  [ "$status" -eq 0 ]
}

@test "task db integrity advisory warns on event log edits" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\".principled/tasks.jsonl\"}}' | bash '${TASK_HOOKS}/check-db-integrity.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"source of truth"* ]]
}

@test "task db integrity advisory warns on cache edits" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\".impl/tasks.db\"}}' | bash '${TASK_HOOKS}/check-db-integrity.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rebuilt"* ]]
}

@test "task db integrity advisory warns without jq" {
  run run_without_jq "${TASK_HOOKS}/check-db-integrity.sh" '{"tool_input":{"file_path":".principled/tasks.jsonl"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"source of truth"* ]]
}

# --- Every hook survives hostile input ---

@test "no hook crashes on empty, malformed, or absent fields" {
  local script payload
  for script in \
    "${DOCS_HOOKS}/check-adr-immutability.sh" \
    "${DOCS_HOOKS}/check-proposal-lifecycle.sh" \
    "${DOCS_HOOKS}/check-required-frontmatter.sh" \
    "${DOCS_HOOKS}/check-doc-numbering.sh" \
    "${DOCS_HOOKS}/check-plan-proposal-link.sh" \
    "${IMPL_HOOKS}/check-manifest-integrity.sh" \
    "${GH_HOOKS}/check-pr-references.sh" \
    "${QUAL_HOOKS}/check-review-checklist.sh" \
    "${REL_HOOKS}/check-release-readiness.sh" \
    "${ARCH_HOOKS}/check-boundary-violation.sh" \
    "${TASK_HOOKS}/check-db-integrity.sh"; do
    for payload in '' '{}' 'garbage' '{"tool_input":{}}' '{"tool_input":{"file_path":""}}'; do
      run bash -c "echo '${payload}' | bash '${script}' 2>&1"
      # Exit 1 means the script itself errored — never acceptable.
      # 0 = allow, 2 = block are both legitimate.
      [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
    done
  done
}

# --- Breadth: every document in the repository, not just a representative one ---
#
# The tests above pin behaviour with one ADR and one proposal. These check the whole
# corpus, which is what catches a guard that works on the file it was developed
# against and fails on some other frontmatter shape.

@test "every accepted ADR is blocked" {
  local adr status result checked=0
  for adr in docs/decisions/*.md; do
    status=$(bash "${DOCS_HOOKS}/parse-frontmatter.sh" --file "$adr" --field status)
    [[ "$status" == "accepted" ]] || continue
    checked=$((checked + 1))
    result=0
    echo "{\"tool_input\":{\"file_path\":\"${adr}\"}}" | bash "${DOCS_HOOKS}/check-adr-immutability.sh" > /dev/null 2>&1 || result=$?
    [ "$result" -eq 2 ] || {
      echo "expected exit 2 for accepted ADR ${adr}, got ${result}"
      return 1
    }
  done
  [ "$checked" -gt 0 ]
}

@test "every terminal-status proposal is blocked" {
  local doc status result checked=0
  for doc in docs/proposals/*.md; do
    status=$(bash "${DOCS_HOOKS}/parse-frontmatter.sh" --file "$doc" --field status)
    case "$status" in
      accepted | rejected | superseded) ;;
      *) continue ;;
    esac
    checked=$((checked + 1))
    result=0
    echo "{\"tool_input\":{\"file_path\":\"${doc}\"}}" | bash "${DOCS_HOOKS}/check-proposal-lifecycle.sh" > /dev/null 2>&1 || result=$?
    [ "$result" -eq 2 ] || {
      echo "expected exit 2 for ${status} proposal ${doc}, got ${result}"
      return 1
    }
  done
  [ "$checked" -gt 0 ]
}

@test "every draft proposal is editable" {
  local doc status result
  for doc in docs/proposals/*.md; do
    status=$(bash "${DOCS_HOOKS}/parse-frontmatter.sh" --file "$doc" --field status)
    [[ "$status" == "draft" || "$status" == "in-review" ]] || continue
    result=0
    echo "{\"tool_input\":{\"file_path\":\"${doc}\"}}" | bash "${DOCS_HOOKS}/check-proposal-lifecycle.sh" > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] || {
      echo "expected exit 0 for ${status} proposal ${doc}, got ${result}"
      return 1
    }
  done
}

@test "every pipeline document passes the frontmatter guard" {
  local doc result
  for doc in docs/proposals/*.md docs/plans/*.md docs/decisions/*.md; do
    result=0
    echo "{\"tool_input\":{\"file_path\":\"${doc}\"}}" | bash "${DOCS_HOOKS}/check-required-frontmatter.sh" > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] || {
      echo "frontmatter guard rejected ${doc} (exit ${result})"
      return 1
    }
  done
}
