---
name: ingest-issue
description: >
  Ingest a GitHub issue into the principled pipeline. Fetches the issue,
  determines what documents are needed (proposal, plan, or both), creates
  them pre-populated from issue content, and comments on the issue with
  links to the new documents on a feature branch.
allowed-tools: Read, Write, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*), Bash(wc *)
user-invocable: true
---

# Ingest Issue --- GitHub Issue to Principled Pipeline

Ingest a GitHub issue into the principled documentation pipeline. Automatically determines what documents are needed and creates them pre-populated from the issue content.

## Command

```
/ingest-issue <issue-number> [--module <path>] [--root]
```

## Arguments

| Argument          | Required | Description                                                   |
| ----------------- | -------- | ------------------------------------------------------------- |
| `<issue-number>`  | Yes      | GitHub issue number to ingest                                 |
| `--module <path>` | No       | Target module path for documents. Defaults to current module. |
| `--root`          | No       | Create documents at the repo root level (`docs/`)             |
| `--dry-run`       | No       | Show what would be created without making changes             |

## Prerequisites

- `gh` CLI must be installed and authenticated
- Repository must have a GitHub remote configured

## Workflow

1. **Verify prerequisites.** Check that `gh` is available and authenticated:

   ```bash
   bash scripts/check-gh-cli.sh
   ```

   If not available, report: _"The `gh` CLI is required. Install it from <https://cli.github.com/>."_

2. **Fetch the issue.** Extract issue metadata:

   ```bash
   bash scripts/extract-issue-metadata.sh --number <issue-number>
   ```

   Returns: title, body, labels, author, created date, comments, and state.

3. **Check for existing principled documents.** Search for an existing sync marker linking this issue to principled documents:

   ```bash
   bash scripts/find-ingested-docs.sh --issue <issue-number>
   ```

   If documents already exist, report them and ask if the user wants to update or create additional ones.

4. **Classify the issue.** Analyze the issue to determine what documents to create. Read `reference/classification-guide.md` for guidance. Consider:
   - **Issue labels** — `bug`, `enhancement`, `feature`, etc.
   - **Issue body length and complexity** — longer, more detailed issues suggest larger scope
   - **Mentions of architecture, API changes, or cross-cutting concerns** — suggest an RFC is needed

   Classification outcomes:
   - **RFC + Plan**: The issue describes something that needs design discussion and then implementation. Most features and significant changes fall here.
   - **Plan only**: The issue describes well-scoped work where the approach is clear and doesn't need design review. Bug fixes with known root cause, small improvements with obvious implementation.
   - Report the classification to the user and proceed.

5. **Determine target directory.** Based on arguments:
   - If `--root`: target is `docs/` at the repo root
   - If `--module <path>`: target is `<path>/docs/`
   - Otherwise: determine from current working context

6. **Get the next sequence number(s).** For each document type to create, determine the next available NNN in the target directory.

7. **Create documents.** For each document type:

   **If creating a proposal (RFC):**
   - Read `templates/ingested-proposal.md`
   - Populate frontmatter (title, number, status=draft, author from issue, dates)
   - Map issue body sections into proposal sections (Context, Proposal, Open Questions)
   - Add an ingest marker: `<!-- principled-ingested-from: #<issue-number> -->`
   - Write to `<target>/proposals/NNN-<slug>.md`

   **If creating a plan:**
   - Read `templates/ingested-plan.md`
   - Populate frontmatter (title, number, status=active, originating_proposal if RFC was also created)
   - Map issue body into plan sections (Objective, Tasks)
   - Add an ingest marker: `<!-- principled-ingested-from: #<issue-number> -->`
   - Write to `<target>/plans/NNN-<slug>.md`

8. **Comment on the GitHub issue.** Add a comment linking to the created documents:

   ```bash
   gh issue comment <issue-number> --body "$(cat <<'EOF'
   ## Principled Pipeline

   This issue has been ingested into the principled documentation pipeline:

   - **RFC-NNN**: [`docs/proposals/NNN-slug.md`](link) — Status: draft
   - **Plan-NNN**: [`docs/plans/NNN-slug.md`](link) — Status: active

   Documents are the source of truth. Use `/sync-issues` to keep this issue updated.

   <!-- principled-ingest-comment -->
   EOF
   )"
   ```

9. **Apply labels.** Add principled lifecycle labels to the issue:

   ```bash
   gh issue edit <issue-number> --add-label "type:rfc,proposal:draft"
   ```

10. **Report results.** Summarize what was created:
    - Document paths and types
    - Issue comment link
    - Labels applied
    - Next steps: review and flesh out the generated documents

## Slug Rules

The issue title is converted to a slug:

- Lowercase only
- Words separated by hyphens
- Strip special characters, brackets, parentheses
- Truncate to 50 characters at a word boundary

## Ingest Marker

Every ingested document contains: `<!-- principled-ingested-from: #<issue-number> -->`. This enables detecting that an issue has already been ingested.

## Scripts

- `scripts/check-gh-cli.sh` --- Verify gh CLI availability and auth status (copy from sync-issues)
- `scripts/extract-issue-metadata.sh` --- Fetch and parse a GitHub issue
- `scripts/find-ingested-docs.sh` --- Search for existing docs linked to an issue

## Templates

- `templates/ingested-proposal.md` --- Proposal template pre-populated from issue content
- `templates/ingested-plan.md` --- Plan template pre-populated from issue content

## Reference

- `reference/classification-guide.md` --- How to classify issues into document types
