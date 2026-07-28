#!/usr/bin/env bash
# check-memory-integrity.sh — Advisory integrity check for agent memory files
#
# Fires after a write to anything under .agents/. Validates frontmatter structure
# and reports against the context budget from RFC-011:
#
#   under 8 KB      silent
#   8 KB to 16 KB   warn, suggest synthesis
#   over 16 KB      warn loudly
#
# The budget is about context, not disk: every byte is injected at spawn and
# competes with the task description. It is advisory because the cure — synthesis
# — requires judgment this script does not have.
#
# Input: JSON on stdin with tool_input.file_path
# Output: Warnings to stderr
# Exit: Always 0 (advisory)

set -euo pipefail

SOFT_LIMIT_BYTES=8192
HARD_LIMIT_BYTES=16384

input=$(cat 2> /dev/null || true)

file_path=""
if command -v jq &> /dev/null; then
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2> /dev/null || true)
else
  file_path=$(echo "$input" \
    | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' \
    | sed 's/"$//' || true)
fi

if [[ -z "$file_path" ]]; then
  exit 0
fi

# Only concerned with agent state.
case "$file_path" in
*/.agents/* | .agents/*) ;;
*) exit 0 ;;
esac

# The registry is JSON, not a memory document — different checks apply.
if [[ "$file_path" == *"registry.json"* ]]; then
  if [[ -f "$file_path" ]] && command -v jq &> /dev/null; then
    if ! jq . "$file_path" > /dev/null 2>&1; then
      echo "⚠️  Advisory: .agents/registry.json is not valid JSON." >&2
      echo "   Agent lookup and memory injection will silently skip agents until this parses." >&2
    fi
  fi
  exit 0
fi

# Retrospectives are prose; no budget applies.
case "$file_path" in
*/retrospectives/*) exit 0 ;;
esac

# Global memory is injected into every memory-bearing agent, so a line here costs a
# line in every agent's context and changes what all of them believe. Say so loudly.
#
# This is advisory, not blocking, and deliberately: a PreToolUse guard cannot tell an
# agent editing this file from a human curating it, so blocking would stop the
# maintainer along with the agent. The mechanical protection is elsewhere —
# inject-agent-memory.sh reads HEAD, so nothing here takes effect until it is
# committed and reviewed.
case "$file_path" in
*/memory/global.md)
  echo "⚠️  Advisory: writing to global agent memory." >&2
  echo "   global.md is injected into EVERY memory-bearing agent, so this changes what" >&2
  echo "   all of them believe. It is the highest-blast-radius file in the repository." >&2
  echo "   Injection reads HEAD, so this takes effect only once committed and merged —" >&2
  echo "   make sure the reviewer sees it as its own change, not buried in a larger PR." >&2
  ;;
esac

# Only memory markdown files past this point.
case "$file_path" in
*.md) ;;
*) exit 0 ;;
esac

if [[ ! -f "$file_path" ]]; then
  exit 0
fi

# --- Frontmatter structure -------------------------------------------------
if [[ "$(head -1 "$file_path")" != "---" ]]; then
  echo "⚠️  Advisory: ${file_path} has no YAML frontmatter." >&2
  echo "   Memory files are frontmatter + markdown (ADR-020). Without frontmatter," >&2
  echo "   metrics and integrity checks cannot read this file." >&2
  exit 0
fi

# The agent_id must match the filename, or injection will look up the wrong file.
base="$(basename "$file_path" .md)"
case "$file_path" in
*/memory/agents/*)
  declared="$(awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^agent_id:/ {
      v = $0
      sub(/^agent_id:[[:space:]]*/, "", v)
      gsub(/^"|"$/, "", v)
      print v
      exit
    }
  ' "$file_path")"

  if [[ -n "$declared" && "$declared" != "$base" ]]; then
    echo "⚠️  Advisory: ${file_path} declares agent_id '${declared}' but is named '${base}.md'." >&2
    echo "   Memory is looked up by filename, so this file will never be injected for" >&2
    echo "   '${declared}'. Rename the file or correct the frontmatter." >&2
  fi
  ;;
esac

# --- Context budget --------------------------------------------------------
size="$(wc -c < "$file_path" | awk '{print $1}')"

if [[ "$size" -gt "$HARD_LIMIT_BYTES" ]]; then
  echo "⚠️  Advisory: ${file_path} is ${size} bytes, well over the ${HARD_LIMIT_BYTES} byte budget." >&2
  echo "   Every byte is injected at spawn and competes with the task description." >&2
  echo "   Synthesize it into fewer, denser statements — injection is never truncated," >&2
  echo "   so this file will be delivered in full at whatever size it reaches." >&2
elif [[ "$size" -gt "$SOFT_LIMIT_BYTES" ]]; then
  echo "⚠️  Advisory: ${file_path} is ${size} bytes, over the ${SOFT_LIMIT_BYTES} byte soft budget." >&2
  echo "   Consider synthesizing accumulated notes into fewer, denser statements." >&2
fi

exit 0
