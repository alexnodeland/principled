---
name: review-summary
description: >
  Generate a structured review summary for a pull request. Collects
  review state, builds a findings table linked to spec items, and
  produces a summary with coverage metrics and unresolved items.
allowed-tools: Read, Write, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *), Bash(mkdir *)
user-invocable: true
---

# Review Summary --- Structured Review Report

Generate a structured summary of a PR's review state. Collects checklist status, review comments, and findings into a report linked to specification items.

## Command

```
/review-summary <pr-number> [--local-only]
```

## Arguments

| Argument       | Required | Description                                         |
| -------------- | -------- | --------------------------------------------------- |
| `<pr-number>`  | Yes      | The GitHub PR number to summarize.                  |
| `--local-only` | No       | Write to `.review/` only; do not post a PR comment. |

## Prerequisites

- `gh` CLI must be installed and authenticated
- A review checklist should exist for the PR (generates a more useful summary)

## Workflow

1. **Verify prerequisites.** Check that `gh` is available and authenticated:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

2. **Collect review state.** Gather all review data for the PR:
   - **PR metadata:** title, body, state, merged status

     ```bash
     gh pr view <pr-number> --json number,title,body,state,reviews,comments,files
     ```

   - **Checklist state:** Locate the review checklist (PR comments, then `.review/` fallback) and parse checked/unchecked items per section.

   - **Review comments:** Collect all review comments including inline file comments:

     ```bash
     gh api repos/{owner}/{repo}/pulls/<pr-number>/comments
     ```

   - **Review decisions:** Extract review approvals, change requests, and comments:

     ```bash
     gh pr view <pr-number> --json reviews --jq '.reviews[] | {author: .author.login, state: .state}'
     ```

3. **Build findings table.** For each review comment or finding, create an entry with these columns:
   - **Finding:** Summary of the review comment or concern
   - **Severity:** Blocking, Important, or Advisory (inferred from context)
   - **Spec Item:** Which checklist item or ADR this relates to (if identifiable)
   - **File:** Which file the finding relates to
   - **Status:** Resolved, Unresolved, or Acknowledged

4. **Compile coverage metrics.** Calculate per-section and overall coverage:
   - Acceptance Criteria: X/Y addressed
   - ADR Compliance: X/Y addressed
   - General Quality: X/Y addressed
   - Total: X/Y addressed (Z%)

5. **Identify unresolved items.** List any:
   - Unchecked checklist items with no corresponding discussion
   - Review comments marked as "changes requested" without resolution
   - Blocking findings that remain open

6. **Generate the summary.** Read the template from `templates/review-summary.md` and fill in all placeholder values. Add reviewer notes section with:
   - Overall review recommendation (approve, request changes, needs discussion)
   - Key strengths observed in the implementation
   - Areas for follow-up in subsequent PRs

7. **Post as PR comment.** Unless `--local-only` is set, post the summary:

   ```bash
   gh pr comment <pr-number> --body "<summary-content>"
   ```

   Check for existing summary comments (marker: `<!-- principled-review-summary: PR-<number> -->`) and update rather than duplicate.

8. **Save locally.** Write the summary to `.review/<pr-number>-summary.md`:

   ```bash
   mkdir -p .review
   ```

9. **Report results.** Summarize what was generated:

   ```
   Review summary generated for PR #42:
     Coverage: 10/14 items (71%)
     Findings: 3 blocking, 2 important, 4 advisory
     Unresolved: 2 items
     Status: Changes requested

     Posted as PR comment: yes
     Saved to: .review/42-summary.md
   ```

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from principled-github canonical)

## Templates

- `templates/review-summary.md` --- Summary template with coverage table, findings, unresolved items, and reviewer notes
