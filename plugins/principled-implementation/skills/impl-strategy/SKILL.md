---
name: impl-strategy
description: >
  Implementation orchestration strategy for the Principled framework.
  Consult when working with DDD plan execution, git worktrees for task
  isolation, task manifests, or the decompose-spawn-validate-merge lifecycle.
  Covers worktree management, sub-agent patterns, task state machines,
  and manifest schema.
user-invocable: false
---

# Implementation Strategy — Background Knowledge

This skill provides Claude Code with comprehensive knowledge of the Principled implementation orchestration strategy. It is not directly invocable — it informs Claude's behavior when implementation-related context is encountered.

## When to Consult This Skill

Activate this knowledge when:

- Working with `.impl/` directory or `manifest.json`
- Executing tasks from a DDD implementation plan
- Managing git worktrees for isolated task execution
- Launching or monitoring implementation sub-agents
- Discussing the decompose → spawn → validate → merge lifecycle
- Encountering task status fields or state transitions

## Reference Documentation

Read these files for detailed guidance on specific topics:

### Task Lifecycle

- **`reference/task-lifecycle.md`** — Complete task state machine: `pending → in_progress → validating → passed|failed → merged|abandoned`. Defines all valid transitions, retry behavior, and terminal states.

### Orchestration Guide

- **`reference/orchestration-guide.md`** — Full lifecycle walkthrough: decompose → spawn → validate → merge/re-decompose. Covers phase iteration, error recovery, merge conflict handling, and the decision framework for handling failures.

### Manifest Schema

- **`reference/manifest-schema.md`** — JSON schema for `.impl/manifest.json`. Field descriptions, types, valid status values, and concurrency notes.

## Key Principles

1. **Isolation via worktrees.** Every task gets its own git worktree via `isolation: worktree`. No task can interfere with another or with the main working tree.
2. **Phases are sequential; tasks within a phase are parallel.** Respect dependency ordering from the DDD plan.
3. **Validate before merge.** No worktree branch merges without passing the project's test/check suite.
4. **Manifest is the single source of truth.** All task state lives in `.impl/manifest.json`. Scripts read and update it atomically.
5. **Sub-agents are stateless.** Each impl-worker agent receives a self-contained prompt with all context needed to complete its task. It cannot access `.impl/manifest.json` directly.
6. **The orchestrator decides.** When failures occur, the orchestrator evaluates the failure type and decides whether to retry, skip, or pause for user input.
