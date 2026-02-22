---
name: check-impl
description: >
  Validate task implementations by running the project's test suite,
  linters, and CI checks. Discovers test commands from common project
  patterns (package.json, Makefile, pytest, cargo, go) and reports
  pass/fail with details. Use after a sub-agent completes a task.
allowed-tools: Read, Bash(npm *), Bash(npx *), Bash(make *), Bash(bash *), Bash(git *), Bash(ls *), Bash(grep *), Bash(find *)
user-invocable: true
---

# Check Implementation — Validation Runner

Run the project's test suite and checks against a task's implementation to verify correctness.

## Command

```
/check-impl [--task <task-id>] [--all]
```

## Arguments

| Argument      | Required             | Description                                 |
| ------------- | -------------------- | ------------------------------------------- |
| `--task <id>` | Yes (unless `--all`) | Specific task to validate                   |
| `--all`       | No                   | Validate all tasks with status `validating` |

## Workflow

1. **Parse arguments.** Determine target task(s) from `$ARGUMENTS`.

2. **Identify worktree path(s).** For each target task:
   - Read the task's branch from the manifest: `bash scripts/task-manifest.sh --get-task --task-id <id>`
   - Discover the worktree path via `git worktree list` matching the branch name

3. **Discover check commands.** Run:

   ```bash
   bash scripts/run-checks.sh --discover --cwd <worktree-path>
   ```

   Reports which checks were discovered and their sources. See `reference/check-discovery.md` for supported project types.

4. **Run checks.** For each task, within its worktree:

   ```bash
   bash scripts/run-checks.sh --execute --cwd <worktree-path>
   ```

   Runs each discovered check and captures exit code + output.

5. **Update manifest.** Run:

   ```bash
   bash scripts/task-manifest.sh --update-status \
     --task-id <task-id> \
     --status passed|failed \
     --check-results "<summary>"
   ```

6. **Report results.** For each task:
   - List each check run with pass/fail status
   - Show failing check output (first 20 lines if lengthy)
   - Overall verdict: PASS or FAIL
   - If PASS: _"Run `/merge-work <task-id>` to merge."_
   - If FAIL: _"Fix issues and re-run `/spawn <task-id>` to retry, or address manually in the worktree."_

## Scripts

- `scripts/run-checks.sh` — Check discovery and execution (canonical copy)
- `scripts/task-manifest.sh` — Task manifest CRUD (copy from decompose)

## Reference

- `reference/check-discovery.md` — How check commands are discovered from various project types
