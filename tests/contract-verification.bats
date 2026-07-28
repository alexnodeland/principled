#!/usr/bin/env bats
# Tests for the cross-plugin contract verification in
# scripts/check-skill-references.sh (RFC-014, Plan-012).
#
# The check exists because the halt switch is coupled by a bare path that nothing
# resolves: /orchestrate tests for .agents/HALT, a string it learns from prose. Rename
# it and the kill switch stops working with no failing test — the exact scenario
# ADR-022 exists to prevent.
#
# So the load-bearing test here is not "the repository passes". It is "a rename FAILS".
# A checker that cannot fail is decoration, and the repository already had one form of
# that: the table these contracts live in was documented as unverified.
#
# Each test copies the repository into a temp directory and mutates the copy, so a
# failure case can be constructed without touching the working tree.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  WORK="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$WORK"
  # Copy only what the check reads: the declaration and the plugin tree.
  mkdir -p "${WORK}/scripts" "${WORK}/docs/architecture" "${WORK}/plugins"
  cp "${REPO_ROOT}/scripts/check-skill-references.sh" "${WORK}/scripts/"
  cp "${REPO_ROOT}/docs/architecture/plugin-system.md" "${WORK}/docs/architecture/"
  cp -R "${REPO_ROOT}/plugins/." "${WORK}/plugins/"
  CHECK="${WORK}/scripts/check-skill-references.sh"
  DOC="${WORK}/docs/architecture/plugin-system.md"
}

# Run the check and return only the contract section, so assertions are not confused
# by the reference-resolution output above it.
run_contracts() {
  run bash "$CHECK"
}

# --- The repository as it stands ---

@test "every declared contract passes against the real repository" {
  run_contracts
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "declared contracts match the code"
}

@test "all four contracts are discovered, not silently skipped" {
  run_contracts
  echo "$output" | grep -q "Checked 4 cross-plugin contract(s)"
}

@test "the halt switch contract is among them" {
  run_contracts
  echo "$output" | grep -q "OK: .agents/HALT — writer principled-agent"
}

# --- The failure this exists to catch ---

@test "renaming the halt switch everywhere in the writer fails the check" {
  # A complete rename: principled-agent drops the path entirely.
  grep -rlF '.agents/HALT' "${WORK}/plugins/principled-agent" \
    | while IFS= read -r f; do
      sed 's|\.agents/HALT|.agents/STOP|g' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    done
  run_contracts
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "does not contain it"
}

@test "renaming the halt switch in ONLY the implementing file fails the check" {
  # The regression from #40, and the more likely refactor: someone edits the
  # implementation and does not grep for stale mentions. principled-agent references
  # .agents/HALT in three files, so a plugin-granular check passed here while the
  # kill switch was genuinely broken — the exact failure RFC-014 targeted.
  #
  # The original test suite missed this because it renamed across every file in the
  # plugin, sharing the check's blind spot.
  f="${WORK}/plugins/principled-agent/lib/agent-governance.sh"
  sed 's|\.agents/HALT|.agents/STOPPED|g' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"

  # Stale references survive elsewhere in the plugin — that is what made it invisible.
  [ "$(grep -rlF '.agents/HALT' "${WORK}/plugins/principled-agent" | wc -l | tr -d ' ')" -gt 0 ]

  run_contracts
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "agent-governance.sh does not contain it"
}

@test "a writer declared as a bare plugin name is rejected" {
  # Plugin granularity cannot catch a partial rename, so it is not an accepted
  # declaration form.
  python3 - "$DOC" << 'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
t = t.replace("`principled-agent/lib/agent-governance.sh`", "principled-agent")
p.write_text(t)
PY
  run_contracts
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "writer must be a plugin-relative file path"
}

@test "a declared writing file that does not exist fails" {
  python3 - "$DOC" << 'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
t = t.replace("`principled-agent/lib/agent-governance.sh`",
              "`principled-agent/lib/does-not-exist.sh`")
p.write_text(t)
PY
  run_contracts
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "declared writing file does not exist"
}

@test "a reader drifting to a different literal fails the check" {
  # principled-implementation looks for a path principled-agent never writes.
  grep -rlF '.agents/HALT' "${WORK}/plugins/principled-implementation" \
    | while IFS= read -r f; do
      sed 's|\.agents/HALT|.agents/halt|g' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    done
  run_contracts
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "declared reader 'principled-implementation' does not use this literal"
}

@test "an undeclared cross-plugin reader fails the check" {
  # principled-release starts reading the manifest without a table entry.
  printf 'Reads .agents/HALT for no good reason.\n' >> "${WORK}/plugins/principled-release/README.md"
  run_contracts
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "'principled-release' references it but is not declared"
}

@test "a contract naming a nonexistent plugin fails" {
  python3 - "$DOC" << 'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
t = t.replace("`principled-agent/lib/agent-governance.sh`",
              "`principled-nope/lib/agent-governance.sh`")
p.write_text(t)
PY
  run_contracts
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "is not a plugin"
}

# --- Parser robustness ---

@test "a missing declaration table fails loudly rather than passing vacuously" {
  # The contract section is currently the last in the file, so a lookahead for a
  # following heading would match nothing and silently leave the table in place.
  python3 - "$DOC" << 'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); t = p.read_text()
new, n = re.subn(r'^## Cross-plugin coupling.*?(?=^## |\Z)', '', t, flags=re.S | re.M)
assert n == 1 and '## Cross-plugin coupling' not in new, "section was not removed"
p.write_text(new)
PY
  run_contracts
  [ "$status" -eq 1 ]
  # A silently empty parse would let every contract go unchecked — worse than no check.
  echo "$output" | grep -q "no contract rows parsed"
}

@test "reflowing the table columns does not break the parser" {
  # The parser keys on the backticked path, not on column width. Prettier reflows
  # these columns whenever a cell changes length, so this must not matter.
  python3 - "$DOC" << 'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); t = p.read_text()
out = []
for line in t.splitlines():
    if line.startswith('| `') or re.match(r'^\| -+ \|', line):
        line = re.sub(r'[ \t]+\|', ' |', line)
        line = re.sub(r'\|[ \t]+', '| ', line)
    out.append(line)
p.write_text("\n".join(out) + "\n")
PY
  run_contracts
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Checked 4 cross-plugin contract(s)"
}

@test "a multi-reader row accepts every declared reader" {
  # Regression: declared readers were newline-separated while the membership test was
  # a glob against " $readers ", so a newline never matched and every reader on a
  # multi-reader row was reported undeclared. The manifest row has three.
  run_contracts
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "OK: .impl/manifest.json"
  ! echo "$output" | grep -q "principled-github' references it but is not declared"
}

@test "an 'any plugin' wildcard imposes no reader requirement" {
  # .principled/tasks.jsonl is readable by anything; adding a new reader must not fail.
  printf 'Mentions .principled/tasks.jsonl in passing.\n' >> "${WORK}/plugins/principled-quality/README.md"
  run_contracts
  [ "$status" -eq 0 ]
}

# --- Reporting honesty ---

@test "the check states that it compares strings rather than behaviour" {
  run_contracts
  # Without this, a green check reads as "the halt switch works", which it cannot prove.
  echo "$output" | grep -q "literal strings only"
}
