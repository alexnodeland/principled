---
title: "Claude-Mediated Template Placeholder Replacement"
number: 002
status: accepted
author: Claude
created: 2026-02-04
originating_proposal: 000
superseded_by: null
---

# ADR-002: Claude-Mediated Template Placeholder Replacement

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

Templates throughout the plugin use `{{PLACEHOLDER}}` syntax (e.g., `{{MODULE_NAME}}`, `{{DATE}}`, `{{AUTHOR}}`, `{{NUMBER}}`). When a skill creates a new document from a template, these placeholders must be replaced with actual values. The question is whether this replacement happens via automated `sed` substitution in bash scripts or via Claude's Read/Write tool workflow.

The PRD's skill definitions specify `allowed-tools: Read, Write, Bash(...)` — skills read template files and write populated documents using Claude Code's tool system. This implies Claude performs the replacement as part of its tool workflow, not as a separate script step.

## Decision

Template placeholders are guidance markers for Claude, not machine-processed tokens. Claude reads the template file via the Read tool, substitutes placeholders with actual values as part of its skill execution workflow, and writes the populated file via the Write tool. No `sed`-based or script-based replacement is used.

## Options Considered

### Option 1: Claude-mediated replacement (selected)

Claude reads templates, understands the `{{PLACEHOLDER}}` markers, substitutes values contextually, and writes the result. The skill's SKILL.md documents which placeholders exist and what values to use.

**Pros:**
- Leverages Claude's ability to understand context — can populate not just simple substitutions but also contextual sections (e.g., pre-populating a plan's bounded contexts from the proposal)
- No brittle `sed` commands to maintain
- Handles edge cases naturally (missing git user name falls back to prompting, date formatting is handled natively)
- Template files remain human-readable documentation of the expected structure
- Skills already have Read and Write permissions — no additional tooling needed

**Cons:**
- Non-deterministic: Claude may interpret placeholders slightly differently across invocations
- Cannot be unit-tested as a standalone script
- Requires Claude Code runtime — templates cannot be populated by CI or other tools

### Option 2: Bash sed substitution

Write a `populate-template.sh` script that takes a template file and a set of `KEY=VALUE` pairs, runs `sed` replacements, and outputs the populated file.

**Pros:**
- Deterministic, testable, scriptable
- Can be used in CI pipelines without Claude Code
- Clear separation of concerns

**Cons:**
- Fragile with special characters in values (sed delimiter conflicts)
- Cannot handle contextual population (e.g., pre-populating from proposal content)
- Adds another script to maintain and drift-check
- Skills would still need Claude to gather the values before calling the script

### Option 3: Hybrid approach

Use `sed` for simple placeholders (`{{DATE}}`, `{{AUTHOR}}`) and Claude for contextual sections.

**Pros:**
- Deterministic where possible, contextual where needed

**Cons:**
- Split responsibility is confusing — which replacements are scripted vs. Claude-mediated?
- More moving parts for the same outcome
- Marginal benefit over pure Claude-mediated approach

## Consequences

### Positive

- Templates serve dual purpose: they are both machine-readable structures for Claude and human-readable documentation of the expected document format.
- Contextual pre-population (e.g., seeding a plan's bounded contexts from a proposal) works naturally as part of the same workflow.
- No additional scripts or dependencies for template population.
- The SKILL.md placeholder table provides clear documentation of what each placeholder means and where its value comes from.

### Negative

- Template population cannot be tested in isolation — it requires a Claude Code runtime.
- CI cannot scaffold modules without Claude Code. This is acceptable because the PRD explicitly states CI handles validation, not generation (§3 Non-Goals).
- If a placeholder is missed by Claude, there's no script-level safety net. The validation engine partially mitigates this by detecting placeholder-only content.

## References

- [RFC-000: Principled Docs Plugin](../proposals/000-principled-docs.md) — PRD §8 (Templates), §6.2 (scaffold workflow step 4)
- [Plan-000](../plans/000-principled-docs.md) — Decisions Required, item 2
- Implementation: `skills/scaffold/SKILL.md` (placeholder table), all template files in `skills/scaffold/templates/`
