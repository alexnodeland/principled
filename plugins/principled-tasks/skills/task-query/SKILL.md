---
name: task-query
description: >
  Answer natural-language questions about the task graph by translating
  them to SQL queries against .impl/tasks.db. Supports any question
  about tasks, edges, status, plans, agents, or dependencies.
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

| Argument     | Required | Description                                    |
| ------------ | -------- | ---------------------------------------------- |
| `<question>` | Yes      | Natural-language question about the task graph |

## Workflow

1. **Parse arguments.** Extract the question from `$ARGUMENTS`.

2. **Ensure the graph is current.** Run `bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --sync` to fold the event log into the cache. If it reports 0 tasks: _"No tasks yet. Run `/task-open` to create your first task."_

3. **Read the schema.** Consult `reference/schema.md` from the `task-strategy` skill to understand the table structure. The two tables are:
   - `tasks` — id, title, status, agent, plan, task_id, notes, created_at, closed_at, discovered_from
   - `task_edges` — from_id, to_id, kind (blocks, spawned_by, part_of, related_to)

4. **Translate to SQL.** Based on the question, generate a SQL query. Common patterns:
   - "what tasks are blocked?" → `SELECT * FROM tasks WHERE status = 'blocked';`
   - "what is agent X working on?" → `SELECT * FROM tasks WHERE agent = 'X' AND status = 'in_progress';`
   - "how many tasks per plan?" → `SELECT plan, COUNT(*) FROM tasks GROUP BY plan;`
   - "what blocks task-001a?" → `SELECT b.* FROM tasks b JOIN task_edges e ON b.id = e.from_id WHERE e.to_id = 'task-001a' AND e.kind = 'blocks';`

5. **Execute the query.** Run:

   ```bash
   sqlite3 -header -column .impl/tasks.db "<generated SQL>"
   ```

6. **Display results.** Show:
   - The generated SQL query (for transparency)
   - The query results in a formatted table
   - A brief natural-language summary of the findings

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh` — task graph interface (single shared copy, ADR-018)
