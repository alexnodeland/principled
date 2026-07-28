# task-update

Update the status, notes, or agent assignment of an existing task without closing it.

## Command

```
/task-update --id <task-id> --status <status> [--notes <text>] [--agent <name>]
```

## Arguments

| Flag       | Required | Description                                                  |
| ---------- | -------- | ------------------------------------------------------------ |
| `--id`     | Yes      | Task ID to update (e.g. `task-0a3f`)                         |
| `--status` | Yes      | New status: `open`, `in_progress`, `blocked`, or `abandoned` |
| `--notes`  | No       | Append a note to the task                                    |
| `--agent`  | No       | Reassign the task to a different agent                       |

## Examples

```bash
# Mark a task as in-progress
/task-update --id task-0a3f --status in_progress

# Mark blocked with context
/task-update --id task-0a3f --status blocked --notes "Waiting on PR #42 to merge"

# Reassign to another agent
/task-update --id task-0a3f --status in_progress --agent impl-worker
```

## Status Lifecycle

```
open ──→ in_progress ──→ done (via /task-close)
  │          │
  │          ├──→ blocked ──→ open (when unblocked)
  │          │
  │          └──→ abandoned (via /task-close)
  │
  └──→ abandoned (via /task-close)
```

Use `/task-close` to move a task to `done` or `abandoned`. Use `/task-update` for all intermediate transitions.

## Implementation

Calls `task-db.sh --update` with the provided flags.
