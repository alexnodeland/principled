---
name: task-strategy
description: >
  Task tracking strategy for the Principled framework.
  Consult when working with the task graph model,
  task dependencies, discovery chains, or cross-plan task visibility.
  Covers the SQLite schema, edge semantics, and audit patterns.
user-invocable: false
---

# Task Strategy — Background Knowledge

This skill provides Claude Code with comprehensive knowledge of the Principled task tracking strategy. It is not directly invocable — it informs Claude's behavior when task-related context is encountered.

## When to Consult This Skill

Activate this knowledge when:

- Working with the task graph
- Creating, closing, or querying tasks
- Analyzing task dependencies or blocked chains
- Discussing cross-plan task visibility
- Translating natural-language questions to SQL queries against the task schema
- Auditing task health: orphans, stale in_progress, agent workload

## Reference Documentation

Read these files for detailed guidance on specific topics:

### Task Model

- **`reference/task-model.md`** — Complete task lifecycle: `open → in_progress → done/blocked/abandoned`. Edge semantics: blocks, spawned_by, part_of, related_to. Discovery chains and cross-plan tracking.

### Schema Reference

- **`reference/schema.md`** — Full SQLite CREATE TABLE statements with field descriptions, constraints, and example queries for common operations.

## Key Principles

1. **Tasks are the universal task unit.** Every trackable piece of work — plan tasks, discovered bugs, follow-up items — is a task in the graph.
2. **Edges are typed and directional.** `blocks` means A must complete before B. `spawned_by` means A was discovered during B. `part_of` means A is a subtask of B. `related_to` is a soft link.
3. **The event log is the source of truth.** `.principled/tasks.jsonl` is append-only and committed after every write. `.impl/tasks.db` is a derived cache: gitignored, disposable, and rebuilt with `--sync`. The log is the audit trail.
4. **Append-only means mergeable.** Two agents on separate branches append different lines, so Git merges their work without conflict. A committed binary database could not — every concurrent write would collide.
5. **SQLite is the query engine, not the record.** Use SQL for filtering, aggregation, and graph traversal against the cache. The `sqlite3` CLI (3.38+) is the only runtime dependency.
6. **Skills own the write path.** Only `/task-open`, `/task-update`, and `/task-close` modify the graph. Read skills (`/task-graph`, `/task-audit`, `/task-query`) are pure queries.
7. **Natural-language queries map to SQL.** When a user asks a question, translate it to a SQL query against the tasks and task_edges tables.
