# GitHub Label Taxonomy

## Label Groups

### Proposal Lifecycle

| Label                 | Color     | Description             |
| --------------------- | --------- | ----------------------- |
| `proposal:draft`      | `#0E8A16` | Proposal in draft state |
| `proposal:in-review`  | `#FBCA04` | Proposal under review   |
| `proposal:accepted`   | `#006B75` | Proposal accepted       |
| `proposal:rejected`   | `#B60205` | Proposal rejected       |
| `proposal:superseded` | `#5319E7` | Proposal superseded     |

### Plan Lifecycle

| Label            | Color     | Description             |
| ---------------- | --------- | ----------------------- |
| `plan:active`    | `#0E8A16` | Plan actively executing |
| `plan:complete`  | `#006B75` | Plan completed          |
| `plan:abandoned` | `#B60205` | Plan abandoned          |

### Decision Lifecycle

| Label                 | Color     | Description                   |
| --------------------- | --------- | ----------------------------- |
| `decision:proposed`   | `#FBCA04` | Decision proposed             |
| `decision:accepted`   | `#006B75` | Decision accepted (immutable) |
| `decision:deprecated` | `#E4E669` | Decision deprecated           |
| `decision:superseded` | `#5319E7` | Decision superseded           |

### Task Status

| Label              | Color     | Description                |
| ------------------ | --------- | -------------------------- |
| `task:in-progress` | `#0E8A16` | Task being implemented     |
| `task:validating`  | `#FBCA04` | Task undergoing validation |
| `task:passed`      | `#006B75` | Task passed validation     |
| `task:failed`      | `#B60205` | Task failed validation     |
| `task:merged`      | `#5319E7` | Task merged                |
| `task:abandoned`   | `#E4E669` | Task abandoned             |

### Document Type

| Label       | Color     | Description                   |
| ----------- | --------- | ----------------------------- |
| `type:rfc`  | `#C5DEF5` | Proposal / RFC document       |
| `type:adr`  | `#D4C5F9` | Architectural Decision Record |
| `type:plan` | `#BFD4F2` | DDD Implementation Plan       |
| `type:arch` | `#BFDADC` | Architecture document         |

### Workflow

| Label              | Color     | Description            |
| ------------------ | --------- | ---------------------- |
| `ready-for-review` | `#0E8A16` | Ready for human review |
| `needs-discussion` | `#FBCA04` | Needs team discussion  |
| `blocked`          | `#B60205` | Blocked on dependency  |
| `automated`        | `#E4E669` | Created by automation  |

## Naming Convention

- Groups use colon separator: `group:value`
- All lowercase
- Hyphens for multi-word values: `task:in-progress`
- Group prefixes: `proposal:`, `plan:`, `decision:`, `task:`, `type:`
