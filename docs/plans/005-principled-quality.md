---
title: "Principled Quality Plugin"
number: "005"
status: active
author: Alex
created: 2026-02-22
updated: 2026-02-22
originating_proposal: "003"
---

# Plan-005: Principled Quality Plugin

## Objective

Implements [RFC-003](../proposals/003-principled-quality-plugin.md).

Build the `principled-quality` Claude Code plugin end-to-end: plugin infrastructure, 5 skills (1 background + 4 user-invocable), 1 advisory hook, shared scripts with cross-plugin drift detection, reference documentation, templates, and a plugin README --- following the directory layout and conventions established in the marketplace.

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **5 bounded contexts**, each representing a distinct area of domain responsibility within the plugin:

| #    | Bounded Context           | Responsibility                                                                | Key Artifacts                                          |
| ---- | ------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------ |
| BC-1 | **Plugin Infrastructure** | Plugin manifest, directory skeleton, marketplace integration                  | `plugin.json`, directory tree, marketplace.json        |
| BC-2 | **Knowledge System**      | Background knowledge on review standards, checklist conventions, dual storage | `quality-strategy/` skill with reference docs          |
| BC-3 | **Review Generation**     | Generate review checklists from plans and ADRs                                | `review-checklist/` skill with scripts and templates   |
| BC-4 | **Review Analysis**       | Surface context and assess coverage                                           | `review-context/`, `review-coverage/` skills           |
| BC-5 | **Enforcement & Drift**   | Advisory hook for review/merge, cross-plugin drift detection                  | `check-review-checklist.sh`, `check-template-drift.sh` |

### Aggregates

#### BC-1: Plugin Infrastructure

| Aggregate          | Root Entity   | Description                                                               |
| ------------------ | ------------- | ------------------------------------------------------------------------- |
| **PluginManifest** | `plugin.json` | Plugin identity, version, metadata                                        |
| **DirectoryTree**  | Plugin root   | Complete directory skeleton for all skills, hooks, scripts, and templates |

#### BC-2: Knowledge System

| Aggregate                | Root Entity                | Description                                                        |
| ------------------------ | -------------------------- | ------------------------------------------------------------------ |
| **ReviewStandards**      | `review-standards.md`      | Three checklist categories, severity classification, quality gates |
| **ChecklistConventions** | `checklist-conventions.md` | Dual storage model, `.review/` structure, PR comment markers       |

#### BC-3: Review Generation

| Aggregate              | Root Entity                 | Description                                                |
| ---------------------- | --------------------------- | ---------------------------------------------------------- |
| **ChecklistGenerator** | `review-checklist/SKILL.md` | Generates spec-driven checklists from plans and ADRs       |
| **CriteriaExtractor**  | `extract-plan-criteria.sh`  | Extracts acceptance criteria from DDD plan files           |
| **ADRFinder**          | `find-relevant-adrs.sh`     | Finds ADRs relevant to changed files by module scope       |
| **SummaryGenerator**   | `review-summary/SKILL.md`   | Generates structured review summaries with findings tables |

#### BC-4: Review Analysis

| Aggregate          | Root Entity                | Description                                                        |
| ------------------ | -------------------------- | ------------------------------------------------------------------ |
| **ContextSurface** | `review-context/SKILL.md`  | Maps changed files to modules and surfaces relevant specifications |
| **CoverageAssess** | `review-coverage/SKILL.md` | Assesses review completeness against generated checklist           |
| **ModuleMapper**   | `map-files-to-modules.sh`  | Maps file paths to modules via CLAUDE.md discovery                 |

#### BC-5: Enforcement & Drift

| Aggregate                | Root Entity                 | Description                                                            |
| ------------------------ | --------------------------- | ---------------------------------------------------------------------- |
| **ReviewChecklistNudge** | `check-review-checklist.sh` | Advisory hook reminding about checklists before review/merge           |
| **GHCLICheck**           | `check-gh-cli.sh`           | Verifies gh CLI availability, cross-plugin copy from principled-github |
| **DriftChecker**         | `check-template-drift.sh`   | Verifies all 4 cross-plugin copy pairs match canonical                 |

### Domain Events

| Event                  | Source Context    | Target Context(s) | Description                                             |
| ---------------------- | ----------------- | ----------------- | ------------------------------------------------------- |
| **ChecklistGenerated** | BC-3 (Review Gen) | BC-4 (Analysis)   | Checklist created; coverage can now be assessed         |
| **ContextSurfaced**    | BC-4 (Analysis)   | BC-3 (Review Gen) | Specifications identified; informs checklist generation |
| **CoverageAssessed**   | BC-4 (Analysis)   | BC-3 (Review Gen) | Coverage report ready; informs summary generation       |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Plugin Skeleton & Infrastructure (BC-1)

**Goal:** Create the plugin manifest and integrate with the marketplace.

- [x] **1.1** Create `plugins/principled-quality/.claude-plugin/plugin.json` with name, version 0.1.0, description, author, keywords
- [x] **1.2** Add plugin entry to `.claude-plugin/marketplace.json` with category `quality`
- [x] **1.3** Add `.review/` to `.gitignore` (per ADR-012)
- [x] **1.4** Add `principled-quality@principled-marketplace` to `.claude/settings.json` enabled plugins

### Phase 2: Shared Scripts & Knowledge Base (BC-2, BC-3)

**Goal:** Implement shared utilities and background knowledge.

**Depends on:** Phase 1

- [x] **2.1** Copy `check-gh-cli.sh` from principled-github canonical source to `review-checklist/scripts/`
- [x] **2.2** Implement `review-checklist/scripts/extract-plan-criteria.sh`: parse DDD plan for `- [ ]`/`- [x]` items under Acceptance Criteria
- [x] **2.3** Implement `review-checklist/scripts/find-relevant-adrs.sh`: find ADRs by module scope via CLAUDE.md proximity
- [x] **2.4** Implement `review-context/scripts/map-files-to-modules.sh`: map file paths to modules via CLAUDE.md discovery
- [x] **2.5** Write `quality-strategy/reference/review-standards.md`: three categories, severity, quality gates
- [x] **2.6** Write `quality-strategy/reference/checklist-conventions.md`: format, dual storage, PR markers
- [x] **2.7** Write `quality-strategy/SKILL.md`: background knowledge, non-invocable

### Phase 3: Review Checklist Skill (BC-3)

**Goal:** Implement the core checklist generation skill.

**Depends on:** Phase 2

- [x] **3.1** Create `review-checklist/templates/checklist.md`: template with `{{PLACEHOLDER}}` variables
- [x] **3.2** Write `review-checklist/SKILL.md`: user-invocable, gh CLI → PR resolution → plan context → criteria extraction → ADR discovery → checklist generation → PR comment + local save

### Phase 4: Context & Coverage Skills (BC-4)

**Goal:** Implement specification surfacing and coverage assessment.

**Depends on:** Phase 2

- [x] **4.1** Write `review-context/SKILL.md`: user-invocable, map files to modules, find specs, report context
- [x] **4.2** Write `review-coverage/SKILL.md`: user-invocable, read checklist, read comments, map coverage, report

### Phase 5: Review Summary Skill (BC-3)

**Goal:** Implement structured review summary generation.

**Depends on:** Phase 3, Phase 4

- [x] **5.1** Create `review-summary/templates/review-summary.md`: template with coverage table, findings, unresolved items
- [x] **5.2** Write `review-summary/SKILL.md`: user-invocable, collect state, build findings, generate summary

### Phase 6: Hooks, Drift Detection & Documentation (BC-5, BC-1)

**Goal:** Implement advisory hook, propagate script copies, write documentation.

**Depends on:** Phases 3, 4, 5

- [x] **6.1** Implement `hooks/scripts/check-review-checklist.sh`: PostToolUse hook, reads stdin JSON, checks for `gh pr review`/`gh pr merge`, warns if no checklist, always exits 0
- [x] **6.2** Write `hooks/hooks.json`: PostToolUse hook for Bash targeting review checklist check script
- [x] **6.3** Propagate `check-gh-cli.sh` copies: review-checklist → review-context, review-coverage, review-summary (3 additional copies, 4 total)
- [x] **6.4** Implement `scripts/check-template-drift.sh`: cross-plugin drift checker comparing 4 copies against principled-github canonical
- [x] **6.5** Write plugin `README.md`: installation, skills, hook, architecture, dual storage, drift detection
- [x] **6.6** Create `docs/plans/005-principled-quality.md` (this document)
- [x] **6.7** Update `.github/workflows/ci.yml`: add drift check and hook smoke-test steps
- [x] **6.8** Update root `CLAUDE.md`: add principled-quality to architecture, skills, conventions, hooks, testing, dogfooding
- [x] **6.9** Update `.claude/CLAUDE.md`: add principled-quality dogfooding section and common pitfalls

---

## Decisions Required

Architectural decisions resolved before implementation:

1. **Checklist storage.** → ADR-012: Dual storage — PR comments (primary) + `.review/` files (secondary).
2. **Cross-plugin script sharing.** → Copy with cross-plugin drift check. Canonical stays in principled-github.
3. **Review-to-plan feedback.** → No write-back. `/review-coverage` is read-only and advisory.

---

## Dependencies

| Dependency                           | Required By                        | Status          |
| ------------------------------------ | ---------------------------------- | --------------- |
| gh CLI (installed and authenticated) | All skills except quality-strategy | Required        |
| Bash shell                           | All scripts                        | Available       |
| Git                                  | Module mapping, ADR discovery      | Available       |
| jq (optional, with grep fallback)    | check-review-checklist.sh          | Optional        |
| principled-docs document format      | Criteria extraction, ADR parsing   | Stable (v0.3.1) |
| principled-github check-gh-cli.sh    | Cross-plugin drift canonical       | Stable (v0.1.0) |
| Marketplace structure (RFC-002)      | Plugin location                    | Complete        |

---

## Acceptance Criteria

- [x] `/review-checklist 42 --plan docs/plans/005-feature.md` generates a checklist with acceptance criteria, ADR compliance, and general quality items
- [x] `/review-checklist 42` auto-detects plan from PR description
- [x] `/review-context 42` maps changed files to modules and surfaces relevant specs
- [x] `/review-coverage 42` reads checklist state and reports coverage percentage
- [x] `/review-summary 42` generates a structured summary with findings table
- [x] `check-review-checklist.sh` warns when `gh pr review` is run without a checklist (advisory, never blocks)
- [x] `check-review-checklist.sh` warns when `gh pr merge` is run without a checklist (advisory, never blocks)
- [x] `check-template-drift.sh` passes when all 4 cross-plugin copy pairs match canonical source
- [x] `check-template-drift.sh` fails when any copy diverges
- [x] Plugin README documents all skills, hook, and conventions
- [x] `.review/` directory is gitignored by default
