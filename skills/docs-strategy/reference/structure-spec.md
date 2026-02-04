# Documentation Structure Specification

This document defines the required directories and files for each module type.

## Core Structure (All Module Types)

Every module, regardless of type, must contain:

### Directories

| Directory | Purpose |
|---|---|
| `docs/proposals/` | RFC proposals with lifecycle management |
| `docs/plans/` | DDD implementation plans bridging proposals and decisions |
| `docs/decisions/` | Architectural Decision Records (immutable post-acceptance) |
| `docs/architecture/` | Living documentation of current design |

### Files

| File | Purpose |
|---|---|
| `README.md` | Module front door — purpose, ownership, quick start, links |
| `CONTRIBUTING.md` | Module-specific build, test, lint, and PR conventions |
| `CLAUDE.md` | Module-scoped AI development context |

## Lib Extensions

In addition to the core structure, `lib` modules must contain:

| Component | Purpose |
|---|---|
| `docs/examples/` | Worked usage examples organized by use case |
| `INTERFACE.md` | Public API surface, stability guarantees, key invariants |

## App Extensions

In addition to the core structure, `app` modules must contain:

| Component | Purpose |
|---|---|
| `docs/runbooks/` | Operational procedures (one per incident type) |
| `docs/integration/` | External dependency documentation |
| `docs/config/` | Environment and configuration surface docs |

## Root-Level Structure

Cross-cutting proposals, plans, and decisions that affect multiple modules live in a root-level docs structure:

| Directory | Purpose |
|---|---|
| `docs/proposals/` | Cross-cutting RFCs |
| `docs/plans/` | Cross-cutting implementation plans |
| `docs/decisions/` | Cross-cutting ADRs |
| `docs/architecture/` | System-wide architecture docs |

The root structure follows identical conventions to module-level structure — same naming, same templates, same lifecycle rules. The only difference is scope: root-level documents affect the system, module-level documents affect the module.

## Validation Rules

- **Directories** are checked for existence only. An empty directory is valid (it signals intentional structure).
- **Files** are checked for existence. A file that contains only TODO placeholders is reported as `placeholder` but is not a failure unless `--strict` mode is enabled.
- The `--strict` flag promotes placeholder-only files to warnings/failures.
