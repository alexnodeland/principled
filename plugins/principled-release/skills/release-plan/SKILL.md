---
name: release-plan
description: >
  Draft a human-reviewable release plan summarizing all changes since the
  last tag, grouped by module and category. Includes outstanding items
  and suggested release steps.
allowed-tools: Read, Write, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *), Bash(mkdir *)
user-invocable: true
---

# Release Plan --- Draft Release Plan for Review

Draft a release plan document summarizing all changes since the last tag, grouped by module and category. The plan is written to a local file for team review before proceeding with the release.

## Command

```
/release-plan [--since <tag>] [--version <version>]
```

## Arguments

| Argument              | Required | Description                                                     |
| --------------------- | -------- | --------------------------------------------------------------- |
| `--since <tag>`       | No       | Git tag to use as starting point. Auto-detects latest if absent |
| `--version <version>` | No       | The target version for the release plan header                  |

## Prerequisites

- Git repository with at least one tag
- `gh` CLI recommended for enriched PR context (optional)

## Workflow

1. **Verify prerequisites.** Check that `gh` is available:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

2. **Determine the starting tag.** If `--since` is provided, use it. Otherwise, find the most recent tag:

   ```bash
   git describe --tags --abbrev=0
   ```

3. **Collect changes.** Use the changelog skill's collector to map commits to pipeline documents:

   ```bash
   bash ../changelog/scripts/collect-changes.sh --since <tag>
   ```

4. **Detect modules.** Run the module detector to identify modules and versions:

   ```bash
   bash ../version-bump/scripts/detect-modules.sh
   ```

5. **Check readiness.** Run the readiness checker to identify outstanding items:

   ```bash
   bash ../release-ready/scripts/check-readiness.sh --since <tag>
   ```

   Documents not in terminal status become "Outstanding Items" in the plan.

6. **Generate the release plan.** Read the template from `templates/release-plan.md` and fill in:
   - `{{VERSION}}` --- target version (or "Next" if not specified)
   - `{{DATE}}` --- current date
   - `{{SINCE_TAG}}` --- the starting tag
   - `{{COMMIT_COUNT}}` --- total commits since the tag
   - `{{MODULES_SECTION}}` --- modules affected with current and proposed versions
   - `{{FEATURES_SECTION}}` --- features from accepted proposals
   - `{{IMPROVEMENTS_SECTION}}` --- improvements from plan tasks
   - `{{DECISIONS_SECTION}}` --- ADRs recorded during this period
   - `{{OUTSTANDING_SECTION}}` --- non-terminal documents that need attention

7. **Write the plan.** Save to a local file:

   ```
   .release/release-plan-<version>.md
   ```

   Create the `.release/` directory if it does not exist.

8. **Report results.**

   ```
   Release plan drafted:
     File: .release/release-plan-0.4.0.md
     Modules: 3 affected
     Features: 2 (from RFC-004, RFC-005)
     Outstanding: 1 item (Plan-006 still active)

   Review the plan and resolve outstanding items before proceeding.
   ```

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from principled-github canonical)

## Templates

- `templates/release-plan.md` --- Release plan document template with placeholder variables
