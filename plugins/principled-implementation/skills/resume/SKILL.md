---
name: resume
description: >
  Resume an interrupted orchestration run. Reads the manifest checkpoint for the
  previous session's reasoning, reports divergence against the task graph, and
  continues from the first unverified acceptance criterion. Use after a session
  ends mid-plan, or when picking up work started elsewhere.
allowed-tools: Read, Write, Edit, Bash(bash plugins/*), Bash(bash scripts/*), Bash(git *), Bash(ls *), Bash(cat *)
user-invocable: true
---

# Resume — Continue an Interrupted Run

Pick up an orchestration run where a previous session left off, with its reasoning
intact rather than just its task state.

## Command

```
/resume [<plan-path>] [--from-checkpoint] [--replan]
```

## Arguments

| Argument            | Required | Description                                                       |
| ------------------- | -------- | ----------------------------------------------------------------- |
| `<plan-path>`       | No       | Plan to resume. Read from the manifest when omitted               |
| `--from-checkpoint` | No       | Trust the checkpoint's phase as the resumption point              |
| `--replan`          | No       | Re-derive remaining work from task state, ignoring the checkpoint |

## What makes this different from `--continue`

`/orchestrate --continue` resumes mechanically from task state. It can see that task-2b
is `failed` with `retries: 2`; it cannot see that both failures were the same test
failure and that retrying a third time is the wrong move.

The checkpoint carries that reasoning. `/resume` reads it, so the new session inherits
the previous one's conclusions rather than rediscovering them.

## The authority rule

**The checkpoint is advisory. Task state is authoritative** (ADR-021).

A checkpoint is written by a session that may have been failing when it wrote it, so it
can describe a state that no longer holds or never held. Where the two disagree, believe
the task array and report the disagreement. Never edit task state to match a checkpoint.

## Workflow

1. **Read the manifest.** Fail clearly if there is none — there is nothing to resume:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --summary
   ```

2. **Read the checkpoint.** Exits non-zero when none was recorded, which is normal for a
   run that ended cleanly:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --get-checkpoint
   ```

   Present `orchestrator_summary` and `pending_decisions` to the user before doing
   anything. That prose is the point of the command.

3. **Reconcile the checkpoint against task state.** For each claim the summary makes
   about a task, compare it with the task's actual status. Report every mismatch:

   > Checkpoint says task-2a merged; manifest has it `failed`. Believing the manifest.

   Skip this step entirely under `--replan`.

4. **Report divergence against the task graph.** Only when principled-tasks is in use —
   check for `.principled/tasks.jsonl` first and skip the whole step silently if it is
   absent, since principled-tasks is an independent install:

   Join manifest tasks to graph tasks on `plan` plus `task_id` and report:
   - manifest tasks with no corresponding graph task
   - graph tasks for this plan with no manifest task
   - tasks whose statuses disagree

   **Report only. Never write to the task graph to make it match**, and never edit the
   manifest to match the graph. A disagreement is usually evidence that a session died
   between the two writes, and that evidence is worth more than tidy agreement.

5. **Determine the resumption point.**
   - `--from-checkpoint`: start at the checkpoint's `phase`.
   - `--replan`: ignore the checkpoint and derive remaining work from task state alone.
   - Default: derive from task state, using the checkpoint only as context.

6. **Check acceptance criteria on in-flight tasks.** A task interrupted mid-execution
   may have criteria already verified:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --list-criteria --task-id <id>
   ```

   Resume from the first `pending` criterion rather than restarting the task. Criteria
   are a resumption hint, not an acceptance gate — `/check-impl` remains the actual gate,
   and a task with every criterion ticked is still not done until its checks pass.

7. **Verify the environment.** Worktrees named in `environment_state` may be gone
   (ADR-007 worktrees survive session death, but not `git worktree prune`). Confirm each
   still exists and report any that do not.

8. **Continue.** Hand off to `/orchestrate --continue`, or spawn the next task directly
   with `/spawn <task-id>`.

9. **Write a fresh checkpoint** before doing significant work, so this session is itself
   resumable:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --set-checkpoint \
     --agent-id orchestrator --phase <N> \
     --summary-text "<what is done, what failed and why, what to do next>"
   ```

   Write the summary for a reader who has none of your context. "task-2b failed twice on
   the same fixture collision — change the approach, do not retry" is useful; "phase 2 in
   progress" is not.

## Reporting

Lead with the previous session's reasoning, then the current state, then divergences,
then the plan. Say explicitly when there was no checkpoint, when the task graph was not
consulted, and when the checkpoint disagreed with task state — silence on any of those
reads as confirmation the resume was clean.

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh` — manifest interface, including
  checkpoint and criteria operations (ADR-018, ADR-021)
