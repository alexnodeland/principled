---
name: review-coverage
description: >
  Assess whether a pull request's review comments address the generated
  checklist items. Reads the checklist from PR comments and local files,
  maps review comments to checklist items, and reports coverage.
allowed-tools: Read, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *)
user-invocable: true
---

# Review Coverage --- Checklist Completeness Assessment

Assess whether a PR's review comments and checklist state address all generated checklist items. Reports coverage percentage and identifies uncovered items.

## Command

```
/review-coverage <pr-number>
```

## Arguments

| Argument      | Required | Description                                  |
| ------------- | -------- | -------------------------------------------- |
| `<pr-number>` | Yes      | The GitHub PR number to assess coverage for. |

## Prerequisites

- `gh` CLI must be installed and authenticated
- A review checklist must have been previously generated for the PR (via `/review-checklist`)

## Workflow

1. **Verify prerequisites.** Check that `gh` is available and authenticated:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

2. **Locate the checklist.** Find the review checklist using the dual storage model (ADR-012):
   - **Primary:** Search PR comments for the marker `<!-- principled-review-checklist: PR-<number> -->`

     ```bash
     gh pr view <pr-number> --json comments --jq '.comments[].body'
     ```

   - **Fallback:** Check for `.review/<pr-number>-checklist.md` locally

   If no checklist is found, report the absence and suggest running `/review-checklist` first.

3. **Parse checklist state.** From the located checklist, extract all items and their checked/unchecked state:
   - `- [x]` = checked (addressed)
   - `- [ ]` = unchecked (not addressed)
   - Group by section: Acceptance Criteria, ADR Compliance, General Quality

4. **Retrieve review comments.** Get all review comments on the PR:

   ```bash
   gh pr view <pr-number> --json reviews,comments
   ```

   Also fetch inline review comments (file-level comments):

   ```bash
   gh api repos/{owner}/{repo}/pulls/<pr-number>/comments
   ```

5. **Map comments to checklist items.** For each unchecked checklist item, search review comments for relevant discussion:
   - Match by keyword overlap between the checklist item text and comment content
   - Match by file association (inline comments on files related to specific criteria)
   - A comment is considered to "address" a checklist item if it discusses the same concern, even without checking the box

6. **Calculate coverage.** Compute coverage metrics:
   - **Checked coverage:** percentage of checklist items marked `[x]`
   - **Discussed coverage:** percentage of items either checked or addressed by comments
   - Per-section breakdown

7. **Report results.** Output a structured coverage report:

   ```
   Review Coverage for PR #42:

   Overall: 10/14 items addressed (71%)
     Checked: 8/14 (57%)
     Discussed but unchecked: 2/14 (14%)

   By section:
     Acceptance Criteria:  4/5 addressed (80%)
       - [ ] Widget renders correctly with default props  ← NOT ADDRESSED
     ADR Compliance:       3/3 addressed (100%)
     General Quality:      3/6 addressed (50%)
       - [ ] Documentation updated if public API changed  ← NOT ADDRESSED
       - [ ] No TODO/FIXME comments without linked issues  ← NOT ADDRESSED
       - [ ] Error handling for external calls             ← NOT ADDRESSED

   Recommendation: 4 items remain unaddressed. Consider reviewing
   before approving.
   ```

## Important Notes

- `/review-coverage` is **read-only**. It does not modify the checklist, the PR, or any plan documents.
- Coverage is **advisory**. The plugin reports gaps but does not gate merges.
- Comment-to-item mapping is **best-effort**. Free-text comments may not map cleanly to structured checklist items. When in doubt, items are reported as unaddressed.

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from principled-github canonical)
