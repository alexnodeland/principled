---
title: "Documents as Source of Truth in Bidirectional Sync"
number: "011"
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-22
from_proposal: "007"
supersedes: null
superseded_by: null
---

# ADR-011: Documents as Source of Truth in Bidirectional Sync

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-github plugin synchronizes documents (proposals, plans) with GitHub issues. This bidirectional sync creates a data consistency question: when a proposal title is changed in the markdown file and the corresponding GitHub issue title is changed independently, which version wins?

Three consistency models were considered:

1. **Documents as source of truth** — Markdown documents in the repository are authoritative. GitHub issues are a synchronized view. Sync always overwrites the GitHub issue from the document.
2. **GitHub as source of truth** — GitHub issues are authoritative. Documents are generated from issues.
3. **Last-write-wins** — Whichever side was modified more recently takes precedence.

## Decision

Documents are the source of truth. The principled pipeline's markdown documents (proposals, plans, ADRs) are the authoritative representation. GitHub issues are a synchronized projection — they reflect document state but do not drive it.

This means:

- `/sync-issues` pushes document state to GitHub issues, overwriting issue title, body, and labels
- `/ingest-issue` creates documents _from_ issues (GitHub → documents), but once a document exists, it becomes the authority
- If a document and issue diverge, `/sync-issues` resolves the divergence by updating the issue to match the document
- Changes to the pipeline should be made in documents first, then synced to GitHub

## Options Considered

### Option 1: Documents as source of truth (chosen)

Markdown documents are authoritative. GitHub issues reflect document state.

**Pros:**

- Consistent with the principled methodology: specifications live in the repository, not in an external system
- Documents are version-controlled (git history preserves every change)
- Frontmatter metadata (status, author, dates) is richer than GitHub issue metadata
- Enforcement hooks (ADR immutability, proposal lifecycle) apply to documents, not issues
- No split-brain risk: one clear authority

**Cons:**

- Changes made directly on GitHub issues (by non-technical stakeholders, mobile users, etc.) will be overwritten on next sync
- Requires discipline: team must make changes in documents, not in GitHub issues
- Issue comments on GitHub are not synced back to documents (comments are GitHub-only)

### Option 2: GitHub as source of truth

GitHub issues drive the pipeline. Documents are generated/updated from issues.

**Pros:**

- GitHub issues are more accessible to non-technical stakeholders
- GitHub's UI is richer (labels, assignees, milestones, projects)

**Cons:**

- Loses the principled methodology's core value: specifications in the repository
- GitHub issues lack frontmatter, structured sections, and enforcement hooks
- Version history is in GitHub's API, not in git — harder to audit
- Cannot apply principled-docs enforcement hooks to GitHub issues

### Option 3: Last-write-wins

Compare timestamps; the most recently modified side takes precedence.

**Pros:**

- Flexible: changes can be made on either side
- No data loss (most recent change always preserved)

**Cons:**

- Conflict detection is complex (clock skew, timezone differences)
- No single source of truth — both sides must be consulted to know the current state
- Merge conflicts between document and issue changes are hard to resolve automatically
- Undermines the principled methodology's emphasis on specification-in-repository

## Consequences

### Positive

- Clear authority chain: document → issue. No ambiguity about which side is correct.
- Document enforcement hooks (immutability, lifecycle) are the governance layer. GitHub issues inherit this governance via sync.
- Version-controlled specification: all changes are in git history, auditable and reversible.
- `/sync-issues` is simple: read document, update issue. No conflict resolution needed.

### Negative

- GitHub issue edits are ephemeral: they will be overwritten on next sync. Team members who edit issues directly may lose their changes.
- Non-technical stakeholders who prefer GitHub's UI must learn to request changes through documents (or accept that their GitHub edits are temporary).
- Issue comments are one-directional: comments exist on GitHub but are not reflected in documents. Discussion context lives only on GitHub.

## References

- [RFC-007: Principled GitHub Plugin](../proposals/007-principled-github-plugin.md)
- Implementation: `plugins/principled-github/skills/sync-issues/SKILL.md`
- Sync model reference: `plugins/principled-github/skills/github-strategy/reference/sync-model.md`
