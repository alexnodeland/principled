# Audit Report Format

Specification for the output produced by the `/docs-audit` skill.

## Summary Format (default)

The summary format provides a high-level overview of documentation health across all modules.

```
Documentation Audit Report
══════════════════════════════════════════

Modules scanned: 5
Modules passing: 3
Modules failing: 2
Compliance rate: 60%

Common gaps:
  - CLAUDE.md missing in 2 modules
  - docs/architecture/ missing in 2 modules

Failing modules:
  ✗ packages/auth-service (app) — 2 missing, 1 placeholder
  ✗ packages/shared-utils (lib) — 1 missing

══════════════════════════════════════════
```

## Detailed Format (`--format detailed`)

The detailed format includes per-module breakdowns identical to the `/validate` output.

```
Documentation Audit Report
══════════════════════════════════════════

Module: packages/payment-gateway (app)
────────────────────────────────────────
✓ docs/proposals/          exists (2 files)
✓ docs/plans/              exists (1 file)
✓ docs/decisions/          exists (1 file)
✓ docs/architecture/       exists (1 file)
✓ docs/runbooks/           exists (3 files)
✓ docs/integration/        exists (1 file)
✓ docs/config/             exists (1 file)
✓ README.md                exists
✓ CONTRIBUTING.md          exists
✓ CLAUDE.md                exists
────────────────────────────────────────
Result: PASS

Module: packages/auth-service (app)
────────────────────────────────────────
✓ docs/proposals/          exists (1 file)
✓ docs/plans/              exists (0 files)
✓ docs/decisions/          exists (0 files)
✗ docs/architecture/       MISSING
✓ docs/runbooks/           exists (1 file)
✓ docs/integration/        exists (0 files)
~ docs/config/             placeholder only
✓ README.md                exists
✓ CONTRIBUTING.md          exists
✗ CLAUDE.md                MISSING
────────────────────────────────────────
Result: FAIL (2 missing, 1 placeholder)

══════════════════════════════════════════
Summary
──────────────────────────────────────────
Modules scanned: 2
Modules passing: 1
Modules failing: 1
Compliance rate: 50%
══════════════════════════════════════════
```

## Root-Level Reporting (`--include-root`)

When `--include-root` is specified, the repo-level docs structure is validated and reported as a separate entry:

```
Root: docs/ (cross-cutting)
────────────────────────────────────────
✓ docs/proposals/          exists (3 files)
✓ docs/plans/              exists (1 file)
✓ docs/decisions/          exists (2 files)
✓ docs/architecture/       exists (1 file)
────────────────────────────────────────
Result: PASS
```

The root result is included in the aggregate statistics.

## Report Components

| Component             | Description                                       |
| --------------------- | ------------------------------------------------- |
| **Module header**     | Module path and type                              |
| **Component list**    | Each required directory/file with status marker   |
| **Per-module result** | PASS or FAIL with counts                          |
| **Summary**           | Aggregate statistics across all modules           |
| **Common gaps**       | Most frequently missing components (summary mode) |
| **Failing modules**   | List of non-compliant modules (summary mode)      |

## Status Markers

| Marker | Meaning                                               |
| ------ | ----------------------------------------------------- |
| `✓`    | Present with content                                  |
| `✗`    | Missing (always a failure)                            |
| `~`    | Present but placeholder only (failure in strict mode) |

## Module Type Detection

The audit skill determines module type by:

1. Reading the module's `CLAUDE.md` file, looking for the `## Module Type` section
2. If not found, falling back to the project configuration (`principled-docs.defaultModuleType`)
3. If neither available, reporting an error for that module
