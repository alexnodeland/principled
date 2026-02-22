---
name: review-context
description: >
  Surface the proposals, plans, and ADRs relevant to a pull request's
  changed files. Maps files to modules, finds specification documents,
  and presents a concise summary of the review context.
allowed-tools: Read, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *)
user-invocable: true
---

# Review Context --- Specification Surfacing

Surface the specification context a reviewer needs for a pull request. Lists changed files, maps them to modules, and identifies relevant proposals, plans, and ADRs.

## Command

```
/review-context <pr-number>
```

## Arguments

| Argument      | Required | Description                                  |
| ------------- | -------- | -------------------------------------------- |
| `<pr-number>` | Yes      | The GitHub PR number to analyze for context. |

## Prerequisites

- `gh` CLI must be installed and authenticated
- Repository must have a GitHub remote configured

## Workflow

1. **Verify prerequisites.** Check that `gh` is available and authenticated:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

2. **Get changed files.** List all files changed in the PR:

   ```bash
   gh pr diff <pr-number> --name-only
   ```

3. **Map files to modules.** For each changed file, identify its module:

   ```bash
   bash scripts/map-files-to-modules.sh --files <comma-separated-files>
   ```

   This walks up from each file to the nearest CLAUDE.md and extracts the module type.

4. **Find relevant specifications.** For each unique module identified:
   - **Proposals:** Search `docs/proposals/` (and module-level `docs/proposals/` if it exists) for RFCs that reference the module or its components.
   - **Plans:** Search `docs/plans/` for active plans that reference the module. Check PR description for explicit plan references (e.g., `Plan-NNN`).
   - **ADRs:** Search `docs/decisions/` for ADRs relevant to the module scope. Read each ADR's title and decision summary.

5. **Check PR description for references.** Parse the PR title and body for explicit principled document references:
   - `RFC-NNN` or `Proposal-NNN` patterns
   - `Plan-NNN` or `Plan-NNN (task X.Y)` patterns
   - `ADR-NNN` patterns
   - File paths matching `docs/proposals/*.md`, `docs/plans/*.md`, `docs/decisions/*.md`

6. **Present the context summary.** Output a structured summary:

   ```
   Review Context for PR #42: "Add widget error handling"

   Modules touched:
     - src/widgets/ (lib) — 5 files changed
     - src/core/ (core) — 1 file changed

   Linked specifications (from PR description):
     - Plan-005 (task 2.1): Widget error handling
     - RFC-003: Principled Quality Plugin

   Relevant ADRs:
     - ADR-003: Module type declaration via CLAUDE.md
     - ADR-005: Pre-commit framework for git hooks

   Related proposals:
     - RFC-001: Widget system design (accepted)

   Related plans:
     - Plan-005: Widget improvements (active)
       Tasks touching these modules: 2.1, 2.3, 3.1

   Files by module:
     src/widgets/:
       - src/widgets/error-handler.ts (new)
       - src/widgets/widget.tsx (modified)
       - src/widgets/widget.test.ts (new)
       ...
     src/core/:
       - src/core/types.ts (modified)
   ```

   If no specifications are found for a module, note it:

   ```
   - src/utils/ (lib) — No linked specifications found
   ```

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from principled-github canonical)
- `scripts/map-files-to-modules.sh` --- Map file paths to modules via CLAUDE.md discovery
