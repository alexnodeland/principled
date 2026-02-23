---
name: release-ready
description: >
  Verify that all pipeline documents referenced by merged changes are in
  terminal status. Checks proposals, plans, and ADRs to ensure release
  readiness before tagging.
allowed-tools: Read, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *)
user-invocable: true
---

# Release Ready --- Pre-Release Verification

Verify that all proposals, plans, and ADRs referenced by commits since the last release are in terminal status. A passing check means the release is ready to proceed.

## Command

```
/release-ready [--tag <version>] [--since <tag>] [--strict]
```

## Arguments

| Argument          | Required | Description                                                       |
| ----------------- | -------- | ----------------------------------------------------------------- |
| `--tag <version>` | No       | The version being prepared (for reporting only)                   |
| `--since <tag>`   | No       | Git tag to use as starting point. Auto-detects latest if absent   |
| `--strict`        | No       | Treat non-terminal documents as hard failures instead of warnings |

## Prerequisites

- Git repository with at least one tag
- `gh` CLI recommended for enriched PR reference resolution (optional)

## Workflow

1. **Verify prerequisites.** Check that `gh` is available:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

   If not available, proceed with commit-based reference resolution only.

2. **Determine the starting tag.** If `--since` is provided, use it. Otherwise, find the most recent tag:

   ```bash
   git describe --tags --abbrev=0
   ```

3. **Check readiness.** Run the readiness checker:

   ```bash
   bash scripts/check-readiness.sh --since <tag> [--strict]
   ```

   This collects all pipeline references from commits since the tag and checks each referenced document's frontmatter status.

4. **Evaluate terminal status.** For each referenced document:
   - **Proposals:** `accepted`, `rejected`, or `superseded` = terminal
   - **Plans:** `complete` or `abandoned` = terminal
   - **ADRs:** `accepted`, `deprecated`, or `superseded` = terminal

   Documents in non-terminal status (draft proposals, active plans, proposed ADRs) are flagged.

5. **Report results.** Output a structured readiness report:

   ```
   Release Readiness Check (since v0.3.1):

   PASS  proposal  RFC-001  Principled Docs Plugin       accepted
   PASS  plan      Plan-000 Principled Docs Plugin       complete
   WARN  plan      Plan-006 Principled Release Plugin    active
   PASS  decision  ADR-001  Pure Bash Frontmatter        accepted

   Summary: 3 passed, 1 warning, 0 failed
   ```

   In `--strict` mode, warnings become failures and the skill exits non-zero.

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from principled-github canonical)
- `scripts/check-readiness.sh` --- Check pipeline document statuses against terminal criteria
