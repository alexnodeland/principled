---
title: "Manifest-Driven Orchestration State Management"
number: "008"
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-22
from_proposal: "006"
supersedes: null
superseded_by: null
---

# ADR-008: Manifest-Driven Orchestration State Management

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-implementation plugin orchestrates multi-phase plan execution with task spawning, validation, retry, and merge. This requires persistent state tracking across skill invocations — the orchestrator must know which tasks are pending, in progress, passed, failed, merged, or abandoned. It must also track branch names, retry counts, check results, and error messages.

Three state management approaches were considered:

1. **JSON manifest file** (`.impl/manifest.json`) — A single JSON file managed by a bash script (`task-manifest.sh`).
2. **Plan document mutation** — Update the plan markdown directly (check off tasks, add status annotations).
3. **Git-based state** — Derive state from git branch existence, merge status, and tags.

## Decision

Use a JSON manifest file at `.impl/manifest.json` as the single source of truth for orchestration state. The `task-manifest.sh` script provides a CLI interface for all manifest operations (init, add-task, get-task, update-status, list-tasks, phase-status, summary). All skills interact with the manifest exclusively through this script, never by direct JSON editing.

The manifest stores:

- Plan metadata (path, number, title, decomposition timestamp)
- Phase definitions (number, dependencies, bounded contexts)
- Task records (id, phase, description, status, branch, check results, error, retries, timestamps)

## Options Considered

### Option 1: JSON manifest file (chosen)

A `.impl/manifest.json` file with structured task state, managed by `task-manifest.sh`.

**Pros:**

- Machine-readable: skills can query task state programmatically
- Rich state: supports 8 status values, retry counts, branch tracking, check results, error messages, timestamps
- Resume capability: the manifest persists across sessions, enabling `--continue`
- Single source of truth: all skills read from and write to the same file
- Advisory hook protection: `check-manifest-integrity.sh` warns against direct edits

**Cons:**

- JSON manipulation in bash is fragile (mitigated by jq with sed fallback)
- Adds a `.impl/` directory to the repository that must be gitignored or committed
- Manifest can become stale if the plan document is modified after decomposition

### Option 2: Plan document mutation

Update the plan's markdown directly — check off task checkboxes, add inline status annotations.

**Pros:**

- No additional files — state lives in the plan itself
- Human-readable without tooling

**Cons:**

- Cannot store rich metadata (branch names, retry counts, check results)
- Markdown mutation is fragile (regex-based checkbox toggling)
- Violates the principled methodology's principle that plans describe intent, not execution state
- Cannot easily support resume — parsing inline annotations is complex

### Option 3: Git-based state derivation

Infer task state from git: branches named `impl/<plan>/<task>` exist → in progress; branches merged → complete; no branch → pending.

**Pros:**

- No additional files — state is in git itself
- Inherently consistent with actual git state

**Cons:**

- Cannot distinguish between "in progress" and "failed" without additional markers
- No retry tracking, check results, or error messages
- Branch deletion during cleanup removes the state evidence
- Slow for large repos (branch enumeration)

## Consequences

### Positive

- All orchestration skills share a consistent state interface via `task-manifest.sh`
- Resume capability works across sessions — `/orchestrate --continue` reads the manifest to determine where to pick up
- Rich diagnostics: retry counts, check results, and error messages are available for reporting
- Advisory hook warns against direct manifest edits, protecting state integrity
- The script interface abstracts JSON manipulation, so callers never parse JSON directly

### Negative

- The `.impl/` directory is an implementation artifact that may confuse contributors unfamiliar with the plugin
- jq dependency is optional but produces better results; the sed fallback is more fragile for complex operations
- The manifest must be kept in sync with actual git state (branch existence, merge status) — if someone manually deletes a branch, the manifest becomes stale

## References

- [RFC-006: Principled Implementation Plugin](../proposals/006-principled-implementation-plugin.md)
- Implementation: `plugins/principled-implementation/skills/decompose/scripts/task-manifest.sh`
- Schema reference: `plugins/principled-implementation/skills/impl-strategy/reference/manifest-schema.md`
