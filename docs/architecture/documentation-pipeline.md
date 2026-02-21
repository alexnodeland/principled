---
title: "Documentation Pipeline"
last_updated: 2026-02-04
related_adrs: [002, 003]
---

# Documentation Pipeline

## Purpose

Describes the three-stage documentation pipeline (Proposals → Decisions → Plans) that governs how changes flow from strategic intent through architectural decisions to tactical implementation. Intended for anyone working with the documentation system — authors, reviewers, and maintainers.

## Overview

Every significant change follows a three-stage pipeline:

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│  PROPOSAL    │       │  DECISION    │       │    PLAN      │
│   (RFC)      │──────▶│   (ADR)      │──────▶│   (DDD)      │
│              │       │              │       │              │
│ "what & why" │       │ "what was    │       │ "how"        │
│              │       │  decided"    │       │              │
└─────────────┘       └─────────────┘       └─────────────┘
  Strategic             Permanent              Tactical
  docs/proposals/       docs/decisions/        docs/plans/
```

Each stage has distinct characteristics:

| Property       | Proposal               | Decision                   | Plan                               |
| -------------- | ---------------------- | -------------------------- | ---------------------------------- |
| **Focus**      | What and why           | What was decided           | How, decomposed                    |
| **Method**     | RFC                    | ADR                        | DDD (bounded contexts, aggregates) |
| **Audience**   | Maintainers, reviewers | Future maintainers         | Implementers                       |
| **Mutability** | Mutable until terminal | Immutable after acceptance | Mutable while active               |

## Key Abstractions

### Proposals (RFCs)

Proposals are the entry point. They articulate a problem, propose a solution, consider alternatives, and assess consequences. They exist for team alignment before work begins.

**Lifecycle:**

```
draft ──→ in-review ──→ accepted
                    ──→ rejected
                    ──→ superseded
```

- Mutable in `draft` and `in-review`
- Frozen in terminal states (`accepted`, `rejected`, `superseded`)
- Acceptance triggers decision (ADR) creation

### Decisions (ADRs)

Decisions are the permanent record. They capture what was decided, what options were considered, and what consequences are expected. They are immutable after acceptance. Decisions bridge the gap between strategic intent (proposal) and tactical implementation (plan).

**Lifecycle:**

```
proposed ──→ accepted ──→ deprecated
                      ──→ superseded
```

- Immutable after acceptance (one exception: `superseded_by` field)
- May be standalone or linked to a proposal via `originating_proposal`
- Acceptance enables plan creation
- Referenced by architecture docs

### Plans (DDD Decompositions)

Plans decompose accepted decisions into concrete implementation work. They use domain-driven development to break down work into bounded contexts, aggregates, domain events, and implementation tasks.

**Lifecycle:**

```
active ──→ complete
       ──→ abandoned
```

- Always linked to an accepted proposal via `originating_proposal`
- References related ADRs via `related_adrs` field
- Mutable while `active`
- Provide the tactical roadmap informed by the decisions made in ADRs

### Architecture Docs (Living)

Architecture docs describe the current design. They reference the ADRs that produced the design. Unlike the pipeline documents, architecture docs have no lifecycle — they are living documents updated as the system evolves.

## Component Relationships

### Pipeline Data Flow

```
Proposal (accepted)
    │
    │  originating_proposal: NNN
    ├──────────────────────────────────┐
    │                                  │
    ▼                                  ▼
Decision (ADR, accepted)          Plan (active → complete)
    │                                  │
    │  Permanent record                │  originating_proposal: NNN
    │                                  │  related_adrs: [NNN, ...]
    │                                  │
    │                                  │  During implementation:
    │                                  │  └── Task complete? → Check off
    │
    ▼
Architecture Doc (living)
    │
    │  related_adrs: [NNN, ...]
    │  Updated as design evolves
```

### Cross-Referencing

| Document         | Links To                        | Via                                                  |
| ---------------- | ------------------------------- | ---------------------------------------------------- |
| ADR              | Originating proposal (optional) | `originating_proposal` frontmatter                   |
| ADR              | Superseded ADR                  | `superseded_by` on old ADR                           |
| Plan             | Originating proposal            | `originating_proposal` frontmatter + markdown link   |
| Plan             | Related ADRs                    | `related_adrs` frontmatter + "Related Decisions"     |
| Architecture doc | Related ADRs                    | `related_adrs` frontmatter + "Key Decisions" section |
| Proposal         | Superseding proposal            | `superseded_by` frontmatter                          |

### Scope: Module vs. Root

The pipeline operates at two scopes:

| Scope            | Location                                                  | Affects                       |
| ---------------- | --------------------------------------------------------- | ----------------------------- |
| **Module-level** | `<module>/docs/{proposals,plans,decisions,architecture}/` | Single module                 |
| **Root-level**   | `docs/{proposals,plans,decisions,architecture}/`          | Entire system (cross-cutting) |

Both scopes use identical conventions, templates, lifecycle rules, and naming patterns. The only difference is the breadth of impact.

## Data Flow

### Complete Pipeline Example

```
1. Author creates proposal
   → docs/proposals/001-switch-to-event-sourcing.md (status: draft)

2. Author completes proposal, submits for review
   → /proposal-status 001 in-review

3. Reviewers approve
   → /proposal-status 001 accepted
   → System prompts: "Create an ADR?"

4. Author creates ADR for the key decision
   → docs/decisions/001-use-kafka-for-event-store.md (status: proposed → accepted)

5. Author creates DDD plan from the accepted ADR
   → docs/plans/001-switch-to-event-sourcing.md (status: active)
   → Bounded contexts, aggregates, domain events defined
   → Implementation tasks listed

6. Plan completed
   → Plan status: complete
   → All tasks checked off

7. Architecture doc created/updated
   → docs/architecture/event-sourcing-design.md
   → References ADR-001
```

### Numbering

Each directory (`proposals/`, `plans/`, `decisions/`) maintains an independent `NNN` sequence within its scope:

- Module A proposals: 001, 002, 003...
- Module A decisions: 001, 002, 003...
- Root proposals: 001, 002, 003...

Numbers are never reused. Gaps are not backfilled.

## Key Decisions

- [ADR-002: Claude-Mediated Template Placeholder Replacement](../decisions/002-template-placeholder-syntax.md) — Pipeline documents are created from templates with Claude handling placeholder substitution.
- [ADR-003: Module Type Declaration via CLAUDE.md](../decisions/003-module-type-storage.md) — Module type (which determines required structure) is stored in `CLAUDE.md`.

## Constraints and Invariants

1. **Proposals cannot skip states.** `draft → in-review` is required before any terminal transition.
2. **Terminal documents are frozen.** No edits to accepted/rejected/superseded proposals or accepted ADRs.
3. **The `superseded_by` exception is the only mutation allowed on an accepted ADR.**
4. **Plans require an accepted proposal.** No plan can be created without `--from-proposal` pointing to an accepted proposal. Plans also reference related ADRs created from that proposal.
5. **Architecture docs reference ADRs.** They are living documents that reflect decisions, not independent from them.
6. **Independent numbering per scope.** Module-level and root-level sequences are independent. Proposal, plan, and decision sequences within the same scope are also independent.
