---
name: orchestrate
description: >
  Top-level orchestrator for DDD plan execution. Decomposes a plan into
  tasks, iterates through phases respecting dependencies, spawns
  worktree-isolated agents, validates implementations, and merges
  results. Runs inline to coordinate multiple sub-agent spawns. Use
  for automated end-to-end plan execution.
allowed-tools: Read, Write, Bash(git *), Bash(mkdir *), Bash(ls *), Bash(grep *), Bash(find *), Bash(npm *), Bash(npx *), Bash(make *), Bash(bash plugins/*)
user-invocable: true
---

# Orchestrate — Full Lifecycle Execution

Execute a complete DDD plan from decomposition through validation and merge, managing the entire lifecycle automatically.

## Command

```
/orchestrate <plan-path> [--phase <N>] [--continue] [--dry-run]
             [--mode interactive|supervised|autonomous] [--max-workers <N>]
```

## Arguments

| Argument        | Required | Description                                                |
| --------------- | -------- | ---------------------------------------------------------- |
| `<plan-path>`   | Yes      | Path to DDD plan file                                      |
| `--phase <N>`   | No       | Execute only phase N (skip earlier completed phases)       |
| `--continue`    | No       | Resume from existing manifest (skip decomposition)         |
| `--dry-run`     | No       | Decompose and plan but do not execute                      |
| `--mode <mode>` | No       | Autonomy level. Default `interactive` — existing behaviour |
| `--max-workers` | No       | Concurrent workers under agent teams. Default 3            |

## Two orthogonal axes

"Mode" means two different things here, and conflating them causes real confusion. They
are independent — any autonomy level can run under either parallelism strategy.

| Axis            | Selected by                            | Answers                               |
| --------------- | -------------------------------------- | ------------------------------------- |
| **Parallelism** | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | How many tasks run at once?           |
| **Autonomy**    | `--mode`                               | How much human involvement is needed? |

### Parallelism: sequential or agent teams

**Sequential (default).** When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set, tasks
within a phase execute sequentially via `/spawn`. This is the proven, stable path.

**Agent teams (opt-in).** When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, independent
tasks within a phase execute concurrently, capped by `--max-workers`. The orchestrator
becomes the team lead, spawning one teammate per independent task.

**Dual state model:** the agent teams task list drives coordination (claiming,
dependencies, completion), while `.impl/manifest.json` remains the persistent record.
The lead synchronizes between the two.

See [ADR-016](../../docs/decisions/016-agent-teams-for-parallel-execution.md) and
[orchestration-guide.md](../impl-strategy/reference/orchestration-guide.md).

### Autonomy: `--mode`

| Mode          | Behaviour                                 | Human involvement      |
| ------------- | ----------------------------------------- | ---------------------- |
| `interactive` | Current behaviour, unchanged              | Continuous             |
| `supervised`  | Runs on, pausing at decision points       | At decision gates      |
| `autonomous`  | Runs end to end, posts results for review | Post-completion review |

**`--mode` defaults to `interactive`, so omitting it behaves exactly as before.**

**Supervised** reports at each phase boundary and continues automatically _unless_ a stop
condition fires (below).

**Autonomous** runs decompose → spawn → validate → merge without pausing, maintains a
live progress issue, and finishes by running `/pr-describe`, `/review-checklist`, and
`/release-ready` before opening a **draft** PR labelled `agent-authored`. If blocked, it
files an `agent-blocked` issue with diagnostics rather than stalling.

## Stop conditions

These apply in `supervised` and `autonomous` modes. Each says the same thing: the
evidence indicates the next attempt fails the same way, so stop and surface it rather
than escalating (ADR-022).

| Condition                  | Default | Action                                     |
| -------------------------- | ------- | ------------------------------------------ |
| Halt switch present        | —       | Pause at the next phase boundary           |
| Task retry budget exceeded | 2       | Stop the task, file `agent-blocked`        |
| Phase task-failure rate    | 50%     | Stop the run — systemic, not one hard task |

**The halt switch is checked at every phase boundary**, never mid-task. Interrupting a
worker halfway leaves a worktree in an unknown state; the phase boundary is the nearest
point where stopping is clean.

principled-agent owns the switch but may not be installed, and plugins cannot reference
each other's `${CLAUDE_PLUGIN_ROOT}` (ADR-018). **The file path is the contract**, so
check it directly rather than calling into another plugin:

```bash
test -f .agents/HALT && cat .agents/HALT
```

If it exists, stop at the phase boundary, print the reason, and report clearly that the
run was halted rather than completed. If `.agents/` does not exist at all, there is no
halt switch and the run proceeds — an uninitialized repository is not a halted one.

`--max-workers` defaults to 3. That is a deliberately conservative default, not a
measurement: this repository has never run autonomous dispatch, and review capacity —
not CI or API quota — is the constraint that actually binds (ADR-022).

## Workflow

### Stage 1: Decomposition

1. **Check for existing manifest.** If `--continue` and `.impl/manifest.json` exists, load it and skip to Stage 2. Report: _"Resuming from existing manifest."_

2. **Verify the plan.** Read `<plan-path>` and confirm `status` is `active`.

3. **Extract plan metadata and tasks.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/parse-plan.sh" --file <plan-path> --metadata
   bash "${CLAUDE_PLUGIN_ROOT}/lib/parse-plan.sh" --file <plan-path> --tasks
   ```

4. **Initialize manifest.**

   ```bash
   mkdir -p .impl
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --init \
     --plan-path <plan-path> \
     --plan-number <number> \
     --plan-title "<title>"
   ```

5. **Populate all tasks.** For each extracted task:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --add-task \
     --task-id <id> --phase <N> --description "<desc>" \
     --depends-on "<deps>" --bounded-contexts "<BCs>"
   ```

6. **Report decomposition.** Display phase/task summary. If `--dry-run`, stop here.

### Stage 2: Phase Iteration

For each phase (in numerical order, or just `--phase <N>` if specified):

1. **Check phase readiness.** A phase is ready when all tasks in its dependency phases have status `merged` or `abandoned`. Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --phase-status --phase <dep>
   ```

   If any dependency phase has non-terminal tasks, wait or report the blocker.

2. **Identify pending tasks** in the current phase:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --list-tasks --phase <N> --status pending
   ```

### Stage 3: Task Execution

#### Sequential Mode (default)

For each task in the phase:

1. **Update manifest to in_progress.**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --update-status \
     --task-id <id> --status in_progress
   ```

2. **Invoke `/spawn <task-id>`.** This forks to the impl-worker agent in an isolated worktree. The agent:
   - Creates a named branch (`impl/<plan-number>/<task-id>`)
   - Implements the task
   - Commits changes
   - Returns a summary

3. **Parse agent output.** Extract:
   - Branch name created
   - Files changed
   - Any blockers or errors

4. **Update manifest to validating.**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --update-status \
     --task-id <id> --status validating \
     --branch <branch-name>
   ```

5. **Run validation.** Discover the worktree path and run checks:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/run-checks.sh" --discover --cwd <worktree-path>
   bash "${CLAUDE_PLUGIN_ROOT}/lib/run-checks.sh" --execute --cwd <worktree-path>
   ```

6. **If checks pass:**
   - Update manifest to `passed`
   - Invoke `/merge-work <task-id>` to merge branch and clean up worktree
   - Manifest updates to `merged`

7. **If checks fail:** Decide based on failure type:
   - **Retryable** (test/lint failure, retries < 2): Update manifest to `failed`, increment retries, re-spawn with failure context appended
   - **Non-retryable** (max retries reached): Mark `abandoned`, continue with remaining tasks
   - **Critical** (blocks dependent phases): Pause and report to user with `--continue` instructions

#### Agent Teams Mode (when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)

1. **Detect agent teams.** Check if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set. If not, fall back to sequential mode above.

2. **Populate task list.** For each pending task in the current phase, add it to the agent teams task list with dependency information from the manifest.

3. **Spawn teammates.** The orchestrator (team lead) spawns one teammate per independent task. Teammates self-claim tasks via the task list's file-lock mechanism.

4. **Each teammate executes.** Same as sequential steps 1-6, but running concurrently in separate context windows. The `TaskCompleted` hook (`gate-task-completion.sh`) enforces quality checks.

5. **Handle idle teammates.** When a teammate finishes and others are still running, reassign to review or cleanup work via `TeammateIdle` handling.

6. **Synchronize state.** As teammates complete tasks, the lead synchronizes the agent teams task list with the `.impl/manifest.json`. Team task completion triggers manifest updates.

7. **Merge sequentially.** After all tasks in the phase complete, the lead merges branches sequentially (same as sequential mode) to avoid complex conflict resolution.

### Stage 4: Phase Completion

1. **Check phase status.** After all tasks in the phase are processed:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --phase-status --phase <N>
   ```

2. **Report phase results.** Display: tasks merged, failed, abandoned.

3. **Evaluate stop conditions** (`supervised` and `autonomous` only). This is the phase
   boundary, and the only place a run stops cleanly.

   a. **Halt switch.** If `.agents/HALT` exists, stop here. Print its contents as the
   reason, state plainly that the run was **halted, not completed**, and give the
   `--continue` command for resuming once the halt is cleared. Do not begin the next
   phase.

   b. **Phase failure rate.** If more than 50% of this phase's tasks failed or were
   abandoned, stop. A majority-failed phase is a systemic fault — a broken suite, a bad
   plan, a missing dependency — and the next phase will almost certainly hit it too.
   Under `autonomous`, file an `agent-blocked` issue with the phase status and the
   failure details.

   c. **Retry budget.** Tasks that exhausted their retries (default 2) are already
   `abandoned`. Under `autonomous`, file one `agent-blocked` issue per abandoned task
   rather than one per attempt.

4. **Write a checkpoint** before advancing, so an interrupted run resumes with its
   reasoning intact (ADR-021):

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --set-checkpoint \
     --agent-id orchestrator --phase <N> \
     --summary-text "<what completed, what failed and why, what to do next>"
   ```

5. **Report and advance.**
   - `interactive`: report and continue as today.
   - `supervised`: post a progress summary, then continue automatically unless a stop
     condition fired.
   - `autonomous`: update the live progress issue, then continue.

   Return to Stage 2 for the next phase.

### Stage 5: Completion

1. **Final summary.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --summary
   ```

   Report:
   - Total tasks: N
   - Merged: M
   - Failed/abandoned: F
   - Phases completed: P/T
   - If all merged: _"Plan \<number\> implementation complete."_
   - If some failed: list failed/abandoned tasks with details

   Never report a halted or circuit-broken run as complete. Say which stop condition
   fired and what remains — a run that stopped early and a run that finished are
   different outcomes, and only one of them is done.

2. **Clean up remaining worktrees.** For any worktrees still present:

   ```bash
   git worktree list
   ```

   Remove worktrees for merged or abandoned tasks.

3. **Autonomous mode only — close the loop.** Before opening anything:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/run-checks.sh"
   ```

   Then run `/pr-describe`, `/review-checklist`, and `/release-ready`, and open a
   **draft** PR labelled `agent-authored`, linking the issue, proposal, and plan.

   The draft status and the label are both load-bearing (ADR-022): promotion to
   ready-for-review is a human act, and the in-flight PR budget is counted by that label,
   so an unlabelled agent PR is invisible to the review-capacity circuit breaker.

   Never approve, promote, or merge. No mode auto-merges.

## Error Recovery

- **Merge conflicts:** Pause orchestration, report conflicting files. Re-run with `--continue` after manual resolution.
- **Sub-agent failure:** Retry up to 2 times with failure context appended to the agent prompt. After exhausting retries, mark `abandoned`.
- **Interrupted orchestration:** Re-run with `--continue` to resume from the last known manifest state.
- **All tasks in phase failed:** Pause and report. The plan may need re-decomposition.

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/parse-plan.sh` — Plan parsing (shared, ADR-018)
- `${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh` — Manifest CRUD (shared, ADR-018)
- `${CLAUDE_PLUGIN_ROOT}/lib/run-checks.sh` — Check runner (shared, ADR-018)

## Templates

- `${CLAUDE_PLUGIN_ROOT}/lib/templates/claude-task.md` — Sub-agent instructions (shared, ADR-018)
