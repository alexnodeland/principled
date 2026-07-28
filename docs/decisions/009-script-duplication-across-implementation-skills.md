---
title: "Script Duplication Across Implementation Skills"
number: "009"
status: superseded
author: Alex
created: 2026-02-22
updated: 2026-07-28
from_proposal: "006"
supersedes: null
superseded_by: "018"
---

# ADR-009: Script Duplication Across Implementation Skills

## Status

Superseded by [ADR-018](018-shared-plugin-lib-over-copies.md).

The reasoning below is retained as the historical record. It is no longer current
guidance: shared code now lives in each plugin's `lib/` and is referenced via
`${CLAUDE_PLUGIN_ROOT}`. In practice this decision produced 15 copies of one 31-line
script, 3,382 redundant lines across `plugins/` (20% of the tree), six drift checkers,
and a drift checker that silently missed an already-diverged copy. ADR-018 records the
measurements.

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-implementation plugin has 6 skills, many of which share the same utility scripts:

- `task-manifest.sh` is needed by 5 skills (decompose, spawn, check-impl, merge-work, orchestrate)
- `parse-plan.sh` is needed by 2 skills (decompose, orchestrate)
- `run-checks.sh` is needed by 2 skills (check-impl, orchestrate)
- `claude-task.md` template is needed by 2 skills (spawn, orchestrate)

The principled methodology requires skills to be self-contained — no cross-skill imports. This creates a tension with DRY (Don't Repeat Yourself) when multiple skills need the same script.

Three sharing strategies were considered:

1. **Copy with drift detection** — Each skill maintains its own copy. A CI script verifies all copies match the canonical source.
2. **Shared scripts directory** — A plugin-level `scripts/` directory holds shared scripts, referenced by relative path from each skill.
3. **Symlinks** — Skills use symbolic links to a single canonical copy.

## Decision

Use the copy-with-drift-detection pattern, consistent with the approach already established in principled-docs (ADR template duplication, `next-number.sh` script duplication). Each script has one canonical location, and consuming skills maintain byte-identical copies. The `scripts/check-template-drift.sh` script at the plugin root verifies all 7 canonical-copy pairs in CI.

Canonical locations:

| Script/Template    | Canonical Location                  | Copies To                                                  |
| ------------------ | ----------------------------------- | ---------------------------------------------------------- |
| `parse-plan.sh`    | `decompose/scripts/`               | `orchestrate/scripts/`                                     |
| `task-manifest.sh` | `decompose/scripts/`               | `spawn/`, `check-impl/`, `merge-work/`, `orchestrate/` scripts |
| `run-checks.sh`    | `check-impl/scripts/`              | `orchestrate/scripts/`                                     |
| `claude-task.md`   | `spawn/templates/`                 | `orchestrate/templates/`                                   |

## Options Considered

### Option 1: Copy with drift detection (chosen)

Each consuming skill has its own copy. CI verifies copies match canonical. Drift = failure.

**Pros:**

- Skills remain fully self-contained — each directory has everything it needs
- Consistent with principled-docs' established pattern (templates and `next-number.sh`)
- Drift detection in CI catches forgotten propagation
- No runtime path resolution — each skill's scripts are at predictable relative paths

**Cons:**

- 7 copies to maintain: updates require propagation to all copies
- Human error risk: forgetting to propagate after editing the canonical source
- CI catches drift but doesn't fix it — developer must propagate manually (or use `/propagate-templates`)

### Option 2: Shared scripts directory at plugin root

Place shared scripts in `plugins/principled-implementation/scripts/shared/` and reference them from skills via relative path.

**Pros:**

- Single copy — no duplication or drift risk
- Simpler updates — change once, used everywhere

**Cons:**

- Breaks skill self-containment: skills depend on files outside their directory
- Path resolution complexity: scripts must compute relative paths to the shared directory
- Violates the principled marketplace convention that skills are self-contained

### Option 3: Symlinks

Skills contain symlinks to the canonical copy instead of actual file copies.

**Pros:**

- Automatic synchronization — changes to canonical immediately affect all consumers
- No drift detection needed

**Cons:**

- Symlinks behave differently across platforms (Windows compatibility issues)
- Git stores symlinks as special objects, which some tools handle poorly
- Some CI environments resolve symlinks differently than development environments
- Obscures the actual file content when browsing the skill directory

## Consequences

### Positive

- Consistent with the marketplace's established convention from principled-docs
- Skills remain fully self-contained: each skill directory contains all files needed for execution
- Drift detection script provides CI-level guarantee of copy consistency
- The `/propagate-templates` dev skill can automate propagation across all three plugins

### Negative

- 7 copy operations required when updating any shared script or template
- Total file duplication across the plugin: `task-manifest.sh` has 5 copies, the others have 2 each
- Developers must remember to propagate — the feedback loop (CI failure) is delayed

## References

- [RFC-006: Principled Implementation Plugin](../proposals/006-principled-implementation-plugin.md)
- principled-docs template duplication: [RFC-000](../proposals/000-principled-docs.md) §5.4
- Implementation: `plugins/principled-implementation/scripts/check-template-drift.sh`
