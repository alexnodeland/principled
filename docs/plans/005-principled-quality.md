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

Build the `principled-quality` Claude Code plugin end-to-end: plugin infrastructure, all 5 skills, 1 advisory hook, shared scripts with cross-plugin drift detection, dual-storage review checklist system, and a plugin README — following the directory layout and conventions established in the marketplace.

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **6 bounded contexts**, each representing a distinct area of domain responsibility within the plugin:

| #    | Bounded Context           | Responsibility                                                                  | Key Artifacts                                            |
| ---- | ------------------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------- |
| BC-1 | **Plugin Infrastructure** | Plugin manifest, directory skeleton, marketplace integration                    | `plugin.json`, directory tree, marketplace.json entry    |
| BC-2 | **Knowledge System**      | Background knowledge on review standards, quality conventions, checklist model  | `quality-strategy/` skill with reference docs            |
| BC-3 | **Checklist Generation**  | Generate review checklists from plans and ADRs, dual-storage output            | `review-checklist/` skill with templates and scripts     |
| BC-4 | **Context & Coverage**    | Surface relevant specs for a PR, assess review completeness                    | `review-context/`, `review-coverage/` skills             |
| BC-5 | **Review Summarization**  | Generate structured review summaries linking findings to spec items             | `review-summary/` skill with templates                   |
| BC-6 | **Enforcement & Drift**   | Advisory hook for review checklist reminders, script drift detection            | `check-review-checklist.sh`, `check-template-drift.sh`  |

### Aggregates

#### BC-1: Plugin Infrastructure

| Aggregate          | Root Entity   | Description                                                              |
| ------------------ | ------------- | ------------------------------------------------------------------------ |
| **PluginManifest** | `plugin.json` | Plugin identity, version, metadata                                       |
| **DirectoryTree**  | Plugin root   | Complete directory skeleton for all skills, hooks, scripts, and templates |

#### BC-2: Knowledge System

| Aggregate             | Root Entity               | Description                                                                |
| --------------------- | ------------------------- | -------------------------------------------------------------------------- |
| **ReviewStandards**   | `review-standards.md`     | Review quality expectations, checklist philosophy, coverage model           |
| **ChecklistModel**    | `checklist-model.md`      | How checklists are generated from plans: acceptance criteria → items        |
| **DualStorageModel**  | `dual-storage.md`         | How checklists are stored in PR comments and `.review/` files (ADR-012)    |

#### BC-3: Checklist Generation

| Aggregate                | Root Entity                   | Description                                                              |
| ------------------------ | ----------------------------- | ------------------------------------------------------------------------ |
| **ChecklistGenerator**   | `review-checklist/SKILL.md`   | Generates checklists from plan acceptance criteria and ADRs              |
| **ChecklistTemplate**    | `checklist.md`                | Markdown template for review checklists with sections                    |
| **PlanParser**           | `extract-plan-criteria.sh`    | Extracts acceptance criteria and task definitions from plan documents    |
| **ADRMatcher**           | `match-adrs.sh`               | Identifies ADRs relevant to changed files by module path                 |

#### BC-4: Context & Coverage

| Aggregate              | Root Entity                   | Description                                                              |
| ---------------------- | ----------------------------- | ------------------------------------------------------------------------ |
| **ContextSurfacer**    | `review-context/SKILL.md`     | Maps PR changed files to modules and relevant specs                      |
| **CoverageAssessor**   | `review-coverage/SKILL.md`    | Compares review comments against checklist items                         |

#### BC-5: Review Summarization

| Aggregate              | Root Entity                   | Description                                                              |
| ---------------------- | ----------------------------- | ------------------------------------------------------------------------ |
| **SummaryGenerator**   | `review-summary/SKILL.md`     | Produces structured review summaries linking findings to spec items       |
| **SummaryTemplate**    | `review-summary.md`           | Markdown template for review summaries                                   |

#### BC-6: Enforcement & Drift

| Aggregate               | Root Entity                  | Description                                                              |
| ----------------------- | ---------------------------- | ------------------------------------------------------------------------ |
| **ReviewChecklistNudge**| `check-review-checklist.sh`  | Advisory hook reminding about checklists on `gh pr review`/`gh pr merge` |
| **GHCLICheck**          | `check-gh-cli.sh`            | Verifies gh CLI availability, copied from principled-github              |
| **DriftChecker**        | `check-template-drift.sh`    | Verifies script copies match canonical sources                           |

### Domain Events

| Event                       | Source Context            | Target Context(s)        | Description                                                  |
| --------------------------- | ------------------------- | ------------------------ | ------------------------------------------------------------ |
| **ChecklistGenerated**      | BC-3 (Checklist Gen)     | BC-4 (Context/Coverage)  | Checklist created for a PR; coverage can now be assessed      |
| **ContextSurfaced**         | BC-4 (Context/Coverage)  | BC-3 (Checklist Gen)     | Relevant specs identified; informs checklist generation       |
| **CoverageAssessed**        | BC-4 (Context/Coverage)  | BC-5 (Summarization)     | Coverage gaps identified; summary can include gap analysis    |
| **ReviewSummarized**        | BC-5 (Summarization)     | —                        | Final summary produced; no downstream consumer               |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Plugin Skeleton & Infrastructure (BC-1)

**Goal:** Create the complete directory tree and plugin manifest.

- [ ] **1.1** Create `plugins/principled-quality/.claude-plugin/plugin.json` with name, version `0.1.0`, description, author, homepage, keywords
- [ ] **1.2** Create the full directory skeleton: all 5 skill directories, hook directory, scripts directory, template directories, reference directories
- [ ] **1.3** Add plugin entry to `.claude-plugin/marketplace.json` with category `quality`

### Phase 2: Shared Scripts & Knowledge Base (BC-2, BC-6)

**Goal:** Implement shared utilities and background knowledge.

**Depends on:** Phase 1

- [ ] **2.1** Copy `check-gh-cli.sh` from `plugins/principled-github/skills/sync-issues/scripts/` into `plugins/principled-quality/skills/review-checklist/scripts/` (CANONICAL within this plugin)
- [ ] **2.2** Implement `review-checklist/scripts/extract-plan-criteria.sh`: parse plan Markdown to extract acceptance criteria checkboxes from a given task section
- [ ] **2.3** Implement `review-checklist/scripts/match-adrs.sh`: given a list of file paths, identify the modules they belong to and find relevant ADRs in `docs/decisions/`
- [ ] **2.4** Write `quality-strategy/reference/review-standards.md`: review quality expectations, checklist sections (acceptance criteria, ADR compliance, general quality)
- [ ] **2.5** Write `quality-strategy/reference/checklist-model.md`: how checklists are generated from plan tasks, ADR matching logic, item granularity
- [ ] **2.6** Write `quality-strategy/reference/dual-storage.md`: dual-storage model (ADR-012), PR comment format, `.review/` file format, divergence handling
- [ ] **2.7** Write `quality-strategy/SKILL.md`: background knowledge, non-invocable, references all three reference docs

### Phase 3: Review Checklist Skill (BC-3)

**Goal:** Implement the core checklist generation skill with dual storage.

**Depends on:** Phase 2

- [ ] **3.1** Create `review-checklist/templates/checklist.md`: Markdown template with sections for Acceptance Criteria, ADR Compliance, and General Quality checkboxes
- [ ] **3.2** Write `review-checklist/SKILL.md`: user-invocable, accepts `<pr-number>` and optional `--plan <path>`, identifies plan/task from PR, extracts criteria, matches ADRs, generates checklist, posts as PR comment and saves to `.review/`

### Phase 4: Context & Coverage Skills (BC-4)

**Goal:** Implement spec context surfacing and review coverage assessment.

**Depends on:** Phase 2

- [ ] **4.1** Write `review-context/SKILL.md`: user-invocable, accepts `<pr-number>`, lists changed files via `gh`, maps files to modules via `CLAUDE.md`, finds relevant proposals/plans/ADRs, outputs summary
- [ ] **4.2** Write `review-coverage/SKILL.md`: user-invocable, accepts `<pr-number>`, retrieves checklist (from PR comments or `.review/`), retrieves review comments, maps comments to checklist items, reports covered/uncovered items. Read-only — does not modify plans.

### Phase 5: Review Summary Skill (BC-5)

**Goal:** Implement structured review summary generation.

**Depends on:** Phases 3, 4

- [ ] **5.1** Create `review-summary/templates/review-summary.md`: Markdown template with sections for PR metadata, review outcome, findings linked to spec items, and coverage status
- [ ] **5.2** Write `review-summary/SKILL.md`: user-invocable, accepts `<pr-number>`, collects review comments and checklist status, generates summary linking findings to spec items, records approval/changes-requested/blocking outcome

### Phase 6: Hooks, Drift Detection & Documentation (BC-6, BC-1)

**Goal:** Implement advisory hook, propagate script copies, write README.

**Depends on:** Phases 3, 4, 5

- [ ] **6.1** Implement `hooks/scripts/check-review-checklist.sh`: PostToolUse hook, reads stdin JSON, checks for `gh pr review` or `gh pr merge`, warns if no checklist found for the PR, always exits 0
- [ ] **6.2** Write `hooks/hooks.json`: PostToolUse hook for Bash targeting review checklist check script
- [ ] **6.3** Propagate `check-gh-cli.sh` copies:
  - Canonical `review-checklist/scripts/` → `review-context/`, `review-coverage/`, `review-summary/` (3 copies)
- [ ] **6.4** Implement `scripts/check-template-drift.sh`: verify all 4 `check-gh-cli.sh` pairs (1 canonical + 3 copies), exit non-zero on drift
- [ ] **6.5** Write plugin `README.md`:
  - Installation and gh CLI prerequisites
  - All 5 skills with command syntax and descriptions
  - Hook documentation (review checklist advisory)
  - Dual-storage model explanation
  - Script duplication and drift detection
  - Integration with principled-docs and principled-github

---

## Decisions Required

Architectural decisions resolved before implementation:

1. **Dual-storage for review checklists** → ADR-012: Checklists stored as both PR comments and local `.review/` files.
2. **Cross-plugin script reuse** → Follows ADR-009 convention: copy `check-gh-cli.sh` with drift check, no shared scripts directory.
3. **Read-only plugin interdependency** → Quality plugin reads principled-docs artifacts but never writes to them.

---

## Dependencies

| Dependency                           | Required By                          | Status              |
| ------------------------------------ | ------------------------------------ | ------------------- |
| gh CLI (installed and authenticated) | All skills                           | Required            |
| Bash shell                           | All scripts                          | Available           |
| Git                                  | review-context (module mapping)      | Available           |
| jq (optional, with grep fallback)    | check-review-checklist.sh            | Optional            |
| principled-docs document format      | review-checklist, review-context     | Stable (v0.3.1)     |
| principled-github check-gh-cli.sh    | Cross-plugin copy source             | Available           |
| Marketplace structure (RFC-002)      | Plugin location                      | Complete (Plan-002) |

---

## Acceptance Criteria

- [ ] `/review-checklist 42` generates a checklist from the plan referenced in PR #42, posts it as a PR comment, and saves to `.review/42-checklist.md`
- [ ] `/review-checklist 42 --plan docs/plans/005-feature.md` uses the specified plan instead of auto-detecting
- [ ] `/review-context 42` lists changed files, maps them to modules, and outputs relevant proposals/plans/ADRs
- [ ] `/review-coverage 42` retrieves the checklist and review comments, reports which items are covered and which are not
- [ ] `/review-summary 42` generates a structured summary linking review findings to spec items
- [ ] `check-review-checklist.sh` warns when `gh pr review` or `gh pr merge` is run without a checklist (advisory, never blocks)
- [ ] `check-template-drift.sh` passes when all 4 `check-gh-cli.sh` copies match canonical source
- [ ] `check-template-drift.sh` fails when any copy diverges
- [ ] Plugin README documents all skills, hook, and conventions
- [ ] Plugin entry exists in `.claude-plugin/marketplace.json`
