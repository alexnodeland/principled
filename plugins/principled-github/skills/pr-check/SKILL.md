---
name: pr-check
description: >
  Validate that a pull request follows principled conventions: references
  a plan or proposal, has correct labels, includes required sections in
  the description, and links to relevant documents. Use in CI or
  before merging to enforce PR quality.
allowed-tools: Read, Bash(gh *), Bash(git *), Bash(bash plugins/*)
user-invocable: true
---

# PR Check --- Pull Request Validation

Validate that a pull request follows principled conventions for cross-referencing, labeling, and description quality.

## Command

```
/pr-check [<pr-number>] [--strict] [--json]
```

## Arguments

| Argument      | Required | Description                                                   |
| ------------- | -------- | ------------------------------------------------------------- |
| `<pr-number>` | No       | PR number to check. Defaults to the current branch's open PR. |
| `--strict`    | No       | Fail on warnings (by default, only errors cause failure).     |
| `--json`      | No       | Output results as JSON instead of human-readable text.        |

## Prerequisites

- `gh` CLI must be installed and authenticated
- For default behavior (no PR number): current branch must have an open PR

## Workflow

1. **Resolve PR.** Determine which PR to check:
   - If `<pr-number>` provided: use it directly
   - Otherwise: find the PR for the current branch via `gh pr view --json number`
   - If no PR found: report error and exit

2. **Fetch PR metadata.** Get PR details:

   ```bash
   bash scripts/fetch-pr-metadata.sh --pr <number>
   ```

   Returns: title, body, labels, base branch, head branch, files changed.

3. **Run checks.** Execute each validation:

   ```bash
   bash scripts/validate-pr.sh --pr-body "<body>" --pr-labels "<labels>" --branch "<head-branch>" [--strict]
   ```

   The script checks:

   **Required (errors):**
   - PR body is not empty
   - PR body contains a `## Summary` section
   - PR body contains a `## Test plan` or `## Checklist` section

   **Recommended (warnings, errors in `--strict`):**
   - PR references a plan (`Plan-NNN`) or proposal (`RFC-NNN`)
   - PR has at least one principled label (`type:*`, `plan:*`, `proposal:*`)
   - Branch name follows a recognized convention (`impl/`, `feat/`, `fix/`)
   - Files changed include tests if source files were modified

4. **Report results.** Display check results:
   - Each check with pass/warn/fail status
   - Overall result: pass or fail
   - If `--json`: structured JSON output
   - Exit code 0 for pass, 1 for fail

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability (copy)
- `scripts/fetch-pr-metadata.sh` --- Fetch PR details from GitHub
- `scripts/validate-pr.sh` --- Run PR validation checks
