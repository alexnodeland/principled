---
title: "Manifest Checkpoint and Criterion-Level Acceptance Tracking"
number: "021"
status: accepted
author: Alex
created: 2026-07-28
updated: 2026-07-28
originating_proposal: "011"
supersedes: null
superseded_by: null
---

# ADR-021: Manifest Checkpoint and Criterion-Level Acceptance Tracking

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

ADR-008 established `.impl/manifest.json` as the single source of truth for
orchestration state, with the hierarchy Plan → Phase → Task. It works: `/orchestrate
--continue` resumes correctly at task granularity.

Two things it cannot express surfaced in practice.

**Reasoning does not survive a session.** The manifest records that task 2b is `failed`
and has been retried twice. It cannot record _that retrying is the wrong move_ — that
both failures were the same test failure, and the approach needs changing rather than
repeating. A new session reads `failed, retries: 2` and does the obvious wrong thing.

**Retry is all-or-nothing.** A task whose session dies at 80% restarts at zero. The
manifest's smallest unit is the task, so 80% of the work is discarded along with the 20%
that was missing. Tasks already carry acceptance criteria — as prose, in the task
description — so the information needed to resume mid-task exists but is not addressable.

The obvious fix for the second problem is a fourth hierarchy level, Plan → Phase → Task →
Step. That is exactly what ADR-008's decomposition contract forbids, and it would change
`/decompose`'s output shape and the `impl-worker` contract along with it.

## Decision

**Extend the manifest with two additive, optional fields. Neither changes the hierarchy,
`/decompose`'s interface, nor the `impl-worker` contract.**

### 1. A top-level `checkpoint` object

```json
{
  "plan": { "path": "docs/plans/008-example.md" },
  "checkpoint": {
    "session_id": "sess-abc123",
    "agent_id": "impl-worker",
    "phase": 2,
    "timestamp": "2026-07-28T14:30:00Z",
    "orchestrator_summary": "Phase 1 complete (3/3 merged). Phase 2: task-2a passed, task-2b failed on the test suite twice — needs a different approach, not a retry. task-2c pending.",
    "pending_decisions": [
      "task-2b: response format — envelope vs flat. Blocked on review feedback."
    ],
    "environment_state": {
      "active_worktrees": ["task-2a", "task-2b"],
      "branches": { "task-2a": "impl/plan-008/task-2a" }
    }
  }
}
```

The checkpoint carries natural-language reasoning that structured task state cannot.

**The checkpoint is advisory; the manifest's task array remains authoritative.** A
summary is written by a session that may have been failing when it wrote it, so it can
describe a state that no longer holds or never held. Consumers treat it as context for
the model, never as a source of truth for control flow. Where the two disagree, task
state wins and the divergence is reported.

### 2. Optional `acceptance_criteria` on a task

```json
{
  "id": "2.1",
  "status": "in_progress",
  "acceptance_criteria": [
    {
      "description": "Middleware rejects missing auth with 401",
      "verified": true,
      "verified_at": "2026-07-28T14:20:00Z"
    },
    {
      "description": "Valid tokens pass to next handler",
      "verified": true,
      "verified_at": "2026-07-28T14:22:00Z"
    },
    {
      "description": "Unit tests cover both cases",
      "verified": false,
      "verified_at": null
    }
  ]
}
```

A resumed worker skips verified criteria and continues from the first unverified one.
This buys sub-task resumability by making an existing concept addressable rather than by
adding a hierarchy level: criteria are a **property of a task**, not children of it.
Tasks remain the unit of decomposition, spawning, validation, and merge.

`/check-impl` continues to validate at task level. A task is not complete because its
criteria are ticked; it is complete when its checks pass. Criteria are a resumption
hint, not an acceptance gate.

### Compatibility

Both fields are absent from every existing manifest, and absence is valid. Consumers
(`/orchestrate`, `/check-impl`, `/merge-work`, `/spawn`) must tolerate missing fields and
must not fail on unknown ones. No migration runs; a manifest gains a checkpoint the first
time something writes one.

## Options Considered

### Option 1: Additive optional manifest fields (chosen)

Backward-compatible by construction, keeps one source of truth, and requires no change to
decomposition or the worker contract.

Cost: the manifest now holds prose alongside structured state, and prose can be stale in
ways JSON fields are not. Bounded by making the checkpoint explicitly advisory.

### Option 2: A fourth hierarchy level (Plan → Phase → Task → Step)

Gives genuine sub-task tracking with clean semantics. Rejected: it breaks ADR-008's
decomposition contract, changes `/decompose`'s output shape, changes the `impl-worker`
contract, and forces every manifest consumer to handle a new nesting level — a large
blast radius for something acceptance criteria already deliver.

### Option 3: A separate checkpoint file (`.impl/checkpoint.json`)

Keeps the manifest schema untouched. Rejected: two files describing one execution can
disagree, and there is no atomic write across them. ADR-008 chose a single manifest
precisely to avoid this, and nothing here justifies reversing it.

### Option 4: Reconstruct reasoning from conversation history

No schema change at all. Rejected: history is not git-native, not reviewable, and not
available to a fresh session in another clone — which is the case resumability exists to
serve.

## Consequences

### Positive

- A resumed session inherits reasoning, not just state — including the knowledge that a
  retry is the wrong move
- A task 80% complete resumes at 80%
- Fully backward compatible; existing manifests remain valid and untouched
- The DDD hierarchy, `/decompose`, and the `impl-worker` contract are all unchanged
- One source of truth is preserved, per ADR-008

### Negative

- Manifests grow, and `orchestrator_summary` is unbounded prose in a state file
- A stale checkpoint can mislead a resumed session; mitigated by advisory status and
  divergence reporting, not eliminated
- Four manifest consumers must tolerate the new fields, and the no-jq fallback paths in
  `task-manifest.sh` grow correspondingly
- `verified: true` is asserted by the agent that did the work, so it is a claim rather
  than a proof. `/check-impl` remains the actual gate

## References

- [RFC-011: Agent Memory, Identity, and Resumability](../proposals/011-agent-memory-and-resumability.md)
- [ADR-008: Manifest-Driven Orchestration State](008-manifest-driven-orchestration-state.md) — extended, not superseded
- [ADR-007: Worktree Isolation for Task Execution](007-worktree-isolation-for-task-execution.md)
- [ADR-020: Agent Memory as a Frontmatter Document](020-agent-memory-as-document.md)
- [Plan-010: Agent Memory and Resumability](../plans/010-agent-memory-and-resumability.md)
