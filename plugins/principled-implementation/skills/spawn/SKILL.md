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

<!-- Errors are surfaced, not swallowed. These blocks are the only way the forked
     agent learns what it is supposed to build: if one fails silently, the agent
     proceeds with no task description and implements the wrong thing. -->

!`bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --get-task --task-id $0 || echo "FAILED to load task $0 from manifest — do not proceed; report this and stop."`

## Plan Context

!`bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --get-plan-path | xargs -I{} bash "${CLAUDE_PLUGIN_ROOT}/lib/parse-plan.sh" --file {} --metadata || echo "FAILED to load plan metadata — do not proceed; report this and stop."`

## Related Tasks in This Phase

!`bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --list-tasks --phase $(bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --get-task --task-id $0 | grep '^phase=' | cut -d= -f2) || echo "(no related tasks resolved)"`

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
