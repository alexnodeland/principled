---
title: "Plugin Marketplace Setup"
number: "002"
status: active
author: Alex
created: 2026-02-04
updated: 2026-02-04
originating_proposal: "002"
---

# Plan-002: Plugin Marketplace Setup

## Objective

Implements [RFC-002](../proposals/002-plugin-marketplace-setup.md).

Transform the principled-docs repository from a single-plugin structure into a curated plugin marketplace (Pattern C) with two tiers: first-party plugins in `plugins/` and community plugins in `external_plugins/`. Relocate the principled-docs plugin into `plugins/principled-docs/`, create the marketplace manifest, adapt CI and dev tooling for the new directory layout, and update all documentation to reflect the marketplace structure.

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **5 bounded contexts**, each representing a distinct area of responsibility:

| #    | Bounded Context                  | Responsibility                                                                                                      | Key Artifacts                                                                                                             |
| ---- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| BC-1 | **Marketplace Scaffold**         | Directory structure creation and marketplace manifest — the catalog that makes plugins discoverable                 | `.claude-plugin/marketplace.json`, `plugins/`, `external_plugins/.gitkeep`                                                |
| BC-2 | **Plugin Relocation**            | Moving the principled-docs plugin from root into `plugins/principled-docs/` while preserving self-containment       | `plugins/principled-docs/.claude-plugin/plugin.json`, `plugins/principled-docs/skills/`, `plugins/principled-docs/hooks/` |
| BC-3 | **Build & Enforcement Pipeline** | Adapting CI workflows, pre-commit hooks, and validation scripts to operate on the new directory layout              | `.github/workflows/ci.yml`, `.pre-commit-config.yaml`, marketplace manifest validation script                             |
| BC-4 | **Developer Experience**         | Updating dogfooding configuration, dev skills, and environment variables to reference the relocated plugin          | `.claude/settings.json`, `.claude/skills/*/SKILL.md`, `CLAUDE_PLUGIN_ROOT` env var                                        |
| BC-5 | **Documentation & Onboarding**   | Rewriting root-level docs for the marketplace, moving plugin docs to plugin directory, updating all path references | `CLAUDE.md`, `.claude/CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `plugins/principled-docs/README.md`                     |

### Aggregates

#### BC-1: Marketplace Scaffold

| Aggregate               | Root Entity                       | Description                                                                                                                                                                              |
| ----------------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MarketplaceManifest** | `.claude-plugin/marketplace.json` | The catalog file listing all available plugins with name, source path, description, version, category, and keywords. This is the single source of truth for what the marketplace offers. |
| **PluginDirectory**     | `plugins/`                        | Top-level directory for first-party plugins. Each subdirectory is a self-contained plugin with its own `.claude-plugin/plugin.json`.                                                     |
| **ExternalDirectory**   | `external_plugins/`               | Top-level directory for community-contributed plugins. Starts empty (`.gitkeep`) until the first submission. Same structural requirements as first-party plugins.                        |

#### BC-2: Plugin Relocation

| Aggregate             | Root Entity                                          | Description                                                                                                                                                                            |
| --------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **PluginManifest**    | `plugins/principled-docs/.claude-plugin/plugin.json` | The existing `plugin.json` relocated from the repo root. Content unchanged — only the path changes.                                                                                    |
| **PluginSkills**      | `plugins/principled-docs/skills/`                    | All 9 skill directories (`docs-strategy`, `scaffold`, `validate`, `new-proposal`, `new-plan`, `new-adr`, `new-architecture-doc`, `proposal-status`, `docs-audit`) relocated as a unit. |
| **PluginHooks**       | `plugins/principled-docs/hooks/`                     | Hook configuration (`hooks.json`) and all hook scripts (`check-adr-immutability.sh`, `check-proposal-lifecycle.sh`, `parse-frontmatter.sh`) relocated as a unit.                       |
| **RootPluginCleanup** | (removal)                                            | The original root-level `skills/`, `hooks/`, and `.claude-plugin/plugin.json` are removed after relocation. The root `.claude-plugin/` directory is repurposed for `marketplace.json`. |

#### BC-3: Build & Enforcement Pipeline

| Aggregate                       | Root Entity                | Description                                                                                                                                                                                      |
| ------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **CIPipeline**                  | `.github/workflows/ci.yml` | Updated CI workflow: template drift and structure validation commands must reference `plugins/principled-docs/` paths. New jobs added for marketplace manifest validation and plugin validation. |
| **PreCommitConfig**             | `.pre-commit-config.yaml`  | Updated template drift hook entry point to `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh`.                                                                            |
| **MarketplaceValidationScript** | (new CI step)              | Validates `marketplace.json` is well-formed JSON and that every listed plugin source directory exists on disk.                                                                                   |
| **PluginValidationStep**        | (new CI step)              | Iterates over `plugins/*/` and `external_plugins/*/`, running `claude plugin validate .` in each.                                                                                                |

#### BC-4: Developer Experience

| Aggregate               | Root Entity                 | Description                                                                                                                                                           |
| ----------------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ProjectSettings**     | `.claude/settings.json`     | Updated plugin path from `"."` to `"./plugins/principled-docs"`. Updated `CLAUDE_PLUGIN_ROOT` env var to `"./plugins/principled-docs"`.                               |
| **DevSkillPaths**       | `.claude/skills/*/SKILL.md` | Any dev skill that references plugin scripts (e.g., `/propagate-templates`, `/check-ci`) must update paths from `skills/` to `plugins/principled-docs/skills/`.       |
| **DogfoodingIntegrity** | (verification)              | After all config changes, verify that all 9 plugin skills are available, enforcement hooks fire correctly, and PostToolUse structure nudge works at the new location. |

#### BC-5: Documentation & Onboarding

| Aggregate             | Root Entity                         | Description                                                                                                                                                                          |
| --------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **MarketplaceREADME** | `README.md`                         | New root README covering marketplace purpose, plugin catalog, installation workflow (`/plugin marketplace add`), and contribution guide. Replaces the current plugin-focused README. |
| **PluginREADME**      | `plugins/principled-docs/README.md` | The existing root README content (skills, hooks, pipeline walkthrough, configuration) relocated to serve as the plugin's own documentation.                                          |
| **RootClaudeMD**      | `CLAUDE.md`                         | Updated to describe the marketplace structure, architecture table, path references, and marketplace contribution guidelines. No longer describes itself as "the plugin."             |
| **DevClaudeMD**       | `.claude/CLAUDE.md`                 | Updated path references in common pitfalls, before-committing checklist, and dev skill descriptions.                                                                                 |
| **ContributionGuide** | `CONTRIBUTING.md`                   | New sections added for contributing first-party plugins, submitting external plugins, marketplace manifest maintenance, and plugin review criteria.                                  |
| **ArchitectureDocs**  | `docs/architecture/*.md`            | Path references updated in plugin-system.md, documentation-pipeline.md, and enforcement-system.md. Marketplace layer documented in plugin-system.md.                                 |

### Domain Events

| Event                     | Source Context              | Target Context(s)                      | Description                                                                                                                                              |
| ------------------------- | --------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MarketplaceScaffolded** | BC-1 (Marketplace Scaffold) | BC-2 (Plugin Relocation)               | `plugins/` directory exists and `marketplace.json` is ready. Plugin relocation can proceed because the target directory structure is in place.           |
| **PluginRelocated**       | BC-2 (Plugin Relocation)    | BC-3 (Pipeline), BC-4 (Dev Experience) | `skills/`, `hooks/`, and `plugin.json` are at their new paths. CI, pre-commit, and `.claude/settings.json` must update to reference the new locations.   |
| **PipelineAdapted**       | BC-3 (Pipeline)             | BC-5 (Documentation)                   | CI and pre-commit work with new paths. Documentation can accurately describe the build and validation process.                                           |
| **DogfoodingRestored**    | BC-4 (Dev Experience)       | BC-5 (Documentation)                   | Plugin path and `CLAUDE_PLUGIN_ROOT` are correct. Skills and hooks work from new location. Documentation can describe the developer workflow accurately. |
| **DocumentationComplete** | BC-5 (Documentation)        | (terminal)                             | All docs reflect the marketplace structure. End-to-end verification can proceed.                                                                         |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Marketplace Scaffold & Plugin Relocation (BC-1, BC-2)

**Goal:** Create the marketplace directory structure, relocate the principled-docs plugin, and establish the marketplace manifest. These two contexts are combined into one phase because they form a single atomic `git mv` operation.

- [ ] **1.1** Create directory `plugins/principled-docs/.claude-plugin/`
- [ ] **1.2** Move plugin manifest: `git mv .claude-plugin/plugin.json plugins/principled-docs/.claude-plugin/plugin.json`
- [ ] **1.3** Move skills directory: `git mv skills/ plugins/principled-docs/skills/`
- [ ] **1.4** Move hooks directory: `git mv hooks/ plugins/principled-docs/hooks/`
- [ ] **1.5** Create `.claude-plugin/marketplace.json` with the following content:
  - `"name": "principled-marketplace"`
  - `"version": "1.0.0"`
  - `"description"` per RFC-002 §2
  - `"owner": { "name": "Alex" }`
  - `"metadata": { "pluginRoot": "./plugins" }`
  - `"plugins"` array with principled-docs entry (source `"./plugins/principled-docs"`, category `"documentation"`)
- [ ] **1.6** Create `external_plugins/.gitkeep`
- [ ] **1.7** Commit all moves and new files in a single commit using `git mv` to preserve history: `"refactor: relocate principled-docs plugin into marketplace structure"`

### Phase 2: Build & Enforcement Pipeline (BC-3)

**Goal:** Update CI and pre-commit to work with the new directory layout. Add marketplace-specific validation steps.

**Depends on:** Phase 1 (plugin must be at new paths before CI can reference them)

- [ ] **2.1** Update `.github/workflows/ci.yml` validate job — template drift check:
  - Set `CLAUDE_PLUGIN_ROOT=./plugins/principled-docs`
  - Change script path to `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh`
- [ ] **2.2** Update `.github/workflows/ci.yml` validate job — structure validation:
  - Set `CLAUDE_PLUGIN_ROOT=./plugins/principled-docs`
  - Change script path to `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --root`
- [ ] **2.3** Update `.github/workflows/ci.yml` validate job — hook smoke tests:
  - Update file paths in test JSON inputs to reference `docs/decisions/` and `docs/proposals/` (these stay at root, so paths may not change)
  - Update hook script invocations to reference `plugins/principled-docs/hooks/scripts/`
- [ ] **2.4** Add new CI step: marketplace manifest validation
  - Verify `.claude-plugin/marketplace.json` is valid JSON via `jq`
  - Verify every `source` path in the `plugins` array exists as a directory
- [ ] **2.5** Add new CI step: plugin validation
  - Iterate over `plugins/*/` and `external_plugins/*/`
  - Run plugin structure checks in each (presence of `.claude-plugin/plugin.json`, `README.md`)
- [ ] **2.6** Update `.pre-commit-config.yaml`:
  - Change template drift hook `entry` to `bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh`

### Phase 3: Developer Experience (BC-4)

**Goal:** Restore dogfooding by updating all Claude Code configuration to reference the relocated plugin.

**Depends on:** Phase 1 (plugin must be at new path)

- [ ] **3.1** Update `.claude/settings.json`:
  - Change plugin path from `"."` to `"./plugins/principled-docs"`
  - Change `CLAUDE_PLUGIN_ROOT` from `"."` to `"./plugins/principled-docs"`
- [ ] **3.2** Update `.claude/skills/propagate-templates/SKILL.md`:
  - All template source and destination paths must be prefixed with `plugins/principled-docs/`
  - Drift check script path must reference `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh`
- [ ] **3.3** Update `.claude/skills/check-ci/SKILL.md`:
  - Template drift script path updated
  - Structure validation script path updated
  - Hook smoke test script paths updated
- [ ] **3.4** Update `.claude/skills/test-hooks/SKILL.md`:
  - Hook script paths updated to `plugins/principled-docs/hooks/scripts/`
- [ ] **3.5** Review `.claude/skills/lint/SKILL.md`:
  - Lint operates on repo-wide globs (`**/*.sh`, `**/*.md`) — likely no path changes needed
  - Verify no hardcoded paths to `skills/` or `hooks/`
- [ ] **3.6** Verify dogfooding integrity:
  - Confirm all 9 plugin skills are available as slash commands
  - Confirm enforcement hooks fire when editing accepted proposals/ADRs
  - Confirm PostToolUse structure nudge fires when writing files in `docs/`

### Phase 4: Documentation & Onboarding (BC-5)

**Goal:** Update all documentation to reflect the marketplace structure. Move plugin-specific docs to the plugin directory.

**Depends on:** Phases 2 and 3 (CI and dogfooding must work before docs can accurately describe them)

- [ ] **4.1** Move root `README.md` to `plugins/principled-docs/README.md`:
  - Use `git mv README.md plugins/principled-docs/README.md`
  - Review content — update any self-referential paths (e.g., references to `skills/scaffold/` should become relative to the plugin directory)
- [ ] **4.2** Create new root `README.md` — marketplace README:
  - Marketplace name, description, and purpose
  - Available plugins table (name, category, description, link to plugin README)
  - Installation instructions: adding the marketplace, listing plugins, installing individual plugins
  - Team-wide adoption via `extraKnownMarketplaces` in `.claude/settings.json`
  - Links to `CONTRIBUTING.md` for plugin submission
  - License reference
- [ ] **4.3** Update root `CLAUDE.md`:
  - Change identity from "this repo **is** the principled-docs plugin" to "this repo is the Principled methodology plugin marketplace"
  - Update Architecture table: add Marketplace layer, update path references for Skills, Hooks, and Foundation layers
  - Update Skills table path references
  - Update Enforcement Hooks table: script paths now under `plugins/principled-docs/hooks/scripts/`
  - Update Template Duplication section: canonical paths now under `plugins/principled-docs/skills/scaffold/templates/`
  - Update Script Duplication section with new paths
  - Update Testing section with new script paths and marketplace validation
  - Add `plugins/` and `external_plugins/` to Architecture table
  - Update Dependencies section if needed
- [ ] **4.4** Update `.claude/CLAUDE.md`:
  - Update "Editing Hook Scripts" section: paths now under `plugins/principled-docs/hooks/scripts/`
  - Update "Modifying Templates" section: canonical templates now under `plugins/principled-docs/skills/scaffold/templates/`
  - Update "Before Committing" section if any commands change
  - Update Dev Skills table if skill behavior descriptions change
- [ ] **4.5** Update `CONTRIBUTING.md`:
  - Update "Plugin Architecture Overview" section with marketplace layer
  - Update "Skill Development" section: paths now under `plugins/principled-docs/skills/`
  - Update "Hook Development" section: paths now under `plugins/principled-docs/hooks/`
  - Update "Template Management" section: canonical paths updated
  - Add new section: "Contributing a First-Party Plugin" — directory structure requirements, `plugin.json` manifest, CI requirements
  - Add new section: "Submitting an External Plugin" — PR process, review criteria, required fields (`author`, `homepage`/`repository`)
  - Add new section: "Marketplace Manifest Maintenance" — how to add/update entries in `marketplace.json`
- [ ] **4.6** Update architecture documents in `docs/architecture/`:
  - `plugin-system.md`: Add marketplace layer above plugin layer, document `marketplace.json` ↔ `plugin.json` relationship
  - `documentation-pipeline.md`: Clarify that the pipeline governs the marketplace, not individual plugins
  - `enforcement-system.md`: Update hook script path references

### Phase 5: Verification & Finalization (All BCs)

**Goal:** End-to-end verification that the marketplace structure is complete, all tooling works, and no regressions exist.

**Depends on:** All previous phases

- [ ] **5.1** Run `pre-commit run --all-files` — all hooks pass
- [ ] **5.2** Run full lint suite:
  - `shellcheck --shell=bash` on all `.sh` files
  - `shfmt -i 2 -bn -sr -d` on all `.sh` files
  - `npx markdownlint-cli2 '**/*.md'`
  - `npx prettier --check '**/*.md'`
- [ ] **5.3** Run template drift check: `CLAUDE_PLUGIN_ROOT=./plugins/principled-docs bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh`
- [ ] **5.4** Run root structure validation: `CLAUDE_PLUGIN_ROOT=./plugins/principled-docs bash plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --root`
- [ ] **5.5** Run marketplace manifest validation:
  - `jq . .claude-plugin/marketplace.json` succeeds
  - Every plugin source directory listed in `marketplace.json` exists
- [ ] **5.6** Verify dogfooding:
  - All 9 plugin skills available as slash commands
  - Enforcement hooks fire correctly (test with known inputs)
  - PostToolUse structure nudge fires on write
- [ ] **5.7** Verify git history preservation:
  - `git log --follow plugins/principled-docs/skills/scaffold/SKILL.md` shows history from before the move
  - `git log --follow plugins/principled-docs/hooks/hooks.json` shows history from before the move

---

## Decisions Required

Architectural decisions that may need to become ADRs during implementation:

1. **Marketplace manifest validation strategy.** The CI pipeline needs to validate `marketplace.json` — should this be a dedicated bash script (following the plugin's pure-bash convention) or inline CI steps using `jq`? If a script, where does it live — at the marketplace root or within a plugin? This is a new concern that does not belong to any individual plugin.

2. **Plugin validation without `claude` CLI in CI.** The proposal specifies running `claude plugin validate .` in CI for each plugin. The `claude` CLI may not be available in all CI environments. An ADR should document whether to require the CLI in CI, provide a fallback structural check (verify `plugin.json` exists and is valid JSON), or skip plugin validation in CI entirely.

3. **Git history preservation approach.** The proposal specifies `git mv` for relocation. An ADR may be warranted to document the decision to prioritize `git log --follow` compatibility over a clean single-commit restructure, especially given the large number of files being moved.

---

## Dependencies

| Dependency                            | Required By                                   | Status                                         |
| ------------------------------------- | --------------------------------------------- | ---------------------------------------------- |
| RFC-002 accepted                      | This plan                                     | Draft (requires acceptance to proceed)         |
| Bash 4+                               | Phases 2, 3 (script path updates)             | Assumed available                              |
| Git                                   | Phase 1 (`git mv`), Phase 5 (history verify)  | Assumed available                              |
| jq                                    | Phase 2 (marketplace manifest validation)     | Optional — CI step can fall back to JSON parse |
| Node.js + npm                         | Phase 5 (Markdown lint verification)          | Assumed available (existing dev dependency)    |
| ShellCheck + shfmt                    | Phase 5 (shell lint verification)             | Assumed available (existing dev dependency)    |
| pre-commit                            | Phase 5 (pre-commit verification)             | Assumed available (existing dev dependency)    |
| Claude Code v2.1.3+                   | Phase 3 (dogfooding), Phase 5 (verification)  | Assumed available                              |
| Existing plugin (v0.3.1)              | Phase 1 (content to relocate)                 | Complete                                       |
| Plan-001 complete (DX infrastructure) | All phases (CI, pre-commit, dev skills exist) | Complete                                       |

---

## Acceptance Criteria

- [ ] Root `.claude-plugin/` contains only `marketplace.json` (no `plugin.json`)
- [ ] `plugins/principled-docs/.claude-plugin/plugin.json` exists with unchanged content
- [ ] `plugins/principled-docs/skills/` contains all 9 skill directories
- [ ] `plugins/principled-docs/hooks/` contains `hooks.json` and all hook scripts
- [ ] `.claude-plugin/marketplace.json` lists principled-docs with correct source path, version, category, and keywords
- [ ] `external_plugins/.gitkeep` exists
- [ ] `external_plugins/` contains no other files (empty tier)
- [ ] No `skills/` or `hooks/` directories remain at the repo root
- [ ] `.claude/settings.json` references `"./plugins/principled-docs"` for plugin path and `CLAUDE_PLUGIN_ROOT`
- [ ] `.github/workflows/ci.yml` passes with new paths (template drift, structure validation, hook smoke tests)
- [ ] `.github/workflows/ci.yml` includes marketplace manifest validation step
- [ ] `.pre-commit-config.yaml` template drift hook references `plugins/principled-docs/` path
- [ ] `pre-commit run --all-files` passes
- [ ] `npx prettier --check '**/*.md'` passes
- [ ] `npx markdownlint-cli2 '**/*.md'` passes
- [ ] `shellcheck` and `shfmt` pass on all `.sh` files
- [ ] Template drift check passes at new path
- [ ] Root structure validation passes at new path
- [ ] Root `README.md` describes the marketplace (not the plugin)
- [ ] `plugins/principled-docs/README.md` contains the plugin documentation (skills, hooks, configuration)
- [ ] Root `CLAUDE.md` describes the marketplace structure with correct paths
- [ ] `.claude/CLAUDE.md` has updated paths in all sections
- [ ] `CONTRIBUTING.md` includes sections for first-party plugin contribution, external plugin submission, and marketplace manifest maintenance
- [ ] All 9 plugin skills are available as slash commands (dogfooding verified)
- [ ] Enforcement hooks fire correctly at new path (dogfooding verified)
- [ ] `git log --follow` preserves history for relocated files

---

## Cross-Reference Map

| RFC-002 Section                 | Plan Phase | Key Tasks    |
| ------------------------------- | ---------- | ------------ |
| §1 Repository Structure         | Phase 1    | 1.1–1.7      |
| §2 Marketplace Manifest         | Phase 1    | 1.5          |
| §3 Plugin Relocation            | Phase 1    | 1.2–1.4, 1.7 |
| §4 First-Party Plugin Structure | Phase 1    | 1.1–1.3      |
| §5 External Plugin Structure    | Phase 1    | 1.6          |
| §6 Marketplace Categories       | Phase 1    | 1.5          |
| §7 Dogfooding Update            | Phase 3    | 3.1, 3.6     |
| §8 CI Pipeline Updates          | Phase 2    | 2.1–2.5      |
| §9 Pre-commit Hook Updates      | Phase 2    | 2.6          |
| §10 Dev Skill Updates           | Phase 3    | 3.2–3.5      |
| §11 Documentation Updates       | Phase 4    | 4.1–4.6      |
| §12 User-Facing Workflow        | Phase 4    | 4.2          |
| §13 Migration Strategy          | Phase 1    | 1.1–1.7      |
| Verification                    | Phase 5    | 5.1–5.7      |
