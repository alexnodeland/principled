---
title: "Event-Driven Lifecycle Hooks for Pipeline Enforcement"
number: "015"
status: proposed
author: Alex
created: 2026-02-23
originating_proposal: "008"
superseded_by: null
---

# ADR-015: Event-Driven Lifecycle Hooks for Pipeline Enforcement

## Status

Proposed

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled marketplace's hook layer uses only 2 of the 17 available Claude Code hook events: `PreToolUse` and `PostToolUse`. All hooks use `type: "command"` (shell scripts). This was appropriate when the hooks were designed — Claude Code offered only these events — but the platform has since added lifecycle events that map directly to principled pipeline concerns:

- `WorktreeCreate` and `WorktreeRemove` — fired when agent worktree isolation creates or removes worktrees
- `SubagentStart` and `SubagentStop` — fired when subagents are spawned or finish
- `TaskCompleted` — fired when a task is marked complete in agent teams
- `TeammateIdle` — fired when an agent team teammate finishes its work

The current `principled-implementation` plugin manages worktree lifecycle imperatively within skill scripts (`spawn`, `merge-work`). Subagent completion is unvalidated — if `impl-worker` terminates without updating the manifest, tasks are orphaned in `in_progress` status. These operational concerns belong in the hook layer, not in skill logic.

Additionally, three critical documentation pipeline constraints are unenforced by hooks:

1. Plans must reference an accepted proposal (`originating_proposal` field)
2. Pipeline documents must have valid frontmatter (required fields with valid status values)
3. Document numbers (`NNN-*.md`) must be unique within their directory

These constraints are currently enforced only by skill scripts during creation. Manual file creation bypasses all validation.

The decision is whether to expand the hook layer to use lifecycle events and add enforcement guards, or to continue relying on skills for validation.

## Decision

Expand the hook layer in two dimensions:

**Dimension 1: New guard hooks for document creation enforcement.**

Add three `PreToolUse(Write)` guard hooks to `principled-docs` that validate pipeline document creation:

- `check-plan-proposal-link.sh` — verifies plans reference an accepted proposal
- `check-required-frontmatter.sh` — verifies required fields and valid status values per document type
- `check-doc-numbering.sh` — verifies document number uniqueness within the directory

These hooks use the existing `parse-frontmatter.sh` utility and follow the established pattern: default to allow (exit 0), block only when confident of a violation (exit 2).

**Dimension 2: Lifecycle event hooks for agent operations.**

Add hooks on `WorktreeCreate`, `WorktreeRemove`, `SubagentStop`, and `TaskCompleted` events in `principled-implementation`:

- `setup-impl-worktree.sh` on `WorktreeCreate` — initializes task-specific state in new worktrees
- `cleanup-impl-worktree.sh` on `WorktreeRemove` — archives logs and updates manifest
- `validate-worker-completion.sh` on `SubagentStop` — ensures impl-worker updated manifest before finishing
- `gate-task-completion.sh` on `TaskCompleted` — enforces quality checks before task completion

Additionally, add async hooks (`async: true`) for background template drift checking on `PostToolUse(Write)` across all plugins.

All new hooks follow existing conventions:

- Exit code 0 = allow, exit code 2 = block
- jq primary with grep/sed fallback
- Stdin JSON parsing
- Defensive defaults (allow when information is insufficient)

## Options Considered

### Option 1: Expand hooks to lifecycle events and add guards (chosen)

Use `WorktreeCreate`, `WorktreeRemove`, `SubagentStop`, `TaskCompleted` events for agent lifecycle management. Add guard hooks for document creation validation.

**Pros:**

- Deterministic enforcement: constraints are checked on every write, not just during skill invocation
- Separation of concerns: lifecycle management moves from skill scripts to hooks, simplifying skills
- Leverages platform capabilities: hooks on lifecycle events are purpose-built for the exact problems being solved
- Async hooks enable background validation without blocking the user

**Cons:**

- More hooks increase the number of scripts to maintain and the potential for interaction effects
- Multiple guards on `PreToolUse(Write)` for pipeline documents add latency (sequential execution, 10s timeout each)
- New lifecycle events are relatively recent additions to Claude Code; documentation and community patterns are still maturing

### Option 2: Keep hooks minimal, expand skill-based validation

Add more analytical skills for validation instead of hooks. For example, add a `/validate-frontmatter` skill.

**Pros:**

- Simpler hook layer — fewer scripts, fewer interaction effects
- Skills provide richer feedback (detailed reports vs. pass/fail)
- No dependency on newer Claude Code hook events

**Cons:**

- Skills require explicit invocation — a user can always skip validation
- The enforcement gap remains: manual file creation bypasses all checks
- Worktree lifecycle management stays embedded in skill scripts, violating separation of concerns
- No background validation capability

### Option 3: Use prompt/agent hook types for semantic validation

Use `type: "prompt"` or `type: "agent"` hooks instead of shell scripts for nuanced validation.

**Pros:**

- LLM-based evaluation can catch semantic violations that regex cannot (e.g., substantive ADR changes disguised as `superseded_by` updates)
- Agent hooks can trace import chains and validate cross-document references with tool access

**Cons:**

- Token cost: every `PreToolUse(Write)` invocation would consume LLM tokens for validation
- Latency: prompt hooks add model inference time; agent hooks add multi-turn execution time
- Non-deterministic: LLM evaluation is probabilistic, violating the principled methodology's preference for deterministic enforcement
- Overkill for the identified gaps, which are all structurally checkable (frontmatter fields, file existence, number uniqueness)

## Consequences

### Positive

- The three most critical documentation pipeline constraints become deterministic guardrails, enforced on every write regardless of whether the write was initiated by a skill or manually.
- Worktree lifecycle management is event-driven rather than imperative, simplifying skill scripts and reducing the chance of orphaned state.
- Subagent completion validation prevents orphaned in-progress tasks in the manifest.
- Async drift checking provides continuous background validation without blocking the user's workflow.
- The hook layer's coverage expands from 2 event types to 6, better utilizing the platform's capabilities.

### Negative

- Pipeline document writes now trigger up to 4 hooks sequentially (2 existing guards + up to 2 new guards), adding latency.
- The `principled-implementation` plugin's hook count grows from 1 to 5, increasing maintenance surface.
- Lifecycle event hooks (`WorktreeCreate`, `WorktreeRemove`, `SubagentStop`, `TaskCompleted`) don't support matchers — they fire on every occurrence, requiring the script to filter relevant events.
- Cross-plugin hook ordering is not guaranteed. If principled-docs and principled-implementation both define `PreToolUse(Write)` hooks, execution order may vary.

## References

- [RFC-008: Hooks, Subagents, and Agent Teams Integration](../proposals/008-hooks-subagents-agent-teams-integration.md)
- [ADR-001: Pure Bash Frontmatter Parsing Strategy](./001-frontmatter-parsing-strategy.md) — the parsing utility that new guards build upon
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) — complete event inventory and handler types
- Implementation: `plugins/principled-docs/hooks/scripts/parse-frontmatter.sh` (shared dependency for new guards)
