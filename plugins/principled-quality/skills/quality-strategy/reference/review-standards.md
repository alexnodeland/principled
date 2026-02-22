# Review Standards

Reference documentation for the principled-quality plugin's review model.

## Checklist Categories

Review checklists are organized into three categories, each serving a distinct purpose:

### 1. Acceptance Criteria

Items derived directly from the plan's task definition. These verify that the implementation fulfills the specified requirements.

- Extracted automatically from `- [ ]` / `- [x]` lines under "Acceptance Criteria" headings in plan documents
- Each criterion maps to a specific, verifiable outcome
- Criteria should be binary (pass/fail) --- no partial credit

### 2. ADR Compliance

Items generated from ADRs relevant to the changed files. These verify that the implementation respects architectural decisions.

- Relevant ADRs are identified by module scope (via CLAUDE.md proximity)
- Each ADR produces one checklist item summarizing what to verify
- Focus on the ADR's "Decision" section --- the specific rule or pattern to follow

### 3. General Quality

Standard quality checks that apply to all PRs. These catch common issues not covered by plan-specific criteria.

Default items:

- Tests present and passing for new/changed functionality
- No regressions in existing tests
- Documentation updated if public API changed
- No hardcoded secrets, credentials, or environment-specific values
- Error handling for external calls and user input
- No TODO/FIXME comments without linked issues

## Severity Classification

Review findings are classified by severity to help prioritize responses:

| Severity      | Meaning                                                      | Action Required            |
| ------------- | ------------------------------------------------------------ | -------------------------- |
| **Blocking**  | Implementation does not meet a required acceptance criterion | Must fix before merge      |
| **Important** | ADR violation or significant quality concern                 | Should fix, discuss if not |
| **Advisory**  | Suggestion for improvement, not a requirement                | Author's discretion        |

## Quality Gates

A PR is considered review-complete when:

1. All **Blocking** items are resolved
2. All **Acceptance Criteria** checklist items are checked
3. All **ADR Compliance** items are reviewed (checked or explicitly waived with comment)
4. **General Quality** items are reviewed (some may be marked N/A)

The plugin does not enforce these gates --- it reports status for human judgment.
