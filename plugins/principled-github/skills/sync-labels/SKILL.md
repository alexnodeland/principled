---
name: sync-labels
description: >
  Create and sync GitHub labels for the principled workflow lifecycle.
  Ensures all required labels exist with correct names, colors, and
  descriptions. Use when setting up a new repo or when the label
  taxonomy has been updated.
allowed-tools: Read, Bash(gh *), Bash(bash plugins/*)
user-invocable: true
---

# Sync Labels --- GitHub Label Synchronization

Create and synchronize GitHub labels for the principled workflow lifecycle stages.

## Command

```
/sync-labels [--dry-run] [--prune]
```

## Arguments

| Argument    | Required | Description                                                              |
| ----------- | -------- | ------------------------------------------------------------------------ |
| `--dry-run` | No       | Show what labels would be created/updated/deleted without making changes |
| `--prune`   | No       | Remove labels not in the principled taxonomy (use with caution)          |

## Prerequisites

- `gh` CLI must be installed and authenticated
- Repository must have a GitHub remote configured

## Workflow

1. **Verify prerequisites.** Check that `gh` is available:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

2. **Load label definitions.** Read the label taxonomy from `scripts/label-definitions.sh`:

   ```bash
   bash scripts/label-definitions.sh --list
   ```

   Returns all label definitions: name, color, and description.

3. **Fetch current labels.** Get existing labels from GitHub:

   ```bash
   gh label list --json name,color,description --limit 200
   ```

4. **Compute diff.** For each label in the taxonomy:
   - **Missing:** label does not exist on GitHub --- needs creation
   - **Drifted:** label exists but color or description differs --- needs update
   - **Matching:** label exists and matches --- no action needed

5. **If `--prune`:** identify labels on GitHub that are not in the taxonomy (excluding labels without a principled prefix). These are candidates for deletion.

6. **Apply changes.** Unless `--dry-run`:
   - Create missing labels: `gh label create "<name>" --color "<color>" --description "<desc>"`
   - Update drifted labels: `gh label edit "<name>" --color "<color>" --description "<desc>"`
   - Delete pruned labels (if `--prune`): `gh label delete "<name>" --yes`

7. **Report results.** Summary of:
   - Labels created
   - Labels updated
   - Labels deleted (if `--prune`)
   - Labels already matching

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy)
- `scripts/label-definitions.sh` --- Canonical label taxonomy definitions
