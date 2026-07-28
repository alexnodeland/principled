---
title: "Agent Collaboration and Autonomous Execution"
last_updated: 2026-07-28
related_adrs: [022, 023, 010, 016, 021]
---

# Agent Collaboration and Autonomous Execution

## Purpose

Describes the Agent Contributor Protocol, the governance constraints that make it safe to
run unattended, and how dispatch reaches an agent. Intended for anyone enabling
autonomous execution, reviewing agent-authored PRs, or assessing the governance risk of
letting agents open PRs against a repository.

## The protocol

```
 1. Issue labelled agent-ready, assigned to an agent
 2. Agent picks it up            /agent-dispatch <issue>
 3. Agent drafts a proposal      /new-proposal
 4. ── HUMAN APPROVES ──────────────────────────────────
 5. Agent drafts a plan          /new-plan --from-proposal NNN
 6. ── HUMAN APPROVES ──────────────────────────────────
 7. Agent executes               /orchestrate --mode supervised|autonomous
 8. Agent self-reviews           /review-checklist
 9. Agent opens a DRAFT PR       /pr-describe
10. ── HUMAN REVIEWS ───────────────────────────────────
11. Agent addresses feedback     /agent-respond <pr>
12. ── HUMAN MERGES ────────────────────────────────────
```

**The four human gates are the design, not overhead.** The agent does the work; a human
owns every irreversible decision. Steps 3, 5, 8 and 11 are cheap to redo; steps 4, 6, 10
and 12 are not.

### Not every issue takes the long path

Steps 3–6 apply to **design work**. `/ingest-issue` classifies first, and a fix or chore
worth roughly one PR produces **no pipeline documents at all** — implement, self-review,
draft PR, human merges. That is how most fixes in this repository have actually shipped.

There is deliberately no "plan without a proposal" option:
`check-plan-proposal-link.sh` blocks it, and correctly — a plan is a DDD decomposition of
an accepted design, so a plan with no design is a decomposition of nothing. The trap is
inventing an RFC purely to unlock a plan for work nothing will orchestrate, which puts a
fake design on the permanent record to satisfy a guard (#38).

The protocol is a workflow pattern, not a platform. It runs identically with
`/agent-dispatch --local` in a terminal and through CI.

## Governance is mechanical, not documentary

The modes exist for the case where nobody is watching. "The agent should check" is
unfalsifiable exactly then, so each constraint that matters is enforced by something a
script can answer (ADR-022).

| Constraint             | Mechanism                         | Where                       |
| ---------------------- | --------------------------------- | --------------------------- |
| Halt switch            | `.agents/HALT` exists             | Before dispatch; phase ends |
| Blocker budget         | open `agent-blocked` issues < 5   | `--can-dispatch`            |
| Review-capacity budget | open `agent-authored` PRs < 5     | `--can-dispatch`            |
| Retry budget           | task retries ≤ 2                  | Orchestration loop          |
| Phase circuit breaker  | phase failure rate ≤ 50%          | Phase boundary              |
| Draft PRs, no approval | advisory hook + branch protection | `check-agent-governance.sh` |

### The gate

```
/agent-dispatch
  └─ agent-governance.sh --can-dispatch
       ├─ .agents/HALT exists?        → exit 3, refuse (checked first: no network needed)
       ├─ counts unavailable?         → exit 3, refuse — unknown is NOT headroom
       ├─ agent-blocked  >= budget?   → exit 3, refuse
       ├─ agent-authored >= budget?   → exit 3, refuse
       └─ otherwise                   → exit 0, proceed
```

**Exit 3 means refused; exit 1 means could not tell.** The distinction is load-bearing: a
caller that conflates them either ignores a real refusal or halts on a transient fault.

**Unknown budgets fail closed.** When `gh` is unavailable the counts are unknown, and
dispatch refuses rather than assuming room. Treating unknown as zero would silently
disable the safety layer at exactly the moment the environment is already misbehaving.

### The halt switch

A committed file at `.agents/HALT`, whose contents are a reason string.

File-based rather than a GitHub label because it behaves identically under `--local` and
CI, needs no API call (so it works when the API is what is broken), and is operable by
anyone with repository write access and no running session — which is the point, since
whoever needs to stop a runaway is rarely whoever started it.

Checked before every dispatch and at every **phase boundary**, never mid-task:
interrupting a worker halfway leaves a worktree in an unknown state, and the phase
boundary is the nearest point where stopping is clean.

It is also the seam between two plugins that cannot call each other. principled-agent
owns the switch; principled-implementation only reads the path. Plugins install
independently and cannot reference each other's `${CLAUDE_PLUGIN_ROOT}` (ADR-018), so
**the file path is the contract** — a coupling invisible to the reference checker and
maintained by convention.

## Two orthogonal axes

Conflating these causes real confusion, because both get called "mode".

| Axis            | Selected by                            | Answers                               |
| --------------- | -------------------------------------- | ------------------------------------- |
| **Parallelism** | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | How many tasks run at once?           |
| **Autonomy**    | `--mode`                               | How much human involvement is needed? |

They are independent: any autonomy level runs under either parallelism strategy.

| `--mode`      | Behaviour                                 | Human involvement      |
| ------------- | ----------------------------------------- | ---------------------- |
| `interactive` | Unchanged from before RFC-012             | Continuous             |
| `supervised`  | Runs on, pausing at decision points       | At decision gates      |
| `autonomous`  | Runs end to end, posts results for review | Post-completion review |

`--mode` defaults to `interactive`, so existing invocations behave exactly as before.

## Dispatch

```
/agent-dispatch <issue>
  ├─ --local  → run the protocol in this session   (no CI, no credentials)
  └─ default  → gh workflow run agent-dispatch.yml (opt-in template)
```

**The skill is the abstraction boundary** (ADR-023). There is no runtime interface or
backend registry, because there is exactly one backend and a second does not exist to
generalize from. A future backend changes one branch of one skill.

`--local` is what makes the portability claim honest: it is not a degraded fallback, it
is the primary way to use the protocol with no infrastructure at all.

### The workflow is opt-in

`agent-dispatch.yml` ships as a **template** and is deliberately not active in this
repository. Installing a plugin should not arm anything, and the gap between "I installed
a documentation plugin" and "agents now open PRs on a label" is where unpleasant
surprises live.

When installed it defaults to `workflow_dispatch` only; the `issues` trigger is present
but commented, so enabling automatic dispatch is a visible, reviewable diff. Permissions
are `contents`, `issues`, and `pull-requests` write — no `actions: write`, so a
compromised run cannot rewrite its own dispatcher.

## The feedback loop

This is what stops a reviewer correcting the same thing forever:

```
Human reviews PR
  └─ /agent-respond <pr>
       ├─ defect     → fix, reply                    (a fact about one PR)
       ├─ convention → fix, reply, PROMOTE TO MEMORY (a fact about the codebase)
       └─ preference → judgement, reply either way
                            │
                            └─ .agents/memory/agents/<id>.md
                                 └─ injected at the next spawn (ADR-020)
```

Only conventions are promoted. Promoting a defect writes an incident into memory, where
it dilutes context forever without preventing anything.

## Known limits

- **Review fatigue is the real ceiling.** CI minutes and API quota are elastic; reviewer
  attention is not. If agents open PRs faster than humans read them, the gate becomes a
  rubber stamp — which is worse than no gate, because it looks like oversight. The
  in-flight cap exists for this and is the number most likely to need tuning.
- **The caps are not measured.** 5, 5, 3 and 2 are conservative defaults. This repository
  has never run autonomous dispatch, and any number presented as measured would be
  invented. Raise them from observation: a draining PR queue means headroom, accumulating
  blockers mean none.
- **The template is not exercised by CI.** The reference checker confirms it exists, not
  that it runs, so it can rot undetected.
- **The four-role parallel model needs agent teams** (ADR-016), which remain behind
  the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag. Roles
  are documented as a coordination pattern over shipped skills; no code requires teams.
- **A stale `.agents/HALT` blocks everything.** Every refusal prints the reason and the
  path, so the cause is never a mystery — but nothing expires it.

## Related

- [ADR-022: Agent Governance Constraints](../decisions/022-agent-governance-constraints.md)
- [ADR-023: GitHub Actions as the First Dispatch Backend](../decisions/023-github-actions-dispatch-backend.md)
- [ADR-021: Manifest Checkpoint and Criterion-Level Acceptance](../decisions/021-manifest-checkpoint-schema.md)
- [ADR-010: gh CLI as GitHub Interface](../decisions/010-gh-cli-as-github-interface.md)
- [Agent Memory and Resumability](agent-memory.md)
- [RFC-012](../proposals/012-github-native-agent-collaboration.md) / [Plan-011](../plans/011-github-native-agent-collaboration.md)
