# Naming Conventions

## Numbered Documents: `NNN-short-title.md`

Proposals, plans, and decisions use a three-digit zero-padded number prefix followed by a hyphenated slug:

```
NNN-short-title.md
```

### Rules

| Rule              | Detail                                                                              |
| ----------------- | ----------------------------------------------------------------------------------- |
| **Number format** | Three digits, zero-padded: `001`, `002`, ..., `999`                                 |
| **Separator**     | Single hyphen between number and slug                                               |
| **Slug format**   | Lowercase, hyphen-separated words. No special characters, no underscores, no spaces |
| **Extension**     | `.md` (configurable via `fileExtension` setting)                                    |

### Examples

```
001-switch-to-event-sourcing.md
002-use-kafka-for-event-store.md
003-add-payment-gateway.md
```

### Sequence Numbering

- Numbers are assigned sequentially within each directory scope.
- Each directory (`proposals/`, `plans/`, `decisions/`) maintains its own independent sequence within a module.
- Root-level and module-level directories maintain independent sequences.
- Gaps in sequences are not backfilled. The next number is always `max + 1`.
- When a plan or ADR originates from a proposal, it uses its own sequence number (not the proposal's number). The link to the originating proposal is maintained via the `originating_proposal` frontmatter field.

### Slug Rules

| Do                         | Don't                           |
| -------------------------- | ------------------------------- |
| `switch-to-event-sourcing` | `switch_to_event_sourcing`      |
| `add-payment-gateway`      | `Add-Payment-Gateway`           |
| `use-redis-for-caching`    | `use redis for caching`         |
| `adopt-typescript-strict`  | `adopt-typescript-strict-mode!` |

## Fixed-Name Files

These files use exact, fixed names with no number prefix:

| File              | Location               |
| ----------------- | ---------------------- |
| `README.md`       | Module root            |
| `CONTRIBUTING.md` | Module root            |
| `CLAUDE.md`       | Module root            |
| `INTERFACE.md`    | Module root (lib only) |

## Architecture Documents

Architecture docs use freeform descriptive names (no number prefix):

```
docs/architecture/data-flow.md
docs/architecture/authentication-system.md
docs/architecture/module-boundaries.md
```

## Directory Names

All directory names are lowercase, singular or plural as specified:

| Directory            | Form           |
| -------------------- | -------------- |
| `docs/proposals/`    | Plural         |
| `docs/plans/`        | Plural         |
| `docs/decisions/`    | Plural         |
| `docs/architecture/` | Singular       |
| `docs/examples/`     | Plural (lib)   |
| `docs/runbooks/`     | Plural (app)   |
| `docs/integration/`  | Singular (app) |
| `docs/config/`       | Singular (app) |
