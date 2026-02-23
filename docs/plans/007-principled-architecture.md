---
title: "Principled Architecture Plugin"
number: "007"
status: active
author: Alex
created: 2026-02-22
updated: 2026-02-22
originating_proposal: "005"
related_adrs: [003, 014]
---

# Plan-007: Principled Architecture Plugin

## Objective

Implements [RFC-005](../proposals/005-principled-architecture-plugin.md).

Build the `principled-architecture` Claude Code plugin end-to-end: plugin infrastructure, 6 skills (1 background + 5 user-invocable), 1 advisory hook, shared scripts with drift detection, reference documentation, templates, and a plugin README — following the directory layout and conventions established in the marketplace.

The plugin creates a governance feedback loop from ADRs and architecture documents back to the codebase, detecting drift, auditing coverage, and keeping architecture docs synchronized per [ADR-014](../decisions/014-heuristic-architecture-governance.md). Module dependency direction rules build on the module type system from [ADR-003](../decisions/003-module-type-storage.md).

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **6 bounded contexts**, each representing a distinct area of domain responsibility within the plugin:

| #    | Bounded Context           | Responsibility                                                             | Key Artifacts                                      |
| ---- | ------------------------- | -------------------------------------------------------------------------- | -------------------------------------------------- |
| BC-1 | **Plugin Infrastructure** | Plugin manifest, directory skeleton, marketplace integration               | `plugin.json`, directory tree, `marketplace.json`  |
| BC-2 | **Knowledge System**      | Background knowledge on architecture governance, dependency rules, mapping | `arch-strategy/` skill with reference docs         |
| BC-3 | **Architecture Mapping**  | Discover modules, link to ADRs and architecture docs, build the map        | `arch-map/` skill, `scan-modules.sh`, map template |
| BC-4 | **Drift Detection**       | Analyze code for violations of architectural decisions                     | `arch-drift/` skill, `check-boundaries.sh`         |
| BC-5 | **Coverage & Sync**       | Audit governance gaps, update stale architecture docs                      | `arch-audit/`, `arch-sync/` skills, audit template |
| BC-6 | **Query & Enforcement**   | Answer architecture questions, advisory boundary violation hook            | `arch-query/` skill, `check-boundary-violation.sh` |

### Aggregates

#### BC-1: Plugin Infrastructure

| Aggregate          | Root Entity   | Description                                                               |
| ------------------ | ------------- | ------------------------------------------------------------------------- |
| **PluginManifest** | `plugin.json` | Plugin identity, version, metadata                                        |
| **DirectoryTree**  | Plugin root   | Complete directory skeleton for all skills, hooks, scripts, and templates |

#### BC-2: Knowledge System

| Aggregate              | Root Entity              | Description                                                                 |
| ---------------------- | ------------------------ | --------------------------------------------------------------------------- |
| **GovernanceRules**    | `governance-rules.md`    | Module dependency direction rules, override conventions, enforcement levels |
| **MappingConventions** | `mapping-conventions.md` | How ADRs declare scope, how modules reference decisions, map format         |

#### BC-3: Architecture Mapping

| Aggregate         | Root Entity         | Description                                                               |
| ----------------- | ------------------- | ------------------------------------------------------------------------- |
| **ModuleScanner** | `scan-modules.sh`   | Discovers CLAUDE.md files, parses module type, builds module inventory    |
| **ADRLinker**     | `arch-map/SKILL.md` | Cross-references ADR content against module paths to build governance map |
| **MapTemplate**   | `arch-map.md`       | Template for the rendered architecture map document                       |

#### BC-4: Drift Detection

| Aggregate           | Root Entity           | Description                                                                |
| ------------------- | --------------------- | -------------------------------------------------------------------------- |
| **BoundaryChecker** | `check-boundaries.sh` | Scans import/require statements, checks against dependency direction rules |
| **DriftAnalyzer**   | `arch-drift/SKILL.md` | Orchestrates drift checks across governed modules, classifies findings     |

#### BC-5: Coverage & Sync

| Aggregate           | Root Entity           | Description                                                                |
| ------------------- | --------------------- | -------------------------------------------------------------------------- |
| **CoverageAuditor** | `arch-audit/SKILL.md` | Cross-references map to find ungoverned modules, stale ADRs, orphaned docs |
| **AuditTemplate**   | `audit-report.md`     | Template for the coverage audit report                                     |
| **DocSyncer**       | `arch-sync/SKILL.md`  | Compares documented state vs. codebase, proposes architecture doc updates  |
| **ChangeDetector**  | `detect-changes.sh`   | Identifies discrepancies between architecture docs and actual module state |

#### BC-6: Query & Enforcement

| Aggregate         | Root Entity                   | Description                                                              |
| ----------------- | ----------------------------- | ------------------------------------------------------------------------ |
| **ArchQuery**     | `arch-query/SKILL.md`         | Answers natural-language architecture questions via search and synthesis |
| **BoundaryNudge** | `check-boundary-violation.sh` | PostToolUse hook detecting import violations in written files            |

### Domain Events

| Event                | Source Context     | Target Context(s) | Description                                                   |
| -------------------- | ------------------ | ----------------- | ------------------------------------------------------------- |
| **MapConstructed**   | BC-3 (Mapping)     | BC-4, BC-5, BC-6  | Architecture map built; drift, audit, and query can operate   |
| **DriftDetected**    | BC-4 (Drift)       | BC-5 (Coverage)   | Violations found; audit can assess governance gaps            |
| **CoverageAssessed** | BC-5 (Coverage)    | BC-5 (Sync)       | Gaps identified; architecture docs can be proposed for update |
| **BoundaryViolated** | BC-6 (Enforcement) | BC-4 (Drift)      | Runtime violation detected; informs drift analysis context    |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Plugin Skeleton & Infrastructure (BC-1)

**Goal:** Create the plugin manifest, directory structure, and marketplace integration.

- [ ] **1.1** Create `plugins/principled-architecture/.claude-plugin/plugin.json` with name `principled-architecture`, version `0.1.0`, description, author, keywords (`architecture`, `adr`, `governance`, `drift-detection`, `module-boundaries`)
- [ ] **1.2** Create full directory skeleton:
  - `skills/arch-strategy/`, `skills/arch-map/`, `skills/arch-drift/`, `skills/arch-audit/`, `skills/arch-sync/`, `skills/arch-query/`
  - `hooks/scripts/`
  - `scripts/` (plugin-level drift checker)
- [ ] **1.3** Add plugin entry to `.claude-plugin/marketplace.json` with category `architecture`
- [ ] **1.4** Add `principled-architecture@principled-marketplace` to `.claude/settings.json` enabled plugins

### Phase 2: Knowledge Base & Module Scanner (BC-2, BC-3)

**Goal:** Implement background knowledge and the foundational module scanning utility.

**Depends on:** Phase 1

- [ ] **2.1** Write `arch-strategy/reference/governance-rules.md`: module dependency direction rules (app → lib → core), override mechanism via CLAUDE.md declarations, enforcement levels (advisory vs. strict), violation severity classification
- [ ] **2.2** Write `arch-strategy/reference/mapping-conventions.md`: how ADRs declare scope (explicit `scope` section, module path references, frontmatter hints), how the map is constructed, map format and interpretation
- [ ] **2.3** Write `arch-strategy/SKILL.md`: background knowledge skill, not user-invocable
- [ ] **2.4** Implement `arch-map/scripts/scan-modules.sh`: find all CLAUDE.md files recursively, parse `## Module Type` section to extract type (`core`, `lib`, `app`), output module inventory as structured list (path, type, name)

### Phase 3: Architecture Map Skill (BC-3)

**Goal:** Implement the foundational architecture mapping skill.

**Depends on:** Phase 2

- [ ] **3.1** Create `arch-map/templates/arch-map.md`: template with `{{MODULES}}` sections, each containing governing ADRs, architecture doc references, and coverage classification
- [ ] **3.2** Write `arch-map/SKILL.md`: user-invocable, accepts `--module <path>` and `--output <path>`, runs `scan-modules.sh`, reads all ADRs in `docs/decisions/` and scans body for module path references, reads architecture docs in `docs/architecture/` for module references, cross-references to produce the map, renders via template

### Phase 4: Drift Detection Skill (BC-4)

**Goal:** Implement the core architectural drift detection skill.

**Depends on:** Phase 3

- [ ] **4.1** Implement `arch-drift/scripts/check-boundaries.sh`: accept `--module <path>` and `--type <module-type>`, scan source files for import/require/from statements via regex, check import paths against dependency direction rules, output violations with severity and governing ADR reference
- [ ] **4.2** Write `arch-drift/SKILL.md`: user-invocable, accepts `--module <path>` and `--strict`, builds architecture map (or reads cached), for each accepted ADR extracts constraints, runs `check-boundaries.sh` per module, classifies findings (error/warning/info), reports violations with ADR references, `--strict` mode exits non-zero on any error

### Phase 5: Coverage Audit & Architecture Sync Skills (BC-5)

**Goal:** Implement governance gap detection and architecture document updates.

**Depends on:** Phase 3

- [ ] **5.1** Create `arch-audit/templates/audit-report.md`: template with coverage summary table, ungoverned modules list, orphaned ADRs, stale architecture docs, severity classification
- [ ] **5.2** Write `arch-audit/SKILL.md`: user-invocable, accepts `--module <path>`, uses architecture map to find: modules with no ADRs, modules with no architecture doc mentions, ADRs referencing removed modules, architecture docs referencing removed components, generates audit report via template with severity classification (critical/warning/info)
- [ ] **5.3** Implement `arch-sync/scripts/detect-changes.sh`: compare architecture doc content against actual codebase state — module list, module types, component inventory — output discrepancies
- [ ] **5.4** Write `arch-sync/SKILL.md`: user-invocable, accepts `--doc <path>` and `--all`, reads architecture doc, runs `detect-changes.sh`, proposes updates as inline edits for human review, never auto-modifies (architecture docs require approval)

### Phase 6: Query Skill (BC-6)

**Goal:** Implement the interactive architecture query skill.

**Depends on:** Phase 3

- [ ] **6.1** Write `arch-query/SKILL.md`: user-invocable, accepts `"<question>"`, searches ADRs, architecture docs, proposals, and codebase to find relevant information, synthesizes answer with document references, designed for onboarding and architecture exploration

### Phase 7: Hook, Drift Detection & Documentation (BC-1, BC-6)

**Goal:** Implement advisory hook, set up drift checking, finalize documentation.

**Depends on:** Phases 3, 4, 5, 6

- [ ] **7.1** Implement `hooks/scripts/check-boundary-violation.sh`: PostToolUse hook for Write, reads stdin JSON `tool_input.file_path`, determines if file is in a module directory (check for CLAUDE.md in parent hierarchy), if in module: read module type, scan written file for imports, check against dependency direction rules, warn on violations, advisory only (always exits 0)
- [ ] **7.2** Write `hooks/hooks.json`: PostToolUse hook for Write targeting boundary violation check script
- [ ] **7.3** Copy `check-gh-cli.sh` from principled-github canonical source to skills that need gh CLI access (if any skills require it — `arch-sync` may use `gh` for PR-based updates). If no skills need gh CLI, skip this step.
- [ ] **7.4** Implement `scripts/check-template-drift.sh`: verify any cross-plugin or intra-plugin script copies match canonical sources
- [ ] **7.5** Write plugin `README.md`: installation, skills table, hook, dependency direction rules, architecture map format, governance feedback loop, drift detection approach
- [ ] **7.6** Update `.github/workflows/ci.yml`: add principled-architecture drift check step (if applicable)
- [ ] **7.7** Update root `CLAUDE.md`: add principled-architecture to architecture table, skills table, conventions, hooks, testing, dogfooding, dependencies
- [ ] **7.8** Update `.claude/CLAUDE.md`: add principled-architecture dogfooding section and common pitfalls

---

## Decisions Required

Architectural decisions resolved before implementation:

1. **Analysis approach.** → ADR-014: Heuristic file-level analysis rather than AST-level static analysis. Language-agnostic.
2. **Module type system.** → ADR-003: Module types declared in CLAUDE.md. Foundation for dependency direction rules.

Open decisions to resolve during implementation:

1. **ADR scope declaration.** Should ADRs include a `scope` or `modules` frontmatter field for explicit governance mapping? Or rely on body content parsing?
2. **Architecture map caching.** Should `/arch-map` persist output (e.g., `.architecture/map.json`) or regenerate on every invocation?
3. **Import pattern library.** Which import syntaxes should `check-boundaries.sh` recognize in v0.1.0? (JavaScript import/require, Python import/from, Go import, Rust use — or start with a configurable pattern set?)
4. **Integration with principled-quality.** Should `/arch-drift` findings feed into `/review-checklist`? Define the integration point or keep plugins independent for v0.1.0.

---

## Dependencies

| Dependency                         | Required By                      | Status          |
| ---------------------------------- | -------------------------------- | --------------- |
| Git                                | arch-sync change detection       | Available       |
| Bash shell                         | All scripts                      | Available       |
| jq (optional, with grep fallback)  | JSON parsing in scripts          | Optional        |
| principled-docs document format    | ADR parsing, frontmatter reading | Stable (v0.3.1) |
| ADR-003 module type conventions    | Module scanning, type detection  | Stable          |
| CLAUDE.md `## Module Type` section | scan-modules.sh                  | Convention      |
| Marketplace structure (RFC-002)    | Plugin location                  | Complete        |
| gh CLI (optional)                  | arch-sync PR updates (if needed) | Optional        |

---

## Acceptance Criteria

- [ ] `/arch-map` generates a complete map linking every module to its governing ADRs and architecture docs
- [ ] `/arch-map --module <path>` scopes output to a single module
- [ ] Architecture map classifies each module's coverage as Full, Partial, or None
- [ ] `/arch-drift` detects dependency direction violations (e.g., `core` importing from `app`)
- [ ] `/arch-drift --module <path>` scopes analysis to a single module
- [ ] `/arch-drift --strict` exits non-zero when any error-severity violation exists
- [ ] `/arch-drift` references the governing ADR for each reported violation
- [ ] `/arch-audit` identifies modules with no ADRs and no architecture doc mentions
- [ ] `/arch-audit` identifies orphaned ADRs (referencing modules no longer present)
- [ ] `/arch-audit` identifies stale architecture docs (referencing removed components)
- [ ] `/arch-audit` classifies findings by severity (critical/warning/info)
- [ ] `/arch-sync --doc <path>` proposes updates to a single architecture doc for human review
- [ ] `/arch-sync` never auto-modifies architecture docs — always requires approval
- [ ] `/arch-query "<question>"` answers natural-language architecture questions with document references
- [ ] `check-boundary-violation.sh` warns when a written file contains imports violating dependency direction (advisory, never blocks)
- [ ] `scan-modules.sh` correctly discovers modules by CLAUDE.md and parses module type
- [ ] Plugin README documents all skills, hook, dependency rules, and governance feedback loop
