# Domain-Driven Development for Implementation Plans

This reference explains how to apply domain-driven development (DDD) concepts when creating implementation plans. Plans decompose accepted proposals into bounded contexts, aggregates, domain events, and concrete implementation tasks.

## Why DDD for Plans?

Arbitrary task lists lead to scattered work, unclear boundaries, and missed dependencies. DDD decomposition forces explicit thinking about:

- **What are the distinct areas of responsibility?** (bounded contexts)
- **What are the core objects and their boundaries?** (aggregates)
- **How do areas communicate?** (domain events)
- **What concrete work derives from this analysis?** (tasks)

## Bounded Contexts

A bounded context is a distinct area of domain responsibility with a clear boundary. Within a bounded context, terms have precise, unambiguous meanings. Different contexts may use the same word to mean different things.

### How to Identify Bounded Contexts

1. **Look for distinct responsibilities.** If two areas of the system do fundamentally different things, they belong in separate contexts.
2. **Look for different audiences.** If different people care about different parts of the work, those parts likely belong in separate contexts.
3. **Look for independent change.** If one area can change without affecting another, they are separate contexts.
4. **Look for distinct data ownership.** If different parts of the system own different data, they are separate contexts.

### Naming Bounded Contexts

Use clear, descriptive names that communicate the responsibility:

- "Template Management" (not "Templates")
- "Lifecycle Enforcement" (not "Hooks")
- "Authoring Workflows" (not "Skills")

## Aggregates

An aggregate is a cluster of domain objects treated as a single unit for the purpose of data changes. Each aggregate has a root entity that controls access to the aggregate's internals.

### How to Define Aggregates

1. **Identify the root entity.** What is the primary artifact that this cluster revolves around?
2. **Draw the consistency boundary.** What must change together atomically?
3. **Keep aggregates small.** If an aggregate grows too large, it may contain multiple distinct responsibilities.

### Example

In a documentation plugin:
- **Aggregate:** CanonicalTemplateSet
- **Root entity:** `scaffold/templates/` directory
- **Boundary:** All 12 canonical templates. They are versioned together, validated together, and serve as the source of truth together.

## Domain Events

Domain events represent things that happen in the system that other parts care about. They describe state transitions and trigger cross-context communication.

### How to Identify Domain Events

1. **When does context A's work enable context B's work?** That transition is a domain event.
2. **What state changes matter to multiple contexts?** Each is a domain event.
3. **Look for "when X happens, then Y"** patterns — the X is an event.

### Naming Domain Events

Use past tense to indicate something that has occurred:

- `CanonicalTemplatesWritten`
- `ProposalAccepted`
- `ValidationEngineReady`

## Task Decomposition

Once you have bounded contexts, aggregates, and domain events, derive concrete implementation tasks:

### Process

1. **For each bounded context:** list the aggregates it contains.
2. **For each aggregate:** define what must be built or changed.
3. **Order by domain events:** tasks that produce events must complete before tasks that consume those events.
4. **Group into phases:** tasks within the same context that have no cross-context dependencies can run in parallel.

### Task Granularity

A task should be:
- **Concrete:** "Write `validate-structure.sh` with `--module-path`, `--type`, `--strict`, `--json` flags" (not "implement validation")
- **Completable:** One person can verify it's done
- **Mappable:** It maps to one or more aggregates in one or more bounded contexts

## Putting It Together

A well-decomposed plan follows this structure:

```
1. Domain Analysis
   ├── Bounded Contexts (what are the areas?)
   ├── Aggregates (what are the key objects per area?)
   └── Domain Events (how do areas communicate?)

2. Implementation Tasks (derived from analysis)
   ├── Phase 1 (foundational, no dependencies)
   ├── Phase 2 (depends on Phase 1 events)
   ├── Phase 3 (depends on Phase 2 events)
   └── ...

3. Cross-cutting Concerns
   ├── Decisions Required (what ADRs are needed?)
   ├── Dependencies (what external things are needed?)
   └── Acceptance Criteria (how do we know we're done?)
```
