---
name: docs-strategy
description: >
  Module documentation strategy for the Principled framework.
  Consult when working with proposals/, plans/, decisions/, architecture/ directories,
  README, CONTRIBUTING, CLAUDE, or INTERFACE files in any module.
  Covers the proposals → plans → decisions pipeline, naming conventions,
  lifecycle rules, DDD decomposition, and audience definitions.
user-invocable: false
---

# Documentation Strategy — Background Knowledge

This skill provides Claude Code with comprehensive knowledge of the Principled documentation strategy. It is not directly invocable — it informs Claude's behavior when documentation-related context is encountered.

## When to Consult This Skill

Activate this knowledge when:

- Working with any file in `docs/proposals/`, `docs/plans/`, `docs/decisions/`, or `docs/architecture/`
- Creating, editing, or reviewing `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, or `INTERFACE.md`
- Discussing documentation structure, naming conventions, or lifecycle rules
- A user asks about the documentation pipeline or module documentation strategy
- Scaffolding a new module or validating an existing one

## Reference Documentation

Read these files for detailed guidance on specific topics:

### Structure and Components

- **`reference/structure-spec.md`** — Complete structural definition per module type: which directories and files are required for core, lib, and app modules, plus the root-level structure.
- **`reference/component-guide.md`** — Purpose, audience, and content expectations for every documentation component (proposals, plans, decisions, architecture docs, README, CONTRIBUTING, CLAUDE, INTERFACE, runbooks, integration docs, config docs).

### Naming and Numbering

- **`reference/naming-conventions.md`** — `NNN-short-title.md` patterns, slug rules (lowercase, hyphens, no special characters), zero-padding to 3 digits, sequence numbering rules, fixed-name files, directory naming.

### Lifecycles and Immutability

- **`reference/lifecycle-rules.md`** — Proposal state machine (`draft → in-review → accepted|rejected|superseded`), plan lifecycle (`active → complete|abandoned`), ADR immutability contract (immutable after acceptance, `superseded_by` exception), valid transitions, and terminal state rules.

### Domain-Driven Development

- **`reference/ddd-decomposition.md`** — How to apply DDD concepts when creating implementation plans: bounded contexts, aggregates, domain events, task decomposition, and practical examples.

### Pipeline Overview

- **`diagrams/pipeline-overview.md`** — Visual representation of the Proposals → Plans → Decisions pipeline, lifecycle flows, data flow between stages, immutability boundaries, and module vs. root scope.

## Key Principles

1. **Existence is enforced, content is organic.** Structure must be present. Placeholder TODOs are acceptable. Missing files are not.
2. **Living docs reference immutable records.** Architecture docs link to ADRs. ADRs are never modified after acceptance (except `superseded_by`).
3. **Docs have audiences.** Every file exists for a named reader in a named situation.
4. **Proposals have lifecycles.** Draft → In Review → Accepted/Rejected/Superseded.
5. **Plans use domain-driven decomposition.** Bounded contexts, aggregates, domain events, and concrete tasks.
