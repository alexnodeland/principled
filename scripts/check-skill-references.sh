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

# ===========================================================================
# Cross-plugin file-path contracts (RFC-014)
#
# Plugins install independently and cannot reference each other's
# ${CLAUDE_PLUGIN_ROOT} (ADR-018), so where two must cooperate the coupling is a
# bare path at the repository root. Those paths are invisible to the reference
# check above: nothing resolves them, and a rename breaks them silently.
#
# The halt switch is the case that matters. /orchestrate stops at a phase boundary
# by testing for .agents/HALT — a path it learns from prose. Rename it and the kill
# switch stops working with no failing test, which is exactly the scenario ADR-022
# exists to prevent.
#
# The contract table in docs/architecture/plugin-system.md is the declaration of
# record. It is parsed rather than duplicated into a manifest, because a duplicated
# declaration drifts — the problem ADR-018 solved by deleting copies.
#
# NOTE: this compares literal strings. It proves the declaration matches the code;
# it does not prove the halt logic works.
# ===========================================================================

CONTRACT_DOC="${REPO_ROOT}/docs/architecture/plugin-system.md"
CONTRACT_FAILURES=0
CONTRACTS_CHECKED=0

echo ""
echo "Checking cross-plugin file-path contracts..."

if [[ ! -f "$CONTRACT_DOC" ]]; then
  echo "FAIL: contract declaration not found at docs/architecture/plugin-system.md"
  exit 1
fi

# Extract the contract table. Keyed on the backticked path in the first cell rather
# than on column position, so a formatter reflowing the columns does not break it.
CONTRACT_ROWS="$(awk '
  /^## Cross-plugin coupling/ { in_section = 1; next }
  in_section && /^## / { exit }
  in_section && /^\|[[:space:]]*`/ {
    line = $0
    sub(/^\|[[:space:]]*/, "", line)
    n = split(line, cell, "|")
    if (n < 3) next
    path = cell[1]; writer = cell[2]; readers = cell[3]
    gsub(/`/, "", path)
    gsub(/^[ \t]+|[ \t]+$/, "", path)
    gsub(/^[ \t]+|[ \t]+$/, "", writer)
    gsub(/^[ \t]+|[ \t]+$/, "", readers)
    if (path == "" || path == "Path") next
    print path "\t" writer "\t" readers
  }
' "$CONTRACT_DOC")"

if [[ -z "$CONTRACT_ROWS" ]]; then
  echo "FAIL: no contract rows parsed from docs/architecture/plugin-system.md."
  echo "      The table under '## Cross-plugin coupling' is the declaration of record;"
  echo "      a silently empty parse would let every contract go unchecked."
  exit 1
fi

# Names of plugins mentioned in a table cell.
plugins_in_cell() {
  printf '%s' "$1" | grep -oE 'principled-[a-z]+' | sort -u
}

# Does a plugin reference this literal path anywhere in its tree?
# Markdown counts: a SKILL.md instructing the model to read a path IS the read.
plugin_references_path() {
  grep -rqF -- "$2" "${REPO_ROOT}/plugins/$1" 2> /dev/null
}

while IFS="$(printf '\t')" read -r c_path c_writer c_readers; do
  [[ -n "$c_path" ]] || continue
  CONTRACTS_CHECKED=$((CONTRACTS_CHECKED + 1))

  writer_plugin="$(plugins_in_cell "$c_writer" | head -1)"
  if [[ -z "$writer_plugin" ]]; then
    echo "  FAIL: ${c_path} — no writing plugin named in the table"
    CONTRACT_FAILURES=$((CONTRACT_FAILURES + 1))
    continue
  fi

  if [[ ! -d "${REPO_ROOT}/plugins/${writer_plugin}" ]]; then
    echo "  FAIL: ${c_path} — declared writer '${writer_plugin}' is not a plugin"
    CONTRACT_FAILURES=$((CONTRACT_FAILURES + 1))
    continue
  fi

  if ! plugin_references_path "$writer_plugin" "$c_path"; then
    echo "  FAIL: ${c_path} — declared writer '${writer_plugin}' never references it"
    echo "        Either the path was renamed, or the declaration is stale."
    CONTRACT_FAILURES=$((CONTRACT_FAILURES + 1))
    continue
  fi

  # "any plugin" is an explicit wildcard: no reader requirement, and undeclared
  # readers are expected rather than a finding.
  if printf '%s' "$c_readers" | grep -qi 'any plugin'; then
    echo "  OK: ${c_path} — writer ${writer_plugin}, readers unrestricted"
    continue
  fi

  row_failed=0
  # Space-separated, not newline-separated: the membership test below is a glob
  # against " $declared_readers ", and a newline separator silently never matches —
  # which flags every reader on a multi-reader row as undeclared.
  declared_readers="$(plugins_in_cell "$c_readers" | tr '\n' ' ')"

  for reader in $declared_readers; do
    if [[ ! -d "${REPO_ROOT}/plugins/${reader}" ]]; then
      echo "  FAIL: ${c_path} — declared reader '${reader}' is not a plugin"
      CONTRACT_FAILURES=$((CONTRACT_FAILURES + 1))
      row_failed=1
      continue
    fi
    if ! plugin_references_path "$reader" "$c_path"; then
      echo "  FAIL: ${c_path} — declared reader '${reader}' does not use this literal"
      echo "        A reader looking for a different string is the silent break."
      CONTRACT_FAILURES=$((CONTRACT_FAILURES + 1))
      row_failed=1
    fi
  done

  # Any plugin using the path that the table does not account for is undeclared
  # coupling: real, and invisible to review until it breaks.
  for candidate_dir in "${REPO_ROOT}"/plugins/*/; do
    candidate="$(basename "$candidate_dir")"
    [[ "$candidate" == "$writer_plugin" ]] && continue
    case " $declared_readers " in
    *" $candidate "*) continue ;;
    esac
    if plugin_references_path "$candidate" "$c_path"; then
      echo "  FAIL: ${c_path} — '${candidate}' references it but is not declared"
      echo "        Add it to the table, or remove the reference."
      CONTRACT_FAILURES=$((CONTRACT_FAILURES + 1))
      row_failed=1
    fi
  done

  if [[ "$row_failed" -eq 0 ]]; then
    echo "  OK: ${c_path} — writer ${writer_plugin}, readers ${declared_readers% }"
  fi
done << EOF
$CONTRACT_ROWS
EOF

echo ""
echo "Checked ${CONTRACTS_CHECKED} cross-plugin contract(s)."

if [[ "$CONTRACT_FAILURES" -gt 0 ]]; then
  echo "FAIL: ${CONTRACT_FAILURES} contract violation(s)."
  echo ""
  echo "The table under '## Cross-plugin coupling' in"
  echo "docs/architecture/plugin-system.md is the declaration of record. Update it,"
  echo "or fix the code to match."
  exit 1
fi

echo ""
echo "PASS: All ${CHECKED} references resolve and use a portable path."
echo "PASS: All ${CONTRACTS_CHECKED} declared contracts match the code (literal strings only)."
