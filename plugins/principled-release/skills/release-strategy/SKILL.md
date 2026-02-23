---
name: release-strategy
description: >
  Release strategy for the Principled framework.
  Consult when working with changelogs, release readiness checks,
  version bumps, release plans, or tag operations. Covers changelog
  format conventions, semver bump heuristics, pipeline reference
  resolution, and the release lifecycle.
user-invocable: false
---

# Release Strategy --- Background Knowledge

This skill provides Claude Code with comprehensive knowledge of how the Principled methodology extends to the release boundary. It is not directly invocable --- it informs Claude's behavior when release-related context is encountered.

## When to Consult This Skill

Activate this knowledge when:

- Generating changelogs from the documentation pipeline
- Checking release readiness against pipeline document statuses
- Determining version bump type from pipeline signals
- Drafting release plans for team review
- Tagging and finalizing releases with release notes
- Discussing how the principled pipeline extends through the release stage

## Reference Documentation

Read these files for detailed guidance on specific topics:

### Release Conventions

- **`reference/release-conventions.md`** --- Changelog format adapted from Keep a Changelog, entry grouping categories (Features, Improvements, Decisions, Fixes, Uncategorized), pipeline reference patterns for commit-to-spec mapping, and the distinction between changelogs and release notes.

### Semver Rules

- **`reference/semver-rules.md`** --- Version bump heuristics (supersedes signals major, new RFCs signal minor, plan tasks signal patch), priority rules when multiple signals are present, `--type` override behavior, version manifest file detection across ecosystems, and module detection via CLAUDE.md.

## Key Principles

1. **Pipeline-based changelogs.** Changelogs are generated from proposals, plans, and ADRs --- not from commit messages alone (ADR-013).
2. **Uncategorized changes are visible.** Changes without pipeline references appear as "Uncategorized," surfacing reference discipline gaps.
3. **Interactive workflow.** Release preparation is skill-based and iterative (draft, review, adjust, finalize), not fully automated.
4. **Release readiness is verifiable.** `/release-ready` checks that all referenced pipeline documents are in terminal status before a release proceeds.
5. **Monorepo-aware.** Version bumps and changelogs understand module boundaries via CLAUDE.md declarations (ADR-003).
6. **Release scope boundary.** The plugin stops at tag and release notes. No deployment, environment promotion, or rollback.
