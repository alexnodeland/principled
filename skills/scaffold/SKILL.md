---
name: scaffold
description: >
  Generate the complete documentation structure for a new module.
  Use when creating a new app or lib module, or when asked to
  scaffold, initialize, or set up module documentation.
  Module type must be specified explicitly.
allowed-tools: Read, Write, Bash(mkdir *), Bash(ls *), Bash(cp *)
user-invocable: true
---

# Scaffold — Module Documentation Scaffolding

Generate the complete documentation structure for a new module or the repo root.

## Command

```
/scaffold <module-path> --type core|lib|app
/scaffold --root
```

## Arguments

| Argument | Required | Description |
|---|---|---|
| `<module-path>` | Yes (unless `--root`) | Path to the module root (e.g., `packages/payment-gateway`) |
| `--type` | Yes (unless `--root`) | Module type: `core`, `lib`, or `app`. Determines which directories and files are created. |
| `--root` | No | Scaffold the repo-level `docs/` structure instead of a module |

## Workflow

### Module Scaffolding (`/scaffold <path> --type <type>`)

1. **Parse arguments.** Extract `<module-path>` and `--type` from `$ARGUMENTS`. Type is required — do not guess or auto-detect.

2. **Create core directories:**
   ```
   <module-path>/docs/proposals/
   <module-path>/docs/plans/
   <module-path>/docs/decisions/
   <module-path>/docs/architecture/
   ```

3. **Create type-specific directories:**
   - **lib:** `<module-path>/docs/examples/`
   - **app:** `<module-path>/docs/runbooks/`, `<module-path>/docs/integration/`, `<module-path>/docs/config/`

4. **Populate core files** from `templates/core/`:
   - Read each template file from this skill's `templates/core/` directory
   - Replace placeholders with actual values:

     | Placeholder | Value |
     |---|---|
     | `{{MODULE_NAME}}` | Name derived from module path (e.g., `payment-gateway`) |
     | `{{MODULE_TYPE}}` | The `--type` value: `core`, `lib`, or `app` |
     | `{{DATE}}` | Today's date in `YYYY-MM-DD` format |
     | `{{AUTHOR}}` | Git user name (`git config user.name`) or "TODO" |

   - Write populated files:
     - `<module-path>/README.md`
     - `<module-path>/CONTRIBUTING.md`
     - `<module-path>/CLAUDE.md`

5. **Populate type-specific files:**
   - **lib:** Write `INTERFACE.md` from `templates/lib/INTERFACE.md`
   - **app:** (No additional root files — app extensions are directories with template docs)

6. **Run validation** using `scripts/validate-structure.sh`:
   ```bash
   bash scripts/validate-structure.sh --module-path <module-path> --type <type>
   ```

7. **Report results** to the user: list created directories and files, and validation status.

### Root Scaffolding (`/scaffold --root`)

1. Create repo-root directories:
   ```
   docs/proposals/
   docs/plans/
   docs/decisions/
   docs/architecture/
   ```

2. Run root validation:
   ```bash
   bash scripts/validate-structure.sh --root
   ```

3. Report results.

## Templates

All canonical templates live in this skill's `templates/` directory:

- `templates/core/` — proposal.md, plan.md, decision.md, architecture.md, README.md, CONTRIBUTING.md, CLAUDE.md
- `templates/lib/` — INTERFACE.md, example.md
- `templates/app/` — runbook.md, integration.md, config.md

## Scripts

- `scripts/validate-structure.sh` — Structural validation engine (canonical copy)
- `scripts/check-template-drift.sh` — CI script to verify template copies match canonical
