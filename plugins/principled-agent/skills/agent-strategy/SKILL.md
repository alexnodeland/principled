---
name: agent-strategy
description: >
  Background knowledge on agent identity and memory: what belongs in memory,
  what does not, how memory differs from the task graph, and how the context
  budget is governed. Loaded as context for the other principled-agent skills.
  Not user-invocable.
user-invocable: false
---

# Agent Strategy — Identity and Memory

Background knowledge for working with `.agents/`. This skill is not invoked directly.

## The distinction that governs everything

**Memory is state about the worker. The task graph is state about the work.**

principled-tasks (ADR-017) owns the backlog: what needs doing, what blocks what, who is
assigned. principled-agent owns what an agent has _learned_. When deciding where
something belongs, ask whether it would still be true after every open task closed. If
yes, it is memory.

## What belongs in memory

Durable facts about the codebase that an agent would otherwise rediscover every session:

- Conventions that are not obvious from any single file (`lib/` layout, ADR-018)
- Environment constraints (macOS ships bash 3.2 — no `declare -A`, no `grep -P`)
- Pitfalls encountered and the correct approach instead
- Where things live, when the location is surprising

## What does not belong in memory

- **Task state.** That is the manifest's job (ADR-008) or the task graph's (ADR-017).
- **Anything session-scoped.** If it stops being true when the session ends, it is not
  memory.
- **Secrets.** `.agents/` is committed and pushed like any other directory.
- **Speculation.** Memory is asserted to future agents as fact. An uncertain conclusion
  recorded confidently becomes a bug that recurs on every spawn.

## Which agents carry memory

Only agents spawned repeatedly for substantively similar work accumulate anything
useful. Agents that run a deterministic script learn nothing by definition.

| Agent              | Memory? | Rationale                                    |
| ------------------ | :-----: | -------------------------------------------- |
| `impl-worker`      |   Yes   | Implementation patterns, codebase knowledge  |
| `issue-ingester`   |   Yes   | Triage and classification patterns           |
| `pr-reviewer`      |   Yes   | Recurring review themes                      |
| `module-auditor`   |   No    | Runs a deterministic script                  |
| `decision-auditor` |   No    | Checks supersession chains deterministically |
| `boundary-checker` |   No    | Scans imports against fixed rules            |

This is recorded in `.agents/registry.json` as the `memory` flag.

## Format

Markdown with YAML frontmatter, one file per agent (ADR-020). Frontmatter carries
queryable metadata; the body carries prose the model reads directly.

Memory is **revised, not appended**. A learning that turns out to be wrong is edited
out, and git history records that it was ever believed. This is the property that
distinguishes memory from the event log in ADR-017, where past entries are immutable by
design — a wrong learned pattern that cannot be deleted compounds on every spawn.

Metric fields (`session_count`, `total_tasks`, `success_rate`, `last_updated`) are
script-owned. Use `agent-memory.sh --update-metrics`; do not hand-edit them.

`specializations` is **reserved and currently unused**. Nothing populates it, so every
agent's is `[]`. Dispatch routes by `role` from the registry instead — a field that is
populated for every agent and stable (#37). RFC-013's `/improve` is the intended writer,
once there is evidence to write from.

## The context budget

Every byte of memory is injected at spawn and competes with the task description for
the model's attention. The budget is therefore stated in bytes:

| Size         | Behaviour                                    |
| ------------ | -------------------------------------------- |
| under 8 KB   | silent                                       |
| 8 KB – 16 KB | advisory warning, synthesis suggested        |
| over 16 KB   | louder warning; injection still delivers all |

**Injection is never truncated.** A silently halved memory file gives an agent a
confidently incomplete picture, and the loss is invisible to it. Oversized memory is
reported, never quietly trimmed.

The cure for a bloated file is synthesis — rewriting many accumulated notes into fewer,
denser statements. That requires judgment, so it is a human act today. RFC-013's
`/improve` will automate it.

## Forks

`.agents/` is committed, so a fork inherits everything. Knowledge should transfer — it
describes code the fork still has. Performance metrics should not: they describe a
record against the parent repository's codebase and CI.

Fork detection is unreliable (a fork, a template instantiation, and a clone are
indistinguishable from inside the repository), so resetting is an explicit command:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --reset-metrics
```

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh` — memory and registry interface (ADR-018)
