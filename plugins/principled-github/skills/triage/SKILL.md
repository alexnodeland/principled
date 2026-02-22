---
name: triage
description: >
  Process open GitHub issues through the principled pipeline. Lists
  untriaged issues, normalizes their metadata, ingests them into the
  documentation pipeline, and reports a summary. Operates as the batch
  entry point — delegates to /ingest-issue for each individual issue.
allowed-tools: Read, Write, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *)
user-invocable: true
---

# Triage --- Batch Issue Processing Pipeline

Process open GitHub issues through the principled pipeline. Finds untriaged issues, normalizes their metadata, creates the appropriate principled documents, and reports what was done.

## Command

```
/triage [--limit <n>] [--label <filter>] [--module <path>] [--root] [--dry-run]
```

## Arguments

| Argument           | Required | Description                                                      |
| ------------------ | -------- | ---------------------------------------------------------------- |
| `--limit <n>`      | No       | Maximum number of issues to process. Defaults to all untriaged.  |
| `--label <filter>` | No       | Only triage issues with this label (e.g., `bug`, `enhancement`). |
| `--module <path>`  | No       | Target module for created documents. Defaults to current module. |
| `--root`           | No       | Create documents at the repo root level (`docs/`).               |
| `--dry-run`        | No       | Show what would be done without making changes.                  |

## Prerequisites

- `gh` CLI must be installed and authenticated
- Repository must have a GitHub remote configured

## Workflow

1. **Verify prerequisites.** Check that `gh` is available and authenticated:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

2. **List untriaged issues.** Find open issues that have not been ingested into the principled pipeline:

   ```bash
   bash scripts/list-untriaged.sh [--label <filter>]
   ```

   An issue is considered **untriaged** if it:
   - Is open
   - Does not have principled labels (`proposal:*`, `plan:*`, `type:rfc`, `type:plan`)

   Label-based detection is the primary signal. Issues ingested via `/ingest-issue` always receive lifecycle labels in step 10, so this is reliable for the common case.

   Returns tab-separated `<number>\t<title>`, one issue per line.

3. **Report the triage queue.** Show the user how many issues are queued and list them with titles:

   ```
   Found N untriaged issues:
     #12 — Add dark mode support
     #15 — Fix login timeout on slow connections
     #18 — Refactor auth middleware
   ```

   If `--limit` is set, show only the first N.

   If `--dry-run` is set, stop here. Report the queue and what _would_ happen (estimated classification for each issue based on title/labels) without making any changes. Do not proceed to step 4.

4. **Process each issue sequentially.** For each issue in the queue, follow the `/ingest-issue` SKILL.md workflow inline (steps 2–11). This means each issue gets the full treatment:
   - **Metadata normalization** — missing labels, vague titles are fixed on GitHub
   - **Classification** — determines RFC + Plan vs Plan only
   - **Document creation** — proposals and/or plans created, pre-populated from issue content
   - **Issue comment** — links to created documents posted on the issue
   - **Label application** — principled lifecycle labels added

   Between issues, report progress:

   ```
   [2/5] Processing #15 — Fix login timeout on slow connections
         → Classification: Plan only
         → Created: docs/plans/003-fix-login-timeout.md
         → Labels: type:plan, plan:active
   ```

5. **Handle errors gracefully.** If processing an individual issue fails (e.g., network error, permission issue), log the failure and continue to the next issue. Do not abort the entire triage run for a single issue failure.

6. **Report triage summary.** After all issues are processed, provide a summary:

   ```
   Triage complete:
     Processed: 5 issues
     RFCs created: 2
     Plans created: 5
     Metadata fixed: 3 issues (labels added, titles improved)
     Errors: 0

   Created documents:
     docs/proposals/004-add-dark-mode.md (RFC-004, from #12)
     docs/proposals/005-refactor-auth.md (RFC-005, from #18)
     docs/plans/003-fix-login-timeout.md (Plan-003, from #15)
     docs/plans/004-add-dark-mode.md (Plan-004, from #12)
     docs/plans/005-refactor-auth.md (Plan-005, from #18)
   ```

## Triage vs Ingest

| Concern       | `/triage`                             | `/ingest-issue`      |
| ------------- | ------------------------------------- | -------------------- |
| Scope         | All open untriaged issues (batch)     | One specific issue   |
| Entry point   | User runs once to process the backlog | User runs per-issue  |
| Orchestration | Iterates and delegates                | Does the actual work |
| Reporting     | Aggregate summary                     | Per-issue detail     |

`/triage` is the orchestrator. `/ingest-issue` is the worker. Running `/triage` is equivalent to running `/ingest-issue` on every untriaged issue.

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from sync-issues)
- `scripts/list-untriaged.sh` --- List open issues not yet in the principled pipeline

## Reference

- `reference/triage-guide.md` --- Triage philosophy, prioritization, and edge cases
