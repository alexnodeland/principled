---
name: task-open
description: >
  Create a new task in the persistent task graph. Supports optional
  plan linking, blocking edges, and discovery tracking. The task is
  committed to Git after creation. Use when tracking new work items,
  discovered tasks, or plan-linked implementation tasks.
allowed-tools: Read, Write, Bash(bash plugins/*), Bash(bash scripts/*), Bash(sqlite3 *), Bash(git add *), Bash(git commit *), Bash(mkdir *), Bash(ls *)
user-invocable: true
---

# Task Open — Create a Task

Create a new task in the task graph and commit the change to Git.

## Command

```
/task-open <title> [--plan NNN] [--blocks <id>] [--discovered-from <id>]
```

## Arguments

| Argument                 | Required | Description                                    |
| ------------------------ | -------- | ---------------------------------------------- |
| `<title>`                | Yes      | Human-readable task description                |
| `--plan NNN`             | No       | Link to a plan number (e.g., `003`)            |
| `--blocks <id>`          | No       | Comma-separated task IDs that this task blocks |
| `--discovered-from <id>` | No       | Task ID that led to discovery of this task     |

## Workflow

1. **Parse arguments.** Extract `<title>` and optional flags from `$ARGUMENTS`.

2. **Initialize storage if needed.** If `.principled/tasks.jsonl` does not exist (safe to run either way — it is idempotent):

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --init
   ```

3. **Create the task.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --open \
     --title "<title>" \
     [--plan "<NNN>"] \
     [--blocks "<id1,id2>"] \
     [--discovered-from "<id>"]
   ```

   Captures the generated task ID from stdout.

4. **Commit to Git.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --commit "tasks: open <task-id> — <title>"
   ```

5. **Report result.** Display:
   - Created task ID
   - Title and status (`open`)
   - Any edges created (blocks, spawned_by)
   - Plan link if specified
   - Next steps: _"Use `/task-close <id>` when done, or `/task-graph` to see the full graph."_

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh` — task graph interface (single shared copy, ADR-018)
