---
name: quality-strategy
description: >
  Review quality strategy for the Principled framework.
  Consult when working with code review checklists, review coverage,
  review summaries, or spec-driven review workflows. Covers the three
  checklist categories, severity classification, dual storage model,
  and quality gates.
user-invocable: false
---

# Quality Strategy --- Background Knowledge

This skill provides Claude Code with comprehensive knowledge of how the Principled methodology connects to code review. It is not directly invocable --- it informs Claude's behavior when review-related context is encountered.

## When to Consult This Skill

Activate this knowledge when:

- Generating review checklists from plan acceptance criteria
- Surfacing specification context for a PR's changed files
- Assessing review coverage against checklist items
- Producing structured review summaries
- Discussing how the principled pipeline extends to the review stage

## Reference Documentation

Read these files for detailed guidance on specific topics:

### Review Standards

- **`reference/review-standards.md`** --- The three checklist categories (acceptance criteria, ADR compliance, general quality), severity classification (blocking, important, advisory), and quality gate definitions. Covers what makes a review complete.

### Checklist Conventions

- **`reference/checklist-conventions.md`** --- Checklist Markdown format, dual storage model (ADR-012), `.review/` directory structure, PR comment markers for identification and updates.

## Key Principles

1. **Reviews are spec-driven.** Checklists derive from plan acceptance criteria and ADRs, not from ad hoc reviewer judgment alone.
2. **Dual storage preserves flexibility.** PR comments are the interactive interface; local files provide persistence (ADR-012).
3. **Advisory, never blocking.** The plugin reports and recommends. It does not gate merges or enforce review completion.
4. **No write-back to plans.** Coverage reports are read-only. They do not modify plan documents or task status.
5. **Module scope drives ADR relevance.** ADRs are matched to changed files via CLAUDE.md module boundaries (ADR-003).
6. **Checklist items are traceable.** Every item links back to its source: a plan criterion, an ADR, or a standard quality check.
