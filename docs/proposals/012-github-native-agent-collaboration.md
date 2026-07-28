---
title: "GitHub-Native Agent Collaboration and Autonomous Execution"
number: "012"
status: draft
author: Alex
created: 2026-07-28
updated: 2026-07-28
supersedes: null
superseded_by: null
---

# RFC-012: GitHub-Native Agent Collaboration and Autonomous Execution

## Audience

- Teams who want agents to pick up work from a shared backlog without a human driving each session
- Reviewers who will receive agent-authored PRs and need to know what guarantees apply
- Maintainers of principled-github and principled-implementation
- Anyone assessing the governance risk of letting agents open PRs against their repository

## Context

This is the second of three proposals carved out of RFC-010. RFC-011 covers agent
memory and resumability; this one covers how agents participate in a GitHub workflow
and how far they run without a human present.

### The problem

Every orchestration run today requires a human to start it, watch it, and intervene.
There is no way to hand an agent a backlog and check back later. Humans and agents also
cannot collaborate through the same surface: agents do not create issues, do not respond
to review comments, and do not pick up assigned work.

### What already exists

principled-github ships `/triage`, `/ingest-issue`, `/sync-issues`, `/pr-describe`, and
`/pr-check`. principled-quality ships `/review-checklist`, `/review-context`,
`/review-coverage`, and `/review-summary`. principled-tasks (ADR-017) ships a shared,
git-committed task graph with dependency edges and agent assignment.

The pieces of a collaboration loop exist. Nothing composes them into one.

### Dependencies

- **RFC-011 (required).** Dispatch routes work by agent specialization, which lives in
  the agent registry. Review feedback is written back to agent memory.
- **RFC-008 (partial).** `interactive` and `supervised` modes need only shipped
  infrastructure. The four-role parallel model needs agent teams and the lifecycle
  hooks from Plan-008.

## Proposal

Two layers, deliberately separable: a **protocol** that is portable, and
**infrastructure** that is swappable.

### 1. The Agent Contributor Protocol

A workflow pattern, not a platform. A team can follow it running agents locally, on
GitHub Actions, or on any CI system.

```
1.  Issue assigned to agent (label: agent-ready, assignee: agent ID)
2.  Agent picks up the issue via /triage
3.  Agent drafts a proposal via /new-proposal
4.  Human reviews and approves the proposal
5.  Agent drafts a plan via /new-plan --from-proposal NNN
6.  Human reviews and approves the plan
7.  Agent executes via /orchestrate --mode supervised|autonomous
8.  Agent self-reviews via /review-checklist
9.  Agent opens a draft PR via /pr-describe
10. Human reviews the PR
11. Agent addresses review comments via /agent-respond
12. Human merges
```

The human approval gates at steps 4, 6, 10 and 12 are the point. The agent does the
work; a human owns every irreversible decision.

**Governance constraints**, following GitHub's own agent-as-collaborator model:

- Agents cannot approve their own PRs
- Agents open **draft** PRs; promotion to ready-for-review is a human act
- Agent commits carry co-authorship attribution for audit
- Protected branch rules apply to agent branches exactly as to human ones
- Every agent PR links back to its issue, proposal, and plan

**Review feedback loop:** when a human reviews an agent PR, the comments are captured
via the GitHub API and written into that agent's memory file (RFC-011). Requested
changes spawn a session to address them. This is the mechanism by which review
feedback stops being repeated.

### 2. Dispatch infrastructure

GitHub Actions is the first backend, not the only possible one.

`.github/workflows/agent-dispatch.yml`:

1. Triggers on issues labeled `agent-ready`
2. Dispatches a Claude Code session with the issue context
3. The agent runs the protocol above
4. Progress is posted as issue comments
5. A PR is opened on completion
6. On failure, an `agent-blocked` issue is created with diagnostics

The backlog is **not** a new data structure. `/triage` assigns issues to agents based
on specialization and availability from the registry, and the resulting work units are
tasks in the principled-tasks graph. RFC-010 proposed `.agents/backlog.json`; that is
withdrawn, because principled-tasks already provides it.

### 3. Execution modes

`/orchestrate` gains a `--mode` flag:

| Mode          | Behavior                                     | Human involvement      |
| ------------- | -------------------------------------------- | ---------------------- |
| `interactive` | Current behavior                             | Continuous             |
| `supervised`  | Runs autonomously, pauses at decision points | At decision gates      |
| `autonomous`  | Runs end to end, posts results for review    | Post-completion review |

**Supervised mode** posts a progress comment at each phase boundary and continues
automatically _unless_ a task has exceeded its retry budget (default 2), a decision
point tagged in the plan is reached, or a phase exceeds 50% task failure — the signal
that something systemic is wrong rather than one task being hard.

**Autonomous mode** runs decompose → spawn → validate → merge, maintains a live
progress issue, and finishes by running `/pr-describe`, `/review-checklist`, and
`/release-ready` before opening a PR. If blocked, it files `agent-blocked` and moves to
the next available work rather than stalling.

### 4. Parallel execution roles

Building on RFC-008's agent teams:

| Role             | Responsibility                              | Count               |
| ---------------- | ------------------------------------------- | ------------------- |
| **Orchestrator** | Decomposes, assigns, monitors               | 1                   |
| **Workers**      | Execute tasks in isolated worktrees         | N (`--max-workers`) |
| **Reviewer**     | Pre-validates worker output before merge    | 1                   |
| **Integrator**   | Manages the merge queue, resolves conflicts | 1                   |

Each role maps to a shipped skill: Workers use `impl-worker`, the Reviewer runs
`/check-impl` and `/review-checklist`, the Integrator runs `/merge-work`. The roles are
a coordination pattern over existing capability, not new execution machinery.

This is also where principled-tasks earns its keep: `blocks` edges give the
Orchestrator a dependency order for free, and the append-only log with a union merge
driver means N workers on N branches merge their task updates without conflict.

### New skills

| Skill            | Command                                | Description                          |
| ---------------- | -------------------------------------- | ------------------------------------ |
| `agent-dispatch` | `/agent-dispatch <issue> [--local]`    | Assign an issue to an agent          |
| `agent-respond`  | `/agent-respond <pr-number>`           | Address PR review feedback           |
| `agent-status`   | `/agent-status [--all] [--agent <id>]` | Report workforce status and progress |

`--local` runs dispatch in the current session instead of CI, which makes the entire
infrastructure layer optional. The protocol is usable with no GitHub Actions at all.

## Alternatives Considered

### Alternative 1: Agents as full collaborators with merge rights

Simpler — no draft-PR dance, no promotion step. Rejected: an agent that can merge its
own work removes the only reliable check on a non-deterministic system. The cost of the
extra human step is small; the cost of an unreviewed bad merge is not.

### Alternative 2: A bespoke work queue instead of GitHub issues

More control over scheduling and priority. Rejected because it splits the backlog:
humans would file issues while agents read a queue, and the two would drift. GitHub
issues are where the work already is.

### Alternative 3: Build dispatch on a dedicated agent runtime rather than CI

A long-lived agent service would avoid CI cold starts and job time limits. Rejected for
now as premature — it requires hosting, secrets management, and an availability story,
none of which a repository plugin should own. The dispatch skill abstracts the runtime
specifically so this can be revisited.

### Alternative 4: Skip the protocol, ship only execution modes

`--mode autonomous` is the visible feature; the protocol is process. Rejected because
autonomous execution without governance constraints is the failure mode this proposal
exists to avoid. The protocol is what makes the modes safe to use.

## Consequences

### Positive

- A human can hand agents a labelled backlog and review results, rather than driving
  each run
- Humans and agents collaborate through one surface, with full traceability from issue
  to proposal to plan to PR
- Review feedback stops repeating, because it lands in agent memory (RFC-011)
- The protocol works with no CI infrastructure via `--local`
- Parallel roles reuse shipped skills rather than introducing new execution machinery

### Negative

- Materially expands the blast radius of an agent mistake: unattended runs can produce
  many PRs before a human looks
- GitHub API rate limits become an operational concern under many parallel agents
- `agent-dispatch.yml` puts Claude Code credentials in CI, which is a secrets-management
  burden a repository plugin has not previously had
- Autonomous mode's failure behavior — file `agent-blocked` and move on — can accumulate
  blocked issues faster than a human triages them

### Risks

- **Runaway loops.** An agent that repeatedly fails, files a blocker, and picks up
  adjacent work could burn substantial budget. Mitigation: retry budgets, the 50%
  phase-failure circuit breaker, and a hard cap on concurrent dispatches.
- **Review fatigue.** If agents open PRs faster than humans review them, the human gate
  becomes a rubber stamp — which is worse than no gate, because it looks like oversight.
  Mitigation: cap in-flight agent PRs; treat the queue depth as a health metric.
- **Credential exposure.** A compromised workflow has repository write access.
  Mitigation: least-privilege tokens, protected branches, no auto-merge under any mode.
- **Protocol drift.** Agents may skip steps under `autonomous` mode if the protocol is
  only documentation. Mitigation: enforce the gates with hooks, not prose.

## Architecture Impact

- **New:** `docs/architecture/agent-collaboration.md` — the contributor protocol,
  governance constraints, dispatch flow
- **Update:** `docs/architecture/plugin-system.md` — principled-agent's relationship to
  principled-github and principled-implementation
- **New ADR:** GitHub Actions as the first dispatch backend, and what the abstraction
  boundary is
- **New ADR:** agent governance constraints (draft PRs, no self-approval, attribution)

## Open Questions

- **Where do the execution modes live?** `--mode` extends `/orchestrate` in
  principled-implementation, but dispatch and the protocol are principled-agent. Does
  that split the orchestrator across two plugins?
- **How is `agent-blocked` triaged?** Autonomous mode can produce blockers faster than
  they are read. Should there be a blocked-issue budget that halts dispatch?
- **What is the concurrency ceiling?** RFC-010 cited 20-30 parallel agents from prior
  art. What does this repository's CI, GitHub API quota, and review capacity actually
  support?
- **Does `--mode autonomous` need a kill switch** reachable from outside the session —
  a label or a file that halts all dispatch?
