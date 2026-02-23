---
name: arch-sync
description: >
  Update architecture documents to reflect the current codebase state.
  Compares documented modules, types, and components against actual
  code and proposes updates for human review. Never auto-modifies.
allowed-tools: Read, Write, Edit, Bash(git *), Bash(ls *), Bash(bash plugins/*)
user-invocable: true
---

# Architecture Sync --- Document Synchronization

Update architecture documents to reflect the current codebase state. Compares the documented state against actual modules, types, and components, then proposes changes for human review.

## Command

```
/arch-sync [--doc <path>] [--all]
```

## Arguments

| Argument       | Required | Description                                         |
| -------------- | -------- | --------------------------------------------------- |
| `--doc <path>` | No       | Path to a specific architecture doc to sync.        |
| `--all`        | No       | Sync all architecture docs in `docs/architecture/`. |

If neither `--doc` nor `--all` is provided, list available architecture docs and ask which to sync.

## Workflow

1. **Identify target docs.** If `--doc` is specified, use that file. If `--all`, process every `.md` file in `docs/architecture/`. Otherwise, list available docs for selection.

2. **Detect changes.** For each target doc, run the change detector:

   ```bash
   bash scripts/detect-changes.sh --doc <path>
   ```

   This outputs discrepancies:
   - `missing_module` --- doc references a module that no longer exists
   - `new_module` --- module exists but is not mentioned in the doc
   - `type_mismatch` --- module type in doc doesn't match CLAUDE.md

3. **Analyze document structure.** Read the architecture doc and identify:
   - Module lists or tables that need updating
   - Component inventories that may be incomplete
   - Integration pattern descriptions that reference outdated modules
   - Diagram descriptions that may need revision

4. **Propose updates.** For each discrepancy:
   - Draft a specific edit (addition, removal, or modification)
   - Show the proposed change in context
   - Reference the source of truth (CLAUDE.md, directory structure)

5. **Present for review.** Display all proposed changes and ask for human approval before applying. Architecture documents are too important to modify automatically.

   ```
   Architecture sync for docs/architecture/plugin-system.md:

   Change 1: Add missing module reference
     + principled-architecture (architecture) — new plugin added
     Source: plugins/principled-architecture/CLAUDE.md

   Change 2: Remove stale reference
     - packages/legacy-auth (removed from codebase)

   Apply changes? [y/n/select]
   ```

6. **Apply approved changes.** Only modify the document if the user approves. Apply edits inline, preserving document structure and formatting.

7. **Report results.**

   ```
   Architecture sync complete:
     Document: docs/architecture/plugin-system.md
     Changes detected: 3
     Changes applied: 2
     Changes skipped: 1
   ```

## Scripts

- `scripts/detect-changes.sh` --- Compare architecture doc content against actual codebase module state
