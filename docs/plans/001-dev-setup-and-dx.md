---
title: "Developer Setup and DX Infrastructure"
number: "001"
status: active
author: Alex
created: 2026-02-04
updated: 2026-02-04
originating_proposal: "001"
---

# Plan-001: Developer Setup and DX Infrastructure

## Objective

Implements [RFC-001](../proposals/001-dev-setup-and-dx.md).

Deliver the complete developer setup and DX infrastructure for principled-docs: contribution guide, MIT license, shell and Markdown linting with pre-commit hooks, GitHub Actions CI pipeline, `.claude/` directory with project commands and dogfooding configuration.

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **5 bounded contexts**, each representing a distinct area of responsibility:

| # | Bounded Context | Responsibility | Key Artifacts |
|---|---|---|---|
| BC-1 | **Project Governance** | Legal and contribution framework — license, contribution guide, code of conduct expectations | `LICENSE`, `CONTRIBUTING.md` |
| BC-2 | **Shell Quality** | Shell script linting and formatting infrastructure — tooling config, standards enforcement | `.shellcheckrc`, `.editorconfig`, shfmt config |
| BC-3 | **Markdown Quality** | Markdown linting and formatting infrastructure — tooling config, Node.js dev dependencies | `.markdownlint.jsonc`, `.prettierrc`, `.prettierignore`, `package.json` |
| BC-4 | **Automation** | Pre-commit hooks and CI pipeline — local and remote enforcement of quality gates | `.pre-commit-config.yaml`, `.github/workflows/ci.yml` |
| BC-5 | **Claude Code DX** | `.claude/` directory setup — settings, project commands, dogfooding plugin installation | `.claude/settings.json`, `.claude/commands/*.md`, `.claude/CLAUDE.md` |

### Aggregates

#### BC-1: Project Governance

| Aggregate | Root Entity | Description |
|---|---|---|
| **LicenseFile** | `LICENSE` | MIT license text with correct year and copyright holder. Removes legal ambiguity for adoption. |
| **ContributionGuide** | `CONTRIBUTING.md` | Comprehensive onboarding document covering prerequisites, workflow, architecture orientation, skill/hook development, template management, testing, and code style. |

#### BC-2: Shell Quality

| Aggregate | Root Entity | Description |
|---|---|---|
| **ShellCheckConfig** | `.shellcheckrc` | Project-wide ShellCheck configuration. Shell directive set to `bash`. All rules enabled by default. |
| **EditorConfig** | `.editorconfig` | Editor-agnostic formatting defaults: 2-space indent, LF line endings, UTF-8, trailing whitespace trimming. Applies to `.sh`, `.md`, `.json`, `.yaml` files. |

#### BC-3: Markdown Quality

| Aggregate | Root Entity | Description |
|---|---|---|
| **MarkdownLintConfig** | `.markdownlint.jsonc` | markdownlint rule configuration. MD013 (line length) relaxed for tables/URLs. MD033 (inline HTML) disabled for Mermaid containers. All other rules enabled. |
| **PrettierConfig** | `.prettierrc` | Prettier configuration scoped to Markdown: prose wrap `preserve`, 2-space tab width. |
| **PrettierIgnore** | `.prettierignore` | Exclusion patterns for generated or vendored content. |
| **NodeDevDeps** | `package.json` | Dev-only Node.js dependencies (`markdownlint-cli2`, `prettier`). Does not affect plugin runtime. |

#### BC-4: Automation

| Aggregate | Root Entity | Description |
|---|---|---|
| **PreCommitConfig** | `.pre-commit-config.yaml` | pre-commit framework configuration declaring all hooks: shfmt, ShellCheck, markdownlint-cli2, Prettier, template drift check. |
| **CIPipeline** | `.github/workflows/ci.yml` | GitHub Actions workflow with three jobs: `lint-shell`, `lint-markdown`, `validate`. Runs on PR and push to main. |

#### BC-5: Claude Code DX

| Aggregate | Root Entity | Description |
|---|---|---|
| **ProjectSettings** | `.claude/settings.json` | Claude Code project settings: tool permissions, environment variables, dogfooding plugin reference (`"path": "."`). Committed to repo. |
| **LintCommand** | `.claude/commands/lint.md` | Prompt-based skill that runs the full lint suite and reports results. |
| **ValidateCommand** | `.claude/commands/validate.md` | Prompt-based skill that runs template drift check and full structure validation (`--root`). |
| **TestHooksCommand** | `.claude/commands/test-hooks.md` | Prompt-based skill that smoke-tests enforcement hooks with known good/bad inputs. |
| **PropagateTemplatesCommand** | `.claude/commands/propagate-templates.md` | Prompt-based skill that copies canonical templates to consuming skills and verifies drift-free. |
| **CheckCICommand** | `.claude/commands/check-ci.md` | Prompt-based skill that runs the full CI pipeline locally. |
| **DevClaude** | `.claude/CLAUDE.md` | Development-specific context: pitfalls, template propagation reminders, lint/validate pointers. |

### Domain Events

| Event | Source Context | Target Context(s) | Description |
|---|---|---|---|
| **GovernanceEstablished** | BC-1 (Governance) | BC-4 (Automation) | LICENSE and CONTRIBUTING.md exist; CONTRIBUTING.md can reference lint/CI setup once those are ready. |
| **ShellLintConfigured** | BC-2 (Shell Quality) | BC-4 (Automation) | `.shellcheckrc` and `.editorconfig` exist; pre-commit and CI can wire up ShellCheck/shfmt hooks. |
| **MarkdownLintConfigured** | BC-3 (Markdown Quality) | BC-4 (Automation) | markdownlint and Prettier configs exist with `package.json`; pre-commit and CI can wire up Markdown hooks. |
| **AutomationReady** | BC-4 (Automation) | BC-5 (Claude Code DX) | Pre-commit and CI are functional; project commands can reference them (e.g., `/project:check-ci` runs the pipeline locally). |
| **InitialFormatPass** | BC-4 (Automation) | BC-1 (Governance) | After linting is configured, run formatters on existing files. Results feed back into CONTRIBUTING.md code style section. |
| **DogfoodingActive** | BC-5 (Claude Code DX) | All Contexts | Plugin is self-installed; all enforcement hooks and skills are active during development, validating the full DX. |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Project Governance (BC-1)

**Goal:** Establish legal and contribution framework.

- [ ] **1.1** Create `LICENSE` with MIT license text, year 2026, copyright holder "Alex"
- [ ] **1.2** Create `CONTRIBUTING.md` with the following sections:
  - [ ] **Getting started** — clone instructions, prerequisites (Bash 4+, Git, Node.js for Markdown tooling, optional jq), directory orientation pointing to `CLAUDE.md`
  - [ ] **Development workflow** — branching strategy, commit message conventions (`type: description`), PR process
  - [ ] **Plugin architecture overview** — brief summary with pointers to `CLAUDE.md` and `docs/architecture/`
  - [ ] **Skill development** — directory structure, SKILL.md format (frontmatter fields, workflow section), templates, scripts
  - [ ] **Hook development** — `hooks.json` schema, script conventions (exit 0 = allow, exit 2 = block), `parse-frontmatter.sh` usage
  - [ ] **Template management** — canonical sources in `scaffold/templates/`, copy rules, drift checking with `check-template-drift.sh`, propagation workflow
  - [ ] **Testing locally** — how to run `validate-structure.sh`, hook smoke tests, `check-template-drift.sh`
  - [ ] **Code style** — shell standards (2-space indent, bash dialect) and Markdown standards (ATX headings, backtick fences, preserve prose wrap), with pointers to linter configs
  - [ ] **Pre-commit hooks** — `pre-commit install` instructions, what checks run, how to bypass in emergencies (`--no-verify`)

### Phase 2: Shell Quality Infrastructure (BC-2)

**Goal:** Configure shell script linting and formatting tooling.

- [ ] **2.1** Create `.shellcheckrc`:
  - [ ] Set `shell=bash` directive
  - [ ] No rules disabled initially (all enabled by default)
- [ ] **2.2** Create `.editorconfig`:
  - [ ] Root = true
  - [ ] Default: `indent_style = space`, `indent_size = 2`, `end_of_line = lf`, `charset = utf-8`, `trim_trailing_whitespace = true`, `insert_final_newline = true`
  - [ ] `[*.sh]` section: inherits defaults
  - [ ] `[*.md]` section: `trim_trailing_whitespace = false` (trailing spaces can be meaningful in Markdown)
  - [ ] `[*.{json,yaml,yml}]` section: inherits defaults

### Phase 3: Markdown Quality Infrastructure (BC-3)

**Goal:** Configure Markdown linting and formatting tooling with Node.js dev dependencies.

**Depends on:** None (independent of Phase 2, can run in parallel)

- [ ] **3.1** Create `package.json`:
  - [ ] `"name": "principled-docs"`, `"private": true`
  - [ ] `devDependencies`: `markdownlint-cli2`, `prettier`
  - [ ] `scripts`: `"lint:md": "markdownlint-cli2 '**/*.md'"`, `"format:md": "prettier --check '**/*.md'"`, `"format:md:fix": "prettier --write '**/*.md'"`
- [ ] **3.2** Create `.markdownlint.jsonc`:
  - [ ] `"default": true` (all rules enabled)
  - [ ] `"MD013": false` (line length — disabled globally; tables, long URLs, and prose all exceed reasonable limits)
  - [ ] `"MD033": { "allowed_elements": ["details", "summary", "br", "div"] }` (allow HTML for Mermaid containers and collapsible sections)
  - [ ] `"MD024": { "siblings_only": true }` (allow duplicate headings in different sections, e.g., "Description" under multiple aggregates)
- [ ] **3.3** Create `.prettierrc`:
  - [ ] `"proseWrap": "preserve"`
  - [ ] `"tabWidth": 2`
  - [ ] `"useTabs": false`
  - [ ] `"overrides": [{ "files": "*.md", "options": { "parser": "markdown" } }]`
- [ ] **3.4** Create `.prettierignore`:
  - [ ] `node_modules/`
  - [ ] Any vendored or generated paths
- [ ] **3.5** Add `node_modules/` to `.gitignore` (create if needed, or append)

### Phase 4: Automation — Pre-commit & CI (BC-4)

**Goal:** Wire linting into local pre-commit hooks and remote CI pipeline.

**Depends on:** Phases 2 and 3 (lint configs must exist before hooks reference them)

- [ ] **4.1** Create `.pre-commit-config.yaml`:
  - [ ] `repos:` entry for `shfmt` (using `mvdan/sh` mirror or `pre-commit/mirrors-shfmt`)
  - [ ] `repos:` entry for `shellcheck` (using `shellcheck-py` or `koalaman/shellcheck-precommit`)
  - [ ] `repos:` entry for `markdownlint-cli2` (using `DavidAnson/markdownlint-cli2` hook)
  - [ ] `repos:` entry for `prettier` (using `pre-commit/mirrors-prettier` with `additional_dependencies` for Markdown)
  - [ ] `repos:` local hook entry for template drift check: `skills/scaffold/scripts/check-template-drift.sh`
- [ ] **4.2** Create `.github/workflows/ci.yml`:
  - [ ] Trigger on `push` to main and `pull_request`
  - [ ] Job `lint-shell`:
    - [ ] Checkout repo
    - [ ] Install ShellCheck and shfmt
    - [ ] Run `shfmt --diff` on all `.sh` files (find + xargs or glob)
    - [ ] Run `shellcheck` on all `.sh` files
  - [ ] Job `lint-markdown`:
    - [ ] Checkout repo
    - [ ] Install Node.js, run `npm ci`
    - [ ] Run `npx markdownlint-cli2 '**/*.md'`
    - [ ] Run `npx prettier --check '**/*.md'`
  - [ ] Job `validate`:
    - [ ] Checkout repo
    - [ ] Run `skills/scaffold/scripts/check-template-drift.sh`
    - [ ] Run `skills/scaffold/scripts/validate-structure.sh --root`
    - [ ] Hook smoke tests: feed known good/bad JSON inputs to `check-adr-immutability.sh` and `check-proposal-lifecycle.sh`, assert expected exit codes
- [ ] **4.3** Run initial format pass on existing files:
  - [ ] Run `shfmt -w` on all `.sh` files, commit reformatting separately
  - [ ] Run `prettier --write` on all `.md` files, commit reformatting separately
  - [ ] Verify `markdownlint-cli2` passes on all `.md` files after formatting; fix any remaining issues
  - [ ] Verify `shellcheck` passes on all `.sh` files; fix any issues or add inline directives where justified

### Phase 5: Claude Code DX & Dogfooding (BC-5)

**Goal:** Set up `.claude/` directory with project settings, dev commands, and self-installed plugin.

**Depends on:** Phase 4 (automation must be functional so commands can reference it)

- [ ] **5.1** Create `.claude/settings.json`:
  - [ ] `"permissions"`: pre-approve `Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep`
  - [ ] `"env"`: set `CLAUDE_PLUGIN_ROOT` to repo root
  - [ ] `"plugins"`: `[{ "path": "." }]` (dogfooding — install principled-docs as its own plugin)
- [ ] **5.2** Create `.claude/commands/lint.md`:
  - [ ] Workflow: run ShellCheck on all `.sh` files, run shfmt `--diff` on all `.sh` files, run `npx markdownlint-cli2` on all `.md` files, run `npx prettier --check` on all `.md` files
  - [ ] Report results: count of errors per tool, list affected files, suggest fix commands
- [ ] **5.3** Create `.claude/commands/validate.md`:
  - [ ] Workflow: run `skills/scaffold/scripts/check-template-drift.sh`, run `skills/scaffold/scripts/validate-structure.sh --root`
  - [ ] Report results: pass/fail per check, list any drifted templates or missing structure
- [ ] **5.4** Create `.claude/commands/test-hooks.md`:
  - [ ] Workflow: for each hook script (`check-adr-immutability.sh`, `check-proposal-lifecycle.sh`):
    - [ ] Feed JSON with a path to a known-accepted ADR/proposal → expect exit 2
    - [ ] Feed JSON with a path to a draft document → expect exit 0
    - [ ] Feed JSON with a non-existent file → expect exit 0
  - [ ] Report results: pass/fail per test case
- [ ] **5.5** Create `.claude/commands/propagate-templates.md`:
  - [ ] Workflow: copy each canonical template to its consuming skill per the drift table in CLAUDE.md
    - [ ] `scaffold/templates/core/proposal.md` → `new-proposal/templates/proposal.md`
    - [ ] `scaffold/templates/core/plan.md` → `new-plan/templates/plan.md`
    - [ ] `scaffold/templates/core/decision.md` → `new-adr/templates/decision.md`
    - [ ] `scaffold/templates/core/architecture.md` → `new-architecture-doc/templates/architecture.md`
  - [ ] Copy `next-number.sh`: `new-proposal/scripts/` → `new-plan/scripts/`, `new-adr/scripts/`
  - [ ] Copy `validate-structure.sh`: `scaffold/scripts/` → `validate/scripts/`
  - [ ] Run `check-template-drift.sh` to verify all copies match
- [ ] **5.6** Create `.claude/commands/check-ci.md`:
  - [ ] Workflow: run every check from the CI pipeline locally in sequence:
    - [ ] `shfmt --diff` on all `.sh` files
    - [ ] `shellcheck` on all `.sh` files
    - [ ] `npx markdownlint-cli2 '**/*.md'`
    - [ ] `npx prettier --check '**/*.md'`
    - [ ] `skills/scaffold/scripts/check-template-drift.sh`
    - [ ] `skills/scaffold/scripts/validate-structure.sh --root`
  - [ ] Report aggregate results: all-pass or list of failures
- [ ] **5.7** Create `.claude/CLAUDE.md`:
  - [ ] Development-specific context supplementing root `CLAUDE.md`
  - [ ] Common pitfalls: editing hook scripts (test with known inputs), modifying canonical templates (must propagate), changing frontmatter schema (affects parse-frontmatter.sh)
  - [ ] Reminder: run `/project:lint` and `/project:validate` before committing
  - [ ] Reminder: after modifying canonical templates, run `/project:propagate-templates`
  - [ ] Note: the plugin is self-installed (dogfooding) — all skills and hooks are active
- [ ] **5.8** Verify dogfooding:
  - [ ] Confirm all 9 plugin skills are available as slash commands
  - [ ] Confirm enforcement hooks fire when editing proposals/ADRs
  - [ ] Confirm PostToolUse structure nudge fires when writing files in `docs/`

### Phase 6: Finalize & Update Docs (All BCs)

**Goal:** Update existing documentation to reference new infrastructure and verify everything works end-to-end.

**Depends on:** All previous phases

- [ ] **6.1** Update root `CLAUDE.md`:
  - [ ] Add `.claude/` directory to Architecture table (Foundation layer)
  - [ ] Add reference to `CONTRIBUTING.md` in Key Conventions or a new section
  - [ ] Add CI pipeline to Testing section
  - [ ] Add Markdown linting tools to Dependencies section
  - [ ] Note dogfooding setup
- [ ] **6.2** End-to-end verification:
  - [ ] Run `pre-commit run --all-files` — all hooks pass
  - [ ] Trigger CI pipeline (push to branch, open PR) — all jobs pass
  - [ ] Run `/project:check-ci` — mirrors CI results
  - [ ] Run `/project:lint` — clean output
  - [ ] Run `/project:validate` — all checks pass
  - [ ] Run `/project:test-hooks` — all smoke tests pass
  - [ ] Verify `/project:propagate-templates` completes with no drift

---

## Decisions Required

Architectural decisions that may need to become ADRs during implementation:

1. **Node.js introduction for dev tooling.** The plugin runtime is pure bash, but Markdown tooling requires Node.js as a dev dependency. This is a deliberate boundary: `package.json` is dev-only, not a plugin runtime dependency. If this boundary is unclear, an ADR should document the rationale.

2. **pre-commit framework vs. raw git hooks.** RFC-001 recommends the pre-commit framework (Option A). This adds a Python dependency for hook management. If the team prefers zero non-bash dependencies, Option B (raw git hook script) is the fallback. Decision should be finalized before Phase 4.

---

## Dependencies

| Dependency | Required By | Status |
|---|---|---|
| RFC-001 accepted | This plan | Draft (requires acceptance to proceed) |
| Bash 4+ | Phases 2, 4 (shfmt, ShellCheck, existing scripts) | Assumed available |
| Git | All phases | Assumed available |
| Node.js + npm | Phase 3 (markdownlint-cli2, Prettier) | Must be available; version ≥ 18 recommended |
| Python 3 | Phase 4 (pre-commit framework) | Must be available if Option A chosen |
| ShellCheck | Phases 2, 4 | Must be installed |
| shfmt | Phases 2, 4 | Must be installed |
| GitHub Actions | Phase 4 | Repo must be hosted on GitHub |
| Claude Code v2.1.3+ | Phase 5 | Assumed available |
| Existing plugin (skills, hooks, scripts) | Phase 5 (dogfooding) | Complete (v0.3.1) |

---

## Acceptance Criteria

- [ ] `LICENSE` exists at repo root with MIT license text
- [ ] `CONTRIBUTING.md` exists at repo root and covers all sections specified in task 1.2
- [ ] `.shellcheckrc` exists and sets `shell=bash`
- [ ] `.editorconfig` exists with correct settings for `.sh`, `.md`, `.json`, `.yaml` files
- [ ] `package.json` exists with `markdownlint-cli2` and `prettier` as dev dependencies
- [ ] `.markdownlint.jsonc` exists with MD013 disabled, MD033 configured for allowed elements, MD024 siblings-only
- [ ] `.prettierrc` exists with `proseWrap: preserve`
- [ ] `shellcheck` passes on all `.sh` files with zero warnings
- [ ] `shfmt --diff` produces no output on all `.sh` files (already formatted)
- [ ] `markdownlint-cli2` passes on all `.md` files
- [ ] `prettier --check` passes on all `.md` files
- [ ] `.pre-commit-config.yaml` exists and `pre-commit run --all-files` passes
- [ ] `.github/workflows/ci.yml` exists with `lint-shell`, `lint-markdown`, and `validate` jobs
- [ ] CI pipeline passes on a clean branch (all three jobs green)
- [ ] `.claude/settings.json` exists, is committed, and includes `"plugins": [{"path": "."}]`
- [ ] `.claude/commands/` contains 5 command files: `lint.md`, `validate.md`, `test-hooks.md`, `propagate-templates.md`, `check-ci.md`
- [ ] `.claude/CLAUDE.md` exists with development-specific guidance
- [ ] All 9 plugin skills are available as slash commands when working in this repo (dogfooding verified)
- [ ] Enforcement hooks fire correctly when editing accepted proposals/ADRs (dogfooding verified)
- [ ] Root `CLAUDE.md` updated to reference `.claude/`, `CONTRIBUTING.md`, CI pipeline, and Markdown tooling
- [ ] `/project:check-ci` mirrors CI pipeline results locally
- [ ] `/project:propagate-templates` completes with zero drift

---

## Cross-Reference Map

| RFC-001 Section | Plan Phase | Key Tasks |
|---|---|---|
| §1 CONTRIBUTING.md | Phase 1 | 1.2 |
| §2 MIT License | Phase 1 | 1.1 |
| §3 Shell: ShellCheck + shfmt | Phase 2 | 2.1, 2.2 |
| §3 Markdown: markdownlint + Prettier | Phase 3 | 3.1–3.5 |
| §3 General Configuration | Phase 2 | 2.2 |
| §3 Pre-commit Hook | Phase 4 | 4.1 |
| §3 Shell Formatting Standards | Phase 2, 4 | 2.1, 4.3 |
| §3 Markdown Formatting Standards | Phase 3, 4 | 3.2, 3.3, 4.3 |
| §4 CI Pipeline | Phase 4 | 4.2 |
| §5 `.claude/` Directory Setup | Phase 5 | 5.1–5.7 |
| §6 Dogfooding | Phase 5 | 5.1, 5.8 |
| Decisions | Phase 4, 5 | Pre-commit choice, Node.js boundary |
