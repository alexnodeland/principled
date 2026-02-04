---
title: "Module Type Declaration via CLAUDE.md"
number: 003
status: accepted
author: Claude
created: 2026-02-04
originating_proposal: 000
superseded_by: null
---

# ADR-003: Module Type Declaration via CLAUDE.md

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The PRD requires that module type (`core`, `lib`, or `app`) must be explicitly declared — it is never auto-detected (§3 Non-Goals). Module type determines which directories and files the validation engine expects. However, the PRD does not specify *where* the type declaration lives.

The `validate` and `docs-audit` skills need to determine module type when `--type` is not explicitly provided. This requires a canonical storage location that is:

1. Present in every module (part of the core structure)
2. Human-readable (developers should be able to see the type at a glance)
3. Machine-parseable (scripts and skills must extract it programmatically)
4. Already part of the plugin's documentation philosophy

## Decision

Module type is declared in the module's `CLAUDE.md` file under the `## Module Type` heading. The value is a single word on the line immediately following the heading: `core`, `lib`, or `app`.

```markdown
## Module Type

app
```

The scaffold skill's `CLAUDE.md` template already includes this section with the `{{MODULE_TYPE}}` placeholder. The validation engine (`validate-structure.sh`) reads this section using `awk` when `--type` is not explicitly provided. The `docs-audit` skill uses the same mechanism for module discovery.

## Options Considered

### Option 1: CLAUDE.md `## Module Type` section (selected)

Store the type as a human-readable section in `CLAUDE.md`, parsed by `awk` when needed.

**Pros:**
- `CLAUDE.md` is required in every module — no new file needed
- Human-readable and machine-parseable
- Already part of the template (`{{MODULE_TYPE}}` placeholder)
- Claude Code naturally reads `CLAUDE.md` for module context, so the type is always available
- Follows the plugin's principle that `CLAUDE.md` is the module-scoped AI context file

**Cons:**
- Parsing a markdown section is less precise than structured data (YAML, JSON)
- If someone adds content between the heading and the type value, parsing breaks

### Option 2: YAML frontmatter in CLAUDE.md

Add YAML frontmatter to `CLAUDE.md` with a `module_type` field.

```markdown
---
module_type: app
---
```

**Pros:**
- Structured data — parseable with `parse-frontmatter.sh`
- Unambiguous extraction

**Cons:**
- `CLAUDE.md` is not currently a frontmatter document — adding frontmatter changes its nature
- Claude Code's `CLAUDE.md` convention does not expect frontmatter
- Would require updating the template and the existing `parse-frontmatter.sh` to handle non-proposal/ADR files

### Option 3: Dedicated `.module-type` or `module.json` file

Create a new file per module that stores the type.

**Pros:**
- Clean separation of concerns
- Machine-parseable

**Cons:**
- Adds a new file to every module's required structure
- Another file to scaffold, validate, and maintain
- Violates the PRD's principle of minimal file count

### Option 4: Project-level configuration in `.claude/settings.json`

Declare module types centrally in the project config.

```json
{
  "principled-docs": {
    "moduleTypes": {
      "packages/auth-service": "app",
      "packages/shared-utils": "lib"
    }
  }
}
```

**Pros:**
- Single source of truth for all modules
- Easy to query

**Cons:**
- Requires updating a central file every time a module is added
- Violates the principle of module self-containment — a module's type should be declared in the module, not elsewhere
- Stale entries when modules are renamed or removed

## Consequences

### Positive

- Module type is self-contained within the module. No central registry to maintain.
- The `CLAUDE.md` template already includes the section, so scaffolded modules have the type set automatically.
- Claude Code reads `CLAUDE.md` as standard module context, so the type is always available during AI-assisted development.
- The `awk` parsing is a single line: `awk '/^## Module Type/{getline; gsub(/^[[:space:]]+|[[:space:]]+$/,""); if ($0 != "") print; exit}'`.

### Negative

- The parsing relies on the exact heading format (`## Module Type`) and the value being on the immediately following line. Markdown reformatting or accidental content insertion could break extraction.
- The `--type` flag remains required for the `scaffold` command (since `CLAUDE.md` doesn't exist yet when scaffolding) and is the recommended explicit approach for `validate`. `CLAUDE.md` detection is a fallback, not the primary mechanism.

## References

- [RFC-000: Principled Docs Plugin](../proposals/000-principled-docs.md) — PRD §3 (Non-Goals: no auto-detection), §8.7 (CLAUDE.md template)
- [Plan-000](../plans/000-principled-docs.md) — Decisions Required, item 3
- Implementation: `skills/scaffold/scripts/validate-structure.sh:201-212` (awk-based type detection)
- Implementation: `skills/scaffold/templates/core/CLAUDE.md` (`{{MODULE_TYPE}}` placeholder)
