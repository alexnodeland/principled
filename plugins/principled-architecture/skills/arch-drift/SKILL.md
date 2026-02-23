---
name: arch-drift
description: >
  Detect violations of architectural decisions in the codebase. Checks
  module dependency direction rules, identifies boundary violations, and
  reports drift between documented decisions and actual code.
allowed-tools: Read, Bash(git *), Bash(ls *), Bash(bash plugins/*)
user-invocable: true
---

# Architecture Drift --- Decision Conformance Checking

Detect whether the codebase conforms to documented architectural decisions. Checks dependency direction rules, identifies module boundary violations, and reports drift with references to governing ADRs.

## Command

```
/arch-drift [--module <path>] [--strict]
```

## Arguments

| Argument          | Required | Description                                                       |
| ----------------- | -------- | ----------------------------------------------------------------- |
| `--module <path>` | No       | Scope analysis to a single module. Checks all modules if omitted. |
| `--strict`        | No       | Exit non-zero on any error-severity violation. For CI use.        |

## Workflow

1. **Scan modules.** Discover all modules:

   ```bash
   bash ../arch-map/scripts/scan-modules.sh [--module <path>]
   ```

2. **Read accepted ADRs.** For each ADR in `docs/decisions/` with status `accepted`:
   - Extract the architectural constraints it declares
   - Note which modules it governs (by path references in the body)
   - Focus on the "Decision" section for specific rules or patterns

3. **Check dependency direction.** For each module, run the boundary checker:

   ```bash
   bash scripts/check-boundaries.sh --module <path> --type <type>
   ```

   This scans source files for import statements and checks them against the dependency direction rules:

   | Module Type | Can Depend On     | Cannot Depend On |
   | ----------- | ----------------- | ---------------- |
   | `app`       | `lib`, `core`     | other `app`      |
   | `lib`       | `core`            | `app`, `lib`\*   |
   | `core`      | _(none internal)_ | `app`, `lib`     |

   \*Cross-lib dependencies are allowed if explicitly declared in the module's CLAUDE.md `## Dependencies` section.

4. **Classify findings.** Each violation is classified by severity:
   - **Error**: Clear dependency direction violation (e.g., `core` importing from `app`)
   - **Warning**: Probable violation with heuristic uncertainty
   - **Info**: Governance observations (e.g., no ADR covers this module)

5. **Reference governing ADRs.** For each violation, identify which ADR established the rule being violated and include the reference in the report.

6. **Report results.** Output a structured report:

   ```
   Architecture drift analysis:
     Modules checked: 8
     Violations found: 3
       Errors: 1
       Warnings: 2

     ERROR: packages/core/src/utils.ts:15
       Imports from packages/api (app) — core cannot depend on app
       Governing ADR: ADR-014 (Heuristic Architecture Governance)

     WARNING: packages/auth-lib/src/client.ts:42
       Imports from packages/shared-lib (lib) — lib-to-lib not declared
       Declare in CLAUDE.md ## Dependencies to allow
   ```

7. **Strict mode.** If `--strict` is specified and any error-severity violations exist, report failure. This enables CI integration.

## Scripts

- `scripts/check-boundaries.sh` --- Scan source files for import violations against dependency direction rules
