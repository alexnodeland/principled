---
name: spawn
description: >
  Execute a task from a DDD plan in an isolated git worktree. Reads task
  details from the manifest, embeds them in the prompt, and delegates to
  the impl-worker agent for worktree-isolated execution. Use after
  decomposing a plan into tasks.
context: fork
agent: impl-worker
user-invocable: true
---

# Spawn — Worktree-Isolated Task Execution

Execute task `$ARGUMENTS` from the current DDD implementation plan.

## Task Details

!`bash scripts/task-manifest.sh --get-task --task-id $0 2>/dev/null || echo "Error: could not load task $0 from manifest"`

## Plan Context

!`bash scripts/task-manifest.sh --get-plan-path 2>/dev/null | xargs -I{} bash scripts/parse-plan.sh --file {} --metadata 2>/dev/null || echo "Error: could not load plan metadata"`

## Related Tasks in This Phase

!`bash scripts/task-manifest.sh --list-tasks --phase $(bash scripts/task-manifest.sh --get-task --task-id $0 2>/dev/null | grep '^phase=' | cut -d= -f2) 2>/dev/null || echo "No related tasks found"`

## Instructions

You are the **impl-worker** agent running in an isolated git worktree. Your job is to implement the task described above.

1. **Create a named branch.** Use the plan number and task ID from the details above:

   ```bash
   git checkout -b impl/<plan-number>/<task-id-sanitized>
   ```

   Replace dots with hyphens in the task ID (e.g., `1.1` becomes `1-1`).

2. **Implement the task.** Make all necessary file changes to complete the described work. Focus only on what the task describes.

3. **Run available checks.** If the project has tests or linters, run them:
   - Look for `package.json` scripts, `Makefile` targets, or other test commands
   - Run what is available in this worktree

4. **Commit your changes** with the conventional format:

   ```
   impl(<plan-number>): <task-id> — <brief description>
   ```

5. **Report results:**
   - Branch name created
   - Files changed
   - Summary of implementation
   - Test results (if any)
   - Blockers encountered (if any)

Do NOT push, merge, or modify the main branch. If blocked by out-of-scope issues, document in `.task-blockers.md`.
