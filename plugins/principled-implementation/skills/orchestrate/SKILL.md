---
name: orchestrate
description: >
  Top-level orchestrator for DDD plan execution. Decomposes a plan into
  tasks, iterates through phases respecting dependencies, spawns
  worktree-isolated agents, validates implementations, and merges
  results. Runs inline to coordinate multiple sub-agent spawns. Use
  for automated end-to-end plan execution.
allowed-tools: Read, Write, Bash(git *), Bash(mkdir *), Bash(ls *), Bash(grep *), Bash(find *), Bash(npm *), Bash(npx *), Bash(make *), Bash(bash plugins/*)
user-invocable: true
---

# Orchestrate — Full Lifecycle Execution

Execute a complete DDD plan from decomposition through validation and merge, managing the entire lifecycle automatically.

## Command

```
/orchestrate <plan-path> [--phase <N>] [--continue] [--dry-run]
```

## Arguments

| Argument      | Required | Description                                          |
| ------------- | -------- | ---------------------------------------------------- |
| `<plan-path>` | Yes      | Path to DDD plan file                                |
| `--phase <N>` | No       | Execute only phase N (skip earlier completed phases) |
| `--continue`  | No       | Resume from existing manifest (skip decomposition)   |
| `--dry-run`   | No       | Decompose and plan but do not execute                |

## Workflow

### Stage 1: Decomposition

1. **Check for existing manifest.** If `--continue` and `.impl/manifest.json` exists, load it and skip to Stage 2. Report: _"Resuming from existing manifest."_

2. **Verify the plan.** Read `<plan-path>` and confirm `status` is `active`.

3. **Extract plan metadata and tasks.** Run:

   ```bash
   bash scripts/parse-plan.sh --file <plan-path> --metadata
   bash scripts/parse-plan.sh --file <plan-path> --tasks
   ```

4. **Initialize manifest.**

   ```bash
   mkdir -p .impl
   bash scripts/task-manifest.sh --init \
     --plan-path <plan-path> \
     --plan-number <number> \
     --plan-title "<title>"
   ```

5. **Populate all tasks.** For each extracted task:

   ```bash
   bash scripts/task-manifest.sh --add-task \
     --task-id <id> --phase <N> --description "<desc>" \
     --depends-on "<deps>" --bounded-contexts "<BCs>"
   ```

6. **Report decomposition.** Display phase/task summary. If `--dry-run`, stop here.

### Stage 2: Phase Iteration

For each phase (in numerical order, or just `--phase <N>` if specified):

1. **Check phase readiness.** A phase is ready when all tasks in its dependency phases have status `merged` or `abandoned`. Run:

   ```bash
   bash scripts/task-manifest.sh --phase-status --phase <dep>
   ```

   If any dependency phase has non-terminal tasks, wait or report the blocker.

2. **Identify pending tasks** in the current phase:

   ```bash
   bash scripts/task-manifest.sh --list-tasks --phase <N> --status pending
   ```

### Stage 3: Task Execution (for each task in the phase)

1. **Update manifest to in_progress.**

   ```bash
   bash scripts/task-manifest.sh --update-status \
     --task-id <id> --status in_progress
   ```

2. **Invoke `/spawn <task-id>`.** This forks to the impl-worker agent in an isolated worktree. The agent:
   - Creates a named branch (`impl/<plan-number>/<task-id>`)
   - Implements the task
   - Commits changes
   - Returns a summary

3. **Parse agent output.** Extract:
   - Branch name created
   - Files changed
   - Any blockers or errors

4. **Update manifest to validating.**

   ```bash
   bash scripts/task-manifest.sh --update-status \
     --task-id <id> --status validating \
     --branch <branch-name>
   ```

5. **Run validation.** Discover the worktree path and run checks:

   ```bash
   bash scripts/run-checks.sh --discover --cwd <worktree-path>
   bash scripts/run-checks.sh --execute --cwd <worktree-path>
   ```

6. **If checks pass:**
   - Update manifest to `passed`
   - Invoke `/merge-work <task-id>` to merge branch and clean up worktree
   - Manifest updates to `merged`

7. **If checks fail:** Decide based on failure type:
   - **Retryable** (test/lint failure, retries < 2): Update manifest to `failed`, increment retries, re-spawn with failure context appended
   - **Non-retryable** (max retries reached): Mark `abandoned`, continue with remaining tasks
   - **Critical** (blocks dependent phases): Pause and report to user with `--continue` instructions

### Stage 4: Phase Completion

1. **Check phase status.** After all tasks in the phase are processed:

   ```bash
   bash scripts/task-manifest.sh --phase-status --phase <N>
   ```

2. **Report phase results.** Display: tasks merged, failed, abandoned.

3. **Advance to next phase.** Return to Stage 2 for the next phase.

### Stage 5: Completion

1. **Final summary.** Run:

   ```bash
   bash scripts/task-manifest.sh --summary
   ```

   Report:
   - Total tasks: N
   - Merged: M
   - Failed/abandoned: F
   - Phases completed: P/T
   - If all merged: _"Plan \<number\> implementation complete."_
   - If some failed: list failed/abandoned tasks with details

2. **Clean up remaining worktrees.** For any worktrees still present:

   ```bash
   git worktree list
   ```

   Remove worktrees for merged or abandoned tasks.

## Error Recovery

- **Merge conflicts:** Pause orchestration, report conflicting files. Re-run with `--continue` after manual resolution.
- **Sub-agent failure:** Retry up to 2 times with failure context appended to the agent prompt. After exhausting retries, mark `abandoned`.
- **Interrupted orchestration:** Re-run with `--continue` to resume from the last known manifest state.
- **All tasks in phase failed:** Pause and report. The plan may need re-decomposition.

## Scripts

- `scripts/parse-plan.sh` — Plan parsing (copy from decompose)
- `scripts/task-manifest.sh` — Manifest CRUD (copy from decompose)
- `scripts/run-checks.sh` — Check runner (copy from check-impl)

## Templates

- `templates/claude-task.md` — Sub-agent instructions (copy from spawn)
