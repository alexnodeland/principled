---
name: agent-status
description: >
  Report the state of the agent workforce: whether the halt switch is engaged,
  how much governance budget remains, what work is in flight, and each agent's
  accumulated metrics. Use to check whether dispatch is possible and where the
  queue actually stands.
allowed-tools: Read, Bash(bash plugins/*), Bash(bash scripts/*), Bash(gh *), Bash(git *), Bash(ls *), Bash(cat *), Bash(test *)
user-invocable: true
---

# Agent Status — Workforce Report

Answer two questions: can work start right now, and what is already running?

## Command

```
/agent-status [--all] [--agent <id>] [--format table|json]
```

## Arguments

| Argument       | Required | Description                                              |
| -------------- | -------- | -------------------------------------------------------- |
| `--all`        | No       | Include per-agent memory metrics and orchestration state |
| `--agent <id>` | No       | Restrict the report to one agent                         |
| `--format`     | No       | `table` (default) or `json`                              |

## Workflow

1. **Governance state.** Lead with this — it determines whether anything can start:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-governance.sh" --status
   ```

   Reports halt state and reason, open `agent-blocked` issues against budget, and
   in-flight `agent-authored` PRs against budget.

   **Report `unknown` as `unknown`.** When `gh` is unavailable the counts cannot be
   determined, and dispatch refuses rather than assuming headroom. Presenting an unknown
   budget as zero would invert the safety property this whole layer exists for.

2. **Agent registry and memory** (with `--all` or `--agent`):

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --list
   ```

   Show session counts, task totals, success rates, and memory size against the context
   budget. Flag anything over 8 KB as a synthesis candidate.

3. **Orchestration state**, if a run exists. `.impl/manifest.json` belongs to
   principled-implementation, which may not be installed and cannot be called across the
   plugin boundary (ADR-018) — so read the file directly with Read:
   - plan, phase in progress, task counts by status
   - `checkpoint.orchestrator_summary`, which says what the last session was thinking

   Skip this section silently when there is no manifest.

4. **In-flight work**, when `gh` is available:

   ```bash
   gh pr list --state open --label agent-authored --json number,title,isDraft,createdAt
   gh issue list --state open --label agent-blocked --json number,title,createdAt
   ```

   For each PR, show age and draft status. **A non-draft agent PR is a governance
   violation** (ADR-022) — call it out rather than listing it neutrally.

   Sort blocked issues oldest first. Age is the signal that matters: blockers nobody has
   triaged in a week are why the dispatch budget exists.

## Reporting

Lead with whether dispatch is possible right now and why. Then in-flight work, then
per-agent metrics if requested.

Be direct about problems rather than tabulating around them: a halt in effect, an
exhausted budget, a non-draft agent PR, and a memory file over budget are all findings,
not rows. If everything is clear, say so in one line.

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/agent-governance.sh` — governance state (ADR-022)
- `${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh` — registry and metrics (ADR-018)
