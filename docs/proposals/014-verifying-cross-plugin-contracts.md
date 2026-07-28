---
title: "Verifying Cross-Plugin File-Path Contracts"
number: "014"
status: draft
author: Alex
created: 2026-07-28
updated: 2026-07-28
supersedes: null
superseded_by: null
---

<!-- principled-ingested-from: #36 -->

# RFC-014: Verifying Cross-Plugin File-Path Contracts

## Audience

- Maintainers of any plugin that reads or writes state another plugin owns
- Anyone relying on the halt switch to stop an unattended run
- Reviewers deciding whether a path rename is safe

## Context

Ingested from [#36](https://github.com/alexnodeland/principled/issues/36).

`scripts/check-skill-references.sh` validates every `${CLAUDE_PLUGIN_ROOT}` path referenced
by a SKILL.md or hooks.json, and requires that references use that variable rather than a
bare relative path. That covers intra-plugin dependencies well — it is what caught
`spawn/SKILL.md` invoking a `parse-plan.sh` that had never been copied.

It cannot see the other class of dependency this repository now depends on.

### The gap

Plugins install independently, and `${CLAUDE_PLUGIN_ROOT}` resolves to exactly one plugin
(ADR-018). Where two plugins must cooperate, the only available coupling is a bare path at
the repository root:

| Path                      | Written by                | Read by                                        |
| ------------------------- | ------------------------- | ---------------------------------------------- |
| `.agents/HALT`            | principled-agent          | principled-implementation, at phase boundaries |
| `.impl/manifest.json`     | principled-implementation | principled-agent, read-only                    |
| `.principled/tasks.jsonl` | principled-tasks          | any plugin, read-only                          |

`docs/architecture/plugin-system.md` documents these and states plainly that they "are
invisible to `check-skill-references.sh` … and must be maintained by convention."

### Why this one matters more than it looks

The halt switch is the load-bearing case. `/orchestrate` stops at a phase boundary by
testing for `.agents/HALT` — a path it learns from prose, not from a checked reference.

If principled-agent renames or moves that file, **the kill switch silently stops
working**. No test fails, no reference breaks, and `/orchestrate` simply never halts. The
failure is invisible until someone needs to stop a runaway run and discovers they cannot,
which is precisely the scenario ADR-022 exists to prevent.

A convention that fails silently, guarding a mechanism whose entire purpose is to work
when things are going wrong, is not a convention worth keeping unverified.

## Proposal

Treat the contract table in `plugin-system.md` as a **declaration of record**, and verify
it in CI.

### 1. A machine-readable declaration

Parse the existing markdown table rather than introducing a second source of truth. The
table already exists, is already reviewed, and duplicating it into JSON would create
exactly the drift this repository has spent two ADRs eliminating.

### 2. What gets checked

For each declared contract path:

- **The writer exists.** At least one script in the named writing plugin references the
  literal path. A contract with no writer is either stale or a typo.
- **Readers agree on the literal path.** Every plugin named as a reader references the same
  string. A reader looking for `.agents/halt` while the writer creates `.agents/HALT` is
  the exact failure this is for.
- **No undeclared cross-plugin reads.** A plugin referencing another plugin's state path
  without a table entry is flagged, so the documentation cannot silently fall behind.

### 3. Where it lives

Extend `scripts/check-skill-references.sh` rather than adding a sibling script. It already
owns "references resolve" and runs in `just refs`; splitting the two halves would mean two
scripts, two CI steps, and a new question about which one a given failure belongs to.

## Alternatives Considered

### Alternative 1: A separate JSON manifest of contracts

Trivial to parse and unambiguous. Rejected because it duplicates the table in
`plugin-system.md`, and a duplicated declaration drifts — the precise problem ADR-018
solved by deleting copies rather than checking them.

### Alternative 2: Constants in each plugin's `lib/`

Each plugin exports its paths; readers source the writer's constants. Rejected outright:
it requires exactly the cross-plugin `${CLAUDE_PLUGIN_ROOT}` reference that ADR-018
establishes is impossible.

### Alternative 3: Integration tests that exercise the halt switch end to end

Highest fidelity — a renamed path fails a real test. Rejected as insufficient _alone_: it
would need a full orchestration run per contract, which is slow and requires agent
execution in CI. Worth doing later for the halt switch specifically; not the general
mechanism.

### Alternative 4: Accept the risk and document it

What we do today. Rejected because the documentation already admits the gap, and the
cost of closing it is one parser against a table that already exists.

## Consequences

### Positive

- A renamed or moved contract path fails CI instead of silently disabling the halt switch
- The `plugin-system.md` table stops being decorative and becomes enforced
- Undeclared cross-plugin coupling surfaces at review time
- No new dependency, no second source of truth, no new CI step

### Negative

- Parsing a markdown table is brittle in a way parsing JSON is not; a reformat could break
  the parser. Mitigated by matching on the path cells rather than on column positions
- Only literal-string references are detectable. A path assembled at runtime
  (`"${dir}/HALT"`) is invisible, so the check constrains how these paths may be written
- Another thing to update when adding a contract — though that is the point

### Risks

- **False confidence.** A passing check proves the strings match, not that the halt logic
  works. The distinction should be stated where the check reports, or it invites exactly
  the assumption it cannot support.

## Architecture Impact

- **Update:** `docs/architecture/plugin-system.md` — the contract table becomes normative,
  and its format becomes load-bearing
- **No new ADR.** This implements a check for a coupling ADR-018 and ADR-022 already
  established; it makes no new architectural choice

## Open Questions

None blocking. The one judgement call — parse the existing table rather than add a
manifest — is argued in Alternative 1.
