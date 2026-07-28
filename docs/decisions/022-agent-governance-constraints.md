---
title: "Agent Governance Constraints for Autonomous Execution"
number: "022"
status: accepted
author: Alex
created: 2026-07-28
updated: 2026-07-28
originating_proposal: "012"
supersedes: null
superseded_by: null
---

# ADR-022: Agent Governance Constraints for Autonomous Execution

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

RFC-012 lets agents run without a human present: pick up a labelled issue, execute a
plan, open a PR. That is a material change in blast radius. Today a human starts every
run and watches it; afterwards, an unattended run can produce many PRs before anyone
looks.

The temptation is to treat governance as documentation — a protocol in a markdown file
that agents are told to follow. RFC-012's own risk register names why that fails:
**agents may skip steps under `autonomous` mode if the protocol is only prose.** A
non-deterministic system asked to police itself will sometimes not.

So the question is not whether to have constraints, but which ones are load-bearing
enough to enforce mechanically, and where the enforcement lives.

### What makes this different from the existing hooks

The pipeline's existing guards protect _documents_ from _edits_ — an accepted ADR must
not change. These constraints protect a _repository_ from a _process_ that is running
unattended and may be malfunctioning. The failure they guard against is not one bad
write; it is a loop that produces bad writes faster than anyone reads them.

## Decision

**Six constraints, each enforced by a mechanism rather than by instruction.**

### 1. A file-based halt switch

`.agents/HALT` stops all dispatch and pauses orchestration at the next phase boundary.
Any file content is treated as a reason string and surfaced when a run refuses to start.

File-based rather than a GitHub label because it works identically under `--local` and
under CI (one mechanism, not two that can disagree), needs no API call (so it works when
the API is what is broken), and is operable by anyone with repository write access and no
running session — which is the point, since whoever needs to stop a runaway is usually
not whoever started it.

Checked before every dispatch and at every phase boundary. **Not** checked mid-task:
interrupting a worker halfway leaves a worktree in an unknown state, and the phase
boundary is the nearest point where stopping is clean.

### 2. Agents open draft PRs and cannot approve them

Promotion to ready-for-review is a human act. An agent that can approve or merge its own
work removes the only reliable check on a non-deterministic system.

### 3. Circuit breakers, not retries

Three conditions halt a run rather than escalating it:

| Condition                   | Default | Rationale                                       |
| --------------------------- | ------- | ----------------------------------------------- |
| Task retry budget exceeded  | 2       | A third identical attempt is not a strategy     |
| Phase task-failure rate     | 50%     | Systemic fault, not one hard task               |
| Open `agent-blocked` issues | 5       | Blockers outpacing triage means something broke |

Each says the same thing: the evidence indicates the next attempt fails the same way, so
stop and surface it. Halting is cheap and reversible; an accumulated mess is neither.

### 4. In-flight PR cap over worker parallelism

Default 5 in-flight agent PRs, and a default of 3 parallel workers.

CI minutes and API quota are elastic — money and backoff raise them. **Human review
capacity is not.** Review fatigue is worse than no gate, because a rubber stamp looks
like oversight while providing none. The binding constraint is the reviewer, so the cap
belongs on PRs awaiting review rather than on workers.

Both numbers are conservative defaults, not measurements. This repository has never run
autonomous dispatch, and a number presented as measured would be invented.

### 5. Attribution on every agent commit

Co-authorship trailers, and every agent PR links its issue, proposal, and plan. Without
this an audit cannot distinguish agent work from human work after the fact, which is
exactly what a reviewer needs to know when deciding how hard to look.

### 6. No credentials in this repository's CI by default

The dispatch workflow ships as an **opt-in template**, not an active workflow. See
ADR-023.

## Options Considered

### Option 1: Enforce mechanically at each boundary (chosen)

Each constraint sits at the point where it can actually be checked: the halt file before
dispatch and at phase boundaries, budgets in the orchestration loop, PR governance in the
skill that opens the PR.

Cost: the constraints are spread across two plugins, so there is no single file that
states them all — which is what this ADR and `docs/architecture/agent-collaboration.md`
exist to compensate for.

### Option 2: Governance as documented protocol only

Far less code, and it trusts the model to follow a clearly written process. Rejected on
the proposal's own evidence: the modes exist precisely for the case where no human is
watching, so "the agent should check" is unfalsifiable at the moment it matters most.

### Option 3: A single gatekeeper hook that approves every agent action

One enforcement point, easy to audit. Rejected: it would need to understand dispatch,
orchestration, and PR state simultaneously, coupling the two plugins that ADR-018
deliberately keeps independent — and a gate that must be consulted for everything becomes
a gate that is worked around.

### Option 4: Rely on GitHub branch protection alone

Protected branches and required reviews already prevent an unreviewed merge, at no cost.
Rejected as insufficient rather than wrong: branch protection stops a bad _merge_, but
nothing about it stops a runaway loop from opening ninety PRs, burning budget, and
exhausting reviewers. It remains a required backstop, not the mechanism.

## Consequences

### Positive

- A runaway loop is stoppable by someone with no access to the running session
- Failure surfaces as a halt with a reason, rather than as volume
- Review capacity is treated as the scarce resource it actually is
- Agent work is attributable after the fact
- Constraints hold under `autonomous` mode, where prose would not

### Negative

- More moving parts, and a halted run needs a human to understand _why_ before resuming
- Conservative defaults will feel restrictive to anyone who has the review capacity to go
  faster; they must be raised deliberately
- The circuit breakers can stop a run that would have succeeded on the next attempt —
  accepted, because the failure mode they prevent is much more expensive than one
  unnecessary halt
- Governance state lives in two plugins, coupled only by a file path. That coupling is
  invisible to the reference checker and must be maintained by convention

### Risks

- **A stale `.agents/HALT` silently blocks all work.** Mitigation: every refusal prints
  the file's reason string and its path, so the cause is never a mystery.
- **Caps become the system's throughput and nobody revisits them.** Mitigation: they are
  documented as unmeasured defaults with an explicit signal for raising them.

## References

- [RFC-012: GitHub-Native Agent Collaboration and Autonomous Execution](../proposals/012-github-native-agent-collaboration.md)
- [ADR-023: GitHub Actions as the First Dispatch Backend](023-github-actions-dispatch-backend.md)
- [ADR-020: Agent Memory as a Frontmatter Document](020-agent-memory-as-document.md)
- [ADR-021: Manifest Checkpoint and Criterion-Level Acceptance](021-manifest-checkpoint-schema.md)
- [ADR-010: gh CLI as GitHub Interface](010-gh-cli-as-github-interface.md)
- [Plan-011: GitHub-Native Agent Collaboration](../plans/011-github-native-agent-collaboration.md)
