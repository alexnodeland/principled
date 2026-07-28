#!/usr/bin/env bash
# inject-agent-memory.sh — Surface accumulated agent memory at spawn (ADR-020)
#
# Fires on SubagentStart. Lifecycle events do not support matchers (ADR-015), so
# this script filters for agents that carry memory and exits quietly otherwise.
#
# Memory is written to stderr, which Claude Code returns to the agent as context.
# Global memory is emitted first, then the agent's own file.
#
# Injection is never truncated. An agent given a silently halved memory file has a
# confidently incomplete picture, which is worse than a large file because the loss
# is invisible. Oversized files are reported by check-memory-integrity.sh instead.
#
# Input: JSON on stdin, with the spawning agent's identifier
# Output: memory content to stderr
# Exit: Always 0 (advisory — a memory problem must never block a spawn)

set -euo pipefail

input=$(cat 2> /dev/null || true)

# --- Extract the agent identifier ------------------------------------------
# The field name has varied across Claude Code versions, so try the plausible
# ones rather than depending on one spelling.
agent_id=""
extract_field() {
  local field="$1"
  if command -v jq &> /dev/null; then
    echo "$input" | jq -r ".${field} // .tool_input.${field} // empty" 2> /dev/null || true
  else
    echo "$input" \
      | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -1 \
      | sed "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"//" \
      | sed 's/"$//' || true
  fi
}

for field in agent_id subagent_type agent_type agent; do
  agent_id="$(extract_field "$field")"
  if [[ -n "$agent_id" ]]; then
    break
  fi
done

# Nothing to do if we cannot tell who is spawning.
if [[ -z "$agent_id" ]]; then
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
AGENTS_DIR="${REPO_ROOT}/.agents"
GLOBAL_MEMORY="${AGENTS_DIR}/memory/global.md"
AGENT_MEMORY="${AGENTS_DIR}/memory/agents/${agent_id}.md"

# Not every repository has been initialized.
if [[ ! -d "$AGENTS_DIR" ]]; then
  exit 0
fi

# Only agents the registry marks memory:true receive anything — including global
# memory. An agent that runs a deterministic script learns nothing by definition
# (RFC-011), so injecting conventions into it spends context budget for no benefit.
# Absent an agent memory file, this agent is not a memory-bearing one.
if [[ ! -f "$AGENT_MEMORY" ]]; then
  exit 0
fi

# Read a memory file as of HEAD, not as it sits in the working tree.
#
# This is what makes the ADR-022 review gate bind on EFFECT rather than only on
# distribution. Reading the working tree meant an uncommitted edit was injected
# into the very next spawn: an agent could change what every subsequent agent in
# the same run believed, and produce code under the changed belief, before any
# reviewer saw a diff. "An agent proposes; a human decides" was true of how memory
# spreads and false of when it takes hold.
#
# Untracked files fall back to the working tree, so a fresh `--init` still works.
# The fallback is announced, because silently injecting unreviewed content is the
# behaviour being removed.
read_memory() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  local rel
  rel="${file#"${REPO_ROOT}/"}"

  if git -C "$REPO_ROOT" cat-file -e "HEAD:${rel}" 2> /dev/null; then
    git -C "$REPO_ROOT" show "HEAD:${rel}" 2> /dev/null
    return 0
  fi

  echo "[uncommitted: ${rel} is not in HEAD; injecting the working-tree copy]"
  cat "$file"
}

# The reviewed baseline: the default branch, if one is reachable.
#
# Reading HEAD stops an *uncommitted* edit from taking effect, but not an agent that
# commits memory on its own branch — that branch's HEAD contains it, so it is injected
# for the rest of the run. Injecting from the baseline instead would close that, at the
# cost of making memory changes untestable on the branch that proposes them.
#
# So the hole is made visible rather than closed: if what is being injected differs from
# the baseline, the agent is told the content is unreviewed. Silent is the failure mode;
# an agent acting on unreviewed memory should at least know that is what it is doing.
baseline_ref() {
  local ref
  for ref in origin/HEAD origin/main origin/master main master; do
    if git -C "$REPO_ROOT" rev-parse --verify --quiet "${ref}^{commit}" > /dev/null 2>&1; then
      echo "$ref"
      return 0
    fi
  done
  return 1
}

# Emit a warning when a file's committed content differs from the baseline.
warn_if_unreviewed() {
  local file="$1" base="$2"
  [[ -n "$base" ]] || return 0

  local rel
  rel="${file#"${REPO_ROOT}/"}"

  # Not on the baseline at all — wholly unreviewed.
  if ! git -C "$REPO_ROOT" cat-file -e "${base}:${rel}" 2> /dev/null; then
    echo "[UNREVIEWED: ${rel} does not exist on ${base}. This memory has not been merged.]"
    return 0
  fi

  local here there
  here="$(git -C "$REPO_ROOT" rev-parse "HEAD:${rel}" 2> /dev/null || echo "")"
  there="$(git -C "$REPO_ROOT" rev-parse "${base}:${rel}" 2> /dev/null || echo "")"
  if [[ -n "$here" && -n "$there" && "$here" != "$there" ]]; then
    echo "[UNREVIEWED: ${rel} differs from ${base}. Treat the differences as proposed, not settled.]"
  fi
}

# Print everything after the closing frontmatter delimiter. Frontmatter is
# metadata for scripts; the agent only needs the prose.
emit_body() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local content
  content="$(read_memory "$file")"
  [[ -n "$content" ]] || return 0

  if [[ "$(printf '%s\n' "$content" | head -1)" != "---" ]]; then
    printf '%s\n' "$content"
    return 0
  fi
  printf '%s\n' "$content" | awk '
    NR == 1 { next }
    !done && /^---[[:space:]]*$/ { done = 1; next }
    done { print }
  '
}

BASELINE="$(baseline_ref || true)"

{
  echo "=== Accumulated memory for '${agent_id}' ==="
  echo "Source: .agents/memory/ as of HEAD — uncommitted edits are NOT injected (ADR-020, ADR-022)"
  if [[ -n "$BASELINE" ]]; then
    warn_if_unreviewed "$GLOBAL_MEMORY" "$BASELINE"
    warn_if_unreviewed "$AGENT_MEMORY" "$BASELINE"
  fi
  echo ""

  if [[ -f "$GLOBAL_MEMORY" ]]; then
    echo "--- Global (applies to every agent) ---"
    emit_body "$GLOBAL_MEMORY"
    echo ""
  fi

  if [[ -f "$AGENT_MEMORY" ]]; then
    echo "--- ${agent_id} ---"
    emit_body "$AGENT_MEMORY"
    echo ""
  fi

  echo "=== End memory ==="
} >&2

exit 0
