# Task Manifest Schema

The task manifest at `.impl/manifest.json` is the single source of truth for orchestration state.

## Location

`.impl/manifest.json` in the repository root.

## Schema

```json
{
  "version": "1.0.0",
  "plan": {
    "path": "string — path to the DDD plan file",
    "number": "string — plan number (NNN format)",
    "title": "string — plan title",
    "decomposed_at": "string — ISO 8601 timestamp"
  },
  "phases": [
    {
      "number": "number — phase number",
      "depends_on": "number[] — phase numbers this phase depends on",
      "bounded_contexts": "string[] — BC identifiers (e.g., BC-1)"
    }
  ],
  "tasks": [
    {
      "id": "string — task identifier (e.g., 1.1, 2.3)",
      "phase": "number — phase this task belongs to",
      "description": "string — task description from the plan",
      "bounded_contexts": "string[] — BC identifiers",
      "status": "string — current task status",
      "branch": "string|null — git branch name for this task's worktree",
      "check_results": "string|null — summary of check results",
      "error": "string|null — error message if failed",
      "retries": "number — retry count (0 = first attempt)",
      "created_at": "string — ISO 8601 timestamp",
      "updated_at": "string — ISO 8601 timestamp"
    }
  ]
}
```

## Field Details

### Plan Object

| Field           | Type   | Description                                       |
| --------------- | ------ | ------------------------------------------------- |
| `path`          | string | Relative path to the DDD plan file from repo root |
| `number`        | string | Zero-padded plan number (e.g., "003")             |
| `title`         | string | Human-readable plan title                         |
| `decomposed_at` | string | When decomposition was performed                  |

### Phase Object

| Field              | Type     | Description                                               |
| ------------------ | -------- | --------------------------------------------------------- |
| `number`           | number   | Phase number (matches plan's Phase N headers)             |
| `depends_on`       | number[] | Phase numbers that must complete before this phase starts |
| `bounded_contexts` | string[] | Bounded context identifiers from the plan                 |

### Task Object

| Field              | Type           | Description                                             |
| ------------------ | -------------- | ------------------------------------------------------- |
| `id`               | string         | Task identifier (e.g., "1.1" = phase 1, task 1)         |
| `phase`            | number         | Phase this task belongs to                              |
| `description`      | string         | Full task description from the plan                     |
| `bounded_contexts` | string[]       | Bounded context identifiers                             |
| `status`           | string         | Current lifecycle status (see Task Lifecycle reference) |
| `branch`           | string or null | Git branch name (set when worktree is created)          |
| `check_results`    | string or null | Summary of validation check results                     |
| `error`            | string or null | Error message from failed agent or checks               |
| `retries`          | number         | Number of retry attempts (0 = first attempt)            |
| `created_at`       | string         | ISO 8601 timestamp of task creation                     |
| `updated_at`       | string         | ISO 8601 timestamp of last status change                |

## Valid Status Values

`pending`, `in_progress`, `validating`, `passed`, `failed`, `merged`, `abandoned`, `conflict`

## Script Interface

All manifest operations are performed via `task-manifest.sh`. See the script documentation for available commands.

## Concurrency

The manifest is designed for single-user CLI usage. If file locking is needed, `task-manifest.sh` uses `flock(1)` when available. Without locking, operations are not atomic — avoid concurrent modifications.

## Gitignore

The `.impl/` directory should be added to `.gitignore` as it contains ephemeral orchestration state, not source artifacts.
