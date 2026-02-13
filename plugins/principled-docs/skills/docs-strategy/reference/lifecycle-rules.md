# Lifecycle Rules

## Proposal Lifecycle

```
draft ──→ in-review ──→ accepted
                    ──→ rejected
                    ──→ superseded
```

### States

| State        | Mutable?          | Description                                                                         |
| ------------ | ----------------- | ----------------------------------------------------------------------------------- |
| `draft`      | Yes               | Initial state. Author is actively writing the proposal.                             |
| `in-review`  | Yes               | Proposal is complete and under team review.                                         |
| `accepted`   | **No** (terminal) | Proposal was approved. Triggers ADR creation.                                       |
| `rejected`   | **No** (terminal) | Proposal was declined with rationale.                                               |
| `superseded` | **No** (terminal) | Replaced by a newer proposal. The `superseded_by` field identifies the replacement. |

### Valid Transitions

| From        | To           | Conditions                                                    |
| ----------- | ------------ | ------------------------------------------------------------- |
| `draft`     | `in-review`  | Author considers the proposal ready for review                |
| `in-review` | `accepted`   | Reviewers approve the proposal                                |
| `in-review` | `rejected`   | Reviewers decline the proposal                                |
| `in-review` | `superseded` | A newer proposal replaces this one (must set `superseded_by`) |

### Rules

- **No skipping states.** A proposal cannot go directly from `draft` to `accepted`.
- **No transitions from terminal states.** Once a proposal is `accepted`, `rejected`, or `superseded`, it cannot be changed.
- **Terminal proposals are frozen.** No edits are permitted to the content of a terminal proposal.
- **On acceptance:** The system prompts the user to create an ADR via `/new-adr --from-proposal NNN`.
- **On supersession:** The `superseded_by` field must be set to the number of the superseding proposal.

## Plan Lifecycle

```
active ──→ complete
       ──→ abandoned
```

### States

| State       | Mutable? | Description                                                   |
| ----------- | -------- | ------------------------------------------------------------- |
| `active`    | Yes      | Implementation is in progress. Tasks are being completed.     |
| `complete`  | No       | All tasks are done.                                           |
| `abandoned` | No       | Plan was abandoned. The originating decision may still stand. |

### Rules

- Plans are mutable while `active`. Any section can be updated as implementation progresses.
- Transitioning to `complete` should only happen when all implementation tasks are checked off.
- A plan always links back to its originating decision via the `originating_adr` frontmatter field.

## ADR Lifecycle

```
proposed ──→ accepted ──→ deprecated
                      ──→ superseded
```

### States

| State        | Mutable?           | Description                                                                    |
| ------------ | ------------------ | ------------------------------------------------------------------------------ |
| `proposed`   | Yes                | Decision is being drafted or under discussion.                                 |
| `accepted`   | **No** (immutable) | Decision has been approved and is in effect.                                   |
| `deprecated` | **No** (immutable) | Decision is no longer relevant but was not replaced.                           |
| `superseded` | **No** (immutable) | Replaced by a newer ADR. The `superseded_by` field identifies the replacement. |

### The Immutability Contract

Once an ADR reaches `accepted` status, its content is **immutable**. This is the foundational guarantee of the decision record system:

- No edits to the Decision, Context, Options, or Consequences sections.
- No edits to any frontmatter field **except** `superseded_by`.
- The `superseded_by` exception exists solely to maintain cross-references when a new ADR supersedes an existing one.
- To change a decision, create a new ADR that supersedes the old one.

### Rules

- ADRs may be created standalone or linked to an originating proposal via `--from-proposal`.
- When superseding an existing ADR, the old ADR's `superseded_by` field is updated (the one permitted mutation) and the new ADR references the superseded record.
