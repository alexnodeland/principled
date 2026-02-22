# Checklist Conventions

Reference documentation for review checklist format, storage, and identification.

## Checklist Format

Review checklists use standard GitHub Markdown checkbox syntax:

```markdown
## Review Checklist — PR #42

**Plan:** Plan-005 (task 2.1)
**Generated:** 2026-02-22

### Acceptance Criteria

- [ ] Widget renders correctly with default props
- [ ] Error state displays user-friendly message
- [ ] Loading skeleton matches design spec

### ADR Compliance

- [ ] **ADR-003:** Module type declared in CLAUDE.md
- [ ] **ADR-005:** Pre-commit hooks configured

### General Quality

- [ ] Tests present for new functionality
- [ ] No regressions in existing tests
- [ ] Documentation updated if needed
```

## Dual Storage Model (ADR-012)

Review checklists are stored in two locations:

### Primary: PR Comments

- Posted via `gh pr comment` with a unique HTML comment marker
- Marker format: `<!-- principled-review-checklist: PR-<number> -->`
- Reviewers interact with checkboxes directly on GitHub
- This is the working copy --- reflects current review state

### Secondary: Local Files

- Written to `.review/<pr-number>-checklist.md`
- Provides persistent record beyond PR lifecycle
- `.review/` is gitignored by default (per ADR-012)
- Teams can remove from `.gitignore` for audit trails

### Reading Priority

When reading checklist state:

1. Read PR comment first (current interactive state)
2. Fall back to local file if PR comment not found
3. Report "no checklist" if neither exists

## `.review/` Directory Structure

```
.review/
├── 42-checklist.md      # Checklist for PR #42
├── 42-summary.md        # Review summary for PR #42 (optional)
├── 57-checklist.md      # Checklist for PR #57
└── 57-summary.md        # Review summary for PR #57 (optional)
```

File naming: `<pr-number>-<artifact>.md`

## PR Comment Markers

HTML comment markers enable the plugin to find and update its own comments:

| Marker                                       | Used By             |
| -------------------------------------------- | ------------------- |
| `<!-- principled-review-checklist: PR-N -->` | `/review-checklist` |
| `<!-- principled-review-summary: PR-N -->`   | `/review-summary`   |

These markers are invisible in rendered Markdown but searchable via the GitHub API.

## Identifying Existing Checklists

To check if a checklist already exists for a PR:

1. List PR comments: `gh pr view <number> --json comments`
2. Search for the marker string in comment bodies
3. If found, the checklist exists and can be updated
4. If not found, a new checklist should be created
