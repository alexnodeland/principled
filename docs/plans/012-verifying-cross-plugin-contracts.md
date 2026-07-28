---
title: "Verifying Cross-Plugin File-Path Contracts"
number: "012"
status: complete
author: Alex
created: 2026-07-28
updated: 2026-07-28
originating_proposal: "014"
related_adrs: ["018", "022"]
---

<!-- principled-ingested-from: #36 -->

# Plan-012: Verifying Cross-Plugin File-Path Contracts

## Objective

Implements [RFC-014](../proposals/014-verifying-cross-plugin-contracts.md), closing
[#36](https://github.com/alexnodeland/principled/issues/36).

Make the cross-plugin contract table in `docs/architecture/plugin-system.md` normative:
parse it, verify every declared path has a writer and consistent readers, and fail CI when
a rename would silently disable the halt switch.

## Related Decisions

- [ADR-018](../decisions/018-shared-plugin-lib-over-copies.md) — plugins install
  independently and cannot reference each other's `${CLAUDE_PLUGIN_ROOT}`, which is _why_
  these bare-path contracts exist at all
- [ADR-022](../decisions/022-agent-governance-constraints.md) — the halt switch is the
  load-bearing contract; a silent break defeats its purpose

## Domain Analysis

### Bounded Contexts

**Contract Declaration** (`docs/architecture/plugin-system.md`) — the table is the source
of truth. RFC-014 chose to parse it rather than duplicate it into JSON, so its format
becomes load-bearing.

**Contract Verification** (`scripts/check-skill-references.sh`) — extends the existing
"references resolve" check rather than adding a sibling, so `just refs` stays one command
and a failure has one home.

### Aggregates

| Aggregate    | Root                               | Invariants                                             |
| ------------ | ---------------------------------- | ------------------------------------------------------ |
| Contract row | a table row in `plugin-system.md`  | Path, writer plugin, reader plugins all present        |
| Path usage   | literal string in a plugin's files | Writer references it; every declared reader matches it |

### Domain Events

- **ContractDeclared** → a row is added to the table
- **ContractViolated** → a declared path has no writer, or readers disagree on the literal
- **UndeclaredCoupling** → a plugin references another's state path with no table row

## Implementation Tasks

### Phase 1: Parse the declaration

- [x] Extract the contract table from `docs/architecture/plugin-system.md`, keyed on the
      backticked path in the first cell rather than on column position, so a prettier
      reformat does not break it
- [x] Map the writer and reader cells to plugin directory names, tolerating the prose that
      appears alongside them ("at phase boundaries", "read-only", "any plugin")
- [x] Fail loudly if the table is missing or unparseable — a silently skipped check is the
      failure mode this plan exists to remove

### Phase 2: Verify usage

- [x] For each contract path, confirm at least one file in the writing plugin contains the
      literal string
- [x] Confirm every named reader plugin contains the same literal string; treat "any
      plugin" as no reader requirement
- [x] Report each result in the existing output style, and make clear the check compares
      strings rather than proving the halt logic works (RFC-014's stated risk)

### Phase 3: Tests and integration

- [x] `tests/contract-verification.bats` — a renamed path fails, a missing writer fails, a
      reader typo fails, and the real repository passes
- [x] Confirm `just refs` and the CI job pick it up with no workflow change
- [x] ShellCheck and shfmt clean; bash 3.2 compatible; jq not required

### Phase 4: Documentation

- [x] Note in `plugin-system.md` that the table is verified, and that its format matters
- [x] Update `CLAUDE.md` § Testing to describe the new check

## Dependencies

All shipped. No new tooling, no new CI step, no `jq` requirement.

## Acceptance Criteria

- [x] Renaming `.agents/HALT` in principled-agent fails CI
- [x] A reader referencing a different literal fails CI
- [x] All three declared contracts pass against the repository as it stands
- [x] The check runs inside `just refs` with no workflow change
- [x] Output states plainly that it verifies strings, not behaviour
- [x] ShellCheck and shfmt clean, bash 3.2 compatible
- [x] `just ci` passes

## Verification

`just ci` green — 170 bats tests, up from 158. `tests/contract-verification.bats` (12
tests) copies the repository into a temp directory and mutates the copy, so the failure
cases are constructed rather than asserted:

- renaming `.agents/HALT` in the writer fails
- a reader drifting to `.agents/halt` fails
- an undeclared cross-plugin reader fails
- a contract naming a nonexistent plugin fails
- a missing table fails loudly rather than passing vacuously
- reflowing the table columns does **not** break the parser (prettier reflowed this very
  table during the run, which exercised it for real)

The acceptance criterion said "all three declared contracts pass". There are four —
`.agents/` was in the table and the criterion undercounted it. All four pass.

## What the check found immediately

`.impl/manifest.json` was declared as read only by principled-agent. It is also read by
**principled-github** — `pr-describe/scripts/task-manifest.sh` opens the file directly —
and referenced by principled-tasks' `task-model.md`. Real coupling, undocumented. The
table now declares all three readers.

That is the check earning its place on its first run: the gap it found was not
hypothetical, and nothing else in CI could have surfaced it.

## A bug in the check itself

The first implementation reported every reader on a multi-reader row as undeclared.
`declared_readers` was newline-separated while the membership test was a glob against
`" $declared_readers "`, so a newline never matched. The single-reader rows passed and
masked it; the three-reader manifest row exposed it. Fixed by normalizing to
space-separated, and pinned by the "multi-reader row" test.

## Limits, stated plainly

The check compares **literal strings**. A green result means the declaration matches the
code — not that the halt logic works. A path assembled at runtime (`"${dir}/HALT"`) is
invisible to it, which constrains how these paths may be written.
