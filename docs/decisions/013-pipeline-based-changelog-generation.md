---
title: "Pipeline-Based Changelog Generation"
number: "013"
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-23
from_proposal: "004"
supersedes: null
superseded_by: null
---

# ADR-013: Pipeline-Based Changelog Generation

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled pipeline produces rich metadata about every change: proposals explain the "why," plans describe the "how," and ADRs record architectural decisions. When cutting a release, this metadata is available but not synthesized — teams must manually trace which pipeline documents correspond to which changes.

Three approaches exist for changelog generation:

1. **Conventional Commits** — Parse commit messages (feat:, fix:, etc.) to generate changelogs. Widely adopted but limited to one-line summaries disconnected from the specification pipeline.
2. **CI-only automation** — GitHub Actions generate changelogs on tag push. Fully automated but non-interactive, offering no opportunity for human review before finalization.
3. **Pipeline-based generation** — Map commits to proposals, plans, and ADRs, then synthesize changelog entries that reference the governing specifications.

The principled methodology already requires PR descriptions to reference pipeline documents (principled-github's `/pr-describe`). This creates a traceable link from merged code back to specifications.

## Decision

Changelogs are generated from the documentation pipeline rather than from commit messages or CI automation.

This means:

- `/changelog` maps commits to proposals, plans, and ADRs via PR description references, commit message references (e.g., `RFC-001`, `Plan-001`), and branch naming conventions (e.g., `plan-001/task-3`)
- Changelog entries include parenthetical references to originating specifications (e.g., "Added event sourcing support (RFC-001, Plan-001, ADR-001)")
- Changes without pipeline references appear as "uncategorized" — visible rather than hidden — prompting teams to improve reference discipline
- The changelog template follows [Keep a Changelog](https://keepachangelog.com/) conventions adapted for the principled pipeline
- Generation is interactive via Claude Code skills, not fully automated, allowing human review and adjustment before finalization

## Options Considered

### Option 1: Conventional Commits

Adopt Conventional Commits (feat:, fix:, etc.) for commit messages and generate changelogs from them using tools like `conventional-changelog`.

**Pros:**

- Well-established ecosystem with mature tooling
- Low barrier to adoption — teams only need to follow a commit message convention
- Works independently of any documentation pipeline

**Cons:**

- Commit messages carry far less context than proposals and ADRs
- No link to specifications — "feat: add event sourcing" doesn't explain _why_ or what alternatives were considered
- Duplicates information that already exists in the pipeline
- Requires commit discipline that many teams struggle to maintain

### Option 2: CI-only automation

Generate changelogs in GitHub Actions triggered by tag push or release branch creation.

**Pros:**

- Fully automated — no manual steps
- Runs consistently on every release
- Can be combined with any changelog source (commits, PRs, pipeline docs)

**Cons:**

- Non-interactive — no opportunity to review or adjust before finalization
- The principled approach values human review of specification artifacts; changelogs synthesize multiple specifications and should be reviewed
- CI can _validate_ a changelog but generating it autonomously bypasses the review that makes principled artifacts valuable

### Option 3: Pipeline-based generation (chosen)

Map commits to proposals, plans, and ADRs and synthesize changelog entries with specification references.

**Pros:**

- Leverages the rich metadata already captured in the documentation pipeline
- Changelog entries are strictly more informative than commit-based entries
- Creates a complete audit trail from release notes back to original specifications
- Interactive workflow allows human review and adjustment
- Conventional Commits can serve as a fallback for unreferenced changes

**Cons:**

- Requires consistent pipeline references in PRs and commits
- More complex implementation than commit-based generation
- Depends on the quality of reference discipline across the team

## Consequences

### Positive

- Changelogs become a synthesis of the documentation pipeline, not a separate artifact maintained in isolation.
- Every changelog entry traces back to the specification that motivated it, providing full auditability.
- Unreferenced changes are surfaced as "uncategorized," creating a natural feedback mechanism that improves pipeline reference discipline over time.
- The interactive skill-based workflow preserves human judgment in changelog authoring while automating the heavy lifting of reference collection.

### Negative

- Teams that don't consistently reference pipeline documents in PRs will get sparse changelogs. This is mitigated by principled-github's `/pr-describe`, which auto-generates references.
- The approach is principled-pipeline-specific — it doesn't produce useful changelogs for repositories not using the principled methodology.
- Changelog generation requires traversing git history and PR metadata, which may be slow for repositories with large release deltas.

## References

- [RFC-004: Principled Release Plugin](../proposals/004-principled-release-plugin.md)
- [ADR-011: Documents as Source of Truth](./011-documents-as-source-of-truth-in-sync.md) — establishes the document-first principle extended here to release artifacts
