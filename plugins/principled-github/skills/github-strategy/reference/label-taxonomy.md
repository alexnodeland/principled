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

### Document Type

| Label       | Color     | Description             |
| ----------- | --------- | ----------------------- |
| `type:rfc`  | `#C5DEF5` | Proposal / RFC document |
| `type:plan` | `#BFD4F2` | DDD Implementation Plan |

## Naming Convention

- Groups use colon separator: `group:value`
- All lowercase
- Hyphens for multi-word values: `proposal:in-review`
- Group prefixes: `proposal:`, `plan:`, `type:`
