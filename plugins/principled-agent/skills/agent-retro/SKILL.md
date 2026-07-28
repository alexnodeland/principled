---
name: agent-retro
description: >
  Write a post-execution retrospective after an orchestration run, and promote
  the durable findings into agent memory. Use after /orchestrate completes a
  plan or phase, or after a run that failed in an instructive way.
allowed-tools: Read, Write, Edit, Bash(bash plugins/*), Bash(bash scripts/*), Bash(git add *), Bash(git commit *), Bash(ls *), Bash(git log *)
user-invocable: true
---

# Agent Retro — Post-Execution Retrospective

Record what a run taught, and promote the durable parts into memory.

## Command

```
/agent-retro [<plan-path>] [--promote]
```

## Arguments

| Argument      | Required | Description                                                  |
| ------------- | -------- | ------------------------------------------------------------ |
| `<plan-path>` | No       | Plan the run executed. Inferred from the manifest if omitted |
| `--promote`   | No       | Also write durable findings into agent memory                |

## Why retrospectives are separate from memory

A retrospective is a **dated record of one run**: what happened, what failed, how long
it took. Memory is **durable knowledge**, undated and asserted as currently true.

Most of a retrospective should never reach memory. "task-2b failed twice on the test
suite" is a fact about one run. "This suite needs `--runInBand` or the database fixtures
collide" is a fact about the codebase — that one belongs in memory.

Keeping them separate is what stops memory degrading into a log.

## Workflow

1. **Gather the run.** Read `.impl/manifest.json` directly with Read — task outcomes,
   retry counts, and the `checkpoint.orchestrator_summary` if one was written.

   principled-agent does not depend on principled-implementation: plugins install
   independently and cannot reference each other's `${CLAUDE_PLUGIN_ROOT}` (ADR-018).
   Read the manifest as a file, and fall back to `git log` over the run's branches when
   there is no manifest at all.

2. **Write the retrospective** to `.agents/retrospectives/YYYY-MM-DD-plan-NNN.md`:

   ```markdown
   ---
   date: 2026-07-28
   plan: "008"
   agent: impl-worker
   tasks_total: 7
   tasks_merged: 6
   tasks_failed: 1
   ---

   # Retrospective — Plan-008

   ## What happened

   ## What worked

   ## What failed, and why

   ## Durable learnings

   <!-- Only facts that will still be true next month. These are memory candidates. -->
   ```

   Be specific and unflattering. A retrospective that records only successes teaches
   nothing and costs a file.

3. **Promote, when `--promote` is passed.** For each item under Durable learnings, apply
   the `agent-strategy` standard — durable, certain, not already present — then append
   the survivors to the relevant agent's `## Known Patterns` via `/agent-memory`.

   Promote conservatively. A wrong learning is injected into every future spawn and is
   harder to notice than a wrong retrospective, because nobody re-reads memory to check.

4. **Update metrics** from the run's actual outcome:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --update-metrics \
     --agent impl-worker --session --tasks <total> --succeeded <merged>
   ```

5. **Commit.** Retrospectives and memory changes are reviewable artifacts:

   ```bash
   git add .agents/
   git commit -m "retro: plan-NNN execution retrospective"
   ```

## Reporting

Summarize the run, list what was promoted to memory and what was deliberately left in
the retrospective, and state the agent's updated metrics.

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh` — memory and registry interface (ADR-018)
