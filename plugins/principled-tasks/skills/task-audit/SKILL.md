---
name: task-audit
description: >
  Audit the bead graph for health issues: orphan beads with no edges,
  stale in_progress tasks, blocked chains, and agent workload distribution.
  Use to identify bottlenecks and cleanup opportunities in the task graph.
allowed-tools: Read, Bash(bash plugins/*), Bash(bash scripts/*), Bash(sqlite3 *), Bash(ls *)
user-invocable: true
---

# Task Audit — Graph Health Check

Audit the `.impl/tasks.db` bead graph for health issues and report findings with recommendations.

## Command

```
/task-audit [--plan NNN] [--agent <name>]
```

## Arguments

| Argument         | Required | Description                              |
| ---------------- | -------- | ---------------------------------------- |
| `--plan NNN`     | No       | Filter audit to beads linked to plan NNN |
| `--agent <name>` | No       | Filter audit to beads assigned to agent  |

## Workflow

1. **Parse arguments.** Extract optional filters from `$ARGUMENTS`.

2. **Verify database exists.** Check that `.impl/tasks.db` exists. If not: _"No task database found. Nothing to audit."_

3. **Run audit.** Execute:

   ```bash
   bash scripts/task-db.sh --audit \
     [--plan "<NNN>"] \
     [--agent "<name>"]
   ```

4. **Display audit report.** The report includes:

   **Status Summary** — Count of beads per status.

   **Orphan Beads** — Beads with no edges (no relationships). Recommend: add edges or consider abandoning.

   **Stale In-Progress** — Beads in `in_progress` for more than 24 hours. Recommend: check on agent, close, or re-assign.

   **Blocked Chains** — Blocked beads and their blockers. If blocker is `done`, recommend unblocking. If blocker is also blocked, flag as chained dependency.

   **Agent Workload** — Tasks per agent: total, done, active. Flag imbalanced workload.

   **Completion Rate** — Overall percentage of done beads.

5. **Provide recommendations.** Based on findings:
   - _"N orphan beads found — consider adding edges or closing."_
   - _"N beads stale in in_progress — check agent status."_
   - _"N blocked chains — resolve blockers to unblock progress."_

## Scripts

- `scripts/task-db.sh` — SQLite interface for bead graph operations (copy from task-open)
