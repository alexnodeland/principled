# DDD Decomposition Guide for Implementation Plans

A practical, step-by-step guide for creating DDD-based implementation plans.

## Step 1: Read the Originating Proposal

Before decomposing, understand:
- What problem does the proposal solve?
- What is the proposed solution's scope?
- What systems, components, or modules are affected?

## Step 2: Identify Bounded Contexts

Ask these questions about the proposal's scope:

1. **What are the distinct areas of responsibility?**
   - List every area that must do something different.
   - If two areas serve different audiences, they are likely separate contexts.

2. **Where are the boundaries?**
   - A bounded context has a clear interface with the outside world.
   - Within the context, terms are unambiguous.

3. **Name each context** with a descriptive phrase that communicates responsibility, not implementation detail.

**Format for the plan:**

```markdown
| # | Bounded Context | Responsibility | Key Artifacts |
|---|---|---|---|
| BC-1 | **Context Name** | What this context is responsible for | Files/modules it produces |
```

## Step 3: Define Aggregates per Context

For each bounded context:

1. **What are the primary artifacts or objects?** Each is a candidate aggregate.
2. **What is the root entity?** The thing that controls access to the aggregate.
3. **What must change together?** That defines the aggregate's consistency boundary.

**Format for the plan:**

```markdown
#### BC-N: Context Name

| Aggregate | Root Entity | Description |
|---|---|---|
| **AggregateName** | `root-file-or-dir` | What this aggregate represents |
```

## Step 4: Map Domain Events

Domain events connect bounded contexts:

1. **What does context A produce that context B needs?**
2. **What state transitions trigger work in other contexts?**
3. **Name events in past tense** (something that happened).

**Format for the plan:**

```markdown
| Event | Source Context | Target Context(s) | Description |
|---|---|---|---|
| **EventName** | BC-N | BC-M, BC-P | What happened and what it enables |
```

## Step 5: Derive Implementation Tasks

Now turn the domain analysis into concrete work:

1. **For each aggregate:** What must be created, implemented, or configured?
2. **Order by events:** If Task B depends on an event from Task A, Task A must come first.
3. **Group into phases:** Independent tasks in the same phase can run in parallel.

**Format for the plan:**

```markdown
### Phase N: Phase Name (BC-X, BC-Y)

**Goal:** What this phase accomplishes.

**Depends on:** Previous phases (if any).

- [ ] **N.1** Concrete, specific task description
- [ ] **N.2** Another concrete task
```

### Task Quality Checklist

Each task should be:
- [ ] **Specific:** Names exact files, flags, behaviors
- [ ] **Verifiable:** Someone can check if it's done
- [ ] **Scoped:** Maps to one or more aggregates
- [ ] **Ordered:** Dependencies are explicit

## Step 6: Identify Decisions Required

During decomposition, you will encounter choices that need architectural decisions. List them:

```markdown
## Decisions Required

1. **Decision title.** Context about what needs to be decided and why.
```

Each of these should become an ADR during implementation.

## Step 7: Define Acceptance Criteria

How do you know the plan is complete?

- List observable, testable outcomes.
- Each criterion should be verifiable without subjective judgment.
- Cover the full scope of the plan, not just happy paths.

## Common Pitfalls

| Pitfall | Fix |
|---|---|
| Too few contexts (everything in one) | If a context has more than 5-6 aggregates, split it |
| Too many contexts (one per file) | Merge contexts that always change together |
| Tasks too vague ("implement X") | Name specific files, flags, and behaviors |
| Missing dependencies between phases | Trace domain events — if phase 2 needs output from phase 1, say so |
| No acceptance criteria | Every plan must define how "done" is measured |
