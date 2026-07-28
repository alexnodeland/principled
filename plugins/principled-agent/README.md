# principled-agent

Persistent agent identity and memory for the Principled methodology.

Agents start fresh every session. An `impl-worker` that learned this codebase uses
barrel exports relearns it on the next task, and the one after that. This plugin gives
agents a git-committed, reviewable place to keep what they have learned, and injects it
when they spawn.

Implements [RFC-011](../../docs/proposals/011-agent-memory-and-resumability.md).

## What it is not

This plugin tracks **state about the worker**, not state about the work.

- The backlog — what needs doing, what blocks what — belongs to
  [principled-tasks](../principled-tasks) (ADR-017).
- Execution state — which task is in progress, which merged — belongs to
  [principled-implementation](../principled-implementation) (ADR-008).

If a fact would still be true after every open task closed, it is memory. Otherwise it
belongs to one of the other two.

## Install

```
/plugin marketplace add alexnodeland/principled
/plugin install principled-agent
```

## Quick start

```bash
/agent-init                          # scaffold .agents/
/agent-memory --list                 # what each agent knows, and how big it is
/agent-memory impl-worker            # read one agent's memory
/agent-retro docs/plans/008-....md   # retrospective after an orchestration run
```

## Skills

| Skill            | Command                                             | Category   |
| ---------------- | --------------------------------------------------- | ---------- |
| `agent-strategy` | _(background — not user-invocable)_                 | Knowledge  |
| `agent-init`     | `/agent-init [--commit]`                            | Generative |
| `agent-memory`   | `/agent-memory [<id>] [--list] [--learn] [--check]` | Analytical |
| `agent-retro`    | `/agent-retro [<plan-path>] [--promote]`            | Generative |

## Hooks

| Hook                      | Event                     | Behaviour                                      |
| ------------------------- | ------------------------- | ---------------------------------------------- |
| Agent Memory Injection    | SubagentStart             | Surfaces memory at spawn; always exits 0       |
| Memory Integrity Advisory | PostToolUse (Edit\|Write) | Validates frontmatter and size; always exits 0 |

Neither hook ever blocks. A problem with memory must not prevent an agent from running.

## Layout

```
.agents/
  registry.json          # who exists, who carries memory, and why
  memory/
    global.md            # applies to every agent
    agents/<id>.md       # one file per memory-bearing agent
  retrospectives/        # dated records of individual runs
```

`.agents/` is committed. It is team knowledge, reviewed in pull requests like any other
document — which is what makes a bad learned pattern visible before it merges and
revertable after.

## The context budget

Every byte of memory is injected at spawn and competes with the task description.

| Size         | Behaviour                                       |
| ------------ | ----------------------------------------------- |
| under 8 KB   | silent                                          |
| 8 KB – 16 KB | advisory warning, synthesis suggested           |
| over 16 KB   | louder warning; injection still delivers it all |

**Injection is never truncated.** A silently halved memory file gives an agent a
confidently incomplete picture, and the loss is invisible to it. The cure is synthesis —
rewriting many notes into fewer, denser statements — which requires judgment and so
stays a human act for now. RFC-013's `/improve` will automate it.

## Format

Markdown with YAML frontmatter, one file per agent ([ADR-020](../../docs/decisions/020-agent-memory-as-document.md)):

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

Memory is **revised, not appended**. A learning that turns out to be wrong is edited out
and git records that it was ever believed. That is the deliberate difference from
ADR-017's event log, where past entries are immutable — a wrong learned pattern that
cannot be deleted compounds on every spawn.

Metric fields are script-owned. Use `--update-metrics`, don't hand-edit them.

`specializations` is reserved and unused — nothing populates it, so dispatch routes by
`role` from the registry instead (#37).

## Forks

`.agents/` is committed, so a fork inherits everything. Knowledge should transfer;
performance history should not. Fork detection is unreliable, so the reset is explicit:

```bash
bash lib/agent-memory.sh --reset-metrics
```

## Requirements

- Claude Code v2.1.3+
- Bash 3.2+ (stock macOS)
- jq optional — every script falls back to grep and awk

## Decisions

- [ADR-020: Agent Memory as a Frontmatter Document](../../docs/decisions/020-agent-memory-as-document.md)
- [ADR-021: Manifest Checkpoint and Criterion-Level Acceptance](../../docs/decisions/021-manifest-checkpoint-schema.md)
- [ADR-018: Shared Plugin lib/ Over Copies](../../docs/decisions/018-shared-plugin-lib-over-copies.md)
