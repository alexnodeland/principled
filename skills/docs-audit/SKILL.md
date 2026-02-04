---
name: docs-audit
description: >
  Audit documentation health across all modules in the monorepo.
  Discovers modules, validates each, and produces an aggregate compliance report.
  Use --include-root to also validate the repo-level docs structure.
allowed-tools: Read, Bash(find *), Bash(ls *), Bash(cat *), Bash(grep *), Bash(wc *)
user-invocable: true
---

# Docs Audit — Monorepo-Wide Documentation Audit

Audit documentation health across all modules in the monorepo and produce an aggregate compliance report.

## Command

```
/docs-audit [--modules-dir <path>] [--format summary|detailed] [--include-root]
```

## Arguments

| Argument               | Required | Description                                                                  |
| ---------------------- | -------- | ---------------------------------------------------------------------------- |
| `--modules-dir <path>` | No       | Root directory containing modules (default: `packages` or value from config) |
| `--format`             | No       | Output format: `summary` (default) or `detailed`                             |
| `--include-root`       | No       | Also validate the repo-level `docs/` structure                               |

## Workflow

1. **Parse arguments.** Extract options from `$ARGUMENTS`. Use defaults from project configuration where not specified.

2. **Discover modules.** Find all subdirectories under the modules directory that appear to be modules (contain a `docs/` directory, `README.md`, or `CLAUDE.md`).
   - Filter out modules matching `ignoredModules` glob patterns from project config.

3. **Determine module types.** For each discovered module:
   - Read the module's `CLAUDE.md` and look for the `## Module Type` section
   - If not found, use `defaultModuleType` from project config
   - If neither available, report the module as "unknown type" and skip validation

4. **Validate each module.** For each module with a known type, run the structural validation:

   ```bash
   bash <plugin-root>/skills/scaffold/scripts/validate-structure.sh \
     --module-path <module-path> --type <type>
   ```

   Capture the results (present, missing, placeholder counts).

5. **Validate root (if `--include-root`).** Run:

   ```bash
   bash <plugin-root>/skills/scaffold/scripts/validate-structure.sh --root
   ```

6. **Aggregate results.** Compute:
   - Total modules scanned
   - Modules passing vs. failing
   - Compliance rate (percentage)
   - Most common gaps across all modules

7. **Format output.** Based on `--format`:
   - **summary:** High-level statistics, common gaps, list of failing modules
   - **detailed:** Per-module breakdown (same format as `/validate`) plus summary

   See `reference/report-format.md` for the complete output specification.

## Configuration

The audit skill respects project-level configuration from `.claude/settings.json`:

| Setting             | Used For                                                   |
| ------------------- | ---------------------------------------------------------- |
| `modulesDirectory`  | Default modules directory if `--modules-dir` not specified |
| `defaultModuleType` | Fallback module type if `CLAUDE.md` doesn't declare one    |
| `ignoredModules`    | Glob patterns for modules to skip                          |
| `strictMode`        | If true, placeholder-only files are treated as failures    |

## Reference

- `reference/report-format.md` — Complete specification of the audit output format
