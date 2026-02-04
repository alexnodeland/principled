---
title: "Pure Bash Frontmatter Parsing"
number: 001
status: accepted
author: Claude
created: 2026-02-04
originating_proposal: 000
superseded_by: null
---

# ADR-001: Pure Bash Frontmatter Parsing

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The plugin's enforcement hooks (`check-adr-immutability.sh`, `check-proposal-lifecycle.sh`) and validation scripts need to read YAML frontmatter fields from markdown documents at runtime. The PRD specifies bash-based hook scripts that execute in under 10 seconds. The frontmatter schema is deliberately simple: flat key-value pairs with no nesting, no arrays (except `related_adrs` in architecture docs), and no multi-line values.

Two approaches were considered:

1. **Pure bash parsing** — Read the file line by line, match `field: value` patterns with bash regex, strip quotes.
2. **External YAML parser** — Require `yq`, `python -c 'import yaml'`, or similar.

## Decision

Use pure bash parsing for all frontmatter extraction. The implementation (`hooks/scripts/parse-frontmatter.sh`) reads the frontmatter block between `---` delimiters, matches the requested field with a bash regex (`^${FIELD}:[[:space:]]*(.*)`), strips surrounding quotes, and outputs the value.

## Options Considered

### Option 1: Pure bash (bash builtins + regex)

Parse frontmatter using a `while read` loop with bash regex matching. No external dependencies beyond standard POSIX utilities (`head` for first-line check).

**Pros:**
- Zero external dependencies — works on any system with bash
- Fast execution (no process spawning for parsing)
- Sufficient for the flat key-value schema used by this plugin
- Hook timeout of 10 seconds is easily met

**Cons:**
- Cannot handle nested YAML, multi-line values, or flow sequences
- Regex matching is brittle for complex YAML features (anchors, tags, etc.)

### Option 2: External YAML parser (yq, python yaml)

Shell out to `yq` or `python3 -c 'import yaml; ...'` for parsing.

**Pros:**
- Full YAML spec compliance
- Handles edge cases (multi-line values, special characters, nested structures)

**Cons:**
- Adds an external dependency (`yq` or Python with PyYAML)
- Slower execution (process spawning overhead matters in hooks)
- Over-engineered for the simple flat-key schema this plugin uses

### Option 3: jq-based extraction (convert to JSON first)

Convert frontmatter to JSON, then use `jq` for field extraction.

**Pros:**
- `jq` is commonly available
- Precise field extraction

**Cons:**
- Still requires a YAML-to-JSON conversion step
- Adds `jq` as a hard dependency for hook enforcement (currently optional, only used for `--json` output mode)

## Consequences

### Positive

- No external dependencies for the enforcement layer. The plugin works on any system with bash 4+.
- Hook scripts execute in milliseconds, well within the 10-second timeout.
- The parsing logic is simple, auditable, and contained in a single 78-line script.

### Negative

- The parser cannot handle YAML features beyond flat `key: value` pairs. If the frontmatter schema evolves to include nested structures or multi-line values, this parser will need to be replaced or augmented.
- Quoted values are handled by simple prefix/suffix stripping, which would fail on values containing escaped quotes. This is acceptable because the plugin's frontmatter values are simple strings, numbers, and nulls.

## References

- [RFC-000: Principled Docs Plugin](../proposals/000-principled-docs.md) — PRD §7 (Hooks)
- [Plan-000](../plans/000-principled-docs.md) — Decisions Required, item 1
- Implementation: `hooks/scripts/parse-frontmatter.sh`
