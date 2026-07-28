---
title: "GitHub Actions as the First Dispatch Backend, Shipped Opt-In"
number: "023"
status: accepted
author: Alex
created: 2026-07-28
updated: 2026-07-28
originating_proposal: "012"
supersedes: null
superseded_by: null
---

# ADR-023: GitHub Actions as the First Dispatch Backend, Shipped Opt-In

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

RFC-012 needs a way to start an agent session from an issue without a human running a
command. GitHub Actions is the obvious first backend: the backlog is already GitHub
issues (ADR-010 established `gh` as the GitHub interface), and Actions triggers on issue
events for free.

Two questions follow, and they are usually conflated.

**Where is the abstraction boundary?** If dispatch is written directly against Actions,
swapping backends later means rewriting the skill. If it is abstracted too early, the
abstraction is invented rather than derived, and the second backend will not fit it
anyway.

**Should the workflow be active in this repository?** A workflow that triggers on
`agent-ready` and runs a Claude Code session needs API credentials in CI and has
repository write access. RFC-012 names credential exposure as a risk and notes that
secrets management is a burden a repository plugin has not previously carried.

That second question is easy to answer by default rather than deliberately — shipping a
working `.github/workflows/agent-dispatch.yml` is the natural thing to do, and it is the
wrong thing to do.

## Decision

**GitHub Actions is the first backend. The abstraction boundary is the `/agent-dispatch`
skill. The workflow ships as an opt-in template, not as an active workflow.**

### The boundary is the skill, not a runtime layer

`/agent-dispatch <issue>` is the contract. It does two separable things:

- `--local` runs the protocol in the current session. **No CI, no credentials, no
  workflow file.** The entire infrastructure layer is optional.
- Without `--local`, it triggers the configured backend, today a `workflow_dispatch` call
  via `gh`.

That is the whole abstraction. There is no runtime interface, no backend registry, no
plugin seam — because there is exactly one backend, and a second one does not exist to
generalize from. What the boundary buys is that a future backend changes one branch of
one skill, and the protocol, governance, and every other skill are untouched.

`--local` is what makes this honest rather than aspirational: the fallback path is not a
degraded mode, it is the primary way to use the feature without adopting any
infrastructure at all.

### The workflow is a template

The dispatch workflow lives at
`plugins/principled-agent/skills/agent-dispatch/templates/agent-dispatch.yml` and is
installed deliberately, the same way principled-github's `/gh-scaffold` installs CI
templates.

It is **not** committed to `.github/workflows/` in this repository, and when installed it
defaults to `workflow_dispatch` only — manual trigger — with the `issues` trigger present
but commented, so enabling automatic dispatch is a visible, reviewable edit.

The template requests least-privilege permissions:

```yaml
permissions:
  contents: write # branches and commits
  issues: write # progress comments, agent-blocked
  pull-requests: write # draft PRs
```

No `actions: write`, no `id-token`, no organization scope. The token cannot modify
workflows, so a compromised run cannot rewrite its own dispatcher.

### Why opt-in rather than active

Installing a plugin should not arm anything. A user adding principled-agent for
`/agent-memory` has not consented to a workflow that spends API credits on issue events,
and the gap between "I installed a documentation plugin" and "agents now open PRs in my
repository on a label" is exactly where unpleasant surprises live.

The same reasoning applies to this repository. Dogfooding the _protocol_ is valuable;
dogfooding _unattended dispatch with live credentials_ is a separate decision with a
separate risk profile, and it should be made explicitly rather than inherited from a
merge.

## Options Considered

### Option 1: Actions backend, skill-level boundary, opt-in template (chosen)

Minimal abstraction for a single backend, and no capability is enabled without an
explicit act.

Cost: users who _want_ automatic dispatch have an extra installation step, and the
template can drift from the skill that documents it.

### Option 2: Ship an active workflow in `.github/workflows/`

Immediately usable and genuinely dogfooded. Rejected: it requires credentials in CI
before anyone has decided they want autonomous dispatch, and it makes plugin installation
a security-relevant act. The convenience is small and the surprise is large.

### Option 3: A backend abstraction layer with pluggable runtimes

Clean seam for Actions, GitLab CI, a hosted runner. Rejected as premature — the interface
would be derived from one implementation and would almost certainly be wrong for the
second. `--local` plus a single skill already delivers the portability that matters.

### Option 4: A long-lived agent service instead of CI

Avoids cold starts and job time limits, and would support genuine parallelism. Rejected
for now, matching RFC-012: it requires hosting, secrets management, and an availability
story, none of which a repository plugin should own.

## Consequences

### Positive

- Installing principled-agent arms nothing
- The feature is fully usable with no CI at all, via `--local`
- Least-privilege tokens; a compromised run cannot rewrite its dispatcher
- Enabling automatic dispatch is one visible, reviewable diff
- A future backend touches one branch of one skill

### Negative

- Automatic dispatch requires a manual install step, and users will hit that friction
- The template is not exercised by this repository's CI, so it can rot undetected —
  mitigated only by the reference checker confirming it exists, not that it runs
- `workflow_dispatch`-by-default means the advertised "triggers on `agent-ready`"
  behaviour requires an edit before it is true, which must be documented clearly or it
  reads as a bug
- Actions job time limits still cap how long one dispatched run can take, and nothing here
  removes that

## References

- [RFC-012: GitHub-Native Agent Collaboration and Autonomous Execution](../proposals/012-github-native-agent-collaboration.md)
- [ADR-022: Agent Governance Constraints for Autonomous Execution](022-agent-governance-constraints.md)
- [ADR-010: gh CLI as GitHub Interface](010-gh-cli-as-github-interface.md)
- [ADR-018: Shared Plugin lib/ Over Copies](018-shared-plugin-lib-over-copies.md)
- [Plan-011: GitHub-Native Agent Collaboration](../plans/011-github-native-agent-collaboration.md)
