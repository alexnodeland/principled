---
title: "Agent Memory, Identity, and Resumability"
number: "011"
status: draft
author: Alex
created: 2026-07-28
updated: 2026-07-28
supersedes: null
superseded_by: null
---

# RFC-011: Agent Memory, Identity, and Resumability

## Audience

- Engineers running `/orchestrate` across sessions who lose reasoning context on every restart
- Maintainers of principled-implementation, whose manifest schema this extends
- Anyone evaluating whether agent "memory" is a real capability or a marketing term

## Context

This is the first of three proposals carved out of RFC-010, which covered seven
systems in one document and was too large to review or deliver. RFC-010 remains the
strategic vision; this proposal is the foundation the other two build on.

### The problem

Agents start fresh every session. The manifest (ADR-008) tracks _what_ state each task
is in, but not _why_ — the orchestrator's reasoning, the approaches already tried, the
review feedback already received. When a session ends, that evaporates.

Three concrete symptoms:

1. **No accumulated knowledge.** An `impl-worker` that learned this codebase uses
   barrel exports relearns it on the next task, and the one after that.
2. **No resumability of reasoning.** `--continue` reads task state and resumes
   mechanically, but a new session cannot know that task 2b already failed twice on
   the test suite and why.
3. **All-or-nothing task retry.** A task 80% complete when a session dies restarts
   from zero, because the manifest has no sub-task visibility.

### What already exists

- **Worktree isolation (ADR-007)** — worktrees survive session death; the filesystem
  state is already durable.
- **Manifest-driven state (ADR-008)** — task lifecycle is already tracked and already
  resumable at task granularity.
- **principled-tasks (ADR-017)** — an append-only, git-committed task graph with typed
  dependency edges, agent assignment, and discovery provenance.

That last one matters for scope. RFC-010 assumed it would have to build a shared
backlog. principled-tasks shipped one. **This proposal therefore covers agent state
only — properties of the worker, not of the work.** Work tracking is delegated to
principled-tasks.

## Proposal

Three related additions, all git-native and all backward-compatible.

### 1. Persistent agent identity and memory

A git-committed `.agents/` directory at the repository root:

```
.agents/
  registry.json                    # Agent identity registry (queryable metadata)
  memory/
    global.md                      # Learnings that apply to every agent
    agents/
      impl-worker.md               # Per-agent accumulated knowledge
      issue-ingester.md
      pr-reviewer.md
  retrospectives/
    2026-07-28-plan-008.md         # Post-execution retrospective
```

Memory files use **YAML frontmatter plus a markdown body**, consistent with every
other pipeline document. Frontmatter carries queryable metadata (session count,
success rate, specializations); the body carries knowledge the LLM consumes directly.

```markdown
---
agent_id: "impl-worker"
role: worker
last_updated: 2026-07-28
session_count: 12
total_tasks: 47
success_rate: 0.91
specializations: ["bash", "hook-authoring"]
---

# impl-worker — Accumulated Knowledge

## Known Patterns

- Shared scripts live in each plugin's `lib/`, referenced via
  `${CLAUDE_PLUGIN_ROOT}` (ADR-018). Never copy one into a skill directory.
- macOS ships bash 3.2. No `declare -A`, no `local -n`, no `grep -P`.
```

**Not every agent gets memory.** Only agents spawned repeatedly for substantively
similar work accumulate anything useful:

| Agent              | Memory? | Rationale                                                         |
| ------------------ | :-----: | ----------------------------------------------------------------- |
| `impl-worker`      |   Yes   | Primary beneficiary — implementation patterns, codebase knowledge |
| `issue-ingester`   |   Yes   | Triage and classification patterns accumulate                     |
| `pr-reviewer`      |   Yes   | Learns recurring review themes                                    |
| `module-auditor`   |   No    | Runs a deterministic script; nothing to learn                     |
| `decision-auditor` |   No    | Checks supersession chains deterministically                      |
| `boundary-checker` |   No    | Scans imports against fixed rules                                 |

Memory files are **committed to git**, unlike `.claude/agent-memory/` which is
gitignored. They are shared team knowledge, not session-local scratch.

### 2. Resumable orchestration

Extend the manifest with a `checkpoint` key — a new top-level field that existing
manifests simply lack:

```json
{
  "plan": "docs/plans/008-example.md",
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

The checkpoint carries the **natural-language reasoning** that task state cannot. A
new session reads it, ingests the summary, and continues.

A new `/resume` skill:

```
/resume [plan-path] [--from-checkpoint] [--replan]
```

This is Nondeterministic Idempotence in practice: the path is chaotic (different
session, different reasoning), but the manifest and checkpoint are deterministic
anchors, so outcomes converge.

### 3. Checkpointable acceptance criteria

Rather than adding a fourth hierarchy level, make each acceptance criterion
individually addressable within the existing task model:

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
  ],
  "estimated_complexity": "medium"
}
```

A resumed worker skips verified criteria and continues from the first unverified one.

**What does not change:** the DDD hierarchy stays Plan → Phase → Task (ADR-008),
`/decompose` keeps its interface, the `impl-worker` contract is unchanged, and
`/check-impl` still validates at task level.

### Delivery

| Component                      | Plugin                    |
| ------------------------------ | ------------------------- |
| `.agents/` structure, registry | principled-agent (new)    |
| `/resume` skill                | principled-implementation |
| `inject-agent-memory.sh` hook  | principled-agent          |
| `check-memory-integrity.sh`    | principled-agent          |
| Manifest checkpoint field      | principled-implementation |
| Criterion-level tracking       | principled-implementation |

**No RFC-008 dependency.** Everything here builds on shipped infrastructure.

## Alternatives Considered

### Alternative 1: Pure markdown memory (no frontmatter)

Natural for LLM consumption, but not queryable for routing, metrics, or automated
pruning. Rejected because the pipeline depends on frontmatter for lifecycle
enforcement — memory files without it would be second-class documents.

### Alternative 2: Pure JSON or YAML memory

Queryable and structured, but LLMs consume markdown more effectively than nested data
structures. The primary consumer of memory is the model itself. Rejected.

### Alternative 3: Event log plus SQLite cache, as principled-tasks uses

RFC-010 rejected this outright. That rejection needs revisiting now that ADR-017 has
shipped exactly this pattern, and the answer is that **the two cases are genuinely
different**:

|                  | Agent memory                 | Task graph (ADR-017)              |
| ---------------- | ---------------------------- | --------------------------------- |
| Primary consumer | The LLM, as prose            | Scripts, as queries               |
| Access pattern   | Read whole file into context | Filter, aggregate, traverse edges |
| Write frequency  | Occasionally, after a run    | Every task transition             |
| Merge pressure   | Low — one file per agent     | High — many agents appending      |

Memory is a _document_; the task graph is a _data structure_. Both are git-native,
which is the principle that actually matters. Applying an event log to memory would
buy conflict resistance that memory does not need, at the cost of making the LLM's
primary input unreadable.

### Alternative 4: Add a fourth hierarchy level (Plan → Phase → Task → Step)

Would give sub-task resumability, but breaks the DDD decomposition contract in ADR-008,
changes `/decompose`'s output shape, and changes the `impl-worker` contract. Formalizing
acceptance criteria — which tasks already carry as prose — achieves the same
granularity with no contract change.

## Consequences

### Positive

- Agents stop relearning the same codebase facts every session
- A crashed session resumes with reasoning intact, not just task state
- A task 80% complete resumes at 80%, not zero
- Memory is reviewable in PRs like any other document — a bad learned pattern is
  visible and revertable in git history
- Scope is materially smaller than RFC-010's Phase 1, because work tracking is
  delegated to principled-tasks rather than rebuilt

### Negative

- `.agents/` is a new committed directory; repositories gain state they must review
- Memory files grow unboundedly without a pruning strategy (see Open Questions)
- Injecting memory consumes context budget on every spawn — a large memory file
  competes with the task description for attention
- Three manifest consumers (`/check-impl`, `/merge-work`, `/orchestrate`) must all
  tolerate the new fields

### Risks

- **Learned bad patterns compound.** An agent that records a wrong conclusion will act
  on it repeatedly. Mitigation: memory changes go through PR review like any document,
  and RFC-013's regression detection watches for metric degradation after updates.
- **Memory becomes a dumping ground.** Without curation, files accumulate noise that
  dilutes useful context. Mitigation: `/improve` (RFC-013) synthesizes rather than
  appends.
- **Checkpoint summaries drift from reality.** A summary written by a failing agent may
  describe a state that does not exist. Mitigation: the checkpoint is advisory context;
  the manifest remains authoritative for state.

## Architecture Impact

- **New:** `docs/architecture/agent-memory.md` — the `.agents/` contract, memory
  lifecycle, injection points
- **Update:** `docs/architecture/documentation-pipeline.md` — retrospectives and memory
  files as pipeline document types
- **New ADR:** memory file format (frontmatter + markdown), and why it differs from
  ADR-017's event log
- **New ADR:** manifest checkpoint schema, extending ADR-008

## Open Questions

- **Memory pruning.** At what size does a memory file stop helping and start diluting
  context? Is pruning periodic, size-triggered, or an explicit `/improve` step?
- **Memory and forks.** Should identity and memory carry across a repository fork?
  Codebase knowledge transfers; performance metrics probably do not. A reasonable
  default: memory transfers, registry metrics reset.
- **Correlating with principled-tasks.** Tasks carry `plan` and `task_id` fields
  intended to line up with the manifest, but nothing verifies the correspondence.
  Should `/resume` reconcile the two, and what does it do when they disagree?
- **Does `.agents/` belong in a new plugin at all**, or should memory live in
  principled-implementation alongside the manifest it extends?
