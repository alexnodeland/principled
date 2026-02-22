# Task Lifecycle

Tasks extracted from DDD plans follow a defined state machine with explicit transitions and recovery paths.

## State Machine

```
pending ──→ in_progress ──→ validating ──→ passed ──→ merged
                 │                │           │
                 │                │           └──→ conflict ──→ merged (manual resolve)
                 │                │
                 │                └──→ failed ──→ in_progress (retry, max 2)
                 │                                     │
                 └──→ abandoned                        └──→ abandoned (max retries)
```

## States

| State         | Description                                       | Mutable  | Who Transitions                  |
| ------------- | ------------------------------------------------- | -------- | -------------------------------- |
| `pending`     | Task extracted from plan, not yet started         | Yes      | Orchestrator on spawn            |
| `in_progress` | Sub-agent is actively working in a worktree       | Yes      | Orchestrator on spawn            |
| `validating`  | Sub-agent completed, checks running               | Yes      | Orchestrator after agent returns |
| `passed`      | All checks passed, ready for merge                | Yes      | check-impl skill                 |
| `failed`      | Checks failed or agent errored                    | Yes      | check-impl skill or orchestrator |
| `merged`      | Branch merged to working branch, worktree cleaned | Terminal | merge-work skill                 |
| `abandoned`   | Task cannot be completed (max retries or manual)  | Terminal | Orchestrator or user             |
| `conflict`    | Merge conflict during branch merge                | Yes      | merge-work skill                 |

## Valid Transitions

| From          | To            | Trigger                    | Condition                         |
| ------------- | ------------- | -------------------------- | --------------------------------- |
| `pending`     | `in_progress` | `/spawn` invoked           | Task exists and is pending        |
| `in_progress` | `validating`  | Agent returns successfully | Agent committed changes           |
| `in_progress` | `failed`      | Agent returns with error   | Agent exited non-zero or errored  |
| `in_progress` | `abandoned`   | Manual decision            | User decides to skip              |
| `validating`  | `passed`      | `/check-impl` passes       | All checks exit 0                 |
| `validating`  | `failed`      | `/check-impl` fails        | One or more checks fail           |
| `passed`      | `merged`      | `/merge-work` succeeds     | Branch merges cleanly             |
| `passed`      | `conflict`    | `/merge-work` conflicts    | Git merge conflict                |
| `failed`      | `in_progress` | Retry (re-spawn)           | retries < 2                       |
| `failed`      | `abandoned`   | Max retries reached        | retries >= 2                      |
| `conflict`    | `merged`      | Manual conflict resolution | User resolves and completes merge |

## Retry Behavior

When a task fails validation, the orchestrator may retry:

1. The `retries` counter increments on each `failed → in_progress` transition
2. Maximum 2 retries (3 total attempts)
3. On retry, the agent prompt includes the previous failure context so it can learn from the error
4. After exhausting retries, the task is marked `abandoned`

## Terminal States

Tasks in `merged` or `abandoned` states cannot transition further. They represent the final outcome of the task.
