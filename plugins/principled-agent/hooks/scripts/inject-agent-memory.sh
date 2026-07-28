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

# Print everything after the closing frontmatter delimiter. Frontmatter is
# metadata for scripts; the agent only needs the prose.
emit_body() {
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

{
  echo "=== Accumulated memory for '${agent_id}' ==="
  echo "Source: .agents/memory/ (committed to git, revisable in review — ADR-020)"
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
