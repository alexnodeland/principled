---
name: task-graph
description: >
  Visualize the task graph from the task graph as a formatted table or
  DOT graph. Filter by plan, open-only tasks, or export for Graphviz
  rendering. Use to understand task dependencies and project status.
allowed-tools: Read, Bash(bash plugins/*), Bash(bash scripts/*), Bash(sqlite3 *), Bash(ls *)
user-invocable: true
---

# Task Graph — Visualize Tasks

Display the task graph from the task graph as a formatted table or DOT-format graph for visualization.

## Command

```
/task-graph [--plan NNN] [--open] [--dot]
```

## Arguments

| Argument     | Required | Description                                   |
| ------------ | -------- | --------------------------------------------- |
| `--plan NNN` | No       | Filter to tasks linked to plan NNN            |
| `--open`     | No       | Show only open/in_progress/blocked tasks      |
| `--dot`      | No       | Output in DOT format (for Graphviz rendering) |

## Workflow

1. **Parse arguments.** Extract optional flags from `$ARGUMENTS`.

2. **Ensure the graph is current.** Run `bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --sync` to fold the event log into the cache. If it reports 0 tasks: _"No tasks yet. Run `/task-open` to create your first task."_

3. **Query the graph.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --graph \
     [--plan "<NNN>"] \
     [--open] \
     [--dot]
   ```

4. **Display results.**

   **Table mode (default):**
   - List tasks with id, title, status, plan, agent
   - List edges with from_id, to_id, kind
   - Summary: total tasks, open, done, blocked

   **DOT mode (`--dot`):**
   - Output valid DOT graph definition
   - Nodes colored by status (yellow=open, blue=in_progress, green=done, red=blocked, gray=abandoned)
   - Edges styled by kind (bold=blocks, dashed=spawned_by, dotted=part_of)
   - Suggest: _"Pipe to `dot -Tpng -o graph.png` for visual rendering."_

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh` — task graph interface (single shared copy, ADR-018)
