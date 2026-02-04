# PRD: `principled-docs` — Claude Code Plugin

**Status:** Draft
**Author:** Alex
**Date:** 2026-02-04
**Version:** 0.3.1

---

## 1. Problem Statement

Monorepo modules accumulate documentation inconsistently. Some modules have thorough architecture docs but no decision records. Others have a README and nothing else. Over time, the gap between "what the team agreed to document" and "what actually exists" widens silently. New modules are created without the expected structure. Existing modules drift. Nobody notices until someone needs a runbook at 3am or an ADR during a design review and finds nothing.

The Module Documentation Strategy defines a clear, audience-driven structure for every module — proposals, plans, decisions, architecture docs, and supporting files — but a specification without enforcement is a suggestion. CI can check that files exist, but it cannot scaffold new modules, guide authors through templates, or provide Claude Code with the contextual awareness to maintain documentation as code evolves.

This plugin bridges that gap. It gives Claude Code the knowledge, the tools, and the guardrails to treat documentation structure as a first-class concern throughout the development lifecycle.

---

## 2. Goals

1. **Scaffold correctly from the start.** When a new module is created, produce the complete documentation structure — directories, template files, and CLAUDE.md — in a single command, with no manual file creation required.

2. **Enforce continuously.** Validate that the expected documentation structure exists for every module, surfacing violations during development (via hooks) before they reach CI.

3. **Guide authorship.** Provide templates and contextual instructions for every document type — proposals, plans, ADRs, architecture docs, READMEs — so that authors produce consistent, high-quality documentation without memorizing conventions.

4. **Make Claude Code documentation-aware.** Give Claude Code the skills to understand the documentation strategy, follow naming conventions, respect document lifecycles, and assist with authoring within the established structure.

5. **Work for all module types.** Support the shared core structure, plus the lib-specific and app-specific extensions, through a single configurable plugin.

## 3. Non-Goals

- **Content quality enforcement.** The plugin checks structure and template adherence, not prose quality. Whether an ADR is well-argued is a review concern, not a tooling concern.
- **Replacing CI validation.** The plugin provides fast, local feedback during development. It complements — but does not replace — CI-level structural checks.
- **Managing document content over time.** The plugin scaffolds and validates. It does not auto-update architecture docs when code changes or deprecate ADRs when new decisions supersede them. Those are authoring tasks the plugin *assists* but does not automate.
- **External publishing.** The plugin manages source documentation files. Rendering docs to a site, generating API docs, or publishing to a wiki are separate concerns.
- **Template inheritance.** Teams override templates wholesale via `customTemplatesPath`. There is no mechanism for extending or merging with base templates.
- **Module type detection.** The plugin does not auto-detect whether a module is core, lib, or app. Module type must always be explicitly declared.

---

## 4. Core Documentation Structure

### 4.1 The Proposals → Plans → Decisions Pipeline

The documentation structure is built around a three-stage pipeline that traces the lifecycle of every significant change:

```
Proposal (RFC)  ──→  Plan (DDD Implementation)  ──→  Decision (ADR)
   "what and why"       "how, decomposed"              "what was decided"
```

**Proposals** are Requests for Comments. They describe *what* is being proposed and *why*. They are mutable while in draft and review, frozen once they reach a terminal state (accepted, rejected, superseded).

**Plans** are implementation breakdowns that bridge an accepted proposal and its resulting decisions. They use domain-driven development to decompose the work into bounded contexts, aggregates, and tasks. A plan is the tactical counterpart to a proposal's strategic intent. Plans are mutable throughout implementation and marked complete when all tasks are done.

**Decisions** are Architectural Decision Records. They capture *what was decided*, the options considered, and the consequences expected. They are immutable after acceptance, with one exception: the `superseded_by` field may be updated when a new ADR supersedes an existing one.

### 4.2 Shared Core (All Modules)

```
docs/
├── proposals/               # RFC proposals with lifecycle management
├── plans/                   # DDD implementation plans bridging proposals and decisions
├── decisions/               # Architectural Decision Records (immutable post-acceptance)
├── architecture/            # Living documentation of current design
README.md                    # Module front door
CONTRIBUTING.md              # Module-specific build/test/PR conventions
CLAUDE.md                    # Module-scoped AI development context
```

### 4.3 Root-Level Structure (Multi-Module)

Cross-cutting proposals, plans, and decisions that affect multiple modules live in a root-level docs structure, parallel to the module-level structure:

```
repo-root/
├── docs/
│   ├── proposals/           # Cross-cutting RFCs
│   ├── plans/               # Cross-cutting implementation plans
│   ├── decisions/           # Cross-cutting ADRs
│   └── architecture/        # System-wide architecture docs
├── packages/
│   ├── module-a/
│   │   ├── docs/
│   │   │   ├── proposals/
│   │   │   ├── plans/
│   │   │   ├── decisions/
│   │   │   └── architecture/
│   │   ├── README.md
│   │   ├── CONTRIBUTING.md
│   │   └── CLAUDE.md
│   └── module-b/
│       └── ...
```

The root structure follows identical conventions — same naming, same templates, same lifecycle rules. The only difference is scope: root-level documents affect the system, module-level documents affect the module.

### 4.4 Component Definitions

| Component | Nature | Mutability | Naming Convention | Audience |
|---|---|---|---|---|
| `proposals/` | RFC proposals | Mutable while draft/review; frozen on acceptance | `NNN-short-title.md` | Maintainers, reviewers |
| `plans/` | DDD implementation plans | Mutable during implementation; marked complete when done | `NNN-short-title.md` (matches originating proposal) | Implementers, maintainers |
| `decisions/` | Architectural Decision Records | Immutable after acceptance (exception: `superseded_by`) | `NNN-short-title.md` (matches originating proposal where applicable) | Future maintainers |
| `architecture/` | Living design documentation | Updated as design evolves | Freeform descriptive names | Onboarding engineers |
| `README.md` | Module orientation | Updated as module evolves | Fixed name | Everyone |
| `CONTRIBUTING.md` | Development conventions | Updated as tooling changes | Fixed name | Contributors |
| `CLAUDE.md` | AI development context | Updated as patterns evolve | Fixed name | Claude Code |

### 4.5 Lib Extensions

```
docs/
├── examples/                # Worked usage examples, organized by use case
INTERFACE.md                 # Public API surface, stability guarantees, invariants
```

### 4.6 App Extensions

```
docs/
├── runbooks/                # Operational procedures (one per incident type)
├── integration/             # External dependency documentation
├── config/                  # Environment and configuration surface docs
```

### 4.7 Governing Principles

These principles are not decorative. They drive enforcement and template design throughout the plugin.

- **Existence is enforced, content is organic.** Structure must be present. Placeholder TODOs are acceptable. Missing files are not.
- **Living docs reference immutable records.** Architecture docs link to the ADRs that produced them. ADRs are never modified after acceptance (except `superseded_by`).
- **Docs have audiences.** Every file exists for a named reader in a named situation. Templates encode this by including audience and purpose headers.
- **Proposals have lifecycles.** Draft → In Review → Accepted / Rejected / Superseded. Acceptance triggers plan creation and ultimately ADR creation.
- **Plans use domain-driven decomposition.** Implementation plans break work into bounded contexts, aggregates, and concrete tasks rather than arbitrary work items.

---

## 5. Plugin Architecture

### 5.1 Design Principles

**Skills are the single unit of capability.** Since Claude Code v2.1.3, skills and slash commands are unified. Every skill is also a command. There is no separate `commands/` directory.

**Skills are self-contained.** Each skill directory co-locates everything it needs: the SKILL.md definition, reference documentation, templates, and scripts. Claude loads supporting files through progressive disclosure — they exist in the skill directory and are referenced from SKILL.md when needed. Nothing lives at the plugin root except the manifest, hooks, and plugin-level documentation.

**Hooks are the enforcement layer.** Skills handle generative workflows (scaffolding, authoring). Hooks handle deterministic guardrails (immutability, lifecycle). The two never overlap in responsibility.

**Templates are duplicated, drift is checked.** Several skills use the same template (e.g., the proposal template exists in both `scaffold` and `new-proposal`). The duplication is intentional — each skill must be self-contained. A CI check validates that duplicated templates remain in sync with the canonical copy in `scaffold`.

### 5.2 Directory Layout

```
principled-docs/
├── .claude-plugin/
│   └── plugin.json                          # Plugin manifest
├── skills/
│   ├── docs-strategy/
│   │   ├── SKILL.md                         # Background knowledge skill
│   │   ├── reference/
│   │   │   ├── structure-spec.md            # Complete structure specification
│   │   │   ├── component-guide.md           # Purpose and audience per component
│   │   │   ├── naming-conventions.md        # NNN-short-title and other patterns
│   │   │   ├── lifecycle-rules.md           # Proposal/plan/decision lifecycles
│   │   │   └── ddd-decomposition.md         # DDD concepts for implementation plans
│   │   └── diagrams/
│   │       └── pipeline-overview.md         # Proposals → Plans → Decisions pipeline
│   │
│   ├── scaffold/
│   │   ├── SKILL.md                         # Module scaffolding skill (also /scaffold)
│   │   ├── templates/                       # CANONICAL template set — source of truth
│   │   │   ├── core/
│   │   │   │   ├── proposal.md              # RFC template
│   │   │   │   ├── plan.md                  # DDD implementation plan template
│   │   │   │   ├── decision.md              # ADR template
│   │   │   │   ├── architecture.md          # Architecture doc template
│   │   │   │   ├── README.md                # Module README template
│   │   │   │   ├── CONTRIBUTING.md          # Module CONTRIBUTING template
│   │   │   │   └── CLAUDE.md                # Module CLAUDE.md template
│   │   │   ├── lib/
│   │   │   │   ├── INTERFACE.md             # Interface contract template
│   │   │   │   └── example.md               # Usage example template
│   │   │   └── app/
│   │   │       ├── runbook.md               # Runbook template
│   │   │       ├── integration.md           # Integration doc template
│   │   │       └── config.md                # Configuration surface template
│   │   └── scripts/
│   │       ├── validate-structure.sh        # Structural validation (canonical copy)
│   │       └── check-template-drift.sh      # CI script: verify template copies match canonical
│   │
│   ├── new-proposal/
│   │   ├── SKILL.md                         # Proposal creation skill (also /new-proposal)
│   │   ├── templates/
│   │   │   └── proposal.md                  # RFC template (copy of scaffold's)
│   │   └── scripts/
│   │       └── next-number.sh               # Determine next NNN sequence number
│   │
│   ├── new-plan/
│   │   ├── SKILL.md                         # Implementation plan creation skill (also /new-plan)
│   │   ├── templates/
│   │   │   └── plan.md                      # DDD plan template (copy of scaffold's)
│   │   ├── reference/
│   │   │   └── ddd-guide.md                 # DDD decomposition guide for plans
│   │   └── scripts/
│   │       └── next-number.sh               # Numbering logic (copy)
│   │
│   ├── new-adr/
│   │   ├── SKILL.md                         # ADR creation skill (also /new-adr)
│   │   ├── templates/
│   │   │   └── decision.md                  # ADR template (copy of scaffold's)
│   │   └── scripts/
│   │       └── next-number.sh               # Numbering logic (copy)
│   │
│   ├── proposal-status/
│   │   ├── SKILL.md                         # Proposal lifecycle transition skill (also /proposal-status)
│   │   └── reference/
│   │       └── valid-transitions.md         # State machine definition
│   │
│   ├── new-architecture-doc/
│   │   ├── SKILL.md                         # Architecture doc creation skill
│   │   └── templates/
│   │       └── architecture.md              # Architecture doc template (copy of scaffold's)
│   │
│   ├── validate/
│   │   ├── SKILL.md                         # Validation skill (also /validate)
│   │   └── scripts/
│   │       └── validate-structure.sh        # Validation engine (copy of scaffold's)
│   │
│   └── docs-audit/
│       ├── SKILL.md                         # Monorepo-wide audit skill (also /docs-audit)
│       └── reference/
│           └── report-format.md             # Audit output format specification
│
├── hooks/
│   ├── hooks.json                           # Hook definitions (auto-discovered by Claude Code v2.1+)
│   └── scripts/
│       ├── check-adr-immutability.sh        # PreToolUse: block accepted ADR edits (allows superseded_by)
│       ├── check-proposal-lifecycle.sh      # PreToolUse: block terminal proposal edits
│       └── parse-frontmatter.sh             # Frontmatter parsing utility for hook scripts
│
└── README.md                                # Plugin installation and usage documentation
```

### 5.3 Rationale for `hooks/scripts/`

Hook scripts live alongside `hooks.json` in the `hooks/` directory, following the official Claude Code plugin structure. This is the standard placement for two reasons. First, hooks are not skills — they are deterministic shell commands triggered by Claude Code lifecycle events, with no SKILL.md and no progressive disclosure. They belong with their configuration, not distributed across skill directories. Second, plugin auto-discovery in Claude Code v2.1+ locates `hooks/hooks.json` at the plugin root. Co-locating the scripts that `hooks.json` references keeps the enforcement layer self-contained and auditable as a unit.

Scripts that are only used by a single skill live in that skill's `scripts/` directory. Scripts that are only used by hooks live in `hooks/scripts/`. There is no `shared/` directory — if a utility (e.g., frontmatter parsing) is needed by both a hook and a skill, each maintains its own copy, and the CI drift check validates they remain in sync.

### 5.4 Template Duplication Strategy

The `scaffold` skill owns the canonical set of templates. Other skills (e.g., `new-proposal`, `new-plan`, `new-adr`, `new-architecture-doc`) maintain their own copies for self-containment. A CI script (`skills/scaffold/scripts/check-template-drift.sh`) validates that all copies match their canonical source. Drift is a CI failure.

The drift check compares:

| Canonical (in `scaffold/templates/`) | Copy location |
|---|---|
| `core/proposal.md` | `new-proposal/templates/proposal.md` |
| `core/plan.md` | `new-plan/templates/plan.md` |
| `core/decision.md` | `new-adr/templates/decision.md` |
| `core/architecture.md` | `new-architecture-doc/templates/architecture.md` |
| `validate-structure.sh` | `validate/scripts/validate-structure.sh` |
| `next-number.sh` (in `new-proposal/`) | `new-plan/scripts/next-number.sh`, `new-adr/scripts/next-number.sh` |

### 5.5 Plugin Manifest

```json
{
  "name": "principled-docs",
  "version": "0.3.1",
  "description": "Scaffold, author, and enforce module documentation structure following the Principled specification-first methodology.",
  "author": "Alex",
  "homepage": "https://github.com/<org>/principled-docs",
  "keywords": ["documentation", "rfc", "adr", "specification-first", "monorepo", "ddd"]
}
```

---

## 6. Skills

Every skill is also a slash command. The skill directory name becomes the command name. Skills activate either automatically (when Claude determines relevance from the description) or explicitly (when the user types `/skill-name`).

### 6.1 `docs-strategy` — Core Knowledge Skill

**Type:** Background knowledge (not directly invocable)
**Directory:** `skills/docs-strategy/`

**SKILL.md frontmatter:**

```yaml
name: docs-strategy
description: >
  Module documentation strategy for the Principled framework.
  Consult when working with proposals/, plans/, decisions/, architecture/ directories,
  README, CONTRIBUTING, CLAUDE, or INTERFACE files in any module.
  Covers the proposals → plans → decisions pipeline, naming conventions,
  lifecycle rules, DDD decomposition, and audience definitions.
user-invocable: false
```

**Purpose:** Gives Claude Code comprehensive understanding of the documentation strategy so it makes correct decisions during any documentation-related task. This skill is never invoked directly — it informs Claude's behavior when it encounters docs-related context.

**Co-located reference files:**

| File | Purpose |
|---|---|
| `reference/structure-spec.md` | Complete structural definition per module type: which directories and files are required for core, lib, and app modules, plus the root-level structure |
| `reference/component-guide.md` | Purpose, audience, and content expectations for every component |
| `reference/naming-conventions.md` | `NNN-short-title.md` patterns, slug rules, sequence numbering |
| `reference/lifecycle-rules.md` | Proposal state machine, plan lifecycle, ADR immutability contract (including `superseded_by` exception), valid transitions |
| `reference/ddd-decomposition.md` | How to apply domain-driven development concepts when creating implementation plans: bounded contexts, aggregates, domain events, task decomposition |
| `diagrams/pipeline-overview.md` | Visual representation of the proposals → plans → decisions pipeline |

### 6.2 `scaffold` — Module Scaffolding

**Type:** User-invocable skill / slash command
**Directory:** `skills/scaffold/`
**Command:** `/scaffold <module-path> --type core|lib|app`

**SKILL.md frontmatter:**

```yaml
name: scaffold
description: >
  Generate the complete documentation structure for a new module.
  Use when creating a new app or lib module, or when asked to
  scaffold, initialize, or set up module documentation.
  Module type must be specified explicitly.
allowed-tools: Read, Write, Bash(mkdir *), Bash(ls *), Bash(cp *)
user-invocable: true
```

**Co-located files:**

| File | Purpose |
|---|---|
| `templates/core/proposal.md` | RFC template (canonical) |
| `templates/core/plan.md` | DDD implementation plan template (canonical) |
| `templates/core/decision.md` | ADR template (canonical) |
| `templates/core/architecture.md` | Architecture doc template (canonical) |
| `templates/core/README.md` | Module README template (canonical) |
| `templates/core/CONTRIBUTING.md` | Module CONTRIBUTING template (canonical) |
| `templates/core/CLAUDE.md` | Module CLAUDE.md template (canonical) |
| `templates/lib/INTERFACE.md` | Interface contract template (canonical) |
| `templates/lib/example.md` | Usage example template (canonical) |
| `templates/app/runbook.md` | Runbook template (canonical) |
| `templates/app/integration.md` | Integration doc template (canonical) |
| `templates/app/config.md` | Configuration surface template (canonical) |
| `scripts/validate-structure.sh` | Post-scaffold validation (canonical) |
| `scripts/check-template-drift.sh` | CI: verify template copies match canonical |

**Workflow:**
1. Accept module root path and `--type` flag from `$ARGUMENTS` (type is required)
2. Create directory tree for the determined type (core directories plus type-specific extensions)
3. Read each template from the skill's `templates/` directory
4. Replace placeholders with actual values
5. Write populated files to the target module
6. Run validation script to confirm structure is complete
7. Report created structure to user

**Also scaffolds root-level structure** when invoked with `--root`:
```
/scaffold --root
```
Creates the repo-root `docs/` structure with `proposals/`, `plans/`, `decisions/`, and `architecture/` directories.

### 6.3 `new-proposal` — Proposal (RFC) Creation

**Type:** User-invocable skill / slash command
**Directory:** `skills/new-proposal/`
**Command:** `/new-proposal <short-title> [--module <path>] [--root]`

**SKILL.md frontmatter:**

```yaml
name: new-proposal
description: >
  Create a new proposal (RFC) document.
  Use when proposing a change, new feature, or architectural decision
  that needs team review. Handles numbering, naming, and template population.
  Use --root for cross-cutting proposals that affect multiple modules.
allowed-tools: Read, Write, Bash(ls *), Bash(wc *)
user-invocable: true
```

**Co-located files:**

| File | Purpose |
|---|---|
| `templates/proposal.md` | RFC template (copy of `scaffold/templates/core/proposal.md`) |
| `scripts/next-number.sh` | Scans a directory for `NNN-*.md` files, returns next number zero-padded to 3 digits |

**Workflow:**
1. Parse short title from `$ARGUMENTS`; determine target (`--module` for module-level, `--root` for repo-level)
2. Run `scripts/next-number.sh --dir <target>/docs/proposals/` to get next sequence number
3. Create `NNN-<short-title>.md` from template
4. Set frontmatter: `status: draft`, `number: NNN`, `created: <today>`, `author: <git user>`
5. Pre-populate context section from available module information
6. List architecture docs that may need updating if this proposal is accepted
7. Confirm creation and remind user of next steps

### 6.4 `new-plan` — Implementation Plan Creation

**Type:** User-invocable skill / slash command
**Directory:** `skills/new-plan/`
**Command:** `/new-plan <short-title> --from-proposal NNN [--module <path>] [--root]`

**SKILL.md frontmatter:**

```yaml
name: new-plan
description: >
  Create a DDD implementation plan from an accepted proposal.
  Plans bridge proposals and decisions by decomposing work into
  bounded contexts, aggregates, and concrete tasks using
  domain-driven development. Use when an accepted proposal needs
  a tactical implementation breakdown before work begins.
allowed-tools: Read, Write, Bash(ls *), Bash(grep *), Bash(find *)
user-invocable: true
```

**Co-located files:**

| File | Purpose |
|---|---|
| `templates/plan.md` | DDD implementation plan template (copy of `scaffold/templates/core/plan.md`) |
| `reference/ddd-guide.md` | Practical guide to DDD decomposition for plans: how to identify bounded contexts, define aggregates, map domain events, and derive implementation tasks |
| `scripts/next-number.sh` | Numbering logic (copy) |

**Workflow:**
1. Parse title and `--from-proposal NNN` from `$ARGUMENTS` (linking to a proposal is required)
2. Locate the originating proposal; verify its status is `accepted`
3. Use matching number from the proposal (plan NNN matches proposal NNN)
4. Read `reference/ddd-guide.md` for decomposition guidance
5. Create `NNN-<short-title>.md` from template
6. Set frontmatter: `status: active`, `originating_proposal: NNN`
7. Pre-populate the bounded contexts section from the proposal's scope
8. Confirm creation

**Plan lifecycle states:**
- `active` — work is in progress
- `complete` — all tasks are done; related ADRs have been created
- `abandoned` — plan was abandoned (proposal may still stand)

### 6.5 `new-adr` — ADR Creation

**Type:** User-invocable skill / slash command
**Directory:** `skills/new-adr/`
**Command:** `/new-adr <short-title> [--from-proposal NNN] [--module <path>] [--root]`

**SKILL.md frontmatter:**

```yaml
name: new-adr
description: >
  Create a new Architectural Decision Record (ADR).
  Use when recording an architectural decision, either standalone
  or linked to an accepted proposal. Handles numbering and cross-referencing.
  ADRs are immutable after acceptance except for the superseded_by field.
allowed-tools: Read, Write, Bash(ls *), Bash(grep *)
user-invocable: true
```

**Co-located files:**

| File | Purpose |
|---|---|
| `templates/decision.md` | ADR template (copy of `scaffold/templates/core/decision.md`) |
| `scripts/next-number.sh` | Numbering logic (copy) |

**Workflow:**
1. Parse title and flags from `$ARGUMENTS`
2. If `--from-proposal NNN`: read the proposal, verify status is `accepted`, use matching number and title, copy context
3. If no `--from-proposal`: assign next available number independently
4. Create `NNN-<short-title>.md` from template
5. Set frontmatter: `status: proposed`, `originating_proposal: NNN|null`
6. Identify architecture docs that should reference this ADR
7. Confirm creation

### 6.6 `proposal-status` — Proposal Lifecycle Transitions

**Type:** User-invocable skill / slash command
**Directory:** `skills/proposal-status/`
**Command:** `/proposal-status <number-or-path> <new-status> [--module <path>] [--root]`

**SKILL.md frontmatter:**

```yaml
name: proposal-status
description: >
  Transition a proposal through its lifecycle states.
  Valid transitions: draft → in-review → accepted|rejected|superseded.
  On acceptance, prompts to create a corresponding implementation plan.
allowed-tools: Read, Write, Bash(ls *), Bash(grep *), Bash(sed *)
user-invocable: true
```

**Co-located files:**

| File | Purpose |
|---|---|
| `reference/valid-transitions.md` | State machine definition with every legal transition and conditions/side-effects |

**State machine:**

```
draft ──→ in-review ──→ accepted
                    ──→ rejected
                    ──→ superseded
```

No transitions from terminal states. No skipping states.

**Workflow:**
1. Parse identifier and target status from `$ARGUMENTS`
2. Locate the proposal; read current status from frontmatter
3. Validate the transition against `reference/valid-transitions.md`
4. If invalid: report error with legal transitions from current state
5. If valid: update frontmatter `status` and `updated` fields
6. If transitioning to `accepted`: prompt user to create an implementation plan via `/new-plan`
7. If transitioning to `superseded`: prompt for the superseding proposal number; set `superseded_by`

### 6.7 `new-architecture-doc` — Architecture Doc Creation

**Type:** User-invocable skill / slash command
**Directory:** `skills/new-architecture-doc/`
**Command:** `/new-architecture-doc <title> [--module <path>] [--root]`

**SKILL.md frontmatter:**

```yaml
name: new-architecture-doc
description: >
  Create a new architecture document describing current design.
  Use when documenting a component, data flow, or system design
  that onboarding engineers need to understand.
allowed-tools: Read, Write, Bash(ls *), Bash(find *)
user-invocable: true
```

**Co-located files:**

| File | Purpose |
|---|---|
| `templates/architecture.md` | Architecture doc template (copy of `scaffold/templates/core/architecture.md`) |

**Workflow:**
1. Parse title and target (module or root)
2. Scan `decisions/` for related ADRs to cross-reference
3. Create document from template with ADR links pre-populated
4. Set `last_updated` and `related_adrs` in frontmatter

### 6.8 `validate` — Structural Validation

**Type:** User-invocable skill / slash command
**Directory:** `skills/validate/`
**Command:** `/validate [module-path] --type core|lib|app [--strict] [--root]`

**SKILL.md frontmatter:**

```yaml
name: validate
description: >
  Check documentation structure against the expected standard.
  Reports missing directories, missing files, and placeholder-only content.
  Use after scaffolding, during review, or to check compliance.
  Use --root to validate the repo-level docs structure.
allowed-tools: Read, Bash(find *), Bash(ls *), Bash(cat *), Bash(grep *)
user-invocable: true
```

**Co-located files:**

| File | Purpose |
|---|---|
| `scripts/validate-structure.sh` | Validation engine (copy of `scaffold/scripts/validate-structure.sh`) |

**Behavior:**
- If no path given, validates current working directory
- `--root` validates the repo-level `docs/` structure
- Checks for presence of all required directories and files per module type
- Reports each component as: `present`, `missing`, or `placeholder`
- `--strict` mode treats placeholder-only files as warnings
- `--json` flag produces machine-readable output for CI
- Exits with actionable remediation suggestions

**Report format:**

```
Module: packages/auth-service (app)
─────────────────────────────────────
✓ docs/proposals/          exists (2 files)
✓ docs/plans/              exists (1 file)
✓ docs/decisions/          exists (1 file)
✗ docs/architecture/       MISSING
✓ docs/runbooks/           exists (3 files)
✓ docs/integration/        exists (1 file)
~ docs/config/             placeholder only
✓ README.md                exists
✓ CONTRIBUTING.md          exists
✗ CLAUDE.md                MISSING
─────────────────────────────────────
Result: FAIL (2 missing, 1 placeholder)
```

### 6.9 `docs-audit` — Monorepo-Wide Audit

**Type:** User-invocable skill / slash command
**Directory:** `skills/docs-audit/`
**Command:** `/docs-audit [--modules-dir <path>] [--format summary|detailed] [--include-root]`

**SKILL.md frontmatter:**

```yaml
name: docs-audit
description: >
  Audit documentation health across all modules in the monorepo.
  Discovers modules, validates each, and produces an aggregate compliance report.
  Use --include-root to also validate the repo-level docs structure.
allowed-tools: Read, Bash(find *), Bash(ls *), Bash(cat *), Bash(grep *), Bash(wc *)
user-invocable: true
```

**Co-located files:**

| File | Purpose |
|---|---|
| `reference/report-format.md` | Specification of the audit output format |

**Behavior:**
- Discovers all modules within the specified directory
- Runs structural validation on each module (type must be declared in module's config or CLAUDE.md)
- `--include-root` adds the repo-level `docs/` structure to the audit
- Produces aggregate report: total modules, compliance percentage, common gaps
- `--format detailed` includes per-module breakdown

---

## 7. Hooks

Hooks provide deterministic, automated enforcement that runs without explicit user action. Hook scripts live in `hooks/scripts/`, co-located with the `hooks.json` configuration they serve.

### 7.1 Hook Configuration

**File:** `hooks/hooks.json`

```json
{
  "description": "Principled docs enforcement: ADR immutability and proposal lifecycle guards",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/check-adr-immutability.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/check-proposal-lifecycle.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/skills/scaffold/scripts/validate-structure.sh --on-write",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

### 7.2 Hook Definitions

#### 7.2.1 ADR Immutability Guard

**Event:** `PreToolUse` on `Edit` and `Write`
**Script:** `hooks/scripts/check-adr-immutability.sh`

**Behavior:**
- Receives JSON via stdin containing `tool_input.file_path`
- If path does not contain `/decisions/`: exit 0 (allow)
- If file does not exist yet (new creation): exit 0 (allow)
- Reads frontmatter `status` field using `parse-frontmatter.sh`
- If status is `accepted`, `deprecated`, or `superseded`:
  - Parse the incoming edit to check if it *only* modifies the `superseded_by` frontmatter field
  - If the edit is limited to `superseded_by`: exit 0 (allow — this is the exception)
  - Otherwise: exit 2 (block) with message:
    *"Cannot modify ADR-NNN: this record has been accepted and is immutable. The only permitted change is setting superseded_by when a new ADR supersedes this one. To change this decision, create a new ADR. Use /new-adr."*
- Otherwise: exit 0 (allow)

#### 7.2.2 Proposal Lifecycle Guard

**Event:** `PreToolUse` on `Edit` and `Write`
**Script:** `hooks/scripts/check-proposal-lifecycle.sh`

**Behavior:**
- Receives JSON via stdin containing `tool_input.file_path`
- If path does not contain `/proposals/`: exit 0 (allow)
- If file does not exist yet: exit 0 (allow)
- Reads frontmatter `status` field
- If status is `accepted`, `rejected`, or `superseded`: exit 2 (block) with message:
  *"Cannot modify proposal NNN: this proposal has reached terminal status. To propose changes, create a new proposal that supersedes it. Use /new-proposal."*
- Otherwise: exit 0 (allow)

#### 7.2.3 Post-Write Structure Nudge

**Event:** `PostToolUse` on `Write`
**Script:** `skills/scaffold/scripts/validate-structure.sh --on-write`

**Behavior:**
- After any file write, determines which module the file belongs to
- Runs lightweight structural check
- If violations detected: outputs warning (advisory, does not block)
- If file is not inside a known module or root docs: silently exits 0

### 7.3 Hook Utilities

**`hooks/scripts/parse-frontmatter.sh`** — Extracts a named field from YAML frontmatter.

**Inputs:** `--file <path> --field <name>`
**Output:** The value of the specified frontmatter field, or empty string if not found.

---

## 8. Templates

Every template lives inside the skill that uses it. The `scaffold` skill owns the canonical set. Other skills maintain copies. CI enforces that copies match.

### 8.1 Proposal (RFC) Template

**Canonical:** `skills/scaffold/templates/core/proposal.md`

```markdown
---
title: "{{TITLE}}"
number: {{NUMBER}}
status: draft
author: {{AUTHOR}}
created: {{DATE}}
updated: {{DATE}}
supersedes: null
superseded_by: null
---

# RFC-{{NUMBER}}: {{TITLE}}

## Audience

<!-- Who needs to review this? Who will be affected by this decision? -->

TODO

## Context

<!-- What is the current state? What problem or opportunity motivates this proposal? -->

TODO

## Proposal

<!-- What specifically are you proposing? Be concrete and precise. -->

TODO

## Alternatives Considered

<!-- What other approaches were evaluated? Why were they not chosen? -->

### Alternative 1: TODO

### Alternative 2: TODO

## Consequences

### Positive

TODO

### Negative

TODO

### Risks

TODO

## Architecture Impact

<!-- Which architecture docs will need to be created or updated if this proposal is accepted? -->

TODO

## Open Questions

TODO
```

### 8.2 Implementation Plan Template (DDD)

**Canonical:** `skills/scaffold/templates/core/plan.md`

```markdown
---
title: "{{TITLE}}"
number: {{NUMBER}}
status: active
author: {{AUTHOR}}
created: {{DATE}}
updated: {{DATE}}
originating_proposal: {{PROPOSAL_NUMBER}}
---

# Plan-{{NUMBER}}: {{TITLE}}

## Objective

<!-- What does this plan accomplish? Link to the originating proposal. -->

Implements [RFC-{{PROPOSAL_NUMBER}}](../proposals/{{PROPOSAL_NUMBER}}-{{PROPOSAL_SLUG}}.md).

TODO

## Domain Analysis

### Bounded Contexts

<!-- What are the distinct areas of domain responsibility affected by this work? -->

TODO

### Aggregates

<!-- What are the core domain objects and their boundaries? -->

TODO

### Domain Events

<!-- What events flow between contexts? What state transitions matter? -->

TODO

## Implementation Tasks

<!-- Concrete, ordered tasks derived from the domain analysis. Each task should map to one or more bounded contexts. -->

### Phase 1: TODO

- [ ] TODO

### Phase 2: TODO

- [ ] TODO

## Decisions Required

<!-- What architectural decisions need to be made during implementation? Each should become an ADR. -->

TODO

## Dependencies

<!-- What must be in place before implementation can begin? -->

TODO

## Acceptance Criteria

<!-- How do we know this plan is complete? -->

TODO
```

### 8.3 ADR Template

**Canonical:** `skills/scaffold/templates/core/decision.md`

```markdown
---
title: "{{TITLE}}"
number: {{NUMBER}}
status: proposed
author: {{AUTHOR}}
created: {{DATE}}
originating_proposal: {{PROPOSAL_NUMBER_OR_NULL}}
superseded_by: null
---

# ADR-{{NUMBER}}: {{TITLE}}

## Status

Proposed

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

<!-- What forces are at play? What is the technical and business context? -->

TODO

## Decision

<!-- What is the decision? State it clearly and unambiguously. -->

TODO

## Options Considered

### Option 1: TODO

### Option 2: TODO

### Option 3: TODO

## Consequences

### Positive

TODO

### Negative

TODO

## References

<!-- Links to originating proposal, implementation plan, related ADRs, architecture docs -->

TODO
```

### 8.4 Architecture Doc Template

**Canonical:** `skills/scaffold/templates/core/architecture.md`

```markdown
---
title: "{{TITLE}}"
last_updated: {{DATE}}
related_adrs: []
---

# {{TITLE}}

## Purpose

<!-- What does this document describe? Who is the intended reader? -->

TODO

## Overview

TODO

## Key Abstractions

TODO

## Component Relationships

TODO

## Data Flow

TODO

## Key Decisions

<!-- Link to the ADRs that produced this design. -->

TODO

## Constraints and Invariants

TODO
```

### 8.5 README Template

**Canonical:** `skills/scaffold/templates/core/README.md`

```markdown
# {{MODULE_NAME}}

<!-- Module purpose in one sentence. -->

TODO

## Ownership

| Role | Owner |
|------|-------|
| Maintainer | TODO |
| Team | TODO |

## Quick Start

TODO

## Documentation

- [Architecture](docs/architecture/) — How it works
- [Proposals](docs/proposals/) — Proposed changes (RFCs)
- [Plans](docs/plans/) — Implementation breakdowns (DDD)
- [Decisions](docs/decisions/) — Why it works this way (ADRs)
- [Contributing](CONTRIBUTING.md) — How to contribute
```

### 8.6 CONTRIBUTING Template

**Canonical:** `skills/scaffold/templates/core/CONTRIBUTING.md`

```markdown
# Contributing to {{MODULE_NAME}}

## Build

TODO

## Test

TODO

## Lint

TODO

## Pull Request Process

TODO

## Module-Specific Conventions

TODO
```

### 8.7 CLAUDE.md Template

**Canonical:** `skills/scaffold/templates/core/CLAUDE.md`

```markdown
# {{MODULE_NAME}} — Claude Code Context

## Module Type

{{MODULE_TYPE}}

## Key Conventions

TODO

## Documentation Structure

This module follows the Principled docs strategy:
- `docs/proposals/` — RFCs (proposals). Naming: `NNN-short-title.md`.
- `docs/plans/` — DDD implementation plans. Naming: `NNN-short-title.md` (matches proposal).
- `docs/decisions/` — ADRs (immutable after acceptance). Naming: `NNN-short-title.md`.
- `docs/architecture/` — Living design documentation.

## Pipeline

Proposals → Plans → Decisions. Proposals are strategic (what/why). Plans are tactical
(how, decomposed via DDD). Decisions are the permanent record (what was decided).

## Important Constraints

- Proposals with terminal status (accepted/rejected/superseded) must NOT be modified.
- ADRs with status `accepted` must NOT be modified (exception: `superseded_by` field).
- Plans require an accepted proposal (`--from-proposal NNN`).
- New architectural decisions follow the pipeline: proposal → plan → ADR.

## Testing

TODO

## Dependencies

TODO
```

### 8.8 Lib-Specific Templates

**INTERFACE.md** (`skills/scaffold/templates/lib/INTERFACE.md`):

```markdown
# {{MODULE_NAME}} — Interface Contract

## Public API Surface

<!-- If it's not listed here, it's internal. -->

TODO

## Stability Guarantees

| Export | Stability | Since |
|--------|-----------|-------|
| TODO | stable | TODO |

## Key Invariants

TODO

## Deprecation Policy

TODO
```

**example.md** (`skills/scaffold/templates/lib/example.md`):

```markdown
# Example: {{EXAMPLE_TITLE}}

## Use Case

TODO

## Code

TODO

## Notes

TODO
```

### 8.9 App-Specific Templates

**runbook.md** (`skills/scaffold/templates/app/runbook.md`):

```markdown
# Runbook: {{TITLE}}

## Symptoms

TODO

## Diagnosis

TODO

## Remediation

TODO

## Escalation

TODO

## Prevention

TODO
```

**integration.md** (`skills/scaffold/templates/app/integration.md`):

```markdown
# Integration: {{DEPENDENCY_NAME}}

## Connection Details

| Property | Value |
|----------|-------|
| Type | TODO |
| Protocol | TODO |
| Authentication | TODO |

## Failure Modes

TODO

## Retry Behavior

TODO

## Health Check

TODO
```

**config.md** (`skills/scaffold/templates/app/config.md`):

```markdown
# Configuration: {{MODULE_NAME}}

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| TODO | TODO | TODO | TODO |

## Feature Flags

TODO

## Secrets

<!-- List by name and purpose. NEVER include values. -->

| Secret | Purpose | Rotation Policy |
|--------|---------|-----------------|
| TODO | TODO | TODO |

## Environment Differences

### Production

TODO

### Staging

TODO
```

---

## 9. User Workflows

### 9.1 Creating a New Module

```
Developer: /scaffold packages/payment-gateway --type app

Claude Code:
  1. Creates docs/proposals/, docs/plans/, docs/decisions/, docs/architecture/
  2. Creates docs/runbooks/, docs/integration/, docs/config/   (app-specific)
  3. Populates README.md, CONTRIBUTING.md, CLAUDE.md
  4. Runs validation → all checks pass

Output:
  ✓ Scaffolded app module at packages/payment-gateway
  Created 7 directories, 10 files
```

### 9.2 Scaffolding Root-Level Docs

```
Developer: /scaffold --root

Claude Code:
  1. Creates docs/proposals/, docs/plans/, docs/decisions/, docs/architecture/
  2. Confirms root-level structure is in place for cross-cutting concerns
```

### 9.3 Full Pipeline: Proposal → Plan → Decision

```
Developer: /new-proposal switch-to-event-sourcing --module packages/payment-gateway

Claude Code:
  1. Creates docs/proposals/001-switch-to-event-sourcing.md (status: draft)

Developer: [writes proposal content]

Developer: /proposal-status 001 in-review
Developer: /proposal-status 001 accepted

Claude Code:
  1. Updates proposal to accepted
  2. Prompts: "Create an implementation plan? (Y/n)"

Developer: Y

Claude Code → /new-plan switch-to-event-sourcing --from-proposal 001:
  1. Creates docs/plans/001-switch-to-event-sourcing.md (status: active)
  2. Pre-populates from proposal context
  3. Provides DDD decomposition guidance

Developer: [fills in bounded contexts, aggregates, tasks]
Developer: [during implementation, creates ADR for key decision]

Developer: /new-adr use-kafka-for-event-store --from-proposal 001

Claude Code:
  1. Creates docs/decisions/002-use-kafka-for-event-store.md
  2. Links to originating proposal
```

### 9.4 Superseding an ADR

```
Developer: /new-adr switch-from-kafka-to-pulsar --from-proposal 003

Claude Code:
  1. Creates new ADR
  2. Prompts: "Does this supersede an existing ADR? (enter number or skip)"

Developer: 002

Claude Code:
  1. Updates ADR-002's superseded_by field to 003 (allowed exception)
  2. Sets new ADR's frontmatter to reference the superseded record
```

### 9.5 Blocked: Editing an Accepted ADR

```
Developer: "Update the decision in ADR 001 to include streaming"

→ PreToolUse hook fires
→ check-adr-immutability.sh: status is accepted, edit is not limited to superseded_by
→ Exit code 2: BLOCKED

  "Cannot modify ADR-001: this record has been accepted and is immutable.
   The only permitted change is setting superseded_by.
   To change this decision, create a new ADR. Use /new-adr."
```

### 9.6 Cross-Cutting Proposal

```
Developer: /new-proposal unified-logging-standard --root

Claude Code:
  1. Creates repo-root docs/proposals/001-unified-logging-standard.md
  2. This proposal affects all modules — lives at root level
```

---

## 10. Integration with CI

### 10.1 Structural Validation

```yaml
- name: Validate module docs structure
  run: |
    for module in packages/*/; do
      ./principled-docs/skills/scaffold/scripts/validate-structure.sh \
        --module-path "$module" \
        --json >> results.json
    done
    # Also validate root-level docs
    ./principled-docs/skills/scaffold/scripts/validate-structure.sh \
      --root --json >> results.json
    jq -e '.[] | select(.status == "fail")' results.json && exit 1 || exit 0
```

### 10.2 Template Drift Check

```yaml
- name: Check template drift
  run: |
    ./principled-docs/skills/scaffold/scripts/check-template-drift.sh
```

Exits non-zero if any template copy has diverged from the canonical version in `scaffold/templates/`.

### 10.3 Single Source of Truth

The plugin's template and validation definitions are the single source of truth. Both Claude Code hooks and CI checks reference the same structural definitions, ensuring no drift between local and pipeline enforcement.

---

## 11. Configuration

Project-level configuration via `.claude/settings.json`:

```json
{
  "principled-docs": {
    "modulesDirectory": "packages",
    "defaultModuleType": "core",
    "docsSubdirectory": "docs",
    "strictMode": false,
    "customTemplatesPath": null,
    "ignoredModules": ["packages/deprecated-*"],
    "fileExtension": ".md"
  }
}
```

| Setting | Default | Description |
|---|---|---|
| `modulesDirectory` | `"packages"` | Root directory containing modules |
| `defaultModuleType` | `"core"` | Default when type is not specified |
| `docsSubdirectory` | `"docs"` | Subdirectory within each module for documentation |
| `strictMode` | `false` | When true, placeholder-only files are treated as failures |
| `customTemplatesPath` | `null` | Override all default templates with project-specific ones (no inheritance — full replacement) |
| `ignoredModules` | `[]` | Glob patterns for modules to skip during audit/validation |
| `fileExtension` | `".md"` | Extension for generated documentation files |

---

## 12. Implementation Phases

### Phase 1: Foundation (Days 1–3)

**Deliverables:** Plugin skeleton, all templates, core scripts

- Create plugin directory structure and manifest
- Write all canonical templates in `skills/scaffold/templates/` (core, lib, app) — including new proposal and DDD plan templates
- Copy templates to consuming skills (`new-proposal`, `new-plan`, `new-adr`, `new-architecture-doc`)
- Implement `hooks/scripts/parse-frontmatter.sh`
- Implement `skills/scaffold/scripts/validate-structure.sh` (all module types + root)
- Implement `skills/new-proposal/scripts/next-number.sh`
- Implement `skills/scaffold/scripts/check-template-drift.sh`
- Manual testing of all scripts

### Phase 2: Scaffolding and Validation (Days 4–6)

**Deliverables:** `scaffold` and `validate` skills, module + root generation

- Write `skills/scaffold/SKILL.md` with workflow for core, lib, app, and `--root`
- Write `skills/validate/SKILL.md`
- Test scaffolding for all module types and root structure
- Verify generated structures pass validation
- Write `skills/docs-strategy/` reference files (including DDD decomposition guide)

### Phase 3: Authoring Workflows (Days 7–11)

**Deliverables:** All authoring and lifecycle skills

- Write `skills/new-proposal/SKILL.md`
- Write `skills/new-plan/SKILL.md` with DDD guidance and `--from-proposal` workflow
- Write `skills/new-adr/SKILL.md` with `--from-proposal` workflow and supersession handling
- Write `skills/proposal-status/SKILL.md` with state machine
- Write `skills/new-architecture-doc/SKILL.md`
- Test full pipeline: scaffold → new-proposal → proposal-status → new-plan → new-adr
- Test root-level workflows

### Phase 4: Enforcement (Days 12–14)

**Deliverables:** All hooks, guard scripts

- Implement `hooks/scripts/check-adr-immutability.sh` with `superseded_by` exception
- Implement `hooks/scripts/check-proposal-lifecycle.sh`
- Configure `hooks/hooks.json`
- Test: accepted ADR blocked except for `superseded_by`
- Test: terminal proposals blocked
- Test: post-write nudge on incomplete modules
- Edge cases: new files, non-docs files, malformed/missing frontmatter

### Phase 5: Audit and Polish (Days 15–17)

**Deliverables:** `docs-audit` skill, plugin README, CI examples

- Write `skills/docs-audit/SKILL.md` with `--include-root` support
- Finalize all reference documentation
- Write plugin `README.md`
- Create CI integration examples (validation + template drift check)
- End-to-end testing across realistic monorepo with root + module structures

---

## 13. Success Criteria

| Criterion | Measurement |
|---|---|
| New modules are structurally compliant from creation | `/validate` passes immediately after `/scaffold` |
| Root-level structure works | `/scaffold --root` + `/validate --root` passes |
| ADR immutability is enforced with exception | Accepted ADRs blocked except `superseded_by` updates |
| Proposal lifecycle is enforced | Terminal-state proposals cannot be modified; invalid transitions blocked |
| Plans require accepted proposals | `/new-plan` without `--from-proposal` to an accepted proposal fails |
| DDD guidance is provided | Plan template includes bounded contexts, aggregates, and domain events sections |
| Templates are consistent | CI drift check passes; all copies match canonical |
| Full pipeline works end-to-end | proposal → plan → ADR lifecycle completes without errors |
| Skills are self-contained | Each skill directory contains all its templates, scripts, and reference docs |
| Cross-cutting docs work | Root-level proposals, plans, decisions, and architecture docs can be created and validated |
| Plugin is self-documenting | README covers installation, configuration, all skills, all hooks |

---

## 14. Open Questions

1. **Plan completion workflow.** When all tasks in a plan are checked off, should the plugin automatically transition the plan to `complete` status, or should this always be an explicit action?

2. **ADR-to-plan back-linking.** When an ADR is created during plan implementation, should the plugin automatically add it to the plan's "Decisions Required" section? This is a mutation of an active plan, which is allowed, but the automation may be surprising.

3. **Root vs. module numbering.** Root-level and module-level documents use independent `NNN` sequences. Should the plugin enforce global uniqueness across all modules, or is per-scope uniqueness sufficient?
