---
title: "Agent Memory as a Frontmatter Document, Not an Event Log"
number: "020"
status: accepted
author: Alex
created: 2026-07-28
updated: 2026-07-28
originating_proposal: "011"
supersedes: null
superseded_by: null
---

# ADR-020: Agent Memory as a Frontmatter Document, Not an Event Log

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

RFC-011 introduces persistent agent memory: a git-committed record of what an agent has
learned about a codebase, injected into its context when it spawns. A storage format has
to be chosen, and the repository has already made an adjacent choice that pulls in a
different direction.

ADR-017 stores the task graph as an append-only JSONL event log with a derived SQLite
cache. That decision is recent, accepted, and shipped in principled-tasks. The obvious
move is to reuse it — one storage pattern for all git-native agent state, one set of
merge semantics, one body of code.

RFC-010 rejected an event log for memory without argument. That rejection could not
stand once ADR-017 shipped the pattern successfully, so the question was reopened.

### What memory is actually for

Memory has exactly one consumer at read time: the language model, reading prose into its
context window at spawn. Nothing filters it, aggregates it, or traverses it. The whole
file is read, or none of it is.

That is the opposite of the task graph's access pattern, and the difference is not
incidental:

|                  | Agent memory                 | Task graph (ADR-017)              |
| ---------------- | ---------------------------- | --------------------------------- |
| Primary consumer | The LLM, as prose            | Scripts, as queries               |
| Access pattern   | Read whole file into context | Filter, aggregate, traverse edges |
| Write frequency  | Occasionally, after a run    | Every task transition             |
| Merge pressure   | Low — one file per agent     | High — many agents appending      |
| Unit of value    | A curated paragraph          | A single immutable fact           |

An event log is the right answer when many writers append small immutable facts
concurrently and readers reconstruct state by folding them. Memory has none of those
properties. One agent owns its file, writes to it rarely, and every write is a revision
of prose rather than an appended fact.

## Decision

**Agent memory files are markdown documents with YAML frontmatter, one file per agent,
committed to git and edited in place.**

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

- Shared scripts live in each plugin's `lib/`, referenced via `${CLAUDE_PLUGIN_ROOT}`
  (ADR-018). Never copy one into a skill directory.
- macOS ships bash 3.2. No `declare -A`, no `local -n`, no `grep -P`.
```

Frontmatter carries queryable metadata — the fields a script needs for routing, metrics,
and integrity checks. The body carries knowledge, in the form the model consumes
directly. This is the same shape as every other pipeline document, so the existing
frontmatter tooling applies unchanged.

The corollary: **memory is revised, not appended.** A learning that turns out to be wrong
is edited out, and git history records that it was ever believed. The event log's
defining property — immutability of past entries — is the property memory specifically
must not have, because a wrong learned pattern that cannot be deleted is a defect that
compounds on every spawn.

Metrics in frontmatter are maintained by `agent-memory.sh`, not hand-edited, and are the
only part of the file a script rewrites.

## Options Considered

### Option 1: Markdown with YAML frontmatter (chosen)

Readable by the model without transformation, queryable by scripts through the existing
`parse-frontmatter.sh`, reviewable in a PR diff like any document, and revisable.

Costs: no concurrent-write story beyond git's own merge, and no structural guarantee
that the body stays curated. Both are acceptable — writes are rare and single-owner, and
curation is enforced advisorily by a size budget (RFC-011).

### Option 2: Pure markdown, no frontmatter

Maximally natural for the model, but metrics and specializations become unqueryable, so
routing and integrity checking would have to parse prose. It would also be the only
pipeline document without frontmatter, making it second-class to the lifecycle tooling.
Rejected.

### Option 3: Pure JSON or YAML

Fully structured and trivially queryable, but the primary consumer is a language model,
and prose in a nested data structure reads worse than prose in a document. It optimises
for the secondary consumer at the expense of the primary one. Rejected.

### Option 4: Event log plus SQLite cache, mirroring ADR-017

Consistent with the adjacent decision and genuinely better under concurrent writes. It
was rejected because memory does not have concurrent writes to protect, and the cost is
severe in the one dimension that matters: the model's input becomes a fold over an event
stream rather than a document, and correcting a bad learning becomes a compensating
entry rather than a deletion.

Rejecting it here does not weaken ADR-017. The two decisions differ because the
workloads differ, and the shared principle — state lives in git, in plain text, visible
in review — is honoured by both.

## Consequences

### Positive

- The model's primary input is a document, in the form it consumes best
- Memory diffs are readable in PR review, so a bad learned pattern is visible before it
  is merged and revertable after
- Wrong learnings are deleted outright rather than compensated for
- Reuses `parse-frontmatter.sh` and the pipeline's existing document conventions; no new
  storage engine, no cache to invalidate, no merge driver to register
- No SQLite dependency for memory

### Negative

- Concurrent writes to one agent's memory file from parallel sessions can conflict in
  git, and are resolved manually. Accepted: writes are rare and single-owner by
  construction
- Nothing structurally prevents the body from degrading into an append-only log; only
  the advisory size budget and human review push back
- Two storage patterns now exist for git-native agent state, and contributors must know
  which applies. Mitigated by the workload table above, which is the deciding test

## References

- [RFC-011: Agent Memory, Identity, and Resumability](../proposals/011-agent-memory-and-resumability.md)
- [ADR-017: Event Log as Record, SQLite as Cache](017-event-log-task-graph.md) — the
  adjacent decision this one deliberately diverges from
- [ADR-001: Frontmatter Parsing Strategy](001-frontmatter-parsing-strategy.md)
- [ADR-021: Manifest Checkpoint and Criterion-Level Acceptance](021-manifest-checkpoint-schema.md)
- [Plan-010: Agent Memory and Resumability](../plans/010-agent-memory-and-resumability.md)
