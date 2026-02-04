---
name: validate
description: >
  Check documentation structure against the expected standard.
  Reports missing directories, missing files, and placeholder-only content.
  Use after scaffolding, during review, or to check compliance.
  Use --root to validate the repo-level docs structure.
allowed-tools: Read, Bash(find *), Bash(ls *), Bash(cat *), Bash(grep *)
user-invocable: true
---

# Validate — Structural Validation

Check that a module's documentation structure matches the expected standard for its type.

## Command

```
/validate [module-path] --type core|lib|app [--strict] [--json]
/validate --root [--strict] [--json]
```

## Arguments

| Argument | Required | Description |
|---|---|---|
| `[module-path]` | No | Path to the module to validate. Defaults to current working directory. |
| `--type` | Yes (unless `--root` or detectable from CLAUDE.md) | Module type: `core`, `lib`, or `app` |
| `--root` | No | Validate the repo-level `docs/` structure |
| `--strict` | No | Treat placeholder-only files as failures instead of warnings |
| `--json` | No | Produce machine-readable JSON output for CI |

## Workflow

1. **Parse arguments** from `$ARGUMENTS`.
2. **Determine module path and type.** If no path given, use the current working directory. If no type given, attempt to read from the module's `CLAUDE.md` (under `## Module Type`).
3. **Run the validation engine:**
   ```bash
   bash scripts/validate-structure.sh --module-path <path> --type <type> [--strict] [--json]
   ```
   Or for root validation:
   ```bash
   bash scripts/validate-structure.sh --root [--strict] [--json]
   ```
4. **Present results** to the user.

## Report Format

### Human-Readable (default)

```
Module: packages/auth-service (app)
────────────────────────────────────────
✓ docs/proposals/          exists (2 files)
✓ docs/plans/              exists (1 file)
✓ docs/decisions/          exists (1 file)
✗ docs/architecture/       MISSING
✓ docs/runbooks/           exists (3 files)
✓ docs/integration/        exists (1 file)
~ docs/config/             placeholder only
✓ README.md                exists
✓ CONTRIBUTING.md          exists
✗ CLAUDE.md                MISSING
────────────────────────────────────────
Result: FAIL (2 missing, 1 placeholder)
```

**Legend:**
- `✓` — Component exists with content
- `✗` — Component is MISSING (always a failure)
- `~` — Component exists but contains only placeholder content (failure in `--strict` mode)

### JSON (with `--json`)

Machine-readable output suitable for CI pipelines. Each component is reported with `state`, `label`, and `detail` fields.

## Scripts

- `scripts/validate-structure.sh` — Validation engine (copy of `scaffold/scripts/validate-structure.sh`)
