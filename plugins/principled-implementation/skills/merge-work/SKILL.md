---
name: merge-work
description: >
  Merge a completed and validated task's worktree branch back to the
  working branch. Verifies checks passed, performs the merge, cleans
  up the worktree, and updates the task manifest. Directly invocable
  by users and by the orchestrate skill.
allowed-tools: Read, Bash(git *), Bash(bash plugins/*), Bash(ls *)
user-invocable: true
---

# Merge Work — Worktree Branch Merge and Cleanup

Merge a task's implementation from its worktree branch back to the working branch, then clean up the worktree.

## Command

```
/merge-work <task-id> [--force] [--no-cleanup]
```

## Arguments

| Argument       | Required | Description                                            |
| -------------- | -------- | ------------------------------------------------------ |
| `<task-id>`    | Yes      | Task to merge                                          |
| `--force`      | No       | Merge even if checks have not passed (not recommended) |
| `--no-cleanup` | No       | Keep the worktree after merge for inspection           |

## Workflow

1. **Parse arguments.** Extract `<task-id>` and flags from `$ARGUMENTS`.

2. **Load task from manifest.** Run:

   ```bash
   bash scripts/task-manifest.sh --get-task --task-id <task-id>
   ```

   Verify:
   - Task exists
   - Status is `passed` (or any status if `--force`)
   - Branch name is recorded

   Without `--force`, if status is not `passed`: _"Task \<task-id\> has status '\<status\>'. Run `/check-impl --task <task-id>` first, or use `--force` to merge without validation."_

3. **Discover branch and worktree path.** Get the branch name from the manifest. If not recorded, search for it:

   ```bash
   git branch --list 'impl/*' | grep <task-id-sanitized>
   ```

   Find the worktree path:

   ```bash
   git worktree list | grep <branch>
   ```

4. **Merge branch.** From the main working tree:

   ```bash
   git merge <branch> --no-ff \
     -m "impl(<plan-number>): merge task <task-id> — <description>"
   ```

   **If merge conflict:**
   - Update manifest status to `conflict`
   - Report conflicting files
   - Do NOT auto-resolve
   - Instruct: _"Resolve conflicts manually, then run `/merge-work <task-id>` again."_

5. **Clean up worktree** (unless `--no-cleanup`):

   ```bash
   git worktree remove <worktree-path>
   git branch -d <branch>
   ```

6. **Update manifest.** Run:

   ```bash
   bash scripts/task-manifest.sh --update-status \
     --task-id <task-id> \
     --status merged
   ```

7. **Report results.** Display:
   - Merge commit hash
   - Cleanup status (removed or retained)
   - Remaining tasks in current phase
   - If all phase tasks merged: _"Phase \<N\> complete. Next phase tasks are now ready."_

## Scripts

- `scripts/task-manifest.sh` — Task manifest CRUD (copy from decompose)
