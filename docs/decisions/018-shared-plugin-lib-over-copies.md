---
title: "Shared Plugin lib/ Over Copy-With-Drift-Detection"
number: "018"
status: accepted
author: Alex
created: 2026-07-28
updated: 2026-07-28
supersedes: "009"
superseded_by: null
---

# ADR-018: Shared Plugin lib/ Over Copy-With-Drift-Detection

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

ADR-009 established that skills must be self-contained — no cross-skill imports — and
that scripts needed by several skills are duplicated byte-for-byte, with CI verifying
the copies match a canonical source. That decision has now been exercised across seven
plugins, and the evidence is in.

### What the convention costs

| Measure                                            | Count                      |
| -------------------------------------------------- | -------------------------- |
| Identical copies of `check-gh-cli.sh`              | 15                         |
| Identical copies of `task-manifest.sh` (470 lines) | 5                          |
| Redundant lines across `plugins/`                  | 3,382 of 17,114 (20%)      |
| Drift-checker scripts written to police copies     | 6                          |
| CI jobs dedicated to drift checking                | 6                          |
| Dev skills existing only to propagate copies       | 1 (`/propagate-templates`) |

One fifth of the plugin tree is copy-paste, and a whole subsystem exists to simulate
what a shared directory provides for free.

### The stated reason does not hold

ADR-009 rejected a plugin-level shared directory on the grounds of "path resolution
complexity: scripts must compute relative paths to the shared directory."

That is not what the platform requires. `${CLAUDE_PLUGIN_ROOT}` resolves to the
plugin's root at runtime, and this repository already depends on it 18 times — in
every plugin's `hooks.json` and in `impl-worker.md`. Hooks have always referenced
plugin-root-relative paths without difficulty. The objection described a problem that
the codebase had already solved before ADR-009 was written.

### The invariant is not actually held

Six cross-skill imports already exist in shipped plugins:

```
principled-architecture/skills/arch-drift/SKILL.md:33   bash ../arch-map/scripts/scan-modules.sh
principled-release/skills/tag-release/SKILL.md:55       bash ../release-ready/scripts/check-readiness.sh
principled-release/skills/tag-release/SKILL.md:69       bash ../changelog/scripts/collect-changes.sh
principled-release/skills/release-plan/SKILL.md:50,56,62 (three more)
```

So the duplication tax is being paid to preserve an invariant that two of seven
plugins already violate — and violate using the sibling-directory pattern ADR-009
rejected.

### Drift detection does not detect drift

The mechanism also fails at its own job. In principled-tasks, `task-db.sh` was copied
to six skills; the drift checker enumerated only five. The sixth copy diverged, and CI
reported `PASS: All copies match canonical.` A checker that must be hand-updated with
every new copy will silently miss copies, which is precisely the failure it exists to
prevent.

Separately, nothing verifies the inverse: `spawn/SKILL.md` referenced
`scripts/parse-plan.sh`, which was never copied into `spawn`. The drift checker passed
because it only compares copies that exist; it never asks whether referenced files are
present.

## Decision

**Code shared by more than one skill within a plugin lives in that plugin's `lib/`,
referenced as `${CLAUDE_PLUGIN_ROOT}/lib/<name>.sh`. Copies and drift checkers are
removed.**

Skills remain self-contained in the sense that matters: each owns its own `SKILL.md`,
prompts, and templates. What they stop owning is redundant copies of shared code.

The plugin — not the skill — is the unit of distribution. Skills inside a plugin are
installed together, versioned together, and removed together; there is no scenario in
which one arrives without the others. Skill-level self-containment bought nothing that
plugin-level self-containment does not already provide.

Cross-plugin sharing is a separate question and is **not** addressed here. Plugins are
independently installable, so a script needed by two plugins still needs a deliberate
answer (see Open Questions).

## Options Considered

### Option 1: Plugin-level `lib/` via `${CLAUDE_PLUGIN_ROOT}` (chosen)

**Pros:**

- One copy; drift is impossible rather than merely detected
- Deletes ~3,400 redundant lines, 6 drift checkers, 6 CI jobs, and one dev skill
- Uses the same resolution mechanism `hooks.json` already relies on
- New shared code needs no checker registration, closing the "forgot to add the copy
  to the checker" failure mode

**Cons:**

- Skill directories are no longer independently copy-pasteable out of a plugin
- Requires a migration pass across six plugins
- `${CLAUDE_PLUGIN_ROOT}` must be set; scripts invoked outside a plugin context need
  an explicit path

### Option 2: Keep copies, fix the checkers (rejected)

Harden drift detection by generating the copy list automatically.

**Pros:**

- No migration
- Preserves skill-level self-containment

**Cons:**

- Keeps the 20% duplication and all six CI jobs
- Fixes the symptom while the cause — that correctness depends on a hand-maintained
  list — remains
- Does nothing about the six existing cross-skill imports

### Option 3: Symlinks (rejected, as in ADR-009)

**Pros:**

- Single source of truth on disk

**Cons:**

- Git and archive handling of symlinks varies by platform
- Windows support is unreliable
- Obscures to a reader that a file is shared

## Consequences

### Positive

- Duplication drops from 20% of the plugin tree to approximately zero
- A shared script can be fixed once; no propagation step, no forgotten copy
- `/propagate-templates`, six drift checkers, and six CI jobs can be retired
- CI gets faster and its remaining checks mean more
- The convention finally matches what the code already does with hooks

### Negative

- A migration touching six plugins, to be done plugin by plugin rather than at once
- Documentation referencing the copy convention needs revision (root `CLAUDE.md`,
  `.claude/CLAUDE.md`, `CONTRIBUTING.md`, per-plugin READMEs)
- ADR-009's rationale is now part of the historical record rather than current
  guidance

### Neutral

- Template duplication in principled-docs (`scaffold/templates/`) is a different case:
  those are user-facing scaffolding artifacts, not executable shared code. They are
  out of scope here and keep their drift checker.

## Migration

principled-tasks adopts `lib/` as of ADR-017's revision — six copies of `task-db.sh`
collapsed to one, and its drift checker deleted. Remaining plugins migrate in order of
duplication weight:

1. **principled-github** — `check-gh-cli.sh`, 15 copies across three plugins
2. **principled-implementation** — `task-manifest.sh` (5), `parse-plan.sh` (2),
   `run-checks.sh` (2)
3. **principled-docs** — `next-number.sh` (3), `validate-structure.sh` (2)

Each migration is one PR: add `lib/`, rewrite references to
`${CLAUDE_PLUGIN_ROOT}/lib/`, delete copies, delete the drift checker, drop the CI job.

## Open Questions

- **Cross-plugin sharing.** `check-gh-cli.sh` is used by principled-github,
  principled-quality, and principled-release, which install independently.
  `${CLAUDE_PLUGIN_ROOT}` cannot cross that boundary. Options: vendor one copy per
  plugin's `lib/` (three copies instead of fifteen, drift-checked), declare a plugin
  dependency once the marketplace supports it, or inline the ~31-line check. This
  needs its own ADR.
- **Retiring `/propagate-templates`.** It still serves principled-docs' scaffolding
  templates. It should narrow to that scope rather than being deleted outright.
