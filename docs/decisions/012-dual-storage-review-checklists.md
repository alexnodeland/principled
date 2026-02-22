---
title: "Dual Storage for Review Checklists"
number: "012"
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-22
from_proposal: "003"
supersedes: null
superseded_by: null
---

# ADR-012: Dual Storage for Review Checklists

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-quality plugin generates review checklists from plan acceptance criteria and relevant ADRs. These checklists need a storage location. Three options were considered:

1. **PR comments only** — Checklists posted as GitHub PR comments. Visible to all reviewers. Ephemeral: tied to the PR lifecycle and not version-controlled.
2. **Local files only** — Checklists written to a `.review/` directory in the repository. Version-controlled and persistent. Not visible on GitHub without navigating to the file.
3. **Both PR comments and local files** — Checklists posted as PR comments _and_ saved locally. Dual visibility at the cost of dual storage.

The existing principled-github plugin established documents as the source of truth (ADR-011). Review checklists are a new artifact type that spans both GitHub (where reviews happen) and the repository (where specifications live).

## Decision

Review checklists use dual storage: posted as PR comments for reviewer visibility and saved as local files in `.review/` for version-controlled audit trail.

This means:

- `/review-checklist` posts the checklist as a PR comment (primary interface for reviewers) and writes it to `.review/<pr-number>-checklist.md`
- PR comments are the working copy — reviewers check items off directly on GitHub
- Local files are the persistent record — they survive PR closure and provide git-trackable history
- `/review-coverage` reads from both sources: PR comments for current check state, local files for the original checklist
- The `.review/` directory should be included in `.gitignore` by default, with teams opting in to version control if they want audit trails

## Options Considered

### Option 1: PR comments only

Checklists exist solely as GitHub PR comments.

**Pros:**

- Zero repository clutter
- Natural home: reviews happen on PRs, so checklists belong there
- GitHub renders Markdown checklists natively with interactive checkboxes

**Cons:**

- Ephemeral: closed/merged PRs retain comments but are harder to query historically
- No version control: checklist state changes are not tracked in git
- Requires GitHub access to view past checklists

### Option 2: Local files only

Checklists written to `.review/` directory.

**Pros:**

- Version-controlled: full git history of checklist creation and updates
- Accessible offline without GitHub
- Consistent with principled methodology's repository-first approach

**Cons:**

- Not visible to reviewers during the review process (they'd need to check the file)
- Adds repository clutter (one file per PR)
- Disconnected from where reviews actually happen (GitHub PR UI)

### Option 3: Both PR comments and local files (chosen)

Dual storage with PR comments as primary and local files as secondary.

**Pros:**

- Best of both: reviewers see checklists in the PR, and the repository retains a record
- PR comments provide interactive checkboxes for the review workflow
- Local files enable historical analysis and audit without GitHub API calls
- Teams can choose their persistence preference via `.gitignore`

**Cons:**

- Dual storage introduces potential divergence (PR comment updated but local file not)
- Slightly more complex implementation
- `.review/` directory adds files to the repository

## Consequences

### Positive

- Reviewers interact with checklists where they already work (GitHub PR comments), reducing friction.
- Local files provide a durable audit trail that survives beyond the PR lifecycle.
- Teams control the trade-off: `.gitignore` the `.review/` directory for zero clutter, or track it for full auditability.
- `/review-coverage` can operate offline against local files when GitHub is unavailable.

### Negative

- Two copies of the same checklist can diverge. The PR comment may have checked items that the local file doesn't reflect. Mitigation: `/review-coverage` reads from PR comments (the interactive copy) for current state.
- `.review/` directory requires team agreement on whether to track or ignore in git. No single default satisfies all teams.
- Implementation complexity is higher than either single-storage option, though the additional code is straightforward.

## References

- [RFC-003: Principled Quality Plugin](../proposals/003-principled-quality-plugin.md)
- [ADR-011: Documents as Source of Truth](./011-documents-as-source-of-truth-in-sync.md) — establishes the document-first principle that this ADR extends to a new artifact type
