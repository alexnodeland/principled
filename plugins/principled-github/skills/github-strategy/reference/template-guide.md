# GitHub Template Guide

## Overview

GitHub issue and PR templates in `.github/` mirror the principled document templates. They capture the same structured information and cross-reference the canonical documents in the repository.

## Issue Templates

### Proposal (RFC) Template

**File:** `.github/ISSUE_TEMPLATE/proposal.yml`

Maps to the principled proposal template. Captures:

- Title (becomes the issue title)
- Context summary
- Proposal summary
- Module scope (if applicable)
- Architecture impact
- Open questions

The template includes a note that the issue tracks a proposal document and is not the source of truth.

### Plan Tracking Template

**File:** `.github/ISSUE_TEMPLATE/plan.yml`

Maps to the principled plan template. Captures:

- Plan title
- Originating proposal reference
- Phase summary with task checklist
- Bounded contexts affected
- Acceptance criteria summary

### Bug Report Template

**File:** `.github/ISSUE_TEMPLATE/bug-report.yml`

Standard bug report --- not principled-specific but included for completeness. References the principled workflow for tracking fixes that require proposals.

### Blank Issue Template

**File:** `.github/ISSUE_TEMPLATE/config.yml`

Configuration that allows blank issues while presenting the structured templates as options.

## Pull Request Template

**File:** `.github/pull_request_template.md`

Includes sections for:

- Summary of changes
- Related plan/task reference (`Plan-NNN`, `Task X.Y`)
- Related proposal/ADR references
- Checklist (tests, lint, docs updated)
- Module(s) affected

## Template Frontmatter

GitHub issue templates use YAML frontmatter (for `.yml` templates) or markdown frontmatter (for `.md` templates). The principled-github templates use YAML form templates (`.yml`) for issues and markdown for PR templates.

## Customization

Templates are scaffolded once via `/gh-scaffold`. After scaffolding, teams can customize the templates. The plugin does not enforce template immutability --- only the initial scaffold follows the principled pattern.
