---
name: arch-strategy
description: >
  Architecture governance strategy for the Principled framework.
  Consult when working with architecture maps, drift detection,
  coverage audits, architecture document sync, or module boundary
  enforcement. Covers dependency direction rules, governance mapping
  conventions, and the heuristic analysis approach.
user-invocable: false
---

# Architecture Strategy --- Background Knowledge

This skill provides Claude Code with comprehensive knowledge of how the Principled methodology enforces architectural governance. It is not directly invocable --- it informs Claude's behavior when architecture-related context is encountered.

## When to Consult This Skill

Activate this knowledge when:

- Mapping modules to their governing ADRs and architecture documents
- Detecting drift between documented decisions and actual code
- Auditing architectural decision coverage across modules
- Synchronizing architecture documents with the codebase
- Answering questions about the architecture or its governance
- Encountering module boundary or dependency direction concerns

## Reference Documentation

Read these files for detailed guidance on specific topics:

### Governance Rules

- **`reference/governance-rules.md`** --- Module dependency direction rules (app -> lib -> core), override mechanism via CLAUDE.md declarations, enforcement levels (advisory vs. strict), and violation severity classification.

### Mapping Conventions

- **`reference/mapping-conventions.md`** --- How ADRs declare scope, how modules reference decisions, architecture map format, coverage classification (Full, Partial, None), and map interpretation guidance.

## Key Principles

1. **Heuristic, not semantic.** Analysis uses file-level pattern matching (regex on imports), not AST-level parsing. Language-agnostic by design (ADR-014).
2. **Advisory by default.** Violations are warnings unless `--strict` mode is explicitly requested. Nudge, don't block.
3. **Documentation drives governance.** ADRs and architecture docs are the source of truth. Code is checked against documentation, not the other way around.
4. **Module types define boundaries.** Dependency direction rules build on ADR-003's module type system (`core`, `lib`, `app`).
5. **Coverage is visible.** Every module's governance status (Full, Partial, None) is surfaced. Gaps are explicit, not hidden.
6. **Complementary to static analysis.** The plugin does not replace ArchUnit, dependency-cruiser, or similar tools. It adds documentation-awareness on top.
