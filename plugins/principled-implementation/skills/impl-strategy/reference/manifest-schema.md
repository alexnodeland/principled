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

### Checkpoint Object (optional, ADR-021)

A top-level `checkpoint` key carrying the natural-language reasoning that structured task
state cannot. Absent from manifests written before ADR-021, and absence is valid.

```json
{
  "checkpoint": {
    "session_id": "sess-abc123",
    "agent_id": "impl-worker",
    "phase": 2,
    "timestamp": "2026-07-28T14:30:00Z",
    "orchestrator_summary": "Phase 1 complete (3/3 merged). task-2b failed on the test suite twice — needs a different approach, not a retry.",
    "pending_decisions": ["task-2b: response format — envelope vs flat"],
    "environment_state": {
      "active_worktrees": ["task-2a", "task-2b"]
    }
  }
}
```

| Field                  | Type           | Description                                       |
| ---------------------- | -------------- | ------------------------------------------------- |
| `session_id`           | string         | Session that wrote the checkpoint                 |
| `agent_id`             | string         | Agent that wrote it                               |
| `phase`                | number or null | Phase in progress when written                    |
| `timestamp`            | string         | ISO 8601 write time                               |
| `orchestrator_summary` | string         | Reasoning for a session that has no other context |
| `pending_decisions`    | string[]       | Unresolved questions blocking progress            |
| `environment_state`    | object         | `active_worktrees`, and branch names where known  |

**The checkpoint is advisory. The task array is authoritative.** A checkpoint may be
written by a session that was failing at the time, so it can describe a state that no
longer holds. Consumers use it as context for the model, never as a source of truth for
control flow; on disagreement, task state wins and the divergence is reported.

### Acceptance Criteria (optional, ADR-021)

An optional `acceptance_criteria` array on a task, making each criterion individually
addressable so an interrupted task resumes from the first unverified one rather than
from zero.

```json
{
  "id": "2.1",
  "status": "in_progress",
  "acceptance_criteria": [
    {
      "description": "Rejects missing auth with 401",
      "verified": true,
      "verified_at": "2026-07-28T14:20:00Z"
    },
    {
      "description": "Unit tests cover both cases",
      "verified": false,
      "verified_at": null
    }
  ]
}
```

| Field         | Type           | Description                           |
| ------------- | -------------- | ------------------------------------- |
| `description` | string         | The criterion, as written in the plan |
| `verified`    | boolean        | Whether the agent has confirmed it    |
| `verified_at` | string or null | ISO 8601 time of verification         |

Criteria are a **property of a task, not a fourth hierarchy level**. Plan → Phase → Task
is unchanged (ADR-008), and tasks remain the unit of decomposition, spawning, validation
and merge.

`verified: true` is a claim by the agent that did the work, not a proof. `/check-impl`
remains the acceptance gate; criteria are a resumption hint.

## Compatibility

Both fields above are additive and optional. Consumers must tolerate their absence and
must not fail on unknown fields. No migration runs — a manifest gains a checkpoint the
first time something writes one.

## Valid Status Values

`pending`, `in_progress`, `validating`, `passed`, `failed`, `merged`, `abandoned`, `conflict`

## Script Interface

All manifest operations are performed via `task-manifest.sh`. See the script documentation for available commands.

## Concurrency

The manifest is designed for single-user CLI usage. If file locking is needed, `task-manifest.sh` uses `flock(1)` when available. Without locking, operations are not atomic — avoid concurrent modifications.

## Gitignore

The `.impl/` directory should be added to `.gitignore` as it contains ephemeral orchestration state, not source artifacts.
