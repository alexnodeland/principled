# Component Guide

Purpose, audience, and content expectations for every documentation component.

## Proposals (`docs/proposals/`)

| Property | Value |
|---|---|
| **Nature** | RFC proposals |
| **Audience** | Maintainers, reviewers |
| **Mutability** | Mutable while `draft` or `in-review`; frozen on terminal status (`accepted`, `rejected`, `superseded`) |
| **Naming** | `NNN-short-title.md` |

**Content expectations:** A proposal describes *what* is being proposed and *why*. It should articulate the problem, the proposed solution, alternatives considered, consequences, and architecture impact. Proposals are the entry point to the documentation pipeline.

## Plans (`docs/plans/`)

| Property | Value |
|---|---|
| **Nature** | DDD implementation plans |
| **Audience** | Implementers, maintainers |
| **Mutability** | Mutable during implementation (`active`); marked `complete` or `abandoned` when done |
| **Naming** | `NNN-short-title.md` (number matches originating proposal) |

**Content expectations:** A plan bridges an accepted proposal and its resulting decisions. It decomposes the work using domain-driven development: bounded contexts, aggregates, domain events, and concrete implementation tasks. Plans are tactical — they answer *how*, decomposed.

## Decisions (`docs/decisions/`)

| Property | Value |
|---|---|
| **Nature** | Architectural Decision Records (ADRs) |
| **Audience** | Future maintainers |
| **Mutability** | **Immutable** after acceptance. One exception: the `superseded_by` field may be updated when a new ADR supersedes this one. |
| **Naming** | `NNN-short-title.md` (matches originating proposal where applicable) |

**Content expectations:** A decision records *what was decided*, the options considered, the consequences expected, and references to the originating proposal and related documents. ADRs are the permanent record of the project's architectural choices.

## Architecture (`docs/architecture/`)

| Property | Value |
|---|---|
| **Nature** | Living design documentation |
| **Audience** | Onboarding engineers |
| **Mutability** | Updated as design evolves |
| **Naming** | Freeform descriptive names |

**Content expectations:** Architecture docs describe the current state of the system's design. They reference the ADRs that produced the design. They cover key abstractions, component relationships, data flow, and constraints.

## README.md

| Property | Value |
|---|---|
| **Nature** | Module orientation |
| **Audience** | Everyone |
| **Mutability** | Updated as module evolves |
| **Naming** | Fixed name: `README.md` |

**Content expectations:** The module's front door. States the module's purpose, ownership, quick start instructions, and links to all other documentation.

## CONTRIBUTING.md

| Property | Value |
|---|---|
| **Nature** | Development conventions |
| **Audience** | Contributors |
| **Mutability** | Updated as tooling changes |
| **Naming** | Fixed name: `CONTRIBUTING.md` |

**Content expectations:** Module-specific build, test, lint commands, and pull request conventions.

## CLAUDE.md

| Property | Value |
|---|---|
| **Nature** | AI development context |
| **Audience** | Claude Code |
| **Mutability** | Updated as patterns evolve |
| **Naming** | Fixed name: `CLAUDE.md` |

**Content expectations:** Module type declaration, key conventions, documentation structure summary, pipeline overview, important constraints, testing and dependency information.

## INTERFACE.md (lib only)

| Property | Value |
|---|---|
| **Nature** | Public API contract |
| **Audience** | Consumers of the library |
| **Mutability** | Updated as API evolves |
| **Naming** | Fixed name: `INTERFACE.md` |

**Content expectations:** Public API surface (if it's not listed, it's internal), stability guarantees, key invariants, deprecation policy.

## Runbooks (`docs/runbooks/`, app only)

| Property | Value |
|---|---|
| **Nature** | Operational procedures |
| **Audience** | On-call engineers |
| **Naming** | One file per incident type |

**Content expectations:** Symptoms, diagnosis steps, remediation, escalation path, prevention measures.

## Integration Docs (`docs/integration/`, app only)

| Property | Value |
|---|---|
| **Nature** | External dependency documentation |
| **Audience** | Engineers working on integrations |
| **Naming** | One file per external dependency |

**Content expectations:** Connection details, failure modes, retry behavior, health checks.

## Configuration Docs (`docs/config/`, app only)

| Property | Value |
|---|---|
| **Nature** | Environment and configuration surface |
| **Audience** | DevOps, deployment engineers |
| **Naming** | Descriptive names |

**Content expectations:** Environment variables, feature flags, secrets (names only, never values), environment-specific differences.
