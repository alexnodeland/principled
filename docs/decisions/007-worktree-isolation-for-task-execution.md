---
title: "Worktree Isolation for Sub-Agent Task Execution"
number: "007"
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-22
from_proposal: "006"
supersedes: null
superseded_by: null
---

# ADR-007: Worktree Isolation for Sub-Agent Task Execution

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-implementation plugin executes DDD plan tasks by delegating to Claude Code sub-agents. Each task involves code changes that must be independently validated and merged. The question is how to isolate these task executions from each other and from the main working tree.

Three isolation strategies were considered:

1. **Git worktrees** — Each task gets its own worktree (a separate checkout of the repository), providing full filesystem isolation.
2. **Git branches only** — Tasks work on branches in the main working tree, switching branches between tasks.
3. **Stash-based isolation** — Stash current changes, work on a task, commit, pop stash for the next task.

## Decision

Use git worktrees for sub-agent task isolation. The `/spawn` skill uses `context: fork` and `agent: impl-worker` frontmatter, which causes Claude Code to create a new worktree for the sub-agent. Each task runs in its own filesystem checkout, creates a named branch (`impl/<plan-number>/<task-id>`), implements the work, and commits. The main working tree is never modified during task execution.

## Options Considered

### Option 1: Git worktrees (chosen)

Each sub-agent gets its own worktree via Claude Code's `isolation: worktree` agent configuration.

**Pros:**

- Full filesystem isolation — tasks cannot interfere with each other or the main tree
- Each task's branch exists independently and can be validated in its worktree
- Merge conflicts are detected cleanly at merge time, not during implementation
- Supports the stateless sub-agent model: agent receives context in prompt, works in isolated tree

**Cons:**

- Disk space usage: each worktree is a full checkout (though git shares object storage)
- Worktree cleanup required after merge or abandonment
- Git worktree operations add complexity to the merge and cleanup workflow

### Option 2: Branch switching in main working tree

Tasks work sequentially on branches, with `git checkout` between tasks.

**Pros:**

- No additional disk usage
- Simpler git operations

**Cons:**

- Uncommitted changes from a failed task pollute the working tree for the next task
- Branch switching with uncommitted changes requires stashing, which is fragile
- Cannot validate a task's branch while working on another task
- No isolation from the main session's state

### Option 3: Stash-based isolation

Use `git stash` to save/restore work-in-progress between tasks.

**Pros:**

- No additional disk usage
- Works with a single branch

**Cons:**

- Stash conflicts are common and hard to debug
- No named tracking — stash entries are anonymous and easy to lose
- Cannot run checks against a stashed state
- Fundamentally incompatible with the sub-agent model (agents need a stable filesystem)

## Consequences

### Positive

- Clean isolation guarantees: each task starts from the base branch state, unaffected by other tasks
- Independent validation: checks run in the task's worktree against exactly the changes that task made
- Clean merge semantics: `git merge --no-ff` from a worktree branch is well-understood
- Compatible with Claude Code's agent isolation model (`isolation: worktree` in agent definition)
- Worktrees share git object storage, so disk overhead is limited to checked-out files

### Negative

- Disk usage scales linearly with concurrent worktrees (mitigated by sequential execution and cleanup after merge)
- Worktree paths must be tracked in the manifest for cleanup
- Sub-agents cannot access main worktree files — all context must be injected via the prompt (backtick pre-fork commands)

## References

- [RFC-006: Principled Implementation Plugin](../proposals/006-principled-implementation-plugin.md)
- Claude Code agent documentation: `isolation: worktree` configuration
- Implementation: `plugins/principled-implementation/agents/impl-worker.md`
