---
name: changelog
description: >
  Generate changelog entries from the principled documentation pipeline.
  Maps commits to proposals, plans, and ADRs since the last release tag,
  groups by category, and renders Markdown changelog sections.
allowed-tools: Read, Write, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *)
user-invocable: true
---

# Changelog --- Pipeline-Based Changelog Generation

Generate changelog entries by mapping commits to proposals, plans, and ADRs merged since the last release. Follows Keep a Changelog conventions adapted for the principled pipeline (ADR-013).

## Command

```
/changelog [--since <tag>] [--module <path>]
```

## Arguments

| Argument          | Required | Description                                                         |
| ----------------- | -------- | ------------------------------------------------------------------- |
| `--since <tag>`   | No       | Git tag to use as the starting point. Auto-detects latest if absent |
| `--module <path>` | No       | Scope changelog to changes within a specific module path            |

## Prerequisites

- Git repository with at least one tag
- `gh` CLI recommended for PR reference resolution (optional)

## Workflow

1. **Verify prerequisites.** Check that `gh` is available:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

   If not available, proceed without PR reference resolution --- rely on commit message and branch name references only.

2. **Determine the starting tag.** If `--since` is provided, use it. Otherwise, find the most recent tag:

   ```bash
   git describe --tags --abbrev=0
   ```

   If no tags exist, report the error and stop.

3. **Collect changes.** Run the change collector to map commits to pipeline documents:

   ```bash
   bash scripts/collect-changes.sh --since <tag> [--module <path>]
   ```

   This outputs tab-separated lines: `<hash>\t<category>\t<references>\t<subject>`.

4. **Enrich with PR context.** If `gh` is available, attempt to resolve PR descriptions for richer context:

   ```bash
   gh pr list --state merged --search "<hash>" --json number,title,body --limit 1
   ```

   Extract any additional pipeline references from PR bodies that weren't in commit messages.

5. **Read referenced documents.** For each pipeline reference (RFC-NNN, Plan-NNN, ADR-NNN), read the corresponding document's title from its frontmatter:
   - Proposals: `docs/proposals/NNN-*.md`
   - Plans: `docs/plans/NNN-*.md`
   - Decisions: `docs/decisions/NNN-*.md`

   Use document titles to generate human-readable changelog entries.

6. **Group by category.** Organize entries into sections:
   - **Features** --- changes linked to accepted proposals (RFCs)
   - **Improvements** --- changes linked to plans without a proposal
   - **Decisions** --- ADRs accepted during this release period
   - **Fixes** --- changes referencing bug fixes or issues
   - **Uncategorized** --- changes without pipeline references

   Omit empty sections.

7. **Render the changelog.** Read the template from `templates/changelog-entry.md` and fill in:
   - `{{VERSION}}` --- next version (or "Unreleased" if not specified)
   - `{{DATE}}` --- current date (YYYY-MM-DD)
   - `{{FEATURES}}`, `{{IMPROVEMENTS}}`, `{{DECISIONS}}`, `{{FIXES}}`, `{{UNCATEGORIZED}}` --- rendered sections

8. **Output results.** Display the rendered changelog section. Also report a summary:

   ```
   Changelog generated (since v0.3.1):
     Features: 2 entries
     Improvements: 3 entries
     Decisions: 2 entries (ADR-005, ADR-006)
     Uncategorized: 1 entry
     Total: 8 entries from 15 commits
   ```

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from principled-github canonical)
- `scripts/collect-changes.sh` --- Collect changes since a tag and map to pipeline documents

## Templates

- `templates/changelog-entry.md` --- Changelog section template with placeholder variables for version, date, and category sections
