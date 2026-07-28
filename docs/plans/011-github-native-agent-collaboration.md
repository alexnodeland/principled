---
title: "GitHub-Native Agent Collaboration"
number: "011"
status: complete
author: Alex
created: 2026-07-28
updated: 2026-07-28
originating_proposal: "012"
related_adrs: ["022", "023"]
---

# Plan-011: GitHub-Native Agent Collaboration

## Objective

Implements [RFC-012](../proposals/012-github-native-agent-collaboration.md).

Deliver the Agent Contributor Protocol with its governance constraints enforced
mechanically, execution modes on `/orchestrate`, three workforce skills in
principled-agent, and GitHub Actions dispatch as an opt-in template.

The organizing principle is ADR-022's: every constraint that matters is enforced by a
mechanism, not by instructions an unattended agent may skip.

## Related Decisions

- [ADR-022: Agent Governance Constraints](../decisions/022-agent-governance-constraints.md) —
  halt switch, draft PRs, circuit breakers, in-flight caps, attribution
- [ADR-023: GitHub Actions as the First Dispatch Backend](../decisions/023-github-actions-dispatch-backend.md) —
  skill-level boundary, opt-in template, least privilege
- [ADR-020](../decisions/020-agent-memory-as-document.md) / [ADR-021](../decisions/021-manifest-checkpoint-schema.md) —
  memory and checkpoint, delivered in Plan-010
- [ADR-010: gh CLI as GitHub Interface](../decisions/010-gh-cli-as-github-interface.md)
- [ADR-018: Shared Plugin lib/ Over Copies](../decisions/018-shared-plugin-lib-over-copies.md)

## Domain Analysis

### Bounded Contexts

**Agent Workforce** (`principled-agent`) — who is working, on what, and whether they are
allowed to start. Owns `.agents/HALT`, dispatch, review-feedback capture, and workforce
reporting.

**Execution Modes** (`principled-implementation`) — how much human involvement one
orchestration run requires. Owns `--mode`, retry budgets, and the phase-failure breaker.

**GitHub Surface** (`principled-github`, existing) — issues, PRs, labels. Read and
written through `gh` (ADR-010); unchanged by this plan except for new labels.

The seam between the first two is a **file path, not an API**: `.agents/HALT`. Plugins
install independently and cannot reference each other's `${CLAUDE_PLUGIN_ROOT}`, and the
halt switch must be operable by a human with no session, so a committed file is both the
only available coupling and the correct one.

### Aggregates

| Aggregate       | Root                        | Invariants                                                      |
| --------------- | --------------------------- | --------------------------------------------------------------- |
| Halt state      | `.agents/HALT`              | Presence halts; content is a reason string, surfaced on refusal |
| Dispatch budget | open `agent-blocked` issues | At or above 5, dispatch refuses                                 |
| Review queue    | open agent-authored PRs     | At or above 5 in flight, dispatch refuses                       |
| Run mode        | `.impl/manifest.json`       | Mode is a property of a run; absent means `interactive`         |

### Domain Events

- **DispatchRequested** → halt, blocked-issue, and PR-cap checks run before anything else
- **PhaseBoundaryReached** → halt re-checked; supervised mode reports and continues
- **RetryBudgetExceeded** → run halts, `agent-blocked` filed with diagnostics
- **PhaseFailureRateExceeded** → run halts as systemic rather than retrying
- **ReviewSubmitted** → comments captured and written into agent memory (ADR-020)

## Implementation Tasks

### Phase 1: Governance enforcement

- [x] `lib/agent-governance.sh` in principled-agent — halt check with reason, blocked-issue
      count, in-flight PR count, combined `--can-dispatch` gate; bash 3.2, jq optional,
      degrades cleanly when `gh` is unavailable
- [x] `--halt <reason>` and `--resume` operations that write and clear `.agents/HALT`
- [x] `hooks/scripts/check-agent-governance.sh` — advisory warning when a PR is opened or
      merged in a way the protocol forbids (self-approval, non-draft agent PR)
- [x] Wire the hook into `hooks/hooks.json`

### Phase 2: Execution modes

- [x] `--mode interactive|supervised|autonomous` documented in `/orchestrate`, defaulting
      to `interactive` so existing behaviour is unchanged
- [x] Retry budget (default 2) and 50% phase-failure breaker as explicit stop conditions
- [x] Halt check at every phase boundary in supervised and autonomous modes; never
      mid-task, since interrupting a worker leaves a worktree in an unknown state
- [x] `--max-workers` default 3, documented as an unmeasured conservative default
- [x] Update `skills/impl-strategy/reference/orchestration-guide.md`

### Phase 3: Workforce skills

- [x] `/agent-dispatch <issue> [--local] [--dry-run]` — governance gate, specialization
      routing from the registry, `--local` execution, `workflow_dispatch` otherwise
- [x] `/agent-respond <pr-number>` — read review comments via `gh`, address them, and
      write durable feedback into the agent's memory file
- [x] `/agent-status [--all] [--agent <id>]` — halt state, in-flight PRs, blocked issues,
      per-agent metrics
- [x] Vendored `lib/check-gh-cli.sh` (fourth copy; add to the cross-plugin drift checker)

### Phase 4: Dispatch backend

- [x] `skills/agent-dispatch/templates/agent-dispatch.yml` — least-privilege permissions,
      `workflow_dispatch` only by default, `issues` trigger present but commented
- [x] Installation instructions, and an explicit statement that installing the plugin
      arms nothing
- [x] New labels (`agent-ready`, `agent-blocked`, `agent-authored`) added to
      principled-github's label definitions

### Phase 5: Tests, docs, CI

- [x] `tests/agent-governance.bats` — halt behaviour, budget arithmetic, gate composition,
      and graceful degradation with no `gh`
- [x] Extend `tests/hooks.bats` for the governance advisory, including the no-jq path
- [x] `docs/architecture/agent-collaboration.md` — protocol, governance, dispatch flow
- [x] Update `docs/architecture/plugin-system.md` for principled-agent's relationships
- [x] Root `CLAUDE.md`, `.claude/CLAUDE.md`, README, marketplace metadata
- [x] `just ci` green

## Dependencies

- **Plan-010 (complete).** The registry and memory this plan routes by and writes to.
- **principled-tasks (ADR-017).** Optional at runtime; used for dependency ordering.
- **`gh` CLI.** Required for dispatch, `/agent-respond`, and `/agent-status`; every
  script must degrade with a clear message rather than a stack trace when it is absent.
- **Agent teams (ADR-016, `proposed`).** The four-role parallel model needs them. Roles
  are therefore documented as a coordination pattern over shipped skills, and no code in
  this plan requires teams to be enabled.

## Acceptance Criteria

- [x] `.agents/HALT` blocks dispatch and pauses orchestration at the next phase boundary,
      and every refusal prints the reason and the file path
- [x] Dispatch refuses at or above 5 open `agent-blocked` issues or 5 in-flight agent PRs
- [x] Governance scripts exit cleanly and informatively when `gh` is not installed
- [x] `/orchestrate` with no `--mode` behaves exactly as before
- [x] The dispatch workflow is **not** active in this repository, and the template
      defaults to `workflow_dispatch` only
- [x] The template requests only `contents`, `issues`, and `pull-requests` write scope
- [x] `--local` completes the protocol with no CI and no credentials
- [x] Every new script passes ShellCheck and shfmt and runs on bash 3.2
- [x] `just ci` passes

## Verification

Machine-tested by `just ci` (158 bats tests, up from 126):

- `lib/agent-governance.sh` — halt engage/clear, refusal-vs-error exit codes, budget
  arithmetic including the inclusive boundary, fail-closed behaviour when `gh` is
  unavailable, JSON escaping, and the no-jq count fallback (`tests/agent-governance.bats`,
  23 tests)
- the governance advisory hook — non-draft PRs, missing `agent-authored` label,
  self-approval, merge, ready-for-review promotion, halt surfacing, malformed input, and
  the no-jq path (`tests/hooks.bats`)

Verified directly against the repository:

- no `agent-dispatch.yml` in `.github/workflows/` — the workflow is not active here
- the template parses to exactly one trigger (`workflow_dispatch`) and three permissions
  (`contents`, `issues`, `pull-requests`); `actions: write` appears only in an
  explanatory comment
- `scripts/check-skill-references.sh` resolves all 98 references
- the new labels round-trip through `label-definitions.sh --json`

Delivered as skills, and therefore model-executed rather than machine-tested:
`/agent-dispatch`, `/agent-respond`, `/agent-status`, and `/orchestrate --mode`. Their
script dependencies are covered above; the workflow prose is not executable and is not
claimed to be tested. **The end-to-end protocol has never been run** — no issue has been
dispatched, and the caps in ADR-022 remain unmeasured defaults.

Corrected in passing: `docs/architecture/plugin-system.md` still asserted ADR-009's
"scripts have no shared directory" rule, which ADR-018 superseded. Replaced with the
`lib/` constraint and a new section documenting the cross-plugin file-path contract,
including the fact that those couplings are invisible to `check-skill-references.sh`.
