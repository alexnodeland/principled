---
title: "Principled Release Plugin"
number: "006"
status: complete
author: Alex
created: 2026-02-22
updated: 2026-02-23
originating_proposal: "004"
related_adrs: [013]
---

# Plan-006: Principled Release Plugin

## Objective

Implements [RFC-004](../proposals/004-principled-release-plugin.md).

Build the `principled-release` Claude Code plugin end-to-end: plugin infrastructure, 6 skills (1 background + 5 user-invocable), 1 advisory hook, shared scripts with drift detection, reference documentation, templates, and a plugin README — following the directory layout and conventions established in the marketplace.

The plugin bridges the principled documentation pipeline to the delivery boundary, synthesizing changelogs from proposals/plans/ADRs, verifying release readiness, coordinating version bumps, and governing the release lifecycle per [ADR-013](../decisions/013-pipeline-based-changelog-generation.md).

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **6 bounded contexts**, each representing a distinct area of domain responsibility within the plugin:

| #    | Bounded Context           | Responsibility                                                              | Key Artifacts                                              |
| ---- | ------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------- |
| BC-1 | **Plugin Infrastructure** | Plugin manifest, directory skeleton, marketplace integration                | `plugin.json`, directory tree, `marketplace.json`          |
| BC-2 | **Knowledge System**      | Background knowledge on release conventions, changelog format, semver rules | `release-strategy/` skill with reference docs              |
| BC-3 | **Change Collection**     | Map commits to pipeline documents, collect changes since last release       | `changelog/scripts/collect-changes.sh`, changelog template |
| BC-4 | **Release Verification**  | Check that all referenced pipeline documents are in terminal status         | `release-ready/scripts/check-readiness.sh`                 |
| BC-5 | **Version Coordination**  | Detect modules, determine bump type, apply version changes to manifests     | `version-bump/scripts/detect-modules.sh`                   |
| BC-6 | **Release Orchestration** | Draft release plans, tag releases, generate release notes                   | `release-plan/`, `tag-release/` skills                     |

### Aggregates

#### BC-1: Plugin Infrastructure

| Aggregate          | Root Entity   | Description                                                               |
| ------------------ | ------------- | ------------------------------------------------------------------------- |
| **PluginManifest** | `plugin.json` | Plugin identity, version, metadata                                        |
| **DirectoryTree**  | Plugin root   | Complete directory skeleton for all skills, hooks, scripts, and templates |

#### BC-2: Knowledge System

| Aggregate              | Root Entity              | Description                                                        |
| ---------------------- | ------------------------ | ------------------------------------------------------------------ |
| **ReleaseConventions** | `release-conventions.md` | Changelog format, Keep a Changelog adaptation, entry grouping      |
| **SemverRules**        | `semver-rules.md`        | How change types map to version bumps, override rules, pre-release |

#### BC-3: Change Collection

| Aggregate            | Root Entity          | Description                                                              |
| -------------------- | -------------------- | ------------------------------------------------------------------------ |
| **ChangeCollector**  | `collect-changes.sh` | Traverses git log, resolves PR references, maps commits to pipeline docs |
| **ChangelogBuilder** | `changelog/SKILL.md` | Synthesizes collected changes into Markdown changelog entries            |
| **EntryTemplate**    | `changelog-entry.md` | Template for changelog sections following Keep a Changelog format        |

#### BC-4: Release Verification

| Aggregate             | Root Entity              | Description                                                       |
| --------------------- | ------------------------ | ----------------------------------------------------------------- |
| **ReadinessChecker**  | `check-readiness.sh`     | Reads frontmatter status of referenced proposals, plans, and ADRs |
| **ReadinessReporter** | `release-ready/SKILL.md` | Evaluates readiness results and reports pass/fail with details    |

#### BC-5: Version Coordination

| Aggregate          | Root Entity             | Description                                                    |
| ------------------ | ----------------------- | -------------------------------------------------------------- |
| **ModuleDetector** | `detect-modules.sh`     | Finds modules via CLAUDE.md, identifies version manifest files |
| **BumpCalculator** | `version-bump/SKILL.md` | Determines bump type from change signals, applies to manifests |

#### BC-6: Release Orchestration

| Aggregate          | Root Entity             | Description                                                             |
| ------------------ | ----------------------- | ----------------------------------------------------------------------- |
| **ReleasePlanner** | `release-plan/SKILL.md` | Drafts release plan summarizing pending changes by module/category      |
| **ReleaseTag**     | `tag-release/SKILL.md`  | Validates, tags, generates release notes, optionally creates GH release |
| **TagValidator**   | `validate-tag.sh`       | Checks tag format, prevents duplicate tags                              |

### Domain Events

| Event                  | Source Context      | Target Context(s)                         | Description                                                             |
| ---------------------- | ------------------- | ----------------------------------------- | ----------------------------------------------------------------------- |
| **ChangesCollected**   | BC-3 (Collection)   | BC-4 (Verification), BC-6 (Orchestration) | Changes mapped to pipeline docs; readiness can be checked, plan drafted |
| **ReadinessVerified**  | BC-4 (Verification) | BC-6 (Orchestration)                      | All references in terminal status; release can proceed                  |
| **VersionDetermined**  | BC-5 (Coordination) | BC-6 (Orchestration)                      | Version bumps calculated; tag can be created                            |
| **ChangelogGenerated** | BC-3 (Collection)   | BC-6 (Orchestration)                      | Changelog entries rendered; release notes can be assembled              |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Plugin Skeleton & Infrastructure (BC-1)

**Goal:** Create the plugin manifest, directory structure, and marketplace integration.

- [x] **1.1** Create `plugins/principled-release/.claude-plugin/plugin.json` with name `principled-release`, version `0.1.0`, description, author, keywords (`release`, `changelog`, `versioning`, `semver`)
- [x] **1.2** Create full directory skeleton:
  - `skills/release-strategy/`, `skills/changelog/`, `skills/release-ready/`, `skills/version-bump/`, `skills/release-plan/`, `skills/tag-release/`
  - `hooks/scripts/`
  - `scripts/` (plugin-level drift checker)
- [x] **1.3** Add plugin entry to `.claude-plugin/marketplace.json` with category `workflow`
- [x] **1.4** Add `principled-release@principled-marketplace` to `.claude/settings.json` enabled plugins

### Phase 2: Knowledge Base & Shared Scripts (BC-2, BC-3)

**Goal:** Implement background knowledge and shared utilities.

**Depends on:** Phase 1

- [x] **2.1** Write `release-strategy/reference/release-conventions.md`: Keep a Changelog adaptation, entry format, grouping categories (Features, Improvements, Decisions, Uncategorized), pipeline reference syntax
- [x] **2.2** Write `release-strategy/reference/semver-rules.md`: bump type heuristics (supersedes → major, accepted proposals → minor, plan tasks → patch), `--type` override behavior, pre-release version handling
- [x] **2.3** Write `release-strategy/SKILL.md`: background knowledge skill, not user-invocable
- [x] **2.4** Copy `check-gh-cli.sh` from principled-github canonical source (`plugins/principled-github/skills/sync-issues/scripts/`) to `changelog/scripts/`
- [x] **2.5** Implement `changelog/scripts/collect-changes.sh`: accept `--since <tag>` and optional `--module <path>`, traverse git log, resolve PR references via `gh pr view`, extract pipeline document references (RFC-NNN, Plan-NNN, ADR-NNN patterns), output structured change list

### Phase 3: Changelog Skill (BC-3)

**Goal:** Implement the core changelog generation skill.

**Depends on:** Phase 2

- [x] **3.1** Create `changelog/templates/changelog-entry.md`: template with `{{VERSION}}`, `{{DATE}}`, `{{FEATURES}}`, `{{IMPROVEMENTS}}`, `{{DECISIONS}}`, `{{UNCATEGORIZED}}` placeholders
- [x] **3.2** Write `changelog/SKILL.md`: user-invocable, accepts `--since <tag>` and `--module <path>`, runs `collect-changes.sh`, groups by category, renders via template, outputs Markdown changelog section

### Phase 4: Release Readiness Skill (BC-4)

**Goal:** Implement pre-release verification.

**Depends on:** Phase 2

- [x] **4.1** Implement `release-ready/scripts/check-readiness.sh`: accept `--since <tag>`, collect pipeline references from merged PRs, read frontmatter status of each referenced document, report pass/fail per document, support `--strict` flag for hard failures
- [x] **4.2** Write `release-ready/SKILL.md`: user-invocable, accepts `--tag <version>` and `--strict`, runs `check-readiness.sh`, reports summary with blocking items, optionally runs structure validation on affected modules

### Phase 5: Version Bump Skill (BC-5)

**Goal:** Implement monorepo-aware version coordination.

**Depends on:** Phase 2

- [x] **5.1** Implement `version-bump/scripts/detect-modules.sh`: find CLAUDE.md files, parse module type, locate version manifest files (package.json, Cargo.toml, pyproject.toml), output module-to-manifest mapping
- [x] **5.2** Write `version-bump/SKILL.md`: user-invocable, accepts `--module <path>` and `--type major|minor|patch`, runs `detect-modules.sh`, determines bump type from change signals (or uses `--type` override), applies version change to manifest, reports what was bumped and why

### Phase 6: Release Plan & Tag Skills (BC-6)

**Goal:** Implement release planning and tagging orchestration.

**Depends on:** Phases 3, 4, 5

- [x] **6.1** Create `release-plan/templates/release-plan.md`: template with modules affected, features included, decisions included, outstanding items, suggested timeline
- [x] **6.2** Write `release-plan/SKILL.md`: user-invocable, accepts `--since <tag>`, collects changes, groups by module and category, generates plan document for team review
- [x] **6.3** Implement `tag-release/scripts/validate-tag.sh`: check tag format (vX.Y.Z), check tag doesn't already exist, validate against readiness state
- [x] **6.4** Write `tag-release/SKILL.md`: user-invocable, accepts `<version>` and `--dry-run`, runs `/release-ready --strict`, generates changelog, creates git tag, generates release notes, optionally creates GitHub release via `gh release create`

### Phase 7: Hook, Drift Detection & Documentation (BC-1, BC-6)

**Goal:** Implement advisory hook, propagate script copies, finalize documentation.

**Depends on:** Phases 3, 4, 5, 6

- [x] **7.1** Implement `hooks/scripts/check-release-readiness.sh`: PostToolUse hook for Bash, reads stdin JSON, detects `git tag` commands, warns if `/release-ready` hasn't been run, advisory only (always exits 0)
- [x] **7.2** Write `hooks/hooks.json`: PostToolUse hook for Bash targeting release readiness check script
- [x] **7.3** Propagate `check-gh-cli.sh` copies: `changelog/scripts/` → `release-ready/scripts/`, `tag-release/scripts/`, `release-plan/scripts/` (3 additional copies, 4 total within plugin)
- [x] **7.4** Implement `scripts/check-template-drift.sh`: verify all `check-gh-cli.sh` copies match principled-github canonical source (cross-plugin drift detection)
- [x] **7.5** Write plugin `README.md`: installation, skills table, hook, changelog format, release workflow, version bump heuristics, drift detection
- [x] **7.6** Update `.github/workflows/ci.yml`: add principled-release drift check step
- [x] **7.7** Update root `CLAUDE.md`: add principled-release to architecture table, skills table, conventions, hooks, testing, dogfooding, dependencies
- [x] **7.8** Update `.claude/CLAUDE.md`: add principled-release dogfooding section and common pitfalls

---

## Decisions Required

Architectural decisions resolved before implementation:

1. **Changelog generation source.** → ADR-013: Pipeline-based changelog generation from proposals, plans, and ADRs rather than commit messages.
2. **Cross-plugin script sharing.** → Copy with cross-plugin drift check. Canonical stays in principled-github (same pattern as principled-quality).
3. **Release scope boundary.** → Plugin stops at tag and release notes. No deployment, environment promotion, or rollback.

Open decisions to resolve during implementation:

1. **Changelog file persistence.** Should `/changelog` write to `CHANGELOG.md` or only output to stdout? If written, single root file or per-module?
2. **Pre-release version support.** Include `--pre <label>` in v0.1.0 or defer?
3. **Release branch workflow.** Should `/release-plan` create a branch or assume the team's strategy?

---

## Dependencies

| Dependency                           | Required By                           | Status          |
| ------------------------------------ | ------------------------------------- | --------------- |
| gh CLI (installed and authenticated) | changelog, release-ready, tag-release | Required        |
| Git                                  | All skills (log, tag, history)        | Available       |
| Bash shell                           | All scripts                           | Available       |
| jq (optional, with grep fallback)    | JSON parsing in scripts               | Optional        |
| principled-docs document format      | Frontmatter parsing, status checks    | Stable (v0.3.1) |
| principled-github check-gh-cli.sh    | Cross-plugin drift canonical          | Stable (v0.1.0) |
| principled-github /pr-describe       | PR reference generation (conceptual)  | Stable (v0.1.0) |
| Marketplace structure (RFC-002)      | Plugin location                       | Complete        |

---

## Acceptance Criteria

- [x] `/changelog --since v0.3.1` generates changelog entries grouped by Features, Improvements, Decisions, and Uncategorized
- [x] `/changelog --since v0.3.1 --module plugins/principled-docs` scopes to a single module
- [x] Changelog entries include parenthetical pipeline references (e.g., "(RFC-001, Plan-001)")
- [x] Changes without pipeline references appear under "Uncategorized" (not hidden)
- [x] `/release-ready` reports pass/fail for each referenced pipeline document
- [x] `/release-ready --strict` exits non-zero when any referenced document is not in terminal status
- [x] `/version-bump --module <path>` detects the version manifest and applies the bump
- [x] `/version-bump --type major` overrides automatic bump detection
- [x] `/release-plan --since v0.3.1` generates a reviewable release plan document
- [x] `/tag-release 0.4.0 --dry-run` shows what would happen without creating a tag
- [x] `/tag-release 0.4.0` creates a git tag and generates release notes
- [x] `check-release-readiness.sh` warns when `git tag` is detected without prior readiness check (advisory, never blocks)
- [x] `check-template-drift.sh` passes when all cross-plugin `check-gh-cli.sh` copies match canonical
- [x] `check-template-drift.sh` fails when any copy diverges
- [x] Plugin README documents all skills, hook, changelog format, and release workflow
