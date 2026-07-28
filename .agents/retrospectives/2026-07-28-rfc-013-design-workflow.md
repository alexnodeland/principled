---
date: 2026-07-28
proposal: "013"
agent: orchestrator
mode: workflow
agents_total: 12
agents_completed: 10
agents_errored: 2
outcome: proposal-rejected
defects_found_in_shipped_code: 4
defects_claimed_but_unverified: 1
---

# Retrospective — the RFC-013 design workflow

A 12-agent workflow run to resolve RFC-013's open questions and design the
self-improvement loop: five agents on the open questions, three independent designs, one
judge, three adversarial reviewers.

## Outcome

RFC-013 was **rejected**. All three adversarial lenses refuted the synthesized design.

The workflow's real output was not a design — it was **four verified defects in already
merged code**, fixed in #44. The most serious: injection read the working tree, so an
uncommitted memory edit reached the very next spawn. ADR-022's review guarantee was true
of how memory is distributed and false of when it takes effect.

## What failed, mechanically

**Two of three designs died on the structured-output retry cap.** `DESIGN_SCHEMA` had six
required fields, several demanding long prose. Both failures were in the same `parallel()`
call, so the Designs phase returned one result instead of three.

The consequence is worse than losing two agents: **the judge phase compared one surviving
design against nothing.** It still produced a confident synthesis naming a winner, because
nothing in the script told it the panel had collapsed — `validDesigns.filter(Boolean)`
silently returned an array of one, and the prompt said "three independent designs are
below."

The adversarial phase then refuted a design that had never been scored against
alternatives. The refutations were substantive and independently verified, so the verdict
stands — but the comparison the panel existed to provide never happened.

## Lessons

- A judge panel is only as strong as the number of designs that survive. Check
  `agents_error` and the length of the input array before trusting a synthesis that claims
  to have compared alternatives.
- An over-constrained output schema is a silent failure mode in a fan-out: it does not
  degrade the result, it deletes the agent. Six required fields with long prose values is
  too many.
- A prompt that asserts its own inputs ("three designs are below") will be believed by the
  agent reading it. Interpolate the actual count.

Deliberately **not** promoted to agent memory. These are facts about authoring workflows,
which only the orchestrating session acts on — not durable knowledge about this codebase
that an `impl-worker` spawn needs in context. ADR-020's distinction: a retrospective is a
dated record of one run; memory is undated knowledge asserted as currently true.

## Cost

938k subagent tokens, 220 tool uses, ~25 minutes wall clock, 10 of 12 agents completing.

Whether that was worth it depends on the counterfactual. It did not produce a usable
design. It did find four real defects in shipped code — including one that made a
governance guarantee in an accepted ADR false — and it produced a well-argued rejection
that a future attempt can start from rather than rediscover.
