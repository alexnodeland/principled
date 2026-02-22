---
name: gen-codeowners
description: >
  Generate or update a CODEOWNERS file from the repository's module
  structure and git history. Maps module boundaries to code ownership
  using principled documentation structure as the guide.
  Use when setting up or refreshing code ownership rules.
allowed-tools: Read, Write, Bash(git *), Bash(ls *), Bash(bash plugins/*)
user-invocable: true
---

# Gen CODEOWNERS --- Code Ownership Generator

Generate or update a `.github/CODEOWNERS` file from the repository's module structure and git history.

## Command

```
/gen-codeowners [--modules-dir <path>] [--output <path>] [--dry-run]
```

## Arguments

| Argument               | Required | Description                                                    |
| ---------------------- | -------- | -------------------------------------------------------------- |
| `--modules-dir <path>` | No       | Root directory containing modules. Defaults to auto-detection. |
| `--output <path>`      | No       | Output path. Defaults to `.github/CODEOWNERS`.                 |
| `--dry-run`            | No       | Print the generated CODEOWNERS without writing.                |

## Workflow

1. **Detect modules.** Scan for directories containing `CLAUDE.md`, `docs/`, or `package.json`:

   ```bash
   bash scripts/detect-modules.sh [--modules-dir <path>]
   ```

   Returns a list of module paths.

2. **Analyze ownership.** For each module, determine primary contributors:

   ```bash
   bash scripts/analyze-ownership.sh --module <module-path>
   ```

   Uses `git shortlog -sne` on the module directory to rank contributors by commit count.

3. **Read existing CODEOWNERS.** If `.github/CODEOWNERS` exists, parse it to preserve:
   - Manual overrides (lines with `# manual` comment)
   - Custom patterns not matching detected modules

4. **Generate CODEOWNERS.** Read `templates/codeowners.txt` as a structural guide and produce:
   - Header comment explaining the file
   - Global ownership rule
   - Per-module ownership rules
   - Documentation ownership rules (for `docs/` directories)
   - Preserved manual overrides

5. **Write or display.** Based on flags:
   - Without `--dry-run`: write to output path
   - With `--dry-run`: display generated content

6. **Report results.** Summary of:
   - Modules detected
   - Owners assigned per module
   - Manual overrides preserved (if updating)

## Scripts

- `scripts/detect-modules.sh` --- Find module directories in the repository
- `scripts/analyze-ownership.sh` --- Determine code ownership from git history

## Templates

- `templates/codeowners.txt` --- Structural template for CODEOWNERS file
