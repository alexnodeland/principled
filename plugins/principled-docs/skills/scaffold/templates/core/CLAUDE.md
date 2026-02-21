# {{MODULE_NAME}} — Claude Code Context

## Module Type

{{MODULE_TYPE}}

## Key Conventions

TODO

## Documentation Structure

This module follows the Principled docs strategy:

- `docs/proposals/` — RFCs (proposals). Naming: `NNN-short-title.md`.
- `docs/plans/` — DDD implementation plans. Naming: `NNN-short-title.md` (matches proposal).
- `docs/decisions/` — ADRs (immutable after acceptance). Naming: `NNN-short-title.md`.
- `docs/architecture/` — Living design documentation.

## Pipeline

Proposals → Decisions → Plans. Proposals are strategic (what/why). Decisions are the
permanent record (what was decided). Plans are tactical (how, decomposed via DDD).

## Important Constraints

- Proposals with terminal status (accepted/rejected/superseded) must NOT be modified.
- ADRs with status `accepted` must NOT be modified (exception: `superseded_by` field).
- Plans require an accepted proposal (`--from-proposal NNN`).
- New changes follow the pipeline: proposal → ADR → plan.

## Testing

TODO

## Dependencies

TODO
