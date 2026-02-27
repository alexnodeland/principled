---
name: task-query
description: >
  Answer natural-language questions about the task graph by translating
  them to SQL queries against .impl/tasks.db. Supports any question
  about beads, edges, status, plans, agents, or dependencies.
  Use for ad-hoc task graph exploration.
allowed-tools: Read, Bash(bash plugins/*), Bash(bash scripts/*), Bash(sqlite3 *), Bash(ls *)
user-invocable: true
---

# Task Query — Natural Language Graph Queries

Translate natural-language questions about the task graph into SQL queries against `.impl/tasks.db` and return formatted results.

## Command

```
/task-query "<natural language question>"
```

## Arguments

| Argument      | Required | Description                                      |
| ------------- | -------- | ------------------------------------------------ |
| `<question>`  | Yes      | Natural-language question about the task graph   |

## Workflow

1. **Parse arguments.** Extract the question from `$ARGUMENTS`.

2. **Verify database exists.** Check that `.impl/tasks.db` exists. If not: _"No task database found. Run `/task-open` to create your first bead."_

3. **Read the schema.** Consult `reference/schema.md` from the `task-strategy` skill to understand the table structure. The two tables are:
   - `beads` — id, title, status, agent, plan, task_id, notes, created_at, closed_at, discovered_from
   - `bead_edges` — from_id, to_id, kind (blocks, spawned_by, part_of, related_to)

4. **Translate to SQL.** Based on the question, generate a SQL query. Common patterns:
   - "what tasks are blocked?" → `SELECT * FROM beads WHERE status = 'blocked';`
   - "what is agent X working on?" → `SELECT * FROM beads WHERE agent = 'X' AND status = 'in_progress';`
   - "how many tasks per plan?" → `SELECT plan, COUNT(*) FROM beads GROUP BY plan;`
   - "what blocks bead-001a?" → `SELECT b.* FROM beads b JOIN bead_edges e ON b.id = e.from_id WHERE e.to_id = 'bead-001a' AND e.kind = 'blocks';`

5. **Execute the query.** Run:

   ```bash
   sqlite3 -header -column .impl/tasks.db "<generated SQL>"
   ```

6. **Display results.** Show:
   - The generated SQL query (for transparency)
   - The query results in a formatted table
   - A brief natural-language summary of the findings

## Scripts

- `scripts/task-db.sh` — SQLite interface for bead graph operations (copy from task-open)
