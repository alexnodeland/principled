# Pipeline Overview: Proposals → Decisions → Plans

## The Three-Stage Documentation Pipeline

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│      PROPOSAL        │     │      DECISION        │     │        PLAN          │
│       (RFC)          │     │       (ADR)          │     │   (DDD Breakdown)    │
│                      │     │                      │     │                      │
│  "what and why"      │────▶│  "what was decided"  │────▶│  "how, decomposed"   │
│                      │     │                      │     │                      │
│  Strategic intent    │     │  Permanent record    │     │  Tactical breakdown   │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
        │                           │                           │
        ▼                           ▼                           ▼
   docs/proposals/             docs/decisions/             docs/plans/
   NNN-title.md                NNN-title.md                NNN-title.md
```

## Lifecycle Flow

```
  PROPOSAL                    DECISION                    PLAN
  ────────                    ────────                    ────

  ┌───────┐                 ┌──────────┐               ┌────────┐
  │ draft │                 │ proposed │               │ active │
  └───┬───┘                 └────┬─────┘               └───┬────┘
      │                          │                         │
      ▼                          ▼                         ├──▶ complete
  ┌───────────┐             ┌──────────┐                   │
  │ in-review │             │ accepted │                   └──▶ abandoned
  └───┬───────┘             └────┬─────┘
      │                          │
      ├──▶ accepted ── triggers ──▶ ADR creation
      │                          ├──▶ deprecated
      ├──▶ rejected              │
      │                          └──▶ superseded
      └──▶ superseded
```

## Data Flow Between Stages

```
Proposal (accepted)
    │
    ├── originating_proposal: NNN
    │   (frontmatter field linking ADR back to proposal)
    │
    ▼
Decision (ADR, accepted)
    │
    ├── originating_adr: NNN
    │   (frontmatter field linking plan back to ADR)
    │
    ▼
Plan (active)
    │
    ├── Bounded contexts, aggregates, domain events
    ├── Implementation tasks with checkboxes
    │
    │   During implementation:
    │   └── Task complete? ──▶ Check off in plan
    │
    ▼
Architecture Doc (living)
    │
    ├── related_adrs: [NNN, ...]
    └── Updated as design evolves
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
  │ ADRs             │             │ ADRs             │
  │ (proposed)       │             │ (accepted*)      │
  │                  │             │                  │
  ├──────────────────┤             ├──────────────────┤
  │ Plans            │             │ Plans            │
  │ (active)         │             │ (complete,       │
  │                  │             │  abandoned)      │
  └──────────────────┘             └──────────────────┘

  * Exception: superseded_by field may be updated on accepted ADRs
```

## Scope: Module vs. Root

```
repo-root/
├── docs/                    ◄── Root-level (cross-cutting)
│   ├── proposals/               Scope: affects entire system
│   ├── decisions/
│   ├── plans/
│   └── architecture/
│
├── packages/
│   ├── module-a/
│   │   └── docs/            ◄── Module-level
│   │       ├── proposals/       Scope: affects this module only
│   │       ├── decisions/
│   │       ├── plans/
│   │       └── architecture/
│   │
│   └── module-b/
│       └── docs/            ◄── Module-level
│           └── ...              Independent sequences
```

Both levels use identical conventions, templates, and lifecycle rules. The only difference is scope.
