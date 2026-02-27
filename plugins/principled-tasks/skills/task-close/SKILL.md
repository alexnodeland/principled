---
name: task-close
description: >
  Close a task (bead) in the persistent task graph by marking it as done
  or abandoned. Optionally attach notes explaining the resolution.
  The change is committed to Git. Use when a task is completed or
  no longer relevant.
allowed-tools: Read, Bash(bash plugins/*), Bash(bash scripts/*), Bash(sqlite3 *), Bash(git add *), Bash(git commit *), Bash(ls *)
user-invocable: true
---

# Task Close — Resolve a Bead

Close a task (bead) in the `.impl/tasks.db` graph by setting its status to `done` or `abandoned`, and commit the change to Git.

## Command

```
/task-close <id> [--notes <text>]
```

## Arguments

| Argument        | Required | Description                                         |
| --------------- | -------- | --------------------------------------------------- |
| `<id>`          | Yes      | Bead ID to close (e.g., `bead-0a3f`)                |
| `--notes <text>`| No       | Resolution notes (e.g., "Fixed via PR #42")         |

## Workflow

1. **Parse arguments.** Extract `<id>` and optional `--notes` from `$ARGUMENTS`.

2. **Verify the bead exists.** Run:

   ```bash
   bash scripts/task-db.sh --get --id <id>
   ```

   If no bead found, report: _"No bead found with id '\<id\>'."_

3. **Confirm closure intent.** If the bead status is already `done` or `abandoned`, report: _"Bead '\<id\>' is already closed (status: \<status\>)."_ and stop.

4. **Close the bead.** Run:

   ```bash
   bash scripts/task-db.sh --close \
     --id <id> \
     [--notes "<text>"] \
     --status done
   ```

   Use `--status abandoned` if the user indicates the task should be abandoned rather than completed.

5. **Commit to Git.** Run:

   ```bash
   bash scripts/task-db.sh --commit "tasks: close <id> — done"
   ```

6. **Report result.** Display:
   - Closed bead ID and title
   - New status and closed_at timestamp
   - Notes if provided
   - Remaining open beads count: _"N beads still open."_

## Scripts

- `scripts/task-db.sh` — SQLite interface for bead graph operations (copy from task-open)
