# Triage Guide

## Philosophy

Triage is the entry point where unstructured GitHub issues become structured principled documents. The goal is to ensure every open issue either:

1. Has been ingested into the pipeline (has principled documents), or
2. Is explicitly deferred or excluded

No issue should sit in limbo --- untriaged and unprocessed.

## What Triage Does

For each untriaged issue, triage performs three actions:

### 1. Normalize Metadata

Issues filed by humans are often incomplete. Triage fixes this:

- **Missing labels** --- Analyze the issue content and apply appropriate type labels (`bug`, `enhancement`, `feature`), component labels, and priority labels
- **Vague titles** --- Rewrite titles to be specific and descriptive. "Fix thing" becomes "Fix login timeout when session token expires"
- **Empty bodies** --- Leave empty bodies alone; the principled documents will provide structure. But if the title is also vague, the combination signals that the issue needs human clarification before ingestion

### 2. Classify and Create Documents

Delegate to `/ingest-issue` which determines the right document types:

- **RFC + Plan** for features, design changes, architectural work
- **Plan only** for bugs, fixes, well-scoped improvements

### 3. Link Back

Comment on the issue with links to the created documents and apply principled lifecycle labels. This closes the loop --- the issue now points to its structured representation.

## Prioritization

When processing multiple issues, triage works through them in the order returned by `gh issue list` (typically newest first). The `--label` filter lets users prioritize by type:

```bash
/triage --label bug          # Process all bugs first
/triage --label enhancement  # Then enhancements
/triage --limit 5            # Or just do the first 5
```

## Edge Cases

### Issues That Should Not Be Ingested

Some issues are not candidates for the principled pipeline:

- **Questions** --- Issues that are really support questions. These should be answered and closed, not turned into documents.
- **Duplicates** --- Issues that duplicate existing ones. Close them with a reference.
- **Spam or invalid** --- Close without ingesting.

Triage does not auto-close issues. If an issue looks like a question, duplicate, or invalid, triage will still attempt to ingest it. The human reviews the created documents and can discard them.

### Issues With Existing Documents

If an issue already has principled documents (detected via ingest markers), triage skips it. It only processes untriaged issues.

### Partially Triaged Issues

If an issue has some principled labels but no ingest comment, it may have been manually labeled. Triage treats it as already triaged and skips it. The presence of principled lifecycle labels is sufficient signal.

## When to Run Triage

- **After a batch of issues are filed** --- e.g., after a planning session or user feedback round
- **Periodically** --- weekly or per-sprint to catch stragglers
- **Before planning** --- to ensure all open issues have principled documents before prioritizing work
