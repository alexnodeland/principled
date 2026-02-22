# GitHub-Principled Mapping Model

## Entity Mapping

The principled pipeline maps to GitHub entities as follows:

| Principled Entity | GitHub Entity   | Relationship                                 |
| ----------------- | --------------- | -------------------------------------------- |
| Proposal (RFC)    | Issue           | 1:1 --- each proposal becomes a GitHub issue |
| Plan (DDD)        | Tracking Issue  | 1:1 --- each plan becomes a tracking issue   |
| Plan Task         | Pull Request    | 1:1 --- each task becomes a PR               |
| Decision (ADR)    | Linked Ref      | Referenced in issues/PRs, not a standalone   |
| Architecture Doc  | Wiki/Linked Ref | Referenced in issues/PRs                     |

## Status Mapping

### Proposals to Issues

| Proposal Status | Issue State | Labels                            |
| --------------- | ----------- | --------------------------------- |
| `draft`         | Open        | `proposal:draft`, `type:rfc`      |
| `in-review`     | Open        | `proposal:in-review`, `type:rfc`  |
| `accepted`      | Closed      | `proposal:accepted`, `type:rfc`   |
| `rejected`      | Closed      | `proposal:rejected`, `type:rfc`   |
| `superseded`    | Closed      | `proposal:superseded`, `type:rfc` |

### Plans to Tracking Issues

| Plan Status | Issue State | Labels                        |
| ----------- | ----------- | ----------------------------- |
| `active`    | Open        | `plan:active`, `type:plan`    |
| `complete`  | Closed      | `plan:complete`, `type:plan`  |
| `abandoned` | Closed      | `plan:abandoned`, `type:plan` |

### Tasks to Pull Requests

| Task Status   | PR State      | Labels                            |
| ------------- | ------------- | --------------------------------- |
| `pending`     | (not created) | ---                               |
| `in_progress` | Open (draft)  | `task:in-progress`                |
| `validating`  | Open          | `task:validating`                 |
| `passed`      | Open          | `task:passed`, `ready-for-review` |
| `failed`      | Open          | `task:failed`                     |
| `merged`      | Merged        | `task:merged`                     |
| `abandoned`   | Closed        | `task:abandoned`                  |

## Issue Body Structure

### Proposal Issue

```markdown
## RFC-NNN: <Title>

**Status:** <status>
**Author:** <author>
**Created:** <date>
**Document:** [`docs/proposals/NNN-slug.md`](link)

### Context

<excerpt from proposal context section>

### Proposal Summary

<excerpt from proposal section>

### Open Questions

<from proposal open questions>

---

> This issue tracks [RFC-NNN](link-to-file). The proposal document is the
> source of truth. Update the document first, then sync this issue.
```

### Plan Tracking Issue

```markdown
## Plan-NNN: <Title>

**Status:** <status>
**From Proposal:** RFC-<originating_proposal>
**Document:** [`docs/plans/NNN-slug.md`](link)

### Tasks

- [ ] Task 1.1: <description> (#PR)
- [ ] Task 1.2: <description> (#PR)
- [ ] Task 2.1: <description> (#PR)

### Progress

Phase 1: <status>
Phase 2: <status>

---

> This issue tracks [Plan-NNN](link-to-file). The plan document is the
> source of truth.
```

## Sync Direction

Documents are **always** the source of truth:

1. Create/update the principled document first
2. Run `/sync-issues` to push changes to GitHub
3. GitHub issue/PR metadata reflects document state
4. Comments and discussion happen on GitHub
5. Decisions from discussion are captured back in documents manually

Never auto-update documents from GitHub state changes.
