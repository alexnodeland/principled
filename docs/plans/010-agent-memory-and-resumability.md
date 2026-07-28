---
title: "Agent Memory and Resumability"
number: "010"
status: complete
author: Alex
created: 2026-07-28
updated: 2026-07-28
originating_proposal: "011"
related_adrs: ["020", "021"]
---

# Plan-010: Agent Memory and Resumability

## Objective

Implements [RFC-011](../proposals/011-agent-memory-and-resumability.md).

Deliver persistent agent memory and resumable orchestration: a new `principled-agent`
plugin owning the `.agents/` directory and its injection and integrity hooks, plus
additive extensions to principled-implementation's manifest for checkpointing and
criterion-level acceptance tracking.

Scope is agent state — properties of the worker. Work tracking stays delegated to
principled-tasks (ADR-017), per RFC-011.

## Related Decisions

- [ADR-020: Agent Memory as a Frontmatter Document](../decisions/020-agent-memory-as-document.md) —
  memory is a revisable markdown document, not an event log
- [ADR-021: Manifest Checkpoint and Criterion-Level Acceptance](../decisions/021-manifest-checkpoint-schema.md) —
  two additive optional manifest fields, no hierarchy change
- [ADR-008: Manifest-Driven Orchestration State](../decisions/008-manifest-driven-orchestration-state.md) — extended
- [ADR-018: Shared Plugin lib/ Over Copies](../decisions/018-shared-plugin-lib-over-copies.md) —
  shared code goes in the plugin's `lib/`
- [ADR-003: Module Type Declaration via CLAUDE.md](../decisions/003-module-type-storage.md)

## Domain Analysis

### Bounded Contexts

**Agent Identity** (`principled-agent`) — who an agent is and what it has learned.
Owns `.agents/registry.json`, `.agents/memory/`, and `.agents/retrospectives/`. Knows
nothing about plans, tasks, or manifests.

**Orchestration State** (`principled-implementation`) — what execution has happened and
what remains. Owns `.impl/manifest.json`, now including the checkpoint and per-task
acceptance criteria.

**Work Backlog** (`principled-tasks`, existing) — the task graph. Read-only from this
plan's perspective; `/resume` correlates against it but never writes to it.

The seam between the first two is deliberate: memory is a property of the worker, the
checkpoint is a property of the work. They are separate plugins because the agents that
carry memory live in three different plugins that cannot depend on one another.

### Aggregates

| Aggregate           | Root                            | Invariants                                                        |
| ------------------- | ------------------------------- | ----------------------------------------------------------------- |
| Agent Memory        | `.agents/memory/agents/<id>.md` | Valid frontmatter; `agent_id` matches filename; body is prose     |
| Agent Registry      | `.agents/registry.json`         | One entry per agent; `memory: true` implies a memory file exists  |
| Manifest Checkpoint | `.impl/manifest.json`           | Advisory; task array stays authoritative; absence is valid        |
| Acceptance Criteria | a task within the manifest      | `verified: true` implies non-null `verified_at`; absence is valid |

### Domain Events

- **AgentSpawned** → memory is injected into the agent's context
- **SessionEnded** → checkpoint written with reasoning summary
- **CriterionVerified** → criterion flipped to `verified`, timestamp stamped
- **MemoryWritten** → integrity hook checks frontmatter and size budget
- **ResumeRequested** → checkpoint read, divergence against the task graph reported

## Implementation Tasks

### Phase 1: principled-agent plugin foundation

- [x] Create plugin skeleton: `.claude-plugin/plugin.json`, `README.md`
- [x] Implement `lib/agent-memory.sh` — init, show, update-metrics, reset-metrics,
      list, path resolution; bash 3.2 clean, jq-optional
- [x] Define the `.agents/` scaffold and `registry.json` schema, seeded with the three
      memory-bearing agents (`impl-worker`, `issue-ingester`, `pr-reviewer`)
- [x] Add the plugin to `.claude-plugin/marketplace.json`

### Phase 2: principled-agent skills and hooks

- [x] `agent-strategy` — background knowledge skill (not user-invocable)
- [x] `/agent-init` — scaffold `.agents/` in a repository
- [x] `/agent-memory` — show, edit, and reset metrics for an agent's memory
- [x] `/agent-retro` — write a post-execution retrospective
- [x] `hooks/scripts/inject-agent-memory.sh` — surface memory at spawn; advisory,
      always exits 0, never truncates
- [x] `hooks/scripts/check-memory-integrity.sh` — validate frontmatter and enforce the
      8 KB / 16 KB advisory size budget; always exits 0
- [x] `hooks/hooks.json` wiring both hooks

### Phase 3: manifest checkpoint and acceptance criteria

- [x] Extend `lib/task-manifest.sh` with `--set-checkpoint` and `--get-checkpoint`,
      including the no-jq fallback
- [x] Extend `lib/task-manifest.sh` with `--set-criteria`, `--verify-criterion`, and
      `--list-criteria`
- [x] Confirm `/orchestrate`, `/check-impl`, `/merge-work`, and `/spawn` tolerate both
      new fields and unknown fields
- [x] Update `skills/impl-strategy/reference/manifest-schema.md`

### Phase 4: the /resume skill

- [x] `/resume [plan-path] [--from-checkpoint] [--replan]`
- [x] Divergence report against principled-tasks, degrading silently when the plugin or
      `.principled/tasks.jsonl` is absent
- [x] Document that the checkpoint is advisory and task state is authoritative

### Phase 5: tests, docs, and CI

- [x] `tests/agent-memory.bats` — lib behaviour, frontmatter round-trip, size budget,
      metrics reset
- [x] Extend `tests/hooks.bats` for both new hooks, including the no-jq path
- [x] `tests/manifest-checkpoint.bats` — checkpoint and criteria, with and without jq
- [x] `docs/architecture/agent-memory.md` — the `.agents/` contract and injection points
- [x] Update `docs/architecture/documentation-pipeline.md` for memory and retrospectives
      as document types
- [x] Update root `CLAUDE.md` and `.claude/CLAUDE.md`; correct the stale claim that the
      `lib/` migration is still in progress
- [x] `just ci` green

## Dependencies

All shipped; nothing here is blocked:

- Worktree isolation (ADR-007) and manifest state (ADR-008)
- principled-tasks (ADR-017) — optional at runtime, for correlation only
- `parse-frontmatter.sh` in principled-docs — the pattern for frontmatter reads
- Bash 3.2 and jq-optional constraints apply to every script

No RFC-008 dependency. RFC-012 and RFC-013 depend on this plan, not the reverse.

## Acceptance Criteria

- [x] `principled-agent` is installable and listed in the marketplace manifest
- [x] `.agents/` scaffolds with a valid registry and memory files for the three
      memory-bearing agents
- [x] Memory files parse with the existing frontmatter tooling
- [x] The integrity hook warns past 8 KB and never blocks; injection never truncates
- [x] `--reset-metrics` clears counters while leaving the body intact
- [x] A manifest with a checkpoint and criteria is readable by every existing consumer,
      and a manifest without them still works unchanged
- [x] `/resume` reports divergence against the task graph and exits 0, including when
      principled-tasks is not installed
- [x] Every new script passes ShellCheck and shfmt, and runs on bash 3.2
- [x] `just ci` passes

## Verification

Machine-tested by `just ci` (126 bats tests, each new operation run both with jq and
with a PATH that genuinely lacks it):

- `lib/agent-memory.sh` — scaffold, metrics arithmetic, reset, size budget, structural
  integrity, both output formats (`tests/agent-memory.bats`)
- both principled-agent hooks — injection content, no-truncation, silence for
  non-memory agents, malformed input, no-jq path (`tests/hooks.bats`)
- manifest checkpoint and criteria — round-trip, overwrite, clear, range checking, and
  cross-compatibility between the jq and no-jq writers (`tests/manifest-checkpoint.bats`)

Delivered as skills, and therefore model-executed rather than machine-tested: `/resume`,
`/agent-init`, `/agent-memory`, `/agent-retro`. Their script dependencies are covered
above; the workflow prose is not executable and is not claimed to be tested.

Fixed in passing: five `sed -i` calls in `task-manifest.sh`'s no-jq fallback. BSD sed
reads the following argument as a backup suffix, so adding a second task and every
status update failed on stock macOS. Replaced with awk, pinned by regression tests.
