---
title: "Heuristic Architecture Governance"
number: "014"
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-22
from_proposal: "005"
supersedes: null
superseded_by: null
---

# ADR-014: Heuristic Architecture Governance

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled methodology records architectural decisions in ADRs and maintains living architecture documents, but nothing verifies that the codebase conforms to these decisions. Over time, architectural drift accumulates: module boundaries are violated, dependency directions are ignored, and architecture documents go stale.

Detecting drift requires analyzing the relationship between code and documentation. There are several levels of analysis depth:

1. **File-level heuristics** — Scan `import`/`require` statements and file paths via regex. Language-agnostic but shallow.
2. **AST-level analysis** — Parse source code into abstract syntax trees for precise dependency resolution. Accurate but language-specific (ArchUnit for Java, dependency-cruiser for JavaScript, etc.).
3. **Test-based fitness functions** — Encode architectural rules as test assertions. Precise and CI-enforceable but require manual rule authoring per ADR.

The principled methodology is language-agnostic by design — plugins are pure bash, and the documentation pipeline works across any technology stack. An architecture governance approach must preserve this language-agnostic property.

## Decision

Architecture governance uses file-level heuristic analysis as its primary mechanism, operating at the module and import-path level rather than the AST level.

This means:

- `/arch-drift` scans for import statements and file references using regex patterns, not language-specific parsers
- Module boundaries are detected via `CLAUDE.md` declarations (per ADR-003), and dependency direction is checked by analyzing which modules import from which others
- Default dependency direction rules: `app` can depend on `lib` and `core`; `lib` can depend on `core`; `core` has no internal module dependencies
- Teams can override default rules by declaring explicit dependency allowances in their module's `CLAUDE.md`
- The analysis is advisory-focused: violations are reported as warnings by default, with `--strict` mode available for CI enforcement
- Language-specific static analysis tools are complementary, not replaced — teams can layer ArchUnit, dependency-cruiser, or similar tools on top

## Options Considered

### Option 1: AST-level static analysis

Build language-specific parsers into the plugin for precise dependency and pattern analysis.

**Pros:**

- Highly accurate dependency resolution — no false positives from regex
- Can detect subtle violations (e.g., indirect dependencies through re-exports)
- Established ecosystem of tools (ArchUnit, dependency-cruiser, etc.)

**Cons:**

- Language-specific: requires a separate parser per language ecosystem
- Violates the principled methodology's language-agnostic principle
- Significant implementation complexity per language
- Duplicates functionality that dedicated tools already provide

### Option 2: Test-based fitness functions

Encode architectural rules as test assertions run via the test suite.

**Pros:**

- Precise: rules are explicit code, not heuristic inference
- CI-enforceable: fitness functions run as part of the test pipeline
- Binary pass/fail makes violations unambiguous

**Cons:**

- Requires manual rule authoring for each ADR — no automation to derive rules from ADR content
- Doesn't provide discovery capabilities (mapping, querying, auditing)
- Doesn't detect stale governance (ADRs that no longer match the codebase)
- Provides binary results, not the nuanced reports that guide architectural improvement

### Option 3: File-level heuristic analysis (chosen)

Scan imports and file paths via regex, operating at the module boundary level.

**Pros:**

- Language-agnostic: works across any technology stack using file-level patterns
- Consistent with the principled methodology's bash-and-markdown approach
- Covers the highest-value checks (module boundary violations, dependency direction) with low implementation cost
- Discovery-oriented: supports mapping, auditing, and querying, not just rule enforcement
- Complements rather than replaces language-specific tools

**Cons:**

- Lower precision than AST analysis — may miss indirect violations or flag false positives
- Cannot analyze dynamic imports, runtime dependencies, or complex re-exports
- Pattern-based detection may need tuning for unfamiliar import syntaxes

## Consequences

### Positive

- The principled methodology's language-agnostic property is preserved. Architecture governance works in any repository regardless of technology stack.
- High-value boundary violations (the most common form of architectural drift) are detected with minimal tooling investment.
- The advisory-first approach (warnings, not blocks) matches the principled methodology's preference for nudges over hard constraints at the module level.
- Teams with specific language ecosystems can layer dedicated static analysis tools without conflict.

### Negative

- Some violations will be missed due to the heuristic nature of analysis. Teams requiring guaranteed detection must supplement with language-specific tooling.
- Import pattern regex may require updates when new languages or import syntaxes are encountered.
- The advisory-first approach means violations can be ignored. Teams requiring hard enforcement must opt into `--strict` mode and integrate with CI.

## References

- [RFC-005: Principled Architecture Plugin](../proposals/005-principled-architecture-plugin.md)
- [ADR-003: Module Type Declaration via CLAUDE.md](./003-module-type-storage.md) — establishes the module type system that governance builds upon
