---
name: arch-audit
description: >
  Audit ADR coverage across modules. Identifies modules with no
  architectural governance, orphaned ADRs referencing removed modules,
  and stale architecture docs. Classifies findings by severity.
allowed-tools: Read, Write, Bash(git *), Bash(ls *), Bash(bash plugins/*)
user-invocable: true
---

# Architecture Audit --- Governance Coverage Assessment

Audit architectural decision coverage across all modules. Identify governance gaps, orphaned ADRs, and stale architecture documents.

## Command

```
/arch-audit [--module <path>]
```

## Arguments

| Argument          | Required | Description                                                        |
| ----------------- | -------- | ------------------------------------------------------------------ |
| `--module <path>` | No       | Scope the audit to a single module. Audits all modules if omitted. |

## Workflow

1. **Build architecture map.** Generate the architecture map (same logic as `/arch-map`) to establish the module-to-decision mapping and coverage classification for each module.

2. **Identify ungoverned modules.** List all modules with coverage classification `None`:
   - No governing ADRs and no architecture doc references
   - Classify severity:
     - **Warning** (default): Module has no governance
     - **Critical**: Module has no governance AND is a `core` module (foundational modules should have governance)

3. **Find orphaned ADRs.** For each accepted ADR:
   - Extract module path references from the ADR body
   - Check if referenced modules still exist in the codebase
   - If an ADR references modules that no longer exist, it is orphaned
   - Classify as **Info**: ADR may need review or deprecation

4. **Detect stale architecture docs.** For each architecture document:
   - Extract module and component references from the document body
   - Check if referenced modules still exist
   - Check if referenced module types still match CLAUDE.md declarations
   - If references are outdated, the doc is stale
   - Classify as **Info**: Document may need `/arch-sync` update

5. **Check for deprecated governance.** For each module governed by an ADR:
   - If the ADR has status `deprecated` or `superseded`, check for a replacement
   - If no replacement ADR exists, the module's governance is degraded
   - Classify as **Warning**: Module relies on deprecated decision

6. **Render audit report.** Read the template from `templates/audit-report.md` and fill in:
   - `{{DATE}}` --- current date (YYYY-MM-DD)
   - `{{MODULE_COUNT}}` --- total modules audited
   - `{{FULL_COUNT}}`, `{{PARTIAL_COUNT}}`, `{{NONE_COUNT}}` --- coverage counts
   - `{{FULL_PCT}}`, `{{PARTIAL_PCT}}`, `{{NONE_PCT}}` --- coverage percentages
   - `{{UNGOVERNED_MODULES}}` --- list of modules with no governance
   - `{{ORPHANED_ADRS}}` --- list of ADRs referencing nonexistent modules
   - `{{STALE_ARCH_DOCS}}` --- list of stale architecture documents
   - `{{FINDINGS}}` --- all findings sorted by severity (critical, warning, info)

7. **Report results.** Output the audit report and summarize:

   ```
   Architecture governance audit:
     Modules audited: 12
     Full coverage: 5 (42%)
     Partial coverage: 4 (33%)
     No coverage: 3 (25%)

     Findings:
       Critical: 1 (core module without governance)
       Warning: 2 (ungoverned modules)
       Info: 3 (orphaned ADRs, stale docs)
   ```

## Templates

- `templates/audit-report.md` --- Audit report template with placeholder variables for coverage summary, ungoverned modules, orphaned ADRs, stale docs, and findings
