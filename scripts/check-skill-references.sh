#!/usr/bin/env bash
# check-skill-references.sh — Verify every script a skill invokes actually exists.
#
# Drift checkers compare copies that exist. Nothing verified the inverse: that a path
# a SKILL.md tells Claude to run resolves to a real file. spawn/SKILL.md invoked
# scripts/parse-plan.sh for months while that file existed only in decompose and
# orchestrate. Drift checks passed the whole time, because a missing copy is invisible
# to a checker that only diffs pairs it was told about.
#
# Two reference styles are recognized:
#   bash "${CLAUDE_PLUGIN_ROOT}/lib/foo.sh"   resolved against the plugin root
#   bash scripts/foo.sh                       resolved against the skill directory
#
# Bare relative paths are also reported as warnings: they only resolve when the
# working directory happens to be the skill directory, which is not guaranteed at
# runtime. ${CLAUDE_PLUGIN_ROOT} is the portable form and is what hooks.json uses.
#
# Exit: 0 = all references resolve, 1 = at least one is broken.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BROKEN=0
WARNINGS=0
CHECKED=0

echo "Checking skill script references..."
echo ""

for skill_md in plugins/*/skills/*/SKILL.md; do
  [[ -f "$skill_md" ]] || continue

  skill_dir="$(dirname "$skill_md")"
  plugin_root="${skill_md%%/skills/*}"

  # Style 1: ${CLAUDE_PLUGIN_ROOT}/<path>
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    ref="${ref#*\}/}"
    CHECKED=$((CHECKED + 1))
    target="${plugin_root}/${ref}"
    if [[ ! -e "$target" ]]; then
      echo "BROKEN: $skill_md"
      echo "        references \${CLAUDE_PLUGIN_ROOT}/${ref}"
      echo "        expected at $target"
      BROKEN=$((BROKEN + 1))
    fi
  done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$skill_md" 2> /dev/null | sort -u)

  # Style 2: bare relative scripts/ or templates/ path
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    CHECKED=$((CHECKED + 1))
    target="${skill_dir}/${ref}"
    if [[ ! -e "$target" ]]; then
      echo "BROKEN: $skill_md"
      echo "        references ${ref} (relative to skill directory)"
      echo "        expected at $target"
      BROKEN=$((BROKEN + 1))
    else
      echo "WARN:   $skill_md references ${ref} by bare relative path."
      echo "        Use \${CLAUDE_PLUGIN_ROOT}/... — a relative path only resolves"
      echo "        when the working directory is the skill directory."
      WARNINGS=$((WARNINGS + 1))
    fi
  done < <(grep -oE '(bash|source)[[:space:]]+(scripts|templates)/[A-Za-z0-9._-]+' "$skill_md" 2> /dev/null \
    | awk '{print $2}' | sort -u)

  # Style 3: cross-skill ../sibling/ references
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    CHECKED=$((CHECKED + 1))
    target="${skill_dir}/${ref}"
    if [[ ! -e "$target" ]]; then
      echo "BROKEN: $skill_md"
      echo "        references sibling skill path ${ref}"
      echo "        expected at $target"
      BROKEN=$((BROKEN + 1))
    else
      echo "WARN:   $skill_md reaches into a sibling skill via ${ref}."
      echo "        Shared code belongs in the plugin's lib/ (ADR-018)."
      WARNINGS=$((WARNINGS + 1))
    fi
  done < <(grep -oE '(bash|source)[[:space:]]+\.\./[A-Za-z0-9._/-]+' "$skill_md" 2> /dev/null \
    | awk '{print $2}' | sort -u)
done

# Hook commands must resolve too — a broken hook path fails silently at runtime.
for hooks_json in plugins/*/hooks/hooks.json; do
  [[ -f "$hooks_json" ]] || continue
  plugin_root="${hooks_json%%/hooks/hooks.json}"

  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    ref="${ref#*\}/}"
    CHECKED=$((CHECKED + 1))
    target="${plugin_root}/${ref}"
    if [[ ! -e "$target" ]]; then
      echo "BROKEN: $hooks_json"
      echo "        references \${CLAUDE_PLUGIN_ROOT}/${ref}"
      echo "        expected at $target"
      BROKEN=$((BROKEN + 1))
    fi
  done < <(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$hooks_json" 2> /dev/null | sort -u)
done

echo ""
echo "Checked ${CHECKED} references."

if [[ "$BROKEN" -gt 0 ]]; then
  echo "FAIL: ${BROKEN} reference(s) do not resolve."
  exit 1
fi

# Every reference now uses ${CLAUDE_PLUGIN_ROOT}, so a bare-relative or cross-skill
# path is a regression rather than a leftover. Fail on it: relative paths only resolve
# when the working directory happens to be the skill directory, and cross-skill
# reaching is what lib/ exists to replace (ADR-018).
if [[ "$WARNINGS" -gt 0 ]]; then
  echo "FAIL: ${WARNINGS} non-portable reference(s)."
  echo ""
  echo "Use \${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/<name> for a skill's own"
  echo "scripts, or move shared code to the plugin's lib/ and reference"
  echo "\${CLAUDE_PLUGIN_ROOT}/lib/<name>."
  exit 1
fi

echo "PASS: All ${CHECKED} references resolve and use a portable path."
