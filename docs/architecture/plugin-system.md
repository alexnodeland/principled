---
title: "Plugin System Architecture"
last_updated: 2026-02-04
related_adrs: [002]
---

# Plugin System Architecture

## Purpose

Describes the overall architecture of the `principled-docs` Claude Code plugin: how skills, hooks, templates, and scripts are organized, how they interact, and what design principles govern the structure. Intended for contributors who need to understand or extend the plugin.

## Overview

The system is organized around four architectural layers. The marketplace layer sits above the plugin layers:

```
┌──────────────────────────────────────────────────────────┐
│                   MARKETPLACE LAYER                       │
│  (plugin catalog, discovery, and distribution)            │
│                                                           │
│  marketplace.json, plugins/, external_plugins/            │
├──────────────────────────────────────────────────────────┤
│                     SKILLS LAYER                          │
│  (generative workflows: scaffolding, authoring, audit)    │
│                                                           │
│  9 skills, each self-contained with SKILL.md,             │
│  templates, scripts, and reference docs                   │
├──────────────────────────────────────────────────────────┤
│                  ENFORCEMENT LAYER                         │
│  (deterministic guardrails: hooks + guard scripts)         │
│                                                           │
│  hooks.json + 3 shell scripts                             │
├──────────────────────────────────────────────────────────┤
│                  FOUNDATION LAYER                          │
│  (shared infrastructure: manifest, canonical templates)    │
│                                                           │
│  plugin.json, canonical template set, utility scripts      │
└──────────────────────────────────────────────────────────┘
```

## Key Abstractions

### Skills

Skills are the single unit of capability. Every skill is also a slash command (Claude Code v2.1.3+ unifies skills and commands). A skill directory contains everything it needs:

```
plugins/<plugin-name>/skills/<skill-name>/
├── SKILL.md              # Definition: frontmatter (name, description, tools) + workflow
├── templates/            # Document templates used by this skill
├── reference/            # Reference docs Claude reads during execution
├── scripts/              # Shell scripts invoked during workflow
└── diagrams/             # Visual aids (docs-strategy only)
```

Skills fall into three categories:

| Category                 | Skills                                                                    | Characteristic                                |
| ------------------------ | ------------------------------------------------------------------------- | --------------------------------------------- |
| **Background knowledge** | `docs-strategy`                                                           | Not user-invocable; informs Claude's behavior |
| **Generative**           | `scaffold`, `new-proposal`, `new-plan`, `new-adr`, `new-architecture-doc` | Create files and structure                    |
| **Analytical**           | `validate`, `docs-audit`, `proposal-status`                               | Read and report on existing state             |

### Hooks

Hooks are deterministic shell scripts triggered by Claude Code lifecycle events. They live in a plugin's `hooks/` directory (not in skill directories) because they are not skills — they have no SKILL.md, no progressive disclosure, and no user-facing workflow.

| Hook                       | Event                   | Behavior                              |
| -------------------------- | ----------------------- | ------------------------------------- |
| ADR Immutability Guard     | PreToolUse (Edit/Write) | Blocks edits to accepted ADRs         |
| Proposal Lifecycle Guard   | PreToolUse (Edit/Write) | Blocks edits to terminal proposals    |
| Post-Write Structure Nudge | PostToolUse (Write)     | Advisory validation after file writes |

### Templates

Templates are markdown files with `{{PLACEHOLDER}}` markers. The `scaffold` skill owns the canonical set (12 templates). Consuming skills maintain byte-identical copies for self-containment. CI enforces that copies never drift.

### Scripts

Utility scripts are shell programs that perform deterministic operations:

| Script                    | Purpose                                | Canonical Location             | Copies                                |
| ------------------------- | -------------------------------------- | ------------------------------ | ------------------------------------- |
| `parse-frontmatter.sh`    | Extract YAML frontmatter fields        | `hooks/scripts/`               | None                                  |
| `validate-structure.sh`   | Check module documentation structure   | `skills/scaffold/scripts/`     | `skills/validate/scripts/`            |
| `check-template-drift.sh` | Verify template copies match canonical | `skills/scaffold/scripts/`     | None                                  |
| `next-number.sh`          | Determine next NNN sequence number     | `skills/new-proposal/scripts/` | `skills/new-plan/`, `skills/new-adr/` |

All script paths above are relative to `plugins/principled-docs/`.

## Component Relationships

```
                         plugin.json
                             │
                    ┌────────┴────────┐
                    │                 │
              skills/ (9)        hooks/ (3)
                    │                 │
        ┌───────┬──┴──┬───┐     hooks.json
        │       │     │   │          │
   docs-     scaffold  authoring   guard scripts
   strategy     │     skills(5)      │
        │       │        │      parse-frontmatter.sh
   reference/   ├── canonical        │
   diagrams/    │   templates   ┌────┴────┐
                │   (12 files)  │         │
                │       │       ADR     proposal
                │   copied to   guard    guard
                │   consuming
                │   skills (4)
                │
           validate-structure.sh ←── used by validate skill,
                                     hooks (--on-write),
                                     docs-audit skill
```

## Data Flow

### Skill Execution Flow

```
User invokes /skill-name <args>
       │
       ▼
Claude reads SKILL.md → understands workflow
       │
       ▼
Claude reads reference/ docs (if needed) → gains context
       │
       ▼
Claude reads templates/ → loads document structure
       │
       ▼
Claude executes scripts/ (if needed) → gets computed values
       │
       ▼
Claude writes populated documents → files created/modified
       │
       ▼
PostToolUse hook fires → advisory validation
```

### Hook Execution Flow

```
Claude invokes Edit or Write tool
       │
       ▼
PreToolUse hooks fire (before execution)
       │
       ├── check-adr-immutability.sh
       │   Reads file_path from stdin JSON
       │   Checks if path is in /decisions/
       │   Reads frontmatter status
       │   Blocks if immutable (exit 2) or allows (exit 0)
       │
       └── check-proposal-lifecycle.sh
           Reads file_path from stdin JSON
           Checks if path is in /proposals/
           Reads frontmatter status
           Blocks if terminal (exit 2) or allows (exit 0)
       │
       ▼
Tool executes (if not blocked)
       │
       ▼
PostToolUse hook fires (after execution)
       │
       └── validate-structure.sh --on-write
           Advisory structural check
```

## Key Decisions

- [ADR-002: Claude-Mediated Template Placeholder Replacement](../decisions/002-template-placeholder-syntax.md) — Templates use `{{PLACEHOLDER}}` syntax that Claude interprets during skill execution, rather than sed-based script substitution.

## Constraints and Invariants

1. **Skills are self-contained.** Every skill directory contains everything it needs. No cross-skill imports or shared directories.
2. **Template copies are byte-identical.** The drift checker enforces this. Drift is a CI failure.
3. **Hooks and skills never overlap.** Skills handle generative workflows. Hooks handle deterministic guardrails.
4. **Scripts have no shared directory.** If a utility is needed in multiple places, each location maintains its own copy, validated by drift checks.
5. **Marketplace root contains only infrastructure.** `.claude-plugin/marketplace.json`, `plugins/`, `external_plugins/`, `docs/`, `README.md`. Individual plugins are self-contained under `plugins/`.
