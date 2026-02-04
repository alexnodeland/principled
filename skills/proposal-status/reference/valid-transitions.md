# Proposal State Machine — Valid Transitions

## State Diagram

```
draft ──→ in-review ──→ accepted
                    ──→ rejected
                    ──→ superseded
```

## Transitions

### `draft` → `in-review`

| Property | Value |
|---|---|
| **Condition** | Author considers the proposal ready for team review |
| **Side-effects** | None |
| **Frontmatter changes** | `status: in-review`, `updated: <today>` |

### `in-review` → `accepted`

| Property | Value |
|---|---|
| **Condition** | Reviewers approve the proposal |
| **Side-effects** | Prompt user to create an implementation plan via `/new-plan` |
| **Frontmatter changes** | `status: accepted`, `updated: <today>` |

### `in-review` → `rejected`

| Property | Value |
|---|---|
| **Condition** | Reviewers decline the proposal |
| **Side-effects** | None |
| **Frontmatter changes** | `status: rejected`, `updated: <today>` |

### `in-review` → `superseded`

| Property | Value |
|---|---|
| **Condition** | A newer proposal replaces this one |
| **Side-effects** | Prompt for superseding proposal number; set `superseded_by` field |
| **Frontmatter changes** | `status: superseded`, `superseded_by: <NNN>`, `updated: <today>` |

## Terminal States

The following states are **terminal** — no further transitions are permitted:

- `accepted`
- `rejected`
- `superseded`

Once a proposal reaches a terminal state, its content is frozen. No edits are permitted. The enforcement hook (`check-proposal-lifecycle.sh`) blocks all Edit and Write operations on terminal proposals.

## Invalid Transitions

Any transition not listed above is invalid. Common errors:

| Attempted Transition | Error Message |
|---|---|
| `draft` → `accepted` | "Cannot skip states. Valid transitions from 'draft': in-review." |
| `draft` → `rejected` | "Cannot skip states. Valid transitions from 'draft': in-review." |
| `draft` → `superseded` | "Cannot skip states. Valid transitions from 'draft': in-review." |
| `accepted` → anything | "Proposal has reached terminal status 'accepted' and cannot be transitioned." |
| `rejected` → anything | "Proposal has reached terminal status 'rejected' and cannot be transitioned." |
| `superseded` → anything | "Proposal has reached terminal status 'superseded' and cannot be transitioned." |
