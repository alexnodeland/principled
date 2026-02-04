---
title: "Enforcement System"
last_updated: 2026-02-04
related_adrs: [001]
---

# Enforcement System

## Purpose

Describes the hook-based enforcement layer that provides deterministic guardrails for document immutability and lifecycle compliance. Intended for contributors who need to understand how enforcement works, debug hook behavior, or extend the guard system.

## Overview

The enforcement system uses Claude Code's hook mechanism to intercept file operations and apply rules before they execute. It consists of three components:

```
┌──────────────────────────────────────────────────────┐
│                    hooks.json                          │
│  Declares which events trigger which scripts           │
├──────────────────────────────────────────────────────┤
│                                                        │
│  PreToolUse (Edit|Write)                               │
│  ┌────────────────────────┐ ┌─────────────────────┐   │
│  │ ADR Immutability Guard │ │ Proposal Lifecycle   │   │
│  │                        │ │ Guard                │   │
│  │ Blocks edits to        │ │ Blocks edits to      │   │
│  │ accepted ADRs          │ │ terminal proposals   │   │
│  │ (except superseded_by) │ │                      │   │
│  └────────────────────────┘ └─────────────────────┘   │
│                                                        │
│  PostToolUse (Write)                                   │
│  ┌────────────────────────┐                            │
│  │ Structure Nudge        │                            │
│  │                        │                            │
│  │ Advisory validation    │                            │
│  │ after file writes      │                            │
│  └────────────────────────┘                            │
│                                                        │
├──────────────────────────────────────────────────────┤
│                Shared Utility                          │
│  ┌────────────────────────┐                            │
│  │ parse-frontmatter.sh   │                            │
│  │                        │                            │
│  │ Extracts YAML fields   │                            │
│  │ from document headers  │                            │
│  └────────────────────────┘                            │
└──────────────────────────────────────────────────────┘
```

## Key Abstractions

### Hook Configuration (`hooks.json`)

The hook configuration file declares:

- **Event type:** `PreToolUse` (before tool executes) or `PostToolUse` (after)
- **Matcher:** Which tools trigger the hook (`Edit|Write`)
- **Command:** The shell script to run
- **Timeout:** Maximum execution time (10s for guards, 15s for nudge)

### Guard Scripts

Guard scripts receive JSON on stdin containing the tool invocation details (including `tool_input.file_path`). They make a binary decision:

| Exit Code | Meaning | Effect                                                   |
| --------- | ------- | -------------------------------------------------------- |
| `0`       | Allow   | Tool operation proceeds                                  |
| `2`       | Block   | Tool operation is prevented; error message shown to user |

The decision logic follows a consistent pattern:

```
Read file_path from stdin JSON
  │
  ├── Not in relevant directory? → exit 0 (allow)
  ├── File doesn't exist yet? → exit 0 (allow, it's a creation)
  │
  └── Read frontmatter status
      │
      ├── Status is protected? → exit 2 (block with message)
      └── Status is not protected? → exit 0 (allow)
```

### Frontmatter Parser

`parse-frontmatter.sh` is the shared utility that both guard scripts depend on. It reads YAML frontmatter (between `---` delimiters) and extracts the value of a named field using pure bash parsing.

## Component Relationships

```
hooks.json
    │
    ├── PreToolUse: Edit|Write
    │   ├── check-adr-immutability.sh ───┐
    │   └── check-proposal-lifecycle.sh ──┤
    │                                     │
    │                        parse-frontmatter.sh
    │                       (shared dependency)
    │
    └── PostToolUse: Write
        └── validate-structure.sh --on-write
            (from plugins/principled-docs/skills/scaffold/scripts/)
```

### Dependency Chain

```
hooks.json
    │
    ├── check-adr-immutability.sh
    │   └── parse-frontmatter.sh (reads status field)
    │   └── jq (optional, for JSON input parsing; falls back to grep)
    │
    ├── check-proposal-lifecycle.sh
    │   └── parse-frontmatter.sh (reads status field)
    │   └── jq (optional, for JSON input parsing; falls back to grep)
    │
    └── validate-structure.sh --on-write
        └── No external dependencies (standalone check)
```

## Data Flow

### ADR Immutability Guard — Detailed Flow

```
stdin (JSON with tool_input.file_path)
    │
    ▼
Extract file_path (jq or grep fallback)
    │
    ├── No file_path found → ALLOW
    ├── Path not in /decisions/ → ALLOW
    ├── File doesn't exist → ALLOW (new creation)
    │
    ▼
Read status via parse-frontmatter.sh
    │
    ├── Status is draft/proposed → ALLOW
    │
    ├── Status is accepted/deprecated/superseded
    │   │
    │   ▼
    │   Check edit scope
    │   │
    │   ├── Edit tool: compare old_string/new_string
    │   │   └── Only superseded_by changed? → ALLOW
    │   │   └── Other content changed? → BLOCK
    │   │
    │   ├── Write tool: compare new content vs current file
    │   │   └── Only superseded_by changed? → ALLOW
    │   │   └── Other content changed? → BLOCK
    │   │
    │   └── Cannot determine scope → BLOCK (safe default)
    │
    ▼
BLOCK with message:
"Cannot modify ADR-NNN: this record has been <status> and is
 immutable. The only permitted change is setting superseded_by
 when a new ADR supersedes this one. To change this decision,
 create a new ADR. Use /new-adr."
```

### Proposal Lifecycle Guard — Detailed Flow

```
stdin (JSON with tool_input.file_path)
    │
    ▼
Extract file_path
    │
    ├── No file_path found → ALLOW
    ├── Path not in /proposals/ → ALLOW
    ├── File doesn't exist → ALLOW (new creation)
    │
    ▼
Read status via parse-frontmatter.sh
    │
    ├── Status is draft/in-review → ALLOW
    │
    └── Status is accepted/rejected/superseded → BLOCK
        │
        ▼
    "Cannot modify proposal NNN: this proposal has reached
     terminal status '<status>'. To propose changes, create
     a new proposal that supersedes it. Use /new-proposal."
```

### Post-Write Structure Nudge — Detailed Flow

```
File path of written file
    │
    ▼
Walk up directory tree looking for module root
(identified by docs/ directory + README.md or CLAUDE.md)
    │
    ├── No module root found → silent exit (not a module file)
    │
    ▼
Quick structural check:
    ├── docs/proposals/ exists?
    ├── docs/plans/ exists?
    ├── docs/decisions/ exists?
    ├── docs/architecture/ exists?
    ├── README.md exists?
    └── CLAUDE.md exists?
    │
    ├── All present → silent exit
    │
    └── Missing components → advisory output:
        "Advisory: Module at <path> has incomplete
         documentation structure:
           - docs/architecture/ directory missing
           - CLAUDE.md missing"
```

## Key Decisions

- [ADR-001: Pure Bash Frontmatter Parsing](../decisions/001-frontmatter-parsing-strategy.md) — Guard scripts use pure bash for frontmatter extraction, keeping the enforcement layer dependency-free.
- [ADR-006: Structural Plugin Validation in CI](../decisions/006-structural-plugin-validation-in-ci.md) — CI validates plugins via structural checks (`plugin.json` existence + JSON validity) rather than requiring the `claude` CLI.

## Constraints and Invariants

1. **Guards are binary: allow (0) or block (2).** There is no conditional or partial blocking.
2. **Guards default to allow.** If the file path cannot be extracted, the file doesn't exist, or the file is outside the guarded directory, the operation is allowed. Guards only block when they can positively confirm a violation.
3. **The `superseded_by` exception is implemented by content diffing.** The ADR immutability guard compares old and new content, allowing the operation only if the sole difference is in the `superseded_by` field.
4. **The post-write nudge is advisory only.** It outputs warnings but never blocks. Exit code is always 0.
5. **Guard scripts must complete within 10 seconds.** Hook timeouts are enforced by Claude Code. Pure bash parsing ensures this is met with wide margin.
6. **jq is optional.** Guard scripts use `jq` for JSON input parsing when available and fall back to `grep` extraction when not. The enforcement layer has no hard external dependencies.
7. **Skills and hooks never overlap.** Skills create and modify documents. Hooks enforce rules. A skill never enforces immutability; a hook never scaffolds a document.
