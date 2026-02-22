---
name: sync-issues
description: >
  Sync principled proposals and plans to GitHub issues. Creates or updates
  GitHub issues from proposal and plan documents, maintaining bidirectional
  references. Documents remain the source of truth.
allowed-tools: Read, Bash(gh *), Bash(ls *), Bash(bash plugins/*)
user-invocable: true
---

# Sync Issues --- Proposal and Plan to GitHub Issue Sync

Create or update GitHub issues from principled proposal and plan documents.

## Command

```
/sync-issues [<doc-path>] [--all-proposals] [--all-plans] [--dry-run]
```

## Arguments

| Argument          | Required | Description                                               |
| ----------------- | -------- | --------------------------------------------------------- |
| `<doc-path>`      | No       | Path to a specific proposal or plan file to sync          |
| `--all-proposals` | No       | Sync all proposals in `docs/proposals/`                   |
| `--all-plans`     | No       | Sync all plans in `docs/plans/`                           |
| `--dry-run`       | No       | Show what would be created/updated without making changes |
| `--module <path>` | No       | Target module path. Defaults to root-level `docs/`        |

## Prerequisites

- `gh` CLI must be installed and authenticated
- Repository must have a GitHub remote configured

## Workflow

1. **Verify prerequisites.** Check that `gh` is available and authenticated:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

   If not available, report: _"The `gh` CLI is required for GitHub sync. Install it from <https://cli.github.com/>."_

2. **Determine scope.** Based on arguments:
   - If `<doc-path>`: sync only that document
   - If `--all-proposals`: find all `docs/proposals/*.md` files
   - If `--all-plans`: find all `docs/plans/*.md` files
   - If none specified: prompt user to choose

3. **For each document, extract metadata.** Run:

   ```bash
   bash scripts/extract-doc-metadata.sh --file <doc-path>
   ```

   Returns: title, number, status, author, type (proposal or plan), and a content excerpt.

4. **Check for existing issue.** Search for an existing GitHub issue with the sync marker:

   ```bash
   bash scripts/find-synced-issue.sh --doc-path <doc-path>
   ```

   This searches for issues containing the sync marker `<!-- principled-sync: <doc-path> -->`.

5. **Create or update the issue.**
   - If no existing issue found: create a new one using the appropriate template from `templates/`
   - If existing issue found: update the issue body and labels
   - Read the template from `templates/proposal-issue.md` or `templates/plan-issue.md`
   - Populate the template with extracted metadata
   - Apply lifecycle labels based on document status

6. **Apply labels.** Map document status to GitHub labels:
   - For proposals: `type:rfc` + `proposal:<status>`
   - For plans: `type:plan` + `plan:<status>`

7. **Report results.** For each synced document:
   - Issue URL (new or updated)
   - Labels applied
   - Whether it was created or updated
   - If `--dry-run`, show what would happen without executing

## Sync Marker

Every synced issue contains a hidden HTML comment: `<!-- principled-sync: <relative-doc-path> -->`. This marker enables the plugin to find the corresponding issue for updates.

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status
- `scripts/extract-doc-metadata.sh` --- Extract metadata from a principled document
- `scripts/find-synced-issue.sh` --- Search for an existing synced GitHub issue

## Templates

- `templates/proposal-issue.md` --- Issue body template for proposals
- `templates/plan-issue.md` --- Issue body template for plans
