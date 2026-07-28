---
title: "Agent Self-Improvement Loop"
number: "013"
status: rejected
author: Alex
created: 2026-07-28
updated: 2026-07-28
supersedes: null
superseded_by: null
---

# RFC-013: Agent Self-Improvement Loop

## Audience

- Engineers who have accumulated conversation histories and reviews that currently feed back into nothing
- Maintainers deciding whether "self-improving agents" is a capability worth building or a phrase worth avoiding
- Reviewers who will be asked to approve PRs that change what agents believe

## Context

This is the third of three proposals carved out of RFC-010. RFC-011 provides the
memory substrate; RFC-012 provides the collaboration surface that generates feedback.
This proposal closes the loop between them.

### The problem

Performance data exists and is discarded. Manifest outcomes record which tasks failed
and how often they were retried. PR reviews record what humans corrected. CI records
what broke. Conversation histories record the reasoning that produced all of it.

None of it changes agent behavior. Every run starts from the same baseline regardless
of how the last hundred went.

### Why this is separable

RFC-011 gives agents somewhere to remember. RFC-012 gives them a stream of human
feedback. Neither requires this proposal to be useful — memory can be written by hand,
and review feedback can be applied by a human. This proposal automates the synthesis,
which is why it goes last: it is the only one of the three that can act on its own
conclusions, and that deserves the most scrutiny.

### Dependencies

- **RFC-011 (required).** There is nothing to write to without `.agents/memory/`.
- **RFC-012 (recommended).** PR review comments are the highest-signal input. Without
  it, the loop runs on manifest outcomes and CI results alone.
- **RFC-008: none.**

## Proposal

A closed cycle with an explicit brake:

```
Execute → Capture → Analyze → Synthesize → Inject → Verify → Execute
                                                       │
                                              regression? revert
```

### 1. Capture

| Source                 | What it captures                         | Where it lives            |
| ---------------------- | ---------------------------------------- | ------------------------- |
| Manifest outcomes      | Task success/failure, retry counts       | `.impl/manifest.json`     |
| Task graph             | Discovery chains, blocked chains, timing | `.principled/tasks.jsonl` |
| PR review comments     | Human feedback on quality                | GitHub API                |
| CI results             | Build, test, lint pass rates             | GitHub Actions            |
| Conversation histories | Full reasoning traces                    | User-provided, local      |
| Retrospectives         | Synthesized learnings per run            | `.agents/retrospectives/` |

Every orchestration run generates a retrospective document — a pipeline document with
frontmatter and a structured body, subject to the same hook enforcement as any other.

### 2. Analyze

`/retro [plan-path] [--auto]` processes retrospectives to answer specific questions:

- Which task types consistently fail on first attempt?
- Which review feedback recurs across PRs?
- Which areas of the codebase generate the most retries?
- Which prompt patterns preceded successful runs?

### 3. Synthesize

`/improve [--agent <id>] [--dry-run]` distills findings into memory updates:

- **Global memory** — patterns that apply to every agent
- **Agent memory** — patterns specific to one role or specialization
- **Anti-patterns** — approaches to explicitly avoid

`/improve` **synthesizes rather than appends.** This is the difference between memory
that stays useful and memory that becomes a landfill. `--dry-run` prints the proposed
diff without writing.

### 4. Ingest conversation history

```
/ingest-history <path> [--agent <id>] [--extract-patterns]
```

Conversation histories are the richest available signal and currently the most wasted.
This extracts successful approaches, recurring errors and their resolutions,
codebase-specific knowledge, and — most valuable — the points where a human redirected
the agent.

Histories stay local and are never transmitted; the skill reads them and writes
distilled patterns into memory.

### 5. Verify, and revert on regression

This is the part that makes the loop safe to run.

```
/agent-metrics [--agent <id>] [--since <date>]
```

Reports tasks completed, failed, and retried; average retries by task type; review
feedback frequency by category; and the trend over time.

**Regression detection:** if metrics degrade after a memory update — higher retry rates,
more review rejections — the system flags it. Because memory updates are ordinary git
commits, reverting to the last known-good state is a `git revert`. Without this, a loop
that can rewrite its own instructions on the basis of its own output will eventually
drift, and nothing will notice.

### New skills

| Skill            | Command                               | Description                          |
| ---------------- | ------------------------------------- | ------------------------------------ |
| `retro`          | `/retro [plan-path] [--auto]`         | Generate and analyze a retrospective |
| `ingest-history` | `/ingest-history <path>`              | Extract patterns from histories      |
| `improve`        | `/improve [--agent <id>] [--dry-run]` | Synthesize learnings into memory     |
| `agent-metrics`  | `/agent-metrics [--agent <id>]`       | Performance reporting and trends     |

### Human review is not optional

Memory updates are commits. They go through PR review like any other change. An agent
proposes what it has learned; a human decides whether it is true. `/improve --dry-run`
exists so that this is the default workflow rather than an afterthought.

## Alternatives Considered

### Alternative 1: Fully automatic memory updates, no human gate

Faster, and the obvious reading of "self-improving." Rejected: a system that writes its
own instructions from its own output, with no external check, has no mechanism for
noticing that it has learned something false. The human gate is cheap and is the only
thing standing between this and confident drift.

### Alternative 2: Fine-tuning instead of memory synthesis

Learned patterns could become training signal rather than context. Rejected as out of
scope and out of proportion: it requires infrastructure a repository plugin cannot own,
is not reversible the way a git revert is, and is opaque to review. Memory is auditable
in a way weights are not.

### Alternative 3: Metrics only, no synthesis

Ship `/agent-metrics` and let humans update memory by hand. Genuinely tempting — it is
most of the value at a fraction of the risk. Rejected as the _end state_ but accepted as
the delivery order: metrics and retrospectives are useful alone and should ship before
`/improve`.

### Alternative 4: Store improvement data outside git

A metrics database would query faster and avoid inflating the repository. Rejected for
the same reason ADR-017 landed where it did: if it is not in git, it does not survive a
clone, and it cannot be reviewed or reverted.

## Consequences

### Positive

- Review feedback stops repeating — the single most visible waste in agent work today
- Conversation histories become an asset rather than an archive
- `/agent-metrics` gives an objective answer to "are the agents getting better?", which
  is currently a matter of impression
- Every learned pattern is a reviewable diff with an author and a revert path
- Regression detection means a bad update is caught by measurement, not by noticing

### Negative

- The most complex of the three proposals, and the least independently useful
- Metrics are only as good as the data: sparse runs produce noisy trends that invite
  over-reading
- `/ingest-history` must handle unstructured, potentially very large input
- Adds a per-run cost (retrospective generation) to every orchestration

### Risks

- **Confident drift.** The core risk of any self-modifying system: it learns something
  wrong, applies it consistently, and the resulting failures look like normal variance.
  Mitigation: human review of memory diffs, regression detection, and git revert.
- **Overfitting to recent runs.** A run of unusual failures could produce memory that
  is wrong in the general case. Mitigation: require a minimum sample before synthesis;
  prefer patterns seen across multiple runs.
- **Metric gaming.** If agents optimize for the metrics rather than the outcome —
  splitting tasks to lower per-task retry rates, for instance — the numbers improve
  while the work does not. Mitigation: treat metrics as diagnostic, never as an
  objective handed to the agent.
- **Privacy.** Conversation histories may contain sensitive content. Mitigation:
  histories stay local, are never transmitted, and only distilled patterns are written.

## Architecture Impact

- **New:** `docs/architecture/agent-improvement.md` — the capture/analyze/synthesize/
  inject/verify cycle and its data sources
- **Update:** `docs/architecture/documentation-pipeline.md` — retrospectives as a
  pipeline document type with a defined lifecycle
- **New ADR:** memory updates require human review; the loop is not closed automatically
- **New ADR:** regression detection thresholds and the revert procedure

## Open Questions

- **What counts as a regression?** A single worse run is noise. How many runs, and how
  much degradation, before the system flags an update?
- **How much history is enough?** `/improve` needs a minimum sample to avoid overfitting.
  What is it, and should it differ by agent role?
- **Who owns global memory?** Agent-specific memory has a clear owner. `global.md` is
  edited by every agent — does it need stricter review, or an owner?
- **Should retrospectives expire?** They accumulate per run indefinitely. Is there a
  retention policy, or does `/improve` compact them once synthesized?
- **Delivery order.** Should `/retro` and `/agent-metrics` ship first as read-only
  capability, with `/improve` gated behind evidence that the metrics are trustworthy?

## Rejection

Rejected 2026-07-28, after a 12-agent design workflow resolved the open questions above,
produced a synthesized design, and then refuted it under three independent adversarial
lenses. All three refuted. The reasoning is recorded here because the proposal is sound
in its motivation — performance data really is discarded today — and a future attempt
should start from these objections rather than rediscover them.

### The three objections

**1. The safety mechanism reproduces the failure it is meant to prevent.**

The design's spine was a per-claim falsifier: an executable test asserting each memory
item, so a claim that stops being true fails CI. But a falsifier is authored by the same
agent, in the same session, from the same evidence, as the claim it asserts.

That is precisely the blind spot that cost this repository #40 — where twelve passing
tests hid a live defect because the test mutated state the same way the check inspected
it. The lesson is already in `impl-worker` memory. The design would have rebuilt it as a
safety feature and put a green CI check on top.

**2. It targets a hazard with zero observed instances, and misses the one that occurred.**

Across the 15 items in the live corpus, the count of "memory contained a false claim" is
zero. The failure that actually happened (#39 → #41) was not a false belief: the contract
check asked _"does the writing plugin reference this literal anywhere?"_ — a **true**
predicate, correctly implemented, answering the wrong question. Every memory item could
have been individually true and that defect still ships. The falsification ledger would
have been green throughout.

**3. The human gate binds on the commit; belief propagated from the working tree.**

This one was verified against the code and was **real** — an uncommitted memory edit was
injected into the very next spawn, so "an agent proposes, a human decides" was true of
distribution and false of effect. Fixed in #44, independently of this proposal.

### What was kept

The workflow's genuine output was not a design. It was four verified defects in shipped
code, all fixed in #44: injection reading the working tree, `--check` never validating
`global.md`, the context budget measuring 45% of the real payload, and `global.md` writes
drawing only a generic advisory.

One reviewer claim did not survive checking — that the metric reconstruction
`prior_ok = ct * cr` "compounds every session". Measured drift is 0.0014 and bounded.

### What a future attempt would need

Not a better synthesis engine. A **trustworthy fitness signal**, which this repository
does not yet have — `success_rate` scored the defect-shipping run 1.00, and
`defects_shipped` / `followup_prs` were added to retrospective frontmatter as a starting
point, not a solution.

Until a signal exists that distinguishes a run that shipped a latent defect from one that
did not, an improvement loop optimising against the available metrics would learn most
confidently from the runs it understands least. The read-only half — `/agent-metrics` and
richer retrospectives — remains worth building and needs no new proposal to justify it.

This rejection is reversible. A later proposal may supersede it once the signal problem
is addressed.
