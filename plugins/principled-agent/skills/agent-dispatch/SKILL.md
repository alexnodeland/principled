---
name: agent-dispatch
description: >
  Assign a GitHub issue to an agent and start work on it, either in the current
  session or via the configured CI backend. Enforces the governance gate first:
  halt switch, open blocker budget, and in-flight PR budget. Use to hand an
  agent a piece of the backlog.
allowed-tools: Read, Write, Bash(bash plugins/*), Bash(bash scripts/*), Bash(gh *), Bash(git *), Bash(ls *), Bash(test *), Bash(cat *)
user-invocable: true
---

# Agent Dispatch — Assign Work to an Agent

Start agent work on an issue, after checking that it is allowed to start at all.

## Command

```
/agent-dispatch <issue-number> [--local] [--agent <id>] [--dry-run]
```

## Arguments

| Argument         | Required | Description                                                     |
| ---------------- | -------- | --------------------------------------------------------------- |
| `<issue-number>` | Yes      | GitHub issue to work on                                         |
| `--local`        | No       | Run in the current session instead of CI. No credentials needed |
| `--agent <id>`   | No       | Override routing and assign a specific agent                    |
| `--dry-run`      | No       | Report the gate result and routing, then stop                   |

## The gate comes first

**Run this before anything else, including reading the issue.** It is the mechanism that
makes unattended execution safe (ADR-022), and it is cheap:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-governance.sh" --can-dispatch
```

| Exit | Meaning                                                                |
| ---- | ---------------------------------------------------------------------- |
| 0    | Permitted. Proceed                                                     |
| 3    | Refused. **Stop.** Print the reason verbatim and do not work around it |
| 1    | Environment error. Report it; do not treat it as permission            |

A refusal is a successful answer, not an obstacle. The three refusals mean:

- **Halt engaged** — someone stopped the system deliberately. Clearing it is their call,
  not this session's.
- **Blocker budget exhausted** — blockers are outpacing triage, which is a systemic
  signal. More dispatch makes it worse.
- **Budgets unverifiable** — `gh` is unavailable, so the counts are unknown. An unknown
  budget is not headroom. Suggest `--local`, which needs no GitHub access.

Never re-run the gate with raised `--blocked-budget` or `--pr-budget` values to get past
a refusal. Raising a cap is a human decision made deliberately, not a retry strategy.

## Workflow

1. **Gate.** As above. Under `--dry-run`, report the result and stop here.

2. **Verify `gh`** (skip under `--local` if the issue body is already supplied):

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/check-gh-cli.sh"
   ```

3. **Read the issue.**

   ```bash
   gh issue view <issue-number> --json number,title,body,labels,assignees
   ```

   Confirm it carries `agent-ready`. If not, say so and stop — the label is how a human
   signals that an issue is understood well enough to hand over.

4. **Route to an agent by role.** Unless `--agent` is given, match the kind of work the
   issue describes against each agent's `role`:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --list
   ```

   | Role       | Agent            | Takes                              |
   | ---------- | ---------------- | ---------------------------------- |
   | `worker`   | `impl-worker`    | Implementation — code, tests, docs |
   | `triage`   | `issue-ingester` | Classifying and ingesting issues   |
   | `reviewer` | `pr-reviewer`    | Reviewing an existing change       |

   Only agents with `memory: true` are dispatch targets; the deterministic auditors run
   as hooks and are not assignable. Most issues are implementation work and route to
   `impl-worker` — say so plainly rather than dressing a default as a match.

   **Do not route by `specializations`.** The field exists in the frontmatter but nothing
   populates it, so every agent's is `[]` and matching against it silently falls through
   to a default every time (#37). It is reserved for RFC-013's `/improve` to write once
   there is evidence to write from. `role` is populated for every agent and stable, which
   is what makes it usable as a routing key.

5. **Execute.**

   **With `--local`** — run the protocol in this session, no CI, no credentials.

   `/ingest-issue` classifies first, and the path depends on what it returns.

   **RFC + Plan** — design work that something will orchestrate:

   | Step | Action                                                | Gate               |
   | ---- | ----------------------------------------------------- | ------------------ |
   | 1    | `/ingest-issue <n>` → draft proposal                  | **Human approves** |
   | 2    | `/new-plan --from-proposal NNN`                       | **Human approves** |
   | 3    | `/orchestrate <plan> --mode supervised`               | Stop conditions    |
   | 4    | `/review-checklist` self-review                       | —                  |
   | 5    | `/pr-describe` → **draft** PR, `agent-authored` label | **Human reviews**  |
   | 6    | Human merges                                          | **Human merges**   |

   **No documents** — a fix or chore worth roughly one PR:

   | Step | Action                                                | Gate              |
   | ---- | ----------------------------------------------------- | ----------------- |
   | 1    | Implement directly, referencing the issue             | —                 |
   | 2    | `/review-checklist` self-review                       | —                 |
   | 3    | `/pr-describe` → **draft** PR, `agent-authored` label | **Human reviews** |
   | 4    | Human merges                                          | **Human merges**  |

   Do not invent an RFC to unlock a plan for work nothing will orchestrate. That puts a
   fake design on the permanent record purely to satisfy a guard, and the guard is right
   (#38).

   The approval gates are the point. Stop and ask at each one; do not infer approval from
   silence or from the fact that nobody objected last time.

   **Without `--local`** — trigger the configured backend:

   ```bash
   gh workflow run agent-dispatch.yml -f issue=<issue-number> -f agent=<agent-id>
   ```

   If the workflow does not exist, say so plainly: it ships as an opt-in template and is
   not installed by default (ADR-023). Point at
   `${CLAUDE_PLUGIN_ROOT}/skills/agent-dispatch/templates/agent-dispatch.yml` and offer
   `--local`, which needs no infrastructure at all.

6. **Record the assignment.**

   ```bash
   gh issue comment <issue-number> --body "Dispatched to <agent-id>. Progress will be posted here."
   ```

   When principled-tasks is installed, open a task linking the issue so the work is
   visible in the graph. Skip silently when it is not.

## Reporting

State the gate result with its numbers, which agent was chosen and on what role, the
classification `/ingest-issue` returned and therefore which path was taken, and the next
human gate. If refused, lead with the refusal and its reason — never bury it under what
you would have done.

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/agent-governance.sh` — the governance gate (ADR-022)
- `${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh` — registry and routing (ADR-018)
- `${CLAUDE_PLUGIN_ROOT}/lib/check-gh-cli.sh` — gh availability

## Templates

- `${CLAUDE_PLUGIN_ROOT}/skills/agent-dispatch/templates/agent-dispatch.yml` — opt-in
  GitHub Actions backend (ADR-023). Not installed by default
