---
name: task-close
description: >
  Close a task in the persistent task graph by marking it as done
  or abandoned. Optionally attach notes explaining the resolution.
  The change is committed to Git. Use when a task is completed or
  no longer relevant.
allowed-tools: Read, Bash(bash plugins/*), Bash(bash scripts/*), Bash(sqlite3 *), Bash(git add *), Bash(git commit *), Bash(ls *)
user-invocable: true
---

# Task Close — Resolve a Task

Close a task in the task graph by setting its status to `done` or `abandoned`, and commit the change to Git.

## Command

```
/task-close <id> [--notes <text>]
```

## Arguments

| Argument         | Required | Description                                 |
| ---------------- | -------- | ------------------------------------------- |
| `<id>`           | Yes      | Task ID to close (e.g., `task-0a3f`)        |
| `--notes <text>` | No       | Resolution notes (e.g., "Fixed via PR #42") |

## Workflow

1. **Parse arguments.** Extract `<id>` and optional `--notes` from `$ARGUMENTS`.

2. **Verify the task exists.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --get --id <id>
   ```

   If no task found, report: _"No task found with id '\<id\>'."_

3. **Confirm closure intent.** If the task status is already `done` or `abandoned`, report: _"Task '\<id\>' is already closed (status: \<status\>)."_ and stop.

4. **Close the task.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --close \
     --id <id> \
     [--notes "<text>"] \
     --status done
   ```

   Use `--status abandoned` if the user indicates the task should be abandoned rather than completed.

5. **Commit to Git.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --commit "tasks: close <id> — done"
   ```

6. **Report result.** Display:
   - Closed task ID and title
   - New status and closed_at timestamp
   - Notes if provided
   - Remaining open tasks count: _"N tasks still open."_

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh` — task graph interface (single shared copy, ADR-018)
