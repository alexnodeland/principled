---
name: review-checklist
description: >
  Generate a spec-driven review checklist for a pull request. Extracts
  acceptance criteria from the associated plan, identifies relevant ADRs
  for the changed files, and produces a structured checklist. Posts the
  checklist as a PR comment and saves it locally per ADR-012.
allowed-tools: Read, Write, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *), Bash(mkdir *)
user-invocable: true
---

# Review Checklist --- Spec-Driven PR Review

Generate a review checklist for a pull request by combining plan acceptance criteria, ADR compliance checks, and general quality items. Posts the checklist as a PR comment and saves locally (dual storage per ADR-012).

## Command

```
/review-checklist <pr-number> [--plan <path>] [--task <id>] [--local-only]
```

## Arguments

| Argument        | Required | Description                                                              |
| --------------- | -------- | ------------------------------------------------------------------------ |
| `<pr-number>`   | Yes      | The GitHub PR number to generate a checklist for.                        |
| `--plan <path>` | No       | Path to the DDD plan file. Auto-detected from PR description if omitted. |
| `--task <id>`   | No       | Specific task ID within the plan (e.g., `2.1`).                          |
| `--local-only`  | No       | Write to `.review/` only; do not post a PR comment.                      |

## Prerequisites

- `gh` CLI must be installed and authenticated
- Repository must have a GitHub remote configured

## Workflow

1. **Verify prerequisites.** Check that `gh` is available and authenticated:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

2. **Resolve the PR.** Fetch PR metadata including title, body, and changed files:

   ```bash
   gh pr view <pr-number> --json number,title,body,files
   ```

   If the PR does not exist, report the error and stop.

3. **Determine plan context.** If `--plan` is provided, use it directly. Otherwise, search the PR description for plan references:
   - Look for patterns like `Plan-NNN`, `plan/NNN`, or file paths matching `docs/plans/*.md`
   - If no plan reference is found, skip the acceptance criteria section and note it in the output

4. **Extract acceptance criteria.** If a plan was identified, extract criteria:

   ```bash
   bash scripts/extract-plan-criteria.sh --plan <path> [--task <id>]
   ```

   Each criterion becomes a checklist item in the "Acceptance Criteria" section.

5. **Get changed files.** List files changed in the PR:

   ```bash
   gh pr diff <pr-number> --name-only
   ```

6. **Find relevant ADRs.** Identify ADRs that apply to the changed files:

   ```bash
   bash scripts/find-relevant-adrs.sh --files <comma-separated-files> [--decisions-dir <path>]
   ```

   For each ADR found, read its "Decision" section and create a compliance checklist item summarizing what to verify.

7. **Generate the checklist.** Read the checklist template from `templates/checklist.md` and fill in:
   - `{{PR_NUMBER}}` --- the PR number
   - `{{PLAN_REFERENCE}}` --- plan and task reference (or "No plan linked")
   - `{{DATE}}` --- current date (YYYY-MM-DD)
   - `{{FILE_COUNT}}` --- number of changed files
   - `{{ACCEPTANCE_CRITERIA_ITEMS}}` --- extracted criteria as `- [ ]` items
   - `{{ADR_COMPLIANCE_ITEMS}}` --- ADR compliance items as `- [ ]` items

8. **Post as PR comment.** Unless `--local-only` is set, post the checklist as a PR comment:

   ```bash
   gh pr comment <pr-number> --body "<checklist-content>"
   ```

   Before posting, check if a checklist comment already exists (search for `<!-- principled-review-checklist: PR-<number> -->`). If it exists, update it rather than creating a duplicate.

9. **Save locally.** Write the checklist to `.review/<pr-number>-checklist.md`:

   ```bash
   mkdir -p .review
   ```

   This provides the persistent local copy per ADR-012.

10. **Report results.** Summarize what was generated:

    ```
    Review checklist generated for PR #42:
      Plan: Plan-005 (task 2.1)
      Acceptance criteria: 5 items
      ADR compliance: 3 items (ADR-003, ADR-005, ADR-012)
      General quality: 6 items
      Total: 14 checklist items

      Posted as PR comment: yes
      Saved to: .review/42-checklist.md
    ```

## Checklist Sections

### Acceptance Criteria

Derived from the plan's task definition. Each criterion is a specific, verifiable requirement from the plan's `- [ ]` items under "Acceptance Criteria" headings.

### ADR Compliance

One item per relevant ADR. Each item references the ADR number and summarizes the decision to verify against. Example:

```markdown
- [ ] **ADR-003:** Module type is declared in CLAUDE.md for all new modules
```

### General Quality

Standard checks that apply to all PRs:

- Tests present and passing
- No regressions
- Documentation updated if needed
- No hardcoded secrets
- Error handling present
- No orphaned TODO/FIXME comments

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from principled-github canonical)
- `scripts/extract-plan-criteria.sh` --- Extract acceptance criteria from a DDD plan file
- `scripts/find-relevant-adrs.sh` --- Find ADRs relevant to changed files by module scope

## Templates

- `templates/checklist.md` --- Checklist template with placeholder variables for PR number, plan reference, criteria items, ADR items, and general quality items
