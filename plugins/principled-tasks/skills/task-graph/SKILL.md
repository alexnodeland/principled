---
name: task-graph
description: >
  Visualize the bead graph from .impl/tasks.db as a formatted table or
  DOT graph. Filter by plan, open-only beads, or export for Graphviz
  rendering. Use to understand task dependencies and project status.
allowed-tools: Read, Bash(bash plugins/*), Bash(bash scripts/*), Bash(sqlite3 *), Bash(ls *)
user-invocable: true
---

# Task Graph — Visualize Beads

Display the bead graph from `.impl/tasks.db` as a formatted table or DOT-format graph for visualization.

## Command

```
/task-graph [--plan NNN] [--open] [--dot]
```

## Arguments

| Argument     | Required | Description                                            |
| ------------ | -------- | ------------------------------------------------------ |
| `--plan NNN` | No       | Filter to beads linked to plan NNN                     |
| `--open`     | No       | Show only open/in_progress/blocked beads               |
| `--dot`      | No       | Output in DOT format (for Graphviz rendering)          |

## Workflow

1. **Parse arguments.** Extract optional flags from `$ARGUMENTS`.

2. **Verify database exists.** Check that `.impl/tasks.db` exists. If not: _"No task database found. Run `/task-open` to create your first bead."_

3. **Query the graph.** Run:

   ```bash
   bash scripts/task-db.sh --graph \
     [--plan "<NNN>"] \
     [--open] \
     [--dot]
   ```

4. **Display results.**

   **Table mode (default):**
   - List beads with id, title, status, plan, agent
   - List edges with from_id, to_id, kind
   - Summary: total beads, open, done, blocked

   **DOT mode (`--dot`):**
   - Output valid DOT graph definition
   - Nodes colored by status (yellow=open, blue=in_progress, green=done, red=blocked, gray=abandoned)
   - Edges styled by kind (bold=blocks, dashed=spawned_by, dotted=part_of)
   - Suggest: _"Pipe to `dot -Tpng -o graph.png` for visual rendering."_

## Scripts

- `scripts/task-db.sh` — SQLite interface for bead graph operations (copy from task-open)
