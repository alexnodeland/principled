---
name: tag-release
description: >
  Tag and finalize a release. Validates the tag, verifies release readiness,
  generates changelog and release notes, creates the git tag, and optionally
  creates a GitHub release.
allowed-tools: Read, Write, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *), Bash(mkdir *)
user-invocable: true
---

# Tag Release --- Finalize and Tag a Release

Validate, tag, and finalize a release with generated release notes. This is the final orchestration step that brings together readiness verification, changelog generation, and tag creation.

## Command

```
/tag-release <version> [--dry-run]
```

## Arguments

| Argument    | Required | Description                                     |
| ----------- | -------- | ----------------------------------------------- |
| `<version>` | Yes      | The version to tag (e.g., `0.4.0` or `v0.4.0`)  |
| `--dry-run` | No       | Show what would happen without creating the tag |

## Prerequisites

- Git repository with at least one previous tag
- `gh` CLI required for GitHub release creation (optional for tag-only)
- Working tree must be clean (no uncommitted changes)

## Workflow

1. **Validate the tag.** Check format and uniqueness:

   ```bash
   bash scripts/validate-tag.sh <version>
   ```

   Ensures the version follows semver format and the tag doesn't already exist.

2. **Check working tree.** Verify no uncommitted changes:

   ```bash
   git status --porcelain
   ```

   If the working tree is dirty, warn the user and ask to commit or stash first.

3. **Verify release readiness.** Run the strict readiness check:

   ```bash
   bash ../release-ready/scripts/check-readiness.sh --since <previous-tag> --strict
   ```

   If any referenced pipeline document is not in terminal status, report the failures and stop (unless `--dry-run`).

4. **Determine the previous tag.** Find the most recent tag for changelog scope:

   ```bash
   git describe --tags --abbrev=0
   ```

5. **Generate changelog.** Collect and format changes since the previous tag:

   ```bash
   bash ../changelog/scripts/collect-changes.sh --since <previous-tag>
   ```

   Format the output into release notes using the changelog template.

6. **In dry-run mode, report and stop.** If `--dry-run` is set:

   ```
   Dry run for v0.4.0:
     Previous tag: v0.3.1
     Commits since: 23
     Readiness: PASS (5/5 documents in terminal status)
     Changelog: 8 entries (2 features, 3 improvements, 2 decisions, 1 uncategorized)

   Would create:
     - Git tag: v0.4.0
     - Release notes with changelog
   ```

   Stop without creating anything.

7. **Create the git tag.** Tag the current commit:

   ```bash
   git tag -a v<version> -m "Release v<version>"
   ```

8. **Create GitHub release (optional).** If `gh` is available, create a GitHub release:

   ```bash
   gh release create v<version> --title "v<version>" --notes "<release-notes>"
   ```

9. **Report results.**

   ```
   Release v0.4.0 created:
     Tag: v0.4.0
     Commits: 23 since v0.3.1
     Changelog: 8 entries
     GitHub release: https://github.com/owner/repo/releases/tag/v0.4.0
   ```

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from principled-github canonical)
- `scripts/validate-tag.sh` --- Validate tag format and check for duplicates
