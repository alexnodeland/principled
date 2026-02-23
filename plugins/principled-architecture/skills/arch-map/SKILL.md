---
name: arch-map
description: >
  Generate a map linking modules to their governing ADRs and architecture
  documents. Scans all modules via CLAUDE.md discovery, cross-references
  ADRs and architecture docs, and classifies governance coverage as
  Full, Partial, or None.
allowed-tools: Read, Write, Bash(git *), Bash(ls *), Bash(bash plugins/*)
user-invocable: true
---

# Architecture Map --- Module-to-Decision Mapping

Generate a map between code modules and their governing ADRs and architecture documents. The foundational skill for architecture governance.

## Command

```
/arch-map [--module <path>] [--output <path>]
```

## Arguments

| Argument          | Required | Description                                                    |
| ----------------- | -------- | -------------------------------------------------------------- |
| `--module <path>` | No       | Scope the map to a single module. Maps all modules if omitted. |
| `--output <path>` | No       | Write the map to a file. Prints to output if omitted.          |

## Workflow

1. **Scan modules.** Discover all modules by finding CLAUDE.md files:

   ```bash
   bash scripts/scan-modules.sh [--module <path>]
   ```

   This outputs tab-separated lines: `<module-path>\t<module-type>\t<module-name>`.

2. **Read all ADRs.** List and read each file in `docs/decisions/`:
   - Extract the ADR number and title from frontmatter
   - Extract the status (only process `accepted` ADRs for governance mapping)
   - Scan the ADR body for module path references, component names, and scope indicators

3. **Read all architecture docs.** List and read each file in `docs/architecture/`:
   - Scan each doc's body for module path references and module name mentions

4. **Cross-reference.** For each module:
   - Find all accepted ADRs whose body references this module's path or name
   - Find all architecture docs that reference this module's path or name
   - Classify coverage:
     - **Full**: at least one governing ADR AND at least one architecture doc reference
     - **Partial**: has governing ADRs OR architecture doc references, but not both
     - **None**: no governing ADRs and no architecture doc references

5. **Render the map.** Read the template from `templates/arch-map.md` and fill in:
   - `{{DATE}}` --- current date (YYYY-MM-DD)
   - `{{MODULE_COUNT}}` --- total modules scanned
   - `{{MODULES}}` --- rendered module sections (see format below)
   - `{{FULL_COUNT}}`, `{{PARTIAL_COUNT}}`, `{{NONE_COUNT}}` --- coverage counts

   Each module section follows this format:

   ```markdown
   ## Module: <path> (<type>)

   ### Governing ADRs

   - **ADR-NNN**: <title> --- Affects: <brief scope description>

   ### Architecture Docs

   - [<title>](path) --- Referenced in: <section or "body">

   ### Coverage: <Full|Partial|None>
   ```

   If a module has no governing ADRs, show `- _(none)_`.
   If a module has no architecture doc references, show `- _(none)_`.

6. **Output results.** If `--output` is specified, write the map to that file. Otherwise, display the rendered map. Report a summary:

   ```
   Architecture map generated:
     Modules: 12
     Full coverage: 5
     Partial coverage: 4
     No coverage: 3
   ```

## Scripts

- `scripts/scan-modules.sh` --- Discover modules via CLAUDE.md and parse module type

## Templates

- `templates/arch-map.md` --- Architecture map template with placeholder variables for date, module sections, and coverage counts
