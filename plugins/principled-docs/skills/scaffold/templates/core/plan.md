---
title: "{{TITLE}}"
number: { { NUMBER } }
status: active
author: { { AUTHOR } }
created: { { DATE } }
updated: { { DATE } }
originating_proposal: { { PROPOSAL_NUMBER } }
---

# Plan-{{NUMBER}}: {{TITLE}}

## Objective

<!-- What does this plan accomplish? Link to the originating proposal. -->

Implements [RFC-{{PROPOSAL_NUMBER}}](../proposals/{{PROPOSAL_NUMBER}}-{{PROPOSAL_SLUG}}.md).

TODO

## Domain Analysis

### Bounded Contexts

<!-- What are the distinct areas of domain responsibility affected by this work? -->

TODO

### Aggregates

<!-- What are the core domain objects and their boundaries? -->

TODO

### Domain Events

<!-- What events flow between contexts? What state transitions matter? -->

TODO

## Implementation Tasks

<!-- Concrete, ordered tasks derived from the domain analysis. Each task should map to one or more bounded contexts. -->

### Phase 1: TODO

- [ ] TODO

### Phase 2: TODO

- [ ] TODO

## Decisions Required

<!-- What architectural decisions need to be made during implementation? Each should become an ADR. -->

TODO

## Dependencies

<!-- What must be in place before implementation can begin? -->

TODO

## Acceptance Criteria

<!-- How do we know this plan is complete? -->

TODO
