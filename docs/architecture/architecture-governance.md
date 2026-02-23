---
title: "Architecture Governance"
last_updated: 2026-02-22
related_adrs: [003, 014]
---

# Architecture Governance

## Purpose

Describes the architecture of the principled-architecture plugin: how it maps code to architectural decisions, detects drift between documented design and implementation, audits decision coverage, and keeps architecture documents synchronized. Intended for contributors who need to understand the governance feedback loop, and for architects evaluating how the principled methodology enforces design decisions at the code level.

## Overview

The architecture governance system creates a feedback loop from ADRs and architecture documents back to the codebase. It answers the question: "Does the code match what the architecture says it should be?"

```
┌───────────────────────────────────────────────────────────────┐
│                 GOVERNANCE FEEDBACK LOOP                       │
│                                                               │
│  ADRs ──────────┐                                             │
│  (decisions)     │     /arch-map                              │
│                  ├────▶ (link) ────▶ Architecture Map          │
│  Architecture    │         │                                  │
│  Docs ──────────┘          │                                  │
│  (living design)           ▼                                  │
│                      /arch-drift                              │
│                       (detect) ────▶ Violation Report          │
│                            │                                  │
│                            ▼                                  │
│  Codebase ───────── /arch-audit                               │
│  (modules)          (coverage) ──▶ Coverage Gaps              │
│                            │                                  │
│                            ▼                                  │
│                      /arch-sync                               │
│                       (update) ──▶ Updated Architecture Docs  │
│                                    (feedback to top)          │
└───────────────────────────────────────────────────────────────┘
```

## Key Abstractions

### Architecture Map

The **architecture map** is the foundational data structure. It links every module in the codebase to the ADRs and architecture documents that govern it.

Construction:

1. Discover modules by scanning for `CLAUDE.md` files (per ADR-003)
2. For each module, determine its type (`core`, `lib`, `app`) from the `## Module Type` section
3. For each ADR, parse content for module references, path mentions, and explicit scope
4. For each architecture doc, parse content for module references
5. Cross-reference to produce the map

The map answers queries like:

- "Which ADRs govern module X?"
- "Which modules are covered by ADR-007?"
- "Which modules have no architectural governance?"

### Module Dependency Direction

Modules have a type hierarchy that constrains allowed dependencies:

```
      ┌─────┐
      │ app │ ── can depend on ──▶ lib, core
      └─────┘
         │
         ▼
      ┌─────┐
      │ lib │ ── can depend on ──▶ core
      └─────┘
         │
         ▼
      ┌──────┐
      │ core │ ── no internal module dependencies
      └──────┘
```

| Module Type | Can Depend On     | Cannot Depend On                     |
| ----------- | ----------------- | ------------------------------------ |
| `app`       | `lib`, `core`     | other `app`                          |
| `lib`       | `core`            | `app`, other `lib` (unless declared) |
| `core`      | _(none internal)_ | `app`, `lib`                         |

Teams can override defaults by declaring explicit allowances in their module's `CLAUDE.md`.

### Architectural Drift

**Drift** is the divergence between documented design (ADRs + architecture docs) and actual implementation. Drift manifests as:

- **Boundary violations** — Imports across module boundaries where the architecture prescribes events or interfaces
- **Direction violations** — Dependencies flowing the wrong way (e.g., `core` importing from `app`)
- **Pattern violations** — Code patterns contradicting ADR decisions (e.g., synchronous calls where the ADR mandates async)
- **Technology violations** — Use of libraries or approaches explicitly rejected in an ADR

### Coverage

**Coverage** measures how much of the codebase is governed by explicit architectural decisions. A module has:

- **Full coverage** — At least one governing ADR and mention in an architecture doc
- **Partial coverage** — Either ADRs or architecture doc references, but not both
- **No coverage** — No ADRs, no architecture doc mentions. Architecture is implicit.

## Component Relationships

```
              /arch-map ◄──── scan-modules.sh
                  │                │
     builds the architecture      discovers CLAUDE.md
     map (modules ↔ ADRs ↔        declarations,
     architecture docs)            reads module types
                  │
          ┌───────┴────────┐
          ▼                ▼
     /arch-drift      /arch-audit
          │                │
     detects code     identifies gaps:
     violations        modules without
     against ADRs      governance, stale
          │            ADRs, orphaned docs
          │                │
          └───────┬────────┘
                  ▼
            /arch-sync ◄──── detect-changes.sh
                  │                │
     proposes updates to      compares documented
     architecture docs         state vs. codebase
     based on drift and
     audit findings
                  │
                  ▼
            /arch-query
                  │
     answers natural-language
     questions about architecture
     by cross-referencing the
     map, ADRs, and code
```

## Data Flow

### Architecture Map Construction

```
Find all CLAUDE.md files in repo
       │
       ▼
For each CLAUDE.md:
  ├── Parse ## Module Type section ──▶ {path, type}
  └── Record module entry
       │
       ▼
For each ADR in docs/decisions/:
  ├── Parse frontmatter (status, title)
  ├── Scan body for module path references
  ├── Scan body for explicit scope declarations
  └── Record ADR-to-module mappings
       │
       ▼
For each doc in docs/architecture/:
  ├── Parse frontmatter (related_adrs)
  ├── Scan body for module path references
  └── Record doc-to-module mappings
       │
       ▼
Cross-reference to produce:
  Module → [governing ADRs, architecture docs]
  ADR → [governed modules]
  Coverage classification per module
```

### Drift Detection Flow

```
Load architecture map
       │
       ▼
For each accepted ADR:
  Extract architectural constraints:
  ├── Dependency rules (what can import what)
  ├── Pattern requirements (async, events, interfaces)
  └── Technology constraints (use X, avoid Y)
       │
       ▼
For each governed module:
  Scan source files for:
  ├── import/require statements ──▶ check direction rules
  ├── Pattern indicators ──▶ check against ADR constraints
  └── Technology markers ──▶ check against ADR rejections
       │
       ▼
Classify findings:
  ├── Error: clear boundary/direction violation
  ├── Warning: possible pattern/technology drift
  └── Info: stale ADR reference (module changed)
       │
       ▼
Output: Violation report with ADR references
  (--strict mode: any error = nonzero exit)
```

### Boundary Violation Hook Flow

```
PostToolUse (Write) fires
       │
       ▼
Read written file path from stdin JSON
       │
       ▼
Determine if file is in a module directory
  (check for CLAUDE.md in parent hierarchy)
       │
       ├── Not in module ──▶ exit 0 (no check)
       │
       └── In module ──▶ read module type
              │
              ▼
       Scan written file for imports
              │
              ▼
       Check import paths against
       dependency direction rules
              │
              ├── No violations ──▶ exit 0
              └── Violation found ──▶ stderr warning, exit 0
                                     (advisory only)
```

## Key Decisions

- [ADR-014: Heuristic Architecture Governance](../decisions/014-heuristic-architecture-governance.md) — Architecture governance uses file-level heuristic analysis rather than AST-level static analysis, preserving language-agnostic design.
- [ADR-003: Module Type Declaration via CLAUDE.md](../decisions/003-module-type-storage.md) — Module types are declared in `CLAUDE.md`, providing the foundation for dependency direction rules.

## Constraints and Invariants

1. **Language-agnostic analysis.** All checks operate at the file and import-path level. No language-specific parsers are built into the plugin. Language-specific tools are complementary, not replaced.
2. **Advisory by default.** The boundary violation hook and default `/arch-drift` mode report warnings, never block. Teams opt into strict enforcement explicitly.
3. **Architecture docs are living documents.** `/arch-sync` proposes updates for human review. Architecture documents are never auto-modified — they require approval because they represent design intent, not just current state.
4. **The map is derived, not persisted.** The architecture map is computed on demand from `CLAUDE.md` declarations, ADRs, and architecture docs. No separate configuration file defines the code-to-ADR mapping.
5. **Coverage gaps are visible.** Modules without governance are surfaced in audit reports rather than silently ignored. Explicit coverage is preferred over implicit "everything is fine."
6. **Override via declaration.** Default dependency direction rules can be overridden in a module's `CLAUDE.md`. The governance system reads these declarations and adjusts its checks accordingly.
