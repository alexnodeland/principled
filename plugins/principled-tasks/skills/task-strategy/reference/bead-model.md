# Bead Model

The bead model is the core abstraction of the principled-tasks plugin. Every trackable piece of work is a **bead** — a node in a directed graph with typed edges.

## Bead Lifecycle

```
open ──→ in_progress ──→ done
  │          │
  │          ├──→ blocked ──→ open (when unblocked)
  │          │
  │          └──→ abandoned
  │
  └──→ abandoned
```

### States

| Status        | Meaning                                          |
| ------------- | ------------------------------------------------ |
| `open`        | Ready for work, not yet started                  |
| `in_progress` | Actively being worked on by an agent or human    |
| `done`        | Completed successfully                           |
| `blocked`     | Cannot proceed until a blocking bead is resolved |
| `abandoned`   | Will not be completed (superseded or irrelevant) |

### Transitions

- `open → in_progress` — Work begins
- `in_progress → done` — Work completed
- `in_progress → blocked` — Dependency discovered
- `in_progress → abandoned` — Work no longer needed
- `blocked → open` — Blocker resolved
- `open → abandoned` — Decided not to pursue

## Edge Types

Edges are directed: `from_id → to_id`. The `kind` field determines the relationship semantic.

| Kind         | Meaning                             | Example                             |
| ------------ | ----------------------------------- | ----------------------------------- |
| `blocks`     | from_id must complete before to_id  | "Fix auth" blocks "Add permissions" |
| `spawned_by` | from_id was discovered during to_id | "Fix typo" spawned_by "Refactor UI" |
| `part_of`    | from_id is a subtask of to_id       | "Write tests" part_of "Add feature" |
| `related_to` | Soft link, no ordering implied      | "Update docs" related_to "New API"  |

## Discovery Chains

When an agent works on bead A and discovers additional work, the new bead B is created with:

- `discovered_from` field set to A's ID
- A `spawned_by` edge from B to A

This creates a traceable discovery chain: you can follow `spawned_by` edges to see how work expanded during implementation.

## Cross-Plan Tracking

Beads can optionally be linked to a plan via the `plan` field and to a specific plan task via `task_id`. This enables:

- Filtering the graph by plan: `/task-graph --plan 003`
- Auditing completion by plan: `/task-audit --plan 003`
- Correlating beads with manifest tasks in principled-implementation

## Integration with principled-implementation

The `plan` and `task_id` fields on beads correspond to the plan number and task ID in `.impl/manifest.json`. While principled-tasks does not depend on principled-implementation, the fields enable cross-referencing:

- A bead with `plan: "003"` and `task_id: "1.1"` maps to task 1.1 in Plan-003
- The `/task-audit` skill can compare bead status against manifest status for drift detection
