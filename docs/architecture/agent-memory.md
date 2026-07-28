---
title: "Agent Memory and Resumability"
last_updated: 2026-07-28
related_adrs: [020, 021, 008, 017]
---

# Agent Memory and Resumability

## Purpose

Describes the `.agents/` contract, how memory reaches an agent, and how an interrupted
orchestration run resumes with its reasoning intact. Intended for contributors extending
agent state, and for anyone deciding which of the three state stores a new field belongs
to.

## The three state stores

The repository now keeps three kinds of durable state, and the most common design
mistake is putting a field in the wrong one.

| Store               | Location                  | Owns                        | Governed by |
| ------------------- | ------------------------- | --------------------------- | ----------- |
| Agent memory        | `.agents/`                | What the worker has learned | ADR-020     |
| Orchestration state | `.impl/manifest.json`     | What execution has happened | ADR-008/021 |
| Work backlog        | `.principled/tasks.jsonl` | What needs doing            | ADR-017     |

The deciding question: **would this still be true after every open task closed?** If
yes, it is memory. If it describes a run, it is orchestration state. If it describes work
outstanding, it is the backlog.

A second test separates the first two: memory is a property of the _worker_, the
checkpoint is a property of the _work_. That is why they live in different plugins —
`impl-worker`, `issue-ingester`, and `pr-reviewer` belong to three different plugins that
install independently and cannot reference each other's `${CLAUDE_PLUGIN_ROOT}`.

## Layout

```
.agents/
  registry.json                    # who exists, who carries memory, and why
  memory/
    global.md                      # applies to every memory-bearing agent
    agents/
      impl-worker.md               # one file per memory-bearing agent
      issue-ingester.md
      pr-reviewer.md
  retrospectives/
    2026-07-28-plan-008.md         # dated record of one run
```

`.agents/` is **committed**, unlike the gitignored `.claude/agent-memory/`. That is the
load-bearing property: memory arrives through pull requests, so a bad learned pattern is
visible before it merges and revertable afterwards.

## Memory format

Markdown with YAML frontmatter (ADR-020). Frontmatter is script-owned metadata;
the body is prose the model consumes directly.

Memory is **revised, not appended**. This is the deliberate difference from the task
graph's event log (ADR-017), where past entries are immutable: a wrong learned pattern
that cannot be deleted compounds on every spawn.

The full comparison, and why the same storage decision does not apply to both:

|                  | Agent memory                 | Task graph (ADR-017)              |
| ---------------- | ---------------------------- | --------------------------------- |
| Primary consumer | The LLM, as prose            | Scripts, as queries               |
| Access pattern   | Read whole file into context | Filter, aggregate, traverse edges |
| Write frequency  | Occasionally, after a run    | Every task transition             |
| Merge pressure   | Low — one file per agent     | High — many agents appending      |

## Injection

```
SubagentStart
  └─ inject-agent-memory.sh
       ├─ extract agent id from the event payload
       ├─ no .agents/ directory?        → exit 0, silent
       ├─ no memory file for this agent → exit 0, silent
       └─ emit global.md body + <agent>.md body to stderr
```

Three properties matter:

**It never blocks.** The hook runs on every subagent spawn, so a failure would stop
agents running at all. Every path exits 0, including malformed input and an
uninitialized repository.

**It never truncates.** An agent handed a silently halved memory file has a confidently
incomplete picture, and the loss is invisible to it. Oversized memory is reported by
`check-memory-integrity.sh`, never quietly trimmed.

**Only memory-bearing agents receive anything**, including global memory. `module-auditor`,
`decision-auditor`, and `boundary-checker` run deterministic scripts and learn nothing by
definition, so injecting conventions into them spends context for no benefit.

## The context budget

Memory competes with the task description for the model's attention, so the budget is
stated in bytes rather than in records:

| Size         | Behaviour                                       |
| ------------ | ----------------------------------------------- |
| under 8 KB   | silent                                          |
| 8 KB – 16 KB | advisory warning, synthesis suggested           |
| over 16 KB   | louder warning; injection still delivers it all |

The budget is advisory because the cure — synthesis, rewriting many notes into fewer
denser statements — requires judgment the hook does not have. Until RFC-013's `/improve`
lands, that is a human act, which is exactly the reviewability the design argues for.

## Resumability

```
session dies mid-plan
  └─ .impl/manifest.json survives   (task state + checkpoint)
  └─ worktrees survive              (ADR-007)

/resume
  ├─ read checkpoint       → previous session's reasoning
  ├─ reconcile vs task state → report divergence, never auto-fix
  ├─ correlate vs task graph → report divergence, skip if absent
  ├─ read acceptance criteria → resume at first unverified
  └─ hand off to /orchestrate --continue or /spawn
```

### Why the checkpoint is advisory

The manifest records that task 2b is `failed` with `retries: 2`. It cannot record that
retrying is the wrong move. The checkpoint's `orchestrator_summary` carries that
reasoning.

But a checkpoint is written by a session that may have been failing when it wrote it, so
it can describe a state that never held. **Task state is authoritative; the checkpoint is
context** (ADR-021). Where they disagree, task state wins and the divergence is reported
rather than silently reconciled — a disagreement is usually evidence that a session died
between two writes, and that evidence is worth more than tidy agreement.

The same rule governs correlation with the task graph: `/resume` reports mismatches and
writes to neither store.

### Why criteria are not a hierarchy level

Sub-task resumability could have come from a fourth level, Plan → Phase → Task → Step.
That would break ADR-008's decomposition contract, change `/decompose`'s output shape,
and change the `impl-worker` contract.

Instead, acceptance criteria — which tasks already carried as prose — became individually
addressable as a **property of a task**. Tasks remain the unit of decomposition,
spawning, validation, and merge. `/check-impl` is still the acceptance gate; a ticked
criterion is a resumption hint and an agent's claim, not a proof.

## Retrospectives versus memory

A retrospective is a dated record of one run. Memory is undated knowledge asserted as
currently true. Most of a retrospective must never reach memory:

- "task-2b failed twice on the test suite" — a fact about one run. Retrospective.
- "this suite needs `--runInBand` or the fixtures collide" — a fact about the codebase.
  Memory.

Keeping them separate is what stops memory degrading into a log, which is the failure
mode the byte budget exists to detect.

## Related

- [ADR-020: Agent Memory as a Frontmatter Document](../decisions/020-agent-memory-as-document.md)
- [ADR-021: Manifest Checkpoint and Criterion-Level Acceptance](../decisions/021-manifest-checkpoint-schema.md)
- [ADR-008: Manifest-Driven Orchestration State](../decisions/008-manifest-driven-orchestration-state.md)
- [ADR-017: Event Log as Record, SQLite as Cache](../decisions/017-event-log-task-graph.md)
- [RFC-011: Agent Memory, Identity, and Resumability](../proposals/011-agent-memory-and-resumability.md)
- [Plan-010](../plans/010-agent-memory-and-resumability.md)
