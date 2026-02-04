# Pipeline Overview: Proposals → Plans → Decisions

## The Three-Stage Documentation Pipeline

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│      PROPOSAL        │     │        PLAN          │     │      DECISION        │
│       (RFC)          │     │   (DDD Breakdown)    │     │       (ADR)          │
│                      │     │                      │     │                      │
│  "what and why"      │────▶│  "how, decomposed"   │────▶│  "what was decided"  │
│                      │     │                      │     │                      │
│  Strategic intent    │     │  Tactical breakdown   │     │  Permanent record    │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
        │                           │                           │
        ▼                           ▼                           ▼
   docs/proposals/             docs/plans/               docs/decisions/
   NNN-title.md                NNN-title.md              NNN-title.md
```

## Lifecycle Flow

```
  PROPOSAL                    PLAN                      DECISION
  ────────                    ────                      ────────

  ┌───────┐                 ┌────────┐                ┌──────────┐
  │ draft │                 │ active │                │ proposed │
  └───┬───┘                 └───┬────┘                └────┬─────┘
      │                         │                          │
      ▼                         ├──▶ complete              ▼
  ┌───────────┐                 │                     ┌──────────┐
  │ in-review │                 └──▶ abandoned        │ accepted │
  └───┬───────┘                                       └────┬─────┘
      │                                                    │
      ├──▶ accepted ─── triggers ──▶ Plan creation         ├──▶ deprecated
      │                                                    │
      ├──▶ rejected                                        └──▶ superseded
      │
      └──▶ superseded
```

## Data Flow Between Stages

```
Proposal (accepted)
    │
    ├── originating_proposal: NNN
    │   (frontmatter field linking plan back to proposal)
    │
    ▼
Plan (active)
    │
    ├── Bounded contexts, aggregates, domain events
    ├── Implementation tasks with checkboxes
    ├── Decisions required (each becomes an ADR)
    │
    │   During implementation:
    │   ├── Decision needed? ──▶ Create ADR
    │   └── Task complete? ──▶ Check off in plan
    │
    ▼
Decision (ADR)
    │
    ├── originating_proposal: NNN (if from proposal)
    ├── Immutable after acceptance
    └── superseded_by: NNN (only permitted mutation)
```

## Immutability Boundaries

```
  MUTABLE                          IMMUTABLE
  ───────                          ─────────
  ┌──────────────────┐             ┌──────────────────┐
  │ Proposals        │             │ Proposals        │
  │ (draft,          │             │ (accepted,       │
  │  in-review)      │             │  rejected,       │
  │                  │             │  superseded)     │
  ├──────────────────┤             ├──────────────────┤
  │ Plans            │             │ Plans            │
  │ (active)         │             │ (complete,       │
  │                  │             │  abandoned)      │
  ├──────────────────┤             ├──────────────────┤
  │ ADRs             │             │ ADRs             │
  │ (proposed)       │             │ (accepted*)      │
  │                  │             │                  │
  └──────────────────┘             └──────────────────┘

  * Exception: superseded_by field may be updated on accepted ADRs
```

## Scope: Module vs. Root

```
repo-root/
├── docs/                    ◄── Root-level (cross-cutting)
│   ├── proposals/               Scope: affects entire system
│   ├── plans/
│   ├── decisions/
│   └── architecture/
│
├── packages/
│   ├── module-a/
│   │   └── docs/            ◄── Module-level
│   │       ├── proposals/       Scope: affects this module only
│   │       ├── plans/
│   │       ├── decisions/
│   │       └── architecture/
│   │
│   └── module-b/
│       └── docs/            ◄── Module-level
│           └── ...              Independent sequences
```

Both levels use identical conventions, templates, and lifecycle rules. The only difference is scope.
