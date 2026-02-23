---
title: "Agent Teams for Parallel Plan Execution"
number: "016"
status: proposed
author: Alex
created: 2026-02-23
originating_proposal: "008"
superseded_by: null
---

# ADR-016: Agent Teams for Parallel Plan Execution

## Status

Proposed

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-implementation plugin orchestrates DDD plan execution via `/orchestrate`, which decomposes a plan into phased tasks, spawns `impl-worker` subagents to implement each task in an isolated worktree, validates results, and merges branches. This orchestrator runs inline (not forked) and executes tasks **sequentially** within each phase.

This sequential model was a deliberate choice (RFC-006, Alternative 3) because Claude Code's sub-agent model at the time supported only sequential spawning, and parallel merges would create complex conflict scenarios. However, Claude Code has since introduced **agent teams** — an experimental multi-session orchestration feature that provides:

- **Parallel execution**: multiple teammates run concurrently, each in its own context window
- **Shared task list**: file-backed task board with dependency tracking and file-lock-based claiming
- **Inter-agent messaging**: a mailbox system where teammates can message each other and the lead
- **Lifecycle hooks**: `TeammateIdle` and `TaskCompleted` events for enforcement and automation
- **Display modes**: in-process, split-pane (tmux/iTerm2), or auto-detected

The question is whether the principled marketplace should adopt agent teams for parallel task execution, and if so, how to integrate them with the existing manifest-driven orchestration model (ADR-008).

Three usage patterns are candidates for agent teams:

1. **Plan execution** (principled-implementation): tasks within a phase that have no interdependencies could execute concurrently
2. **Multi-PR review** (principled-quality): multiple PRs could be reviewed in parallel
3. **Monorepo audit** (principled-docs): modules could be validated concurrently

## Decision

Adopt Claude Code agent teams as an opt-in parallel execution layer for principled-implementation's `/orchestrate` skill. The orchestrator becomes the team lead, spawning one teammate per independent task within the current phase. The existing manifest-driven state model (ADR-008) remains the source of truth, with the agent teams task list serving as the coordination mechanism during execution.

The integration model:

1. **Opt-in via environment variable**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` must be set. When disabled, `/orchestrate` falls back to sequential subagent spawning (current behavior). No breaking changes.

2. **Lead-teammate mapping**: the orchestrator session is the team lead. For each phase, it populates the agent teams task list with one task per plan task that has no unresolved dependencies. Teammates self-claim tasks and execute them in isolated worktrees.

3. **Dual state model**: the agent teams task list drives coordination (claiming, dependencies, completion). The `.impl/manifest.json` remains the persistent record (branch names, retry counts, check results, error messages). The lead synchronizes between the two: team task completion triggers manifest updates.

4. **Lifecycle hooks**: `TaskCompleted` hooks enforce quality gates (checks must pass before a task is marked complete). `TeammateIdle` hooks reassign idle teammates to review or cleanup work rather than letting them go idle.

5. **Merge strategy**: when all tasks in a phase complete, the lead merges branches sequentially (same as current behavior). Parallel merges are explicitly avoided to prevent complex conflict resolution.

6. **Fallback guarantee**: every skill that supports agent teams must also support sequential execution. The decision of whether to use teams is made at runtime based on the environment variable, not at skill definition time.

## Options Considered

### Option 1: Adopt agent teams with dual state model (chosen)

Use agent teams for parallel execution while keeping the manifest as the persistent state record.

**Pros:**

- Parallel execution for independent tasks within a phase — potential 3-5x speedup
- Built-in dependency tracking in the task list handles ordering automatically
- File-lock-based task claiming prevents race conditions
- `TaskCompleted` and `TeammateIdle` hooks enable quality enforcement and resource reuse
- Backward compatible: falls back to sequential execution when agent teams are disabled

**Cons:**

- Dual state model (task list + manifest) introduces synchronization complexity
- Agent teams are experimental; API may change before GA
- Token cost scales with the number of concurrent teammates (3-4x for 3 teammates)
- Parallel execution may surface merge conflicts more frequently (mitigated by sequential merge phase)

### Option 2: Expand subagents with manual parallel coordination

Spawn multiple subagents concurrently using the Task tool instead of agent teams.

**Pros:**

- Simpler model — subagents are well-understood in the principled ecosystem
- No dependency on experimental features
- Each subagent reports back to the main context, enabling centralized coordination

**Cons:**

- Subagents cannot message each other — coordination must be centralized
- No built-in task list or dependency tracking — must be reimplemented in skill logic
- No `TaskCompleted` or `TeammateIdle` hooks — validation must be manually triggered
- The principled ecosystem already has one subagent pattern; this would be an incremental extension, not a qualitative improvement

### Option 3: Wait for agent teams to reach GA before adopting

Defer agent teams integration until the feature is stable and well-documented.

**Pros:**

- No risk of breaking changes in the agent teams API
- More community patterns and best practices will be available
- Reduced complexity in the near term

**Cons:**

- Sequential execution bottleneck persists for the foreseeable future
- The principled marketplace misses the opportunity to be an early exemplar of agent teams integration
- Performance improvements for large plans are delayed
- The fallback guarantee (opt-in via env var) already mitigates the stability risk

## Consequences

### Positive

- Tasks within a phase that have no interdependencies execute concurrently, reducing wall-clock time for multi-task phases.
- The native task list with dependency tracking replaces manual dependency checking in the orchestrator script.
- `TaskCompleted` hooks provide a natural enforcement point for quality gates, cleaner than the current post-spawn validation loop.
- `TeammateIdle` hooks enable efficient resource use — idle teammates can be redirected to review or cleanup tasks.
- The opt-in model ensures zero risk to existing workflows. Disabling the environment variable reverts to proven sequential behavior.

### Negative

- The dual state model (agent teams task list + `.impl/manifest.json`) requires careful synchronization. If the lead crashes mid-phase, the two states may diverge, requiring manual reconciliation.
- Token cost increases significantly for parallel phases. A phase with 4 tasks uses roughly 4x the tokens of sequential execution.
- Display mode depends on the user's terminal environment. In-process mode (non-tmux) may be confusing for users unfamiliar with agent teams.
- The experimental nature of agent teams means the integration code may need updates as the feature evolves toward GA.

## References

- [RFC-008: Hooks, Subagents, and Agent Teams Integration](../proposals/008-hooks-subagents-agent-teams-integration.md)
- [RFC-006: Principled Implementation Plugin](../proposals/006-principled-implementation-plugin.md) — original decision to use sequential execution (Alternative 3)
- [ADR-007: Worktree Isolation for Task Execution](./007-worktree-isolation-for-task-execution.md) — worktree isolation model that agent teams build upon
- [ADR-008: Manifest-Driven Orchestration State](./008-manifest-driven-orchestration-state.md) — persistent state model that persists alongside the agent teams task list
- [Claude Code Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams) — feature reference
