---
title: "Principled Docs Plugin Implementation"
number: "000"
status: active
author: Claude
created: 2026-02-04
updated: 2026-02-04
originating_proposal: "000"
---

# Plan-000: Principled Docs Plugin Implementation

## Objective

Implements [RFC-000](../proposals/000-principled-docs.md).

Build the `principled-docs` Claude Code plugin end-to-end: plugin infrastructure, all 9 skills, all 3 hooks, all 12+ templates, all reference documentation, all utility scripts, and a plugin README — following the directory layout, conventions, and workflows defined in the PRD.

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **8 bounded contexts**, each representing a distinct area of domain responsibility within the plugin:

| # | Bounded Context | Responsibility | Key Artifacts |
|---|---|---|---|
| BC-1 | **Plugin Infrastructure** | Plugin manifest, top-level directory skeleton, configuration schema | `plugin.json`, directory tree |
| BC-2 | **Template Management** | Canonical template authoring, template duplication to consuming skills, drift detection | `scaffold/templates/`, `check-template-drift.sh` |
| BC-3 | **Knowledge System** | Background knowledge for Claude Code: structure specs, naming conventions, lifecycle rules, DDD guide, pipeline diagrams | `docs-strategy/` skill with all reference files |
| BC-4 | **Scaffolding & Validation** | Module/root scaffolding, structural validation engine, post-scaffold verification | `scaffold/` skill, `validate/` skill, `validate-structure.sh` |
| BC-5 | **Authoring Workflows** | Creating proposals, plans, ADRs, and architecture docs with correct numbering, linking, and template population | `new-proposal/`, `new-plan/`, `new-adr/`, `new-architecture-doc/` skills |
| BC-6 | **Lifecycle Management** | Proposal state machine, status transitions, side-effects (plan creation prompts, supersession) | `proposal-status/` skill, `valid-transitions.md` |
| BC-7 | **Enforcement Layer** | Deterministic guardrails: ADR immutability, proposal lifecycle freeze, post-write structural nudges | `hooks/hooks.json`, all hook scripts |
| BC-8 | **Audit System** | Multi-module discovery, per-module validation, aggregate compliance reporting | `docs-audit/` skill, `report-format.md` |

### Aggregates

#### BC-1: Plugin Infrastructure

| Aggregate | Root Entity | Description |
|---|---|---|
| **PluginManifest** | `plugin.json` | The plugin's identity, version, and metadata. Governs how Claude Code discovers and loads the plugin. |
| **DirectoryTree** | Plugin root | The complete file/directory skeleton that all other contexts populate. Must be created before any content is written. |

#### BC-2: Template Management

| Aggregate | Root Entity | Description |
|---|---|---|
| **CanonicalTemplateSet** | `scaffold/templates/` | The single source of truth for every document template. Three sub-groups: `core/` (7 templates), `lib/` (2 templates), `app/` (3 templates). |
| **TemplateCopy** | Per-skill `templates/` dir | A derived copy of a canonical template placed inside a consuming skill for self-containment. Must be byte-identical to canonical. |
| **DriftChecker** | `check-template-drift.sh` | CI-facing script that compares every TemplateCopy against its CanonicalTemplate and fails on divergence. |

#### BC-3: Knowledge System

| Aggregate | Root Entity | Description |
|---|---|---|
| **StructureSpec** | `reference/structure-spec.md` | Defines required directories and files per module type (core, lib, app) plus root-level structure. |
| **ComponentGuide** | `reference/component-guide.md` | Purpose, audience, and content expectations for every documentation component. |
| **NamingConventions** | `reference/naming-conventions.md` | `NNN-short-title.md` patterns, slug rules, zero-padding, sequence numbering. |
| **LifecycleRules** | `reference/lifecycle-rules.md` | Proposal state machine, plan lifecycle, ADR immutability contract with superseded_by exception. |
| **DDDGuide** | `reference/ddd-decomposition.md` | How to identify bounded contexts, define aggregates, map domain events, and derive tasks for implementation plans. |
| **PipelineDiagram** | `diagrams/pipeline-overview.md` | Visual representation of the Proposals → Plans → Decisions pipeline. |

#### BC-4: Scaffolding & Validation

| Aggregate | Root Entity | Description |
|---|---|---|
| **ScaffoldSkill** | `scaffold/SKILL.md` | Orchestrates module creation: reads type, creates directories, populates templates, runs validation. Supports `--root` for repo-level structure. |
| **ValidationEngine** | `validate-structure.sh` | Checks that a module's documentation structure matches the expected standard for its type. Supports `--json`, `--strict`, `--root`, `--on-write` modes. |
| **ValidateSkill** | `validate/SKILL.md` | User-facing validation interface that invokes the validation engine and formats output. |

#### BC-5: Authoring Workflows

| Aggregate | Root Entity | Description |
|---|---|---|
| **SequenceNumberer** | `next-number.sh` | Scans a target directory for `NNN-*.md` files and returns the next zero-padded sequence number. Shared via copy across proposal/plan/ADR skills. |
| **ProposalAuthoring** | `new-proposal/SKILL.md` | Creates new RFC documents with correct numbering, frontmatter, and template population. Supports `--module` and `--root`. |
| **PlanAuthoring** | `new-plan/SKILL.md` | Creates DDD implementation plans linked to accepted proposals. Reads DDD guide, pre-populates bounded contexts. Requires `--from-proposal`. |
| **ADRAuthoring** | `new-adr/SKILL.md` | Creates ADRs either standalone or linked to proposals. Handles supersession cross-referencing. |
| **ArchitectureDocAuthoring** | `new-architecture-doc/SKILL.md` | Creates architecture docs with auto-detected ADR cross-references. |

#### BC-6: Lifecycle Management

| Aggregate | Root Entity | Description |
|---|---|---|
| **ProposalStateMachine** | `valid-transitions.md` | Defines legal state transitions: `draft → in-review → accepted|rejected|superseded`. No transitions from terminal states. |
| **StatusTransitionSkill** | `proposal-status/SKILL.md` | Validates requested transition, updates frontmatter, triggers side-effects (plan creation prompt on acceptance, superseded_by prompt on supersession). |

#### BC-7: Enforcement Layer

| Aggregate | Root Entity | Description |
|---|---|---|
| **HookConfiguration** | `hooks.json` | Declares all PreToolUse and PostToolUse hooks with matchers, commands, and timeouts. |
| **FrontmatterParser** | `parse-frontmatter.sh` | Utility that extracts a named field from YAML frontmatter. Used by all guard scripts. |
| **ADRImmutabilityGuard** | `check-adr-immutability.sh` | Blocks edits to accepted/deprecated/superseded ADRs, except updates to the `superseded_by` field. |
| **ProposalLifecycleGuard** | `check-proposal-lifecycle.sh` | Blocks edits to proposals in terminal states (accepted, rejected, superseded). |

#### BC-8: Audit System

| Aggregate | Root Entity | Description |
|---|---|---|
| **ModuleDiscovery** | Audit skill logic | Finds all modules under `modulesDirectory`, determines types, filters by `ignoredModules`. |
| **AuditSkill** | `docs-audit/SKILL.md` | Orchestrates discovery, per-module validation, and aggregate reporting. Supports `--include-root`, `--format summary|detailed`. |
| **ReportFormat** | `report-format.md` | Specifies the audit output structure: per-module results, aggregate statistics, common gaps. |

### Domain Events

Events that flow between bounded contexts and trigger cross-context side-effects:

| Event | Source Context | Target Context(s) | Description |
|---|---|---|---|
| **PluginSkeletonCreated** | BC-1 (Infrastructure) | BC-2, BC-3, BC-4, BC-5, BC-6, BC-7, BC-8 | Directory tree exists; all contexts can begin populating their artifacts. |
| **CanonicalTemplatesWritten** | BC-2 (Templates) | BC-4, BC-5 | Canonical templates are ready; copies can be distributed to consuming skills. |
| **TemplateCopiesDistributed** | BC-2 (Templates) | BC-2 (DriftChecker) | All copies in place; drift checker can be implemented and verified. |
| **KnowledgeBaseComplete** | BC-3 (Knowledge) | BC-4, BC-5, BC-6 | Reference documentation is available for skills that need to read it during execution. |
| **ValidationEngineReady** | BC-4 (Scaffolding) | BC-7 (Enforcement), BC-8 (Audit) | `validate-structure.sh` is functional; hooks and audit can invoke it. |
| **ScaffoldSkillReady** | BC-4 (Scaffolding) | BC-5 (Authoring) | Scaffolding works; authoring skills can assume valid module structures exist. |
| **NextNumberScriptReady** | BC-5 (Authoring) | BC-5 (all authoring skills) | Sequence numbering works; proposal/plan/ADR creation can assign numbers. |
| **AuthoringSkillsReady** | BC-5 (Authoring) | BC-6 (Lifecycle) | Authoring is functional; lifecycle transitions can prompt for follow-up creation. |
| **FrontmatterParserReady** | BC-7 (Enforcement) | BC-7 (Guards) | Frontmatter extraction works; guard scripts can read document status. |
| **ProposalAccepted** | BC-6 (Lifecycle) | BC-5 (PlanAuthoring) | Triggers prompt to create implementation plan. |
| **ProposalSuperseded** | BC-6 (Lifecycle) | BC-5 (ProposalAuthoring) | Triggers cross-reference update on superseding proposal. |
| **ADRSuperseded** | BC-5 (ADRAuthoring) | BC-7 (Enforcement) | Existing ADR's `superseded_by` is updated — the one allowed mutation on an accepted ADR. |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Plugin Skeleton & Canonical Templates (BC-1, BC-2)

**Goal:** Create the complete directory tree and write all canonical templates.

- [ ] **1.1** Create `.claude-plugin/plugin.json` with name, version, description, author, homepage, keywords per PRD §5.5
- [ ] **1.2** Create the full directory skeleton: all skill directories, hook directories, reference directories, template directories, script directories, diagram directories — matching PRD §5.2 exactly
- [ ] **1.3** Write canonical core templates in `skills/scaffold/templates/core/`:
  - [ ] `proposal.md` (RFC template per PRD §8.1)
  - [ ] `plan.md` (DDD implementation plan template per PRD §8.2)
  - [ ] `decision.md` (ADR template per PRD §8.3)
  - [ ] `architecture.md` (Architecture doc template per PRD §8.4)
  - [ ] `README.md` (Module README template per PRD §8.5)
  - [ ] `CONTRIBUTING.md` (Module CONTRIBUTING template per PRD §8.6)
  - [ ] `CLAUDE.md` (Module CLAUDE.md template per PRD §8.7)
- [ ] **1.4** Write canonical lib templates in `skills/scaffold/templates/lib/`:
  - [ ] `INTERFACE.md` (Interface contract template per PRD §8.8)
  - [ ] `example.md` (Usage example template per PRD §8.8)
- [ ] **1.5** Write canonical app templates in `skills/scaffold/templates/app/`:
  - [ ] `runbook.md` (Runbook template per PRD §8.9)
  - [ ] `integration.md` (Integration doc template per PRD §8.9)
  - [ ] `config.md` (Configuration surface template per PRD §8.9)
- [ ] **1.6** Copy templates to consuming skills per PRD §5.4 drift table:
  - [ ] `core/proposal.md` → `new-proposal/templates/proposal.md`
  - [ ] `core/plan.md` → `new-plan/templates/plan.md`
  - [ ] `core/decision.md` → `new-adr/templates/decision.md`
  - [ ] `core/architecture.md` → `new-architecture-doc/templates/architecture.md`
- [ ] **1.7** Copy `next-number.sh` script across skills:
  - [ ] Write canonical `new-proposal/scripts/next-number.sh`
  - [ ] Copy to `new-plan/scripts/next-number.sh`
  - [ ] Copy to `new-adr/scripts/next-number.sh`

### Phase 2: Utility Scripts & Knowledge Base (BC-2, BC-3)

**Goal:** Implement all shared utilities and build the complete knowledge base.

**Depends on:** Phase 1 (directory skeleton and canonical templates exist)

- [ ] **2.1** Implement `hooks/scripts/parse-frontmatter.sh`:
  - [ ] Accept `--file <path> --field <name>` arguments
  - [ ] Extract value of named field from YAML frontmatter (between `---` delimiters)
  - [ ] Output value or empty string if not found
  - [ ] Handle edge cases: missing frontmatter, missing field, multi-word values
- [ ] **2.2** Implement `skills/new-proposal/scripts/next-number.sh`:
  - [ ] Accept `--dir <path>` argument
  - [ ] Scan directory for files matching `NNN-*.md` pattern
  - [ ] Return next number, zero-padded to 3 digits
  - [ ] Handle empty directory (return `001`)
  - [ ] Handle gaps in sequence (use max + 1, not fill gaps)
- [ ] **2.3** Implement `skills/scaffold/scripts/validate-structure.sh`:
  - [ ] Accept `--module-path <path>`, `--type core|lib|app`, `--strict`, `--json`, `--root`, `--on-write` flags
  - [ ] Define required structure per module type (core base + lib/app extensions)
  - [ ] Check directory existence, file existence, placeholder detection
  - [ ] Output human-readable report (with `✓`, `✗`, `~` markers) or JSON
  - [ ] `--on-write` mode: lightweight check, advisory output only
  - [ ] `--root` mode: validate repo-level `docs/` structure
  - [ ] Exit code: 0 for pass, 1 for fail
- [ ] **2.4** Implement `skills/scaffold/scripts/check-template-drift.sh`:
  - [ ] Define canonical-to-copy mapping per PRD §5.4 table
  - [ ] Compare each copy to its canonical source (byte-level diff)
  - [ ] Report drifted files and exit non-zero if any diverge
- [ ] **2.5** Copy utility scripts to consuming skills:
  - [ ] Copy `validate-structure.sh` → `validate/scripts/validate-structure.sh`
- [ ] **2.6** Write `skills/docs-strategy/reference/structure-spec.md`:
  - [ ] Core structure: `docs/{proposals,plans,decisions,architecture}/`, `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`
  - [ ] Lib extensions: `docs/examples/`, `INTERFACE.md`
  - [ ] App extensions: `docs/{runbooks,integration,config}/`
  - [ ] Root-level structure: `docs/{proposals,plans,decisions,architecture}/`
- [ ] **2.7** Write `skills/docs-strategy/reference/component-guide.md`:
  - [ ] Purpose, audience, content expectations for every component per PRD §4.4
- [ ] **2.8** Write `skills/docs-strategy/reference/naming-conventions.md`:
  - [ ] `NNN-short-title.md` pattern, slug rules (lowercase, hyphens, no special chars)
  - [ ] Zero-padding to 3 digits, sequence numbering rules
  - [ ] Fixed-name files: README.md, CONTRIBUTING.md, CLAUDE.md, INTERFACE.md
- [ ] **2.9** Write `skills/docs-strategy/reference/lifecycle-rules.md`:
  - [ ] Proposal lifecycle: `draft → in-review → accepted|rejected|superseded`
  - [ ] Plan lifecycle: `active → complete|abandoned`
  - [ ] ADR lifecycle: `proposed → accepted → deprecated|superseded`
  - [ ] Immutability rules, `superseded_by` exception
  - [ ] No transitions from terminal states
- [ ] **2.10** Write `skills/docs-strategy/reference/ddd-decomposition.md`:
  - [ ] What bounded contexts are, how to identify them
  - [ ] What aggregates are, how to define boundaries
  - [ ] Domain events: what they are, how they flow between contexts
  - [ ] Task decomposition: deriving concrete implementation tasks from domain analysis
  - [ ] Practical examples relevant to documentation systems
- [ ] **2.11** Write `skills/docs-strategy/diagrams/pipeline-overview.md`:
  - [ ] ASCII/text diagram of Proposals → Plans → Decisions pipeline
  - [ ] Key relationships and data flow
- [ ] **2.12** Write `skills/new-plan/reference/ddd-guide.md`:
  - [ ] Practical guide for plan authors (more concise, action-oriented version of 2.10)
  - [ ] Step-by-step process for DDD decomposition in the context of a plan

### Phase 3: SKILL.md Files — Scaffolding, Validation, Knowledge (BC-3, BC-4)

**Goal:** Write the SKILL.md definitions for background knowledge, scaffolding, and validation.

**Depends on:** Phase 2 (scripts and reference docs exist)

- [ ] **3.1** Write `skills/docs-strategy/SKILL.md`:
  - [ ] Frontmatter per PRD §6.1 (background knowledge, `user-invocable: false`)
  - [ ] Body describes when Claude should consult this skill
  - [ ] References all files in `reference/` and `diagrams/` with progressive disclosure instructions
- [ ] **3.2** Write `skills/scaffold/SKILL.md`:
  - [ ] Frontmatter per PRD §6.2 (user-invocable, allowed-tools)
  - [ ] Full workflow: parse arguments, determine type, create directories, populate templates, validate
  - [ ] Document `--root` mode for repo-level structure
  - [ ] Placeholder replacement rules: `{{MODULE_NAME}}`, `{{MODULE_TYPE}}`, `{{DATE}}`, etc.
  - [ ] Reference templates and scripts within the skill directory
- [ ] **3.3** Write `skills/validate/SKILL.md`:
  - [ ] Frontmatter per PRD §6.8 (user-invocable, allowed-tools)
  - [ ] Workflow: parse arguments, invoke validation engine, format output
  - [ ] Document `--strict`, `--json`, `--root` modes
  - [ ] Report format per PRD §6.8

### Phase 4: SKILL.md Files — Authoring Workflows (BC-5)

**Goal:** Write SKILL.md definitions for all document authoring skills.

**Depends on:** Phase 2 (next-number.sh, templates, DDD guide exist)

- [ ] **4.1** Write `skills/new-proposal/SKILL.md`:
  - [ ] Frontmatter per PRD §6.3 (user-invocable, allowed-tools)
  - [ ] Workflow: parse title, determine target (module vs root), get next number, create file from template, set frontmatter
  - [ ] Document `--module <path>` and `--root` flags
- [ ] **4.2** Write `skills/new-plan/SKILL.md`:
  - [ ] Frontmatter per PRD §6.4 (user-invocable, allowed-tools)
  - [ ] Workflow: parse title, require `--from-proposal NNN`, verify proposal is accepted, use matching number, read DDD guide, create from template, pre-populate bounded contexts
  - [ ] Reference `reference/ddd-guide.md` for decomposition guidance
  - [ ] Document plan lifecycle states: `active`, `complete`, `abandoned`
- [ ] **4.3** Write `skills/new-adr/SKILL.md`:
  - [ ] Frontmatter per PRD §6.5 (user-invocable, allowed-tools)
  - [ ] Workflow: parse title, optional `--from-proposal NNN` (verify accepted if present), assign number, create from template
  - [ ] Supersession handling: prompt for superseded ADR, update `superseded_by` on old ADR
  - [ ] Document `--module <path>` and `--root` flags
- [ ] **4.4** Write `skills/new-architecture-doc/SKILL.md`:
  - [ ] Frontmatter per PRD §6.7 (user-invocable, allowed-tools)
  - [ ] Workflow: parse title, scan decisions/ for related ADRs, create from template with ADR links
  - [ ] Document `--module <path>` and `--root` flags
- [ ] **4.5** Write `skills/proposal-status/SKILL.md`:
  - [ ] Frontmatter per PRD §6.6 (user-invocable, allowed-tools)
  - [ ] Workflow: parse identifier and target status, load current status, validate against state machine, update frontmatter
  - [ ] Side-effects: prompt for plan creation on acceptance, prompt for superseding proposal on supersession
  - [ ] Reference `reference/valid-transitions.md`
- [ ] **4.6** Write `skills/proposal-status/reference/valid-transitions.md`:
  - [ ] Full state machine: `draft → in-review → accepted|rejected|superseded`
  - [ ] Conditions and side-effects per transition
  - [ ] Error messages for invalid transitions

### Phase 5: Enforcement Hooks (BC-7)

**Goal:** Implement all hook scripts and hook configuration.

**Depends on:** Phase 2 (parse-frontmatter.sh exists)

- [ ] **5.1** Implement `hooks/scripts/check-adr-immutability.sh`:
  - [ ] Read JSON from stdin (`tool_input.file_path`)
  - [ ] Skip if path does not contain `/decisions/`
  - [ ] Skip if file does not exist (new creation)
  - [ ] Read status via `parse-frontmatter.sh`
  - [ ] If status is `accepted`, `deprecated`, or `superseded`: check if edit is limited to `superseded_by`
  - [ ] If limited to `superseded_by`: exit 0 (allow)
  - [ ] Otherwise: exit 2 (block) with descriptive message per PRD §7.2.1
  - [ ] All other cases: exit 0 (allow)
- [ ] **5.2** Implement `hooks/scripts/check-proposal-lifecycle.sh`:
  - [ ] Read JSON from stdin (`tool_input.file_path`)
  - [ ] Skip if path does not contain `/proposals/`
  - [ ] Skip if file does not exist (new creation)
  - [ ] Read status via `parse-frontmatter.sh`
  - [ ] If status is `accepted`, `rejected`, or `superseded`: exit 2 (block) with descriptive message per PRD §7.2.2
  - [ ] All other cases: exit 0 (allow)
- [ ] **5.3** Write `hooks/hooks.json`:
  - [ ] PreToolUse hooks for Edit|Write: ADR immutability guard, proposal lifecycle guard
  - [ ] PostToolUse hook for Write: post-write structure nudge
  - [ ] Exact configuration per PRD §7.1

### Phase 6: Audit & Documentation (BC-8, Plugin Docs)

**Goal:** Implement the audit skill, write the plugin README, and finalize everything.

**Depends on:** Phases 3, 4, 5 (all skills and hooks exist)

- [ ] **6.1** Write `skills/docs-audit/reference/report-format.md`:
  - [ ] Per-module result format (module name, type, component status)
  - [ ] Aggregate statistics: total modules, compliance percentage, common gaps
  - [ ] Summary vs detailed format differences
- [ ] **6.2** Write `skills/docs-audit/SKILL.md`:
  - [ ] Frontmatter per PRD §6.9 (user-invocable, allowed-tools)
  - [ ] Workflow: discover modules, determine types, run validation per module, aggregate results
  - [ ] Document `--modules-dir`, `--format summary|detailed`, `--include-root` flags
  - [ ] Module type detection: read from module's CLAUDE.md or config
- [ ] **6.3** Write plugin `README.md`:
  - [ ] Installation instructions (how to add plugin to Claude Code)
  - [ ] Configuration options per PRD §11
  - [ ] All 9 skills with usage examples
  - [ ] All hooks with behavioral descriptions
  - [ ] CI integration examples per PRD §10
  - [ ] Template customization via `customTemplatesPath`

---

## Decisions Required

Architectural decisions that should become ADRs during or after implementation:

1. **Frontmatter parsing strategy.** The PRD specifies bash-based YAML frontmatter parsing. Decide on the exact parsing approach: pure bash (sed/awk/grep) vs. requiring a YAML parser. Pure bash is sufficient given the simple frontmatter schema but has edge-case limitations.

2. **Template placeholder syntax.** The PRD uses `{{PLACEHOLDER}}` syntax. Decide on the exact replacement mechanism: sed-based substitution in bash scripts, or Claude-mediated replacement during skill execution. The PRD implies Claude handles replacement (skills use Read/Write tools), so placeholders are guidance for Claude, not machine-processed tokens.

3. **Module type storage.** The PRD notes that module type must be explicitly declared but doesn't specify where. Likely candidates: `CLAUDE.md` (Module Type section), a frontmatter field, or `.claude/settings.json` per module. This affects how `validate` and `docs-audit` determine module type.

---

## Dependencies

| Dependency | Required By | Status |
|---|---|---|
| Claude Code v2.1.3+ plugin system | Entire implementation | Assumed available |
| Bash shell with standard utilities (sed, awk, grep, find) | All scripts | Assumed available |
| Git (for author detection in templates) | Authoring skills | Assumed available |
| `jq` (for JSON output in validation) | validate-structure.sh, hooks | Optional; script should degrade gracefully |
| The PRD itself (RFC-000) | This plan | Complete (status: draft) |

---

## Acceptance Criteria

- [ ] `/scaffold packages/test-module --type core` creates the complete core documentation structure and passes `/validate`
- [ ] `/scaffold packages/test-lib --type lib` creates core + lib extensions and passes `/validate`
- [ ] `/scaffold packages/test-app --type app` creates core + app extensions and passes `/validate`
- [ ] `/scaffold --root` creates repo-level docs structure and passes `/validate --root`
- [ ] `/new-proposal test-feature --module packages/test-module` creates `001-test-feature.md` with correct frontmatter and template content
- [ ] `/new-proposal cross-cutting-change --root` creates proposal at repo root level
- [ ] `/proposal-status 001 in-review` updates frontmatter; `/proposal-status 001 accepted` updates and prompts for plan
- [ ] `/proposal-status 001 accepted` from `draft` fails (cannot skip `in-review`)
- [ ] `/new-plan test-feature --from-proposal 001` creates `001-test-feature.md` plan with DDD sections pre-populated
- [ ] `/new-plan` without `--from-proposal` to accepted proposal fails
- [ ] `/new-adr use-postgres --from-proposal 001` creates ADR linked to proposal
- [ ] `/new-adr standalone-decision` creates ADR without proposal link
- [ ] Editing an accepted ADR is blocked by the immutability hook (exit code 2)
- [ ] Updating `superseded_by` on an accepted ADR is allowed
- [ ] Editing a proposal with status `accepted`, `rejected`, or `superseded` is blocked
- [ ] Editing a proposal with status `draft` or `in-review` is allowed
- [ ] `check-template-drift.sh` passes when all copies match canonical
- [ ] `check-template-drift.sh` fails when a copy diverges
- [ ] `/docs-audit --include-root` discovers all modules and produces aggregate compliance report
- [ ] Plugin README documents all skills, hooks, and configuration options
- [ ] All skills are self-contained: each directory has everything it needs (SKILL.md, templates, scripts, reference docs)

---

## Cross-Reference Map

This plan produces artifacts that map back to PRD sections:

| PRD Section | Plan Phase | Key Tasks |
|---|---|---|
| §5 Plugin Architecture | Phase 1 | 1.1, 1.2 |
| §8 Templates | Phase 1 | 1.3–1.7 |
| §7 Hooks (utilities) | Phase 2 | 2.1 |
| §6.2 scaffold, §6.8 validate | Phase 2, 3 | 2.2–2.5, 3.2–3.3 |
| §6.1 docs-strategy | Phase 2, 3 | 2.6–2.12, 3.1 |
| §6.3 new-proposal | Phase 4 | 4.1 |
| §6.4 new-plan | Phase 4 | 4.2 |
| §6.5 new-adr | Phase 4 | 4.3 |
| §6.7 new-architecture-doc | Phase 4 | 4.4 |
| §6.6 proposal-status | Phase 4 | 4.5–4.6 |
| §7 Hooks (guards) | Phase 5 | 5.1–5.3 |
| §6.9 docs-audit | Phase 6 | 6.1–6.2 |
| §10 CI Integration | Phase 6 | 6.3 |
| §11 Configuration | Phase 6 | 6.3 |
