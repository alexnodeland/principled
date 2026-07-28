---
name: task-audit
description: >
  Audit the task graph for health issues: orphan tasks with no edges,
  stale in_progress tasks, blocked chains, and agent workload distribution.
  Use to identify bottlenecks and cleanup opportunities in the task graph.
allowed-tools: Read, Bash(bash plugins/*), Bash(bash scripts/*), Bash(sqlite3 *), Bash(ls *)
user-invocable: true
---

# Task Audit — Graph Health Check

Audit the task graph for health issues and report findings with recommendations.

## Command

```
/task-audit [--plan NNN] [--agent <name>]
```

## Arguments

| Argument         | Required | Description                              |
| ---------------- | -------- | ---------------------------------------- |
| `--plan NNN`     | No       | Filter audit to tasks linked to plan NNN |
| `--agent <name>` | No       | Filter audit to tasks assigned to agent  |

## Workflow

1. **Parse arguments.** Extract optional filters from `$ARGUMENTS`.

2. **Ensure the graph is current.** Run `bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --sync`. If it reports 0 tasks: _"No tasks yet. Nothing to audit."_

3. **Run audit.** Execute:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh" --audit \
     [--plan "<NNN>"] \
     [--agent "<name>"]
   ```

4. **Display audit report.** The report includes:

   **Status Summary** — Count of tasks per status.

   **Orphan Tasks** — Tasks with no edges (no relationships). Recommend: add edges or consider abandoning.

   **Stale In-Progress** — Tasks in `in_progress` for more than 24 hours. Recommend: check on agent, close, or re-assign.

   **Blocked Chains** — Blocked tasks and their blockers. If blocker is `done`, recommend unblocking. If blocker is also blocked, flag as chained dependency.

   **Agent Workload** — Tasks per agent: total, done, active. Flag imbalanced workload.

   **Completion Rate** — Overall percentage of done tasks.

5. **Provide recommendations.** Based on findings:
   - _"N orphan tasks found — consider adding edges or closing."_
   - _"N tasks stale in in_progress — check agent status."_
   - _"N blocked chains — resolve blockers to unblock progress."_

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/task-db.sh` — task graph interface (single shared copy, ADR-018)
