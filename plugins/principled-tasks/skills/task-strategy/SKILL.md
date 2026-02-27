---
name: task-strategy
description: >
  Task tracking strategy for the Principled framework.
  Consult when working with .impl/tasks.db, the bead graph model,
  task dependencies, discovery chains, or cross-plan task visibility.
  Covers the SQLite schema, edge semantics, and audit patterns.
user-invocable: false
---

# Task Strategy — Background Knowledge

This skill provides Claude Code with comprehensive knowledge of the Principled task tracking strategy. It is not directly invocable — it informs Claude's behavior when task-related context is encountered.

## When to Consult This Skill

Activate this knowledge when:

- Working with `.impl/tasks.db` or the bead graph
- Creating, closing, or querying tasks
- Analyzing task dependencies or blocked chains
- Discussing cross-plan task visibility
- Translating natural-language questions to SQL queries against the bead schema
- Auditing task health: orphans, stale in_progress, agent workload

## Reference Documentation

Read these files for detailed guidance on specific topics:

### Task Model

- **`reference/task-model.md`** — Complete task lifecycle: `open → in_progress → done/blocked/abandoned`. Edge semantics: blocks, spawned_by, part_of, related_to. Discovery chains and cross-plan tracking.

### Schema Reference

- **`reference/schema.md`** — Full SQLite CREATE TABLE statements with field descriptions, constraints, and example queries for common operations.

## Key Principles

1. **Beads are the universal task unit.** Every trackable piece of work — plan tasks, discovered bugs, follow-up items — is a bead in the graph.
2. **Edges are typed and directional.** `blocks` means A must complete before B. `spawned_by` means A was discovered during B. `part_of` means A is a subtask of B. `related_to` is a soft link.
3. **Git is the persistence layer.** `.impl/tasks.db` is committed after every write. The Git log is the audit trail.
4. **SQLite is the query engine.** Use SQL for filtering, aggregation, and graph traversal. The `sqlite3` CLI is the only runtime dependency.
5. **Skills own the write path.** Only `/task-open` and `/task-close` modify the database. Read skills (`/task-graph`, `/task-audit`, `/task-query`) are pure queries.
6. **Natural-language queries map to SQL.** When a user asks a question, translate it to a SQL query against the beads and bead_edges tables.
