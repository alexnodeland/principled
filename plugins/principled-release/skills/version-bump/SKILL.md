---
name: version-bump
description: >
  Coordinate version bumps across module manifests. Detects modules via
  CLAUDE.md, determines bump type from pipeline signals, and applies
  version changes to manifest files.
allowed-tools: Read, Write, Edit, Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *)
user-invocable: true
---

# Version Bump --- Monorepo-Aware Version Coordination

Coordinate version bumps across a monorepo by detecting modules, determining the appropriate bump type from pipeline signals, and applying version changes to manifest files.

## Command

```
/version-bump [--module <path>] [--type major|minor|patch]
```

## Arguments

| Argument                     | Required | Description                                                       |
| ---------------------------- | -------- | ----------------------------------------------------------------- |
| `--module <path>`            | No       | Scope to a single module. Without this, all modules are processed |
| `--type major\|minor\|patch` | No       | Override automatic bump detection with an explicit type           |

## Prerequisites

- Git repository
- Modules must declare themselves via `CLAUDE.md` (ADR-003)

## Workflow

1. **Detect modules.** Run the module detector:

   ```bash
   bash scripts/detect-modules.sh [--module <path>]
   ```

   This finds modules via `CLAUDE.md` files and locates their version manifests (package.json, Cargo.toml, pyproject.toml, VERSION, plugin.json).

2. **Determine bump type.** If `--type` is provided, use it directly. Otherwise, analyze changes since the last tag to determine bump type:
   - **Major:** Any proposal or ADR with `supersedes` set (breaking change)
   - **Minor:** Any accepted proposal (new capability)
   - **Patch:** Plan tasks, fixes, improvements without new proposals

   The highest bump type wins when multiple signals are present.

3. **For each module, apply the version bump.** Read the current version from the manifest, calculate the new version, and write it back:
   - `package.json` / `plugin.json`: Update the `"version"` field
   - `Cargo.toml` / `pyproject.toml`: Update the `version = "..."` line
   - `VERSION`: Replace the file contents

4. **Report results.** For each module bumped:

   ```
   Version bumps applied:
     . (core): 1.0.0 → 1.1.0 (minor — RFC-004 accepted proposal)
     plugins/principled-docs (lib): 0.3.1 → 0.3.2 (patch — Plan-000 tasks)

   2 modules bumped. Run `git diff` to review changes.
   ```

   If a module has no version manifest, report it and skip:

   ```
   Skipped: plugins/example (no version manifest found)
   ```

## Scripts

- `scripts/detect-modules.sh` --- Detect modules via CLAUDE.md and locate version manifests
