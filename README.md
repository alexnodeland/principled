# principled-docs

A Claude Code plugin that scaffolds, authors, and enforces module documentation structure following the Principled specification-first methodology.

## Overview

`principled-docs` gives Claude Code the knowledge, tools, and guardrails to treat documentation structure as a first-class concern. It implements a three-stage documentation pipeline:

```
Proposal (RFC)  →  Plan (DDD Implementation)  →  Decision (ADR)
  "what and why"     "how, decomposed"              "what was decided"
```

## Installation

Add this plugin to your Claude Code project:

```bash
claude plugin add <path-to-principled-docs>
```

Or reference it in your project's Claude Code configuration.

## Skills (Slash Commands)

### `/scaffold` — Module Scaffolding

Generate the complete documentation structure for a new module.

```
/scaffold packages/payment-gateway --type app
/scaffold packages/shared-utils --type lib
/scaffold --root
```

Supported module types: `core`, `lib`, `app`. Use `--root` to scaffold repo-level docs.

### `/new-proposal` — Create an RFC

Create a new proposal document with correct numbering and template.

```
/new-proposal switch-to-event-sourcing --module packages/payment-gateway
/new-proposal unified-logging-standard --root
```

### `/new-plan` — Create a DDD Implementation Plan

Create an implementation plan linked to an accepted proposal. Plans decompose work using domain-driven development: bounded contexts, aggregates, domain events, and tasks.

```
/new-plan switch-to-event-sourcing --from-proposal 001 --module packages/payment-gateway
```

Requires `--from-proposal` pointing to an accepted proposal.

### `/new-adr` — Create an ADR

Create an Architectural Decision Record, standalone or linked to a proposal.

```
/new-adr use-kafka-for-event-store --from-proposal 001
/new-adr adopt-typescript-strict
```

### `/proposal-status` — Transition Proposal Lifecycle

Move a proposal through its lifecycle states.

```
/proposal-status 001 in-review
/proposal-status 001 accepted
```

Valid transitions: `draft → in-review → accepted|rejected|superseded`. On acceptance, prompts for plan creation.

### `/new-architecture-doc` — Create Architecture Doc

Create a living architecture document with ADR cross-references.

```
/new-architecture-doc data-flow --module packages/payment-gateway
/new-architecture-doc system-overview --root
```

### `/validate` — Structural Validation

Check documentation structure against the expected standard.

```
/validate packages/auth-service --type app
/validate --root
/validate packages/shared-utils --type lib --strict --json
```

### `/docs-audit` — Monorepo-Wide Audit

Audit documentation health across all modules.

```
/docs-audit
/docs-audit --format detailed --include-root
/docs-audit --modules-dir packages
```

### `docs-strategy` — Background Knowledge

Not directly invocable. Provides Claude Code with comprehensive understanding of the documentation strategy, naming conventions, lifecycle rules, and DDD decomposition guidance.

## Hooks (Enforcement)

### ADR Immutability Guard

**Event:** PreToolUse on Edit and Write

Blocks edits to ADRs with status `accepted`, `deprecated`, or `superseded`. One exception: updates to the `superseded_by` field are allowed when a new ADR supersedes an existing one.

### Proposal Lifecycle Guard

**Event:** PreToolUse on Edit and Write

Blocks edits to proposals with terminal status (`accepted`, `rejected`, `superseded`). Terminal proposals are frozen — to propose changes, create a new proposal.

### Post-Write Structure Nudge

**Event:** PostToolUse on Write

After any file write, checks if the file belongs to a module and runs a lightweight structural validation. Advisory only — does not block operations.

## Configuration

Configure via `.claude/settings.json`:

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
| `customTemplatesPath` | `null` | Override all default templates (no inheritance — full replacement) |
| `ignoredModules` | `[]` | Glob patterns for modules to skip during audit/validation |
| `fileExtension` | `".md"` | Extension for generated documentation files |

## CI Integration

### Structural Validation

```yaml
- name: Validate module docs structure
  run: |
    for module in packages/*/; do
      ./principled-docs/skills/scaffold/scripts/validate-structure.sh \
        --module-path "$module" \
        --json >> results.json
    done
    ./principled-docs/skills/scaffold/scripts/validate-structure.sh \
      --root --json >> results.json
    jq -e '.[] | select(.status == "fail")' results.json && exit 1 || exit 0
```

### Template Drift Check

```yaml
- name: Check template drift
  run: |
    ./principled-docs/skills/scaffold/scripts/check-template-drift.sh
```

Exits non-zero if any template copy has diverged from the canonical version in `scaffold/templates/`.

## Documentation Structure

Every module follows this structure:

```
module/
├── docs/
│   ├── proposals/        # RFCs (NNN-short-title.md)
│   ├── plans/            # DDD implementation plans (NNN-short-title.md)
│   ├── decisions/        # ADRs — immutable after acceptance (NNN-short-title.md)
│   └── architecture/     # Living design docs
├── README.md             # Module front door
├── CONTRIBUTING.md       # Build/test/PR conventions
└── CLAUDE.md             # AI development context
```

**Lib modules** add: `docs/examples/`, `INTERFACE.md`

**App modules** add: `docs/runbooks/`, `docs/integration/`, `docs/config/`

## Pipeline Workflow

```
1. /new-proposal <title>           → Creates RFC in docs/proposals/
2. [Author writes proposal]
3. /proposal-status NNN in-review  → Moves to review
4. /proposal-status NNN accepted   → Accepts, prompts for plan
5. /new-plan <title> --from-proposal NNN  → Creates DDD plan in docs/plans/
6. [Implementer fills in bounded contexts, aggregates, tasks]
7. /new-adr <title> --from-proposal NNN   → Records decisions in docs/decisions/
```
