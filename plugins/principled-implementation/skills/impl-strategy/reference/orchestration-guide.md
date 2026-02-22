# Orchestration Guide

The implementation orchestrator manages the full lifecycle of executing a DDD plan: decomposition, agent spawning, validation, merging, and error recovery.

## Lifecycle Overview

```
Decompose ──→ Spawn ──→ Validate ──→ Merge ──→ Next Phase
                 │          │           │
                 │          └── Retry ──┘
                 │
                 └── Abandon (max retries)
```

## Stages

### Stage 1: Decomposition

1. Read the DDD plan file and verify `status: active`
2. Extract metadata: title, number, originating proposal
3. Extract phases and tasks with dependency ordering
4. Initialize the task manifest at `.impl/manifest.json`
5. Populate all tasks with status `pending`

### Stage 2: Phase Iteration

Phases execute sequentially, respecting the dependency graph:

1. Check if all dependency phases have all tasks in status `merged` (or `abandoned`)
2. A phase is "ready" when its dependencies are satisfied
3. Collect all `pending` tasks in the current phase

### Stage 3: Task Execution

For each task in the current phase:

1. **Update manifest**: set task status to `in_progress`
2. **Invoke `/spawn <task-id>`**: this forks to the impl-worker agent in a worktree
3. **Agent works**: implements the task, commits changes, returns summary
4. **Update manifest**: set status to `validating`, record branch name
5. **Run validation**: execute project checks against the worktree
6. **If passed**: invoke `/merge-work <task-id>` to merge and clean up
7. **If failed**: decide whether to retry, skip, or pause

### Stage 4: Completion

After all phases are processed:

1. Report final summary: tasks merged, failed, abandoned
2. Clean up any remaining worktrees
3. If all tasks merged: the plan implementation is complete

## Error Recovery

### Task Failure

When a task fails validation:

- **Retry** (default): Re-spawn with failure context appended to the agent prompt. Up to 2 retries.
- **Skip**: Mark as `abandoned` and continue with remaining tasks. Use when the task is non-critical.
- **Pause**: Stop orchestration and report to user. Use when the failure blocks dependent phases.

### Merge Conflicts

When a worktree branch conflicts with the working branch:

1. Set task status to `conflict`
2. Report conflicting files
3. Pause orchestration
4. User resolves conflicts manually
5. Re-run with `--continue` to resume

### Interrupted Orchestration

If orchestration is interrupted (crash, timeout, manual stop):

1. The manifest preserves the last known state
2. Re-run with `--continue` to resume from where it stopped
3. Tasks that were `in_progress` at interruption time need manual inspection

## Decision Framework

The orchestrator decides what to do based on failure context:

| Failure Type                | Action                   | Rationale                         |
| --------------------------- | ------------------------ | --------------------------------- |
| Test failure (specific)     | Retry with error context | Agent can fix the specific issue  |
| Lint/formatting failure     | Retry with error context | Usually auto-fixable              |
| Build failure               | Retry once, then pause   | May indicate fundamental issue    |
| Agent error (non-zero exit) | Retry once, then abandon | Agent may have hit a hard blocker |
| Merge conflict              | Pause for user           | Requires human judgment           |
| All tasks in phase failed   | Pause for user           | Phase may need re-decomposition   |
