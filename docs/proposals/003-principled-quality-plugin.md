---
title: "Principled Quality Plugin"
number: 003
status: draft
author: Alex
created: 2026-02-22
updated: 2026-02-22
supersedes: null
superseded_by: null
---

# RFC-003: Principled Quality Plugin

## Audience

- Teams adopting the principled methodology who want structured code review workflows
- Plugin maintainers evaluating the marketplace's second wave of first-party plugins
- Engineers responsible for enforcing review standards across monorepos
- Contributors to the principled marketplace

## Context

The principled pipeline today covers four stages: specification (principled-docs), decision recording (ADRs via principled-docs), implementation orchestration (principled-implementation), and GitHub integration (principled-github). This pipeline produces well-specified, well-planned code — but it has a blind spot between implementation and merge.

Code review is where implementation meets specification. A reviewer should verify that the code fulfills the plan's acceptance criteria, respects the ADRs that govern the module, and doesn't introduce regressions. Today, this verification is entirely ad hoc:

1. **No link between reviews and specs.** PR reviewers must manually locate the relevant proposal, plan, and ADRs for the code under review. Nothing surfaces these documents automatically.

2. **No structured review checklists.** Review quality depends on individual reviewer discipline. There is no mechanism to generate review checklists from plans or acceptance criteria, and no way to track whether a review covered all required aspects.

3. **No review quality tracking.** Teams have no visibility into whether reviews are thorough — whether acceptance criteria were checked, whether ADR compliance was verified, whether tests were validated against the plan.

4. **The `pr-describe` skill generates descriptions, not review guidance.** `principled-github`'s `/pr-describe` creates PR descriptions from plan context, which helps the _author_. But it doesn't help the _reviewer_ understand what to check or how to verify the implementation against its specification.

This gap means the principled methodology's guarantees weaken at the review stage. Code can be well-specified and well-planned but poorly reviewed, undermining the specification-first approach.

## Proposal

Add a new first-party plugin, `principled-quality`, to the marketplace. This plugin provides skills and hooks that connect the code review process to the principled documentation pipeline, ensuring reviews are informed by specifications and tracked for completeness.

### 1. Plugin Structure

```
plugins/principled-quality/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── quality-strategy/          # Background knowledge skill
│   │   └── SKILL.md
│   ├── review-checklist/          # Generate review checklist from plan
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   │   └── checklist.md
│   │   └── scripts/
│   ├── review-context/            # Surface relevant specs for a PR
│   │   ├── SKILL.md
│   │   └── scripts/
│   ├── review-coverage/           # Assess review completeness
│   │   ├── SKILL.md
│   │   └── scripts/
│   └── review-summary/            # Generate structured review summary
│       ├── SKILL.md
│       └── templates/
│           └── review-summary.md
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── check-review-checklist.sh
└── README.md
```

### 2. Skills

| Skill              | Command                                         | Category   | Description                                                                                                     |
| ------------------ | ----------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------- |
| `quality-strategy` | _(background — not user-invocable)_             | Knowledge  | Provides context about review standards and the quality plugin's conventions                                    |
| `review-checklist` | `/review-checklist <pr-number> [--plan <path>]` | Generative | Generate a review checklist from a plan's acceptance criteria and relevant ADRs; output as a PR comment or file |
| `review-context`   | `/review-context <pr-number>`                   | Analytical | Surface the proposals, plans, and ADRs relevant to the files changed in a PR                                    |
| `review-coverage`  | `/review-coverage <pr-number>`                  | Analytical | Assess whether a PR's review comments address the generated checklist items                                     |
| `review-summary`   | `/review-summary <pr-number>`                   | Generative | Generate a structured review summary linking review findings to spec items                                      |

#### `/review-checklist`

The core skill. Given a PR number (and optionally a plan path), it:

1. Identifies the plan and task associated with the PR (via PR description references or branch naming conventions)
2. Extracts acceptance criteria from the plan's task definition
3. Identifies ADRs relevant to the changed files (by module path and ADR scope)
4. Generates a Markdown checklist with sections:
   - **Acceptance Criteria** — one checkbox per criterion from the plan
   - **ADR Compliance** — one checkbox per relevant ADR, with a summary of what to verify
   - **General Quality** — configurable standard checks (tests present, no regressions, documentation updated)
5. Posts the checklist as a PR comment or writes it to a local file

#### `/review-context`

Surfaces the specification context a reviewer needs. Given a PR number, it:

1. Lists the files changed in the PR
2. Maps changed files to modules (via `CLAUDE.md` module declarations per ADR-003)
3. For each module, finds the relevant proposals, plans, and ADRs
4. Outputs a summary: "This PR touches modules X, Y. Relevant specs: RFC-NNN, Plan-NNN (tasks 2, 5), ADR-001, ADR-003."

This gives reviewers immediate context without manual document hunting.

#### `/review-coverage`

After a review is complete, assesses coverage. Given a PR number, it:

1. Retrieves the review checklist (from PR comments or local file)
2. Retrieves all review comments on the PR
3. Maps review comments to checklist items (by content similarity and file association)
4. Reports which checklist items were addressed and which were not
5. Flags uncovered items for follow-up

#### `/review-summary`

Generates a structured summary after review. Given a PR number, it:

1. Collects all review comments, checklist status, and resolution notes
2. Produces a Markdown summary linking each finding to the relevant spec item
3. Records whether the review resulted in approval, changes requested, or blocking issues
4. Can be appended to the plan's task entry for traceability

### 3. Hooks

| Hook                      | Event              | Script                      | Timeout | Behavior |
| ------------------------- | ------------------ | --------------------------- | ------- | -------- |
| Review Checklist Advisory | PostToolUse (Bash) | `check-review-checklist.sh` | 10s     | Advisory |

The hook triggers when `gh pr review` or `gh pr merge` commands are detected. It reminds the user to generate or check a review checklist if one hasn't been created for the PR. Advisory only — always exits 0.

### 4. Marketplace Integration

Add to `.claude-plugin/marketplace.json`:

```json
{
  "name": "principled-quality",
  "source": "./plugins/principled-quality",
  "description": "Connect code reviews to the principled documentation pipeline with spec-driven checklists and review tracking.",
  "version": "0.1.0",
  "category": "quality",
  "keywords": [
    "code-review",
    "quality",
    "checklist",
    "specification-first",
    "review-coverage"
  ]
}
```

### 5. Dependencies

- **gh CLI** — Required for PR interaction (listing changed files, posting comments, reading reviews)
- **principled-docs** — Conceptual dependency (reads proposals, plans, ADRs), but no import or runtime coupling. The plugin reads Markdown files from `docs/` directories directly.
- **principled-github** — Complementary but independent. `/review-checklist` and `/pr-describe` serve different audiences (reviewer vs. author).

### 6. Script Conventions

All scripts follow marketplace conventions:

- Pure bash, no external dependencies beyond gh CLI
- jq with grep fallback for JSON parsing
- `check-gh-cli.sh` copied from canonical source in principled-github (or a shared convention established)
- Exit codes: 0 = allow/success, 2 = block (hooks only)
- Stdin JSON format for hooks matching existing patterns

## Alternatives Considered

### Alternative 1: Extend principled-github with review skills

Add `/review-checklist` and related skills directly to the principled-github plugin rather than creating a new plugin.

**Rejected because:** principled-github focuses on _GitHub integration mechanics_ (issues, PRs, templates, labels, CODEOWNERS). Review quality is a distinct concern — it's about connecting reviews to specifications, not about GitHub API operations. A team could want review checklists without the full GitHub scaffolding, or vice versa. Separate plugins respect the single-responsibility principle and allow independent adoption.

### Alternative 2: Review checklists as a principled-docs template

Add a review checklist template to principled-docs' scaffold system, generated manually via `/scaffold --type review`.

**Rejected because:** Review checklists should be _generated dynamically_ from plan acceptance criteria and relevant ADRs, not filled in from a static template. The value is in the automation — connecting PR changes to specification documents automatically. A static template would require manual cross-referencing, which is exactly the problem we're solving.

### Alternative 3: PR-level enforcement hooks instead of advisory skills

Use PreToolUse hooks to block PR merges that lack a review checklist, rather than advisory skills that generate and track checklists.

**Rejected because:** Blocking merges on review checklists would be too aggressive for initial adoption. Teams need to build the habit of spec-driven reviews before enforcement makes sense. The advisory hook (reminding about checklists) strikes the right balance. Enforcement could be added as an opt-in feature in a future version.

## Consequences

### Positive

- **Closes the review gap.** The principled pipeline extends from specification through review, ensuring reviews are informed by the same documents that drove implementation.
- **Reduces reviewer cognitive load.** Reviewers get auto-generated checklists and context instead of hunting for relevant specs manually.
- **Traceability.** Review summaries linked to spec items create an audit trail from requirement to review to merge.
- **Independent adoption.** Teams can install principled-quality without principled-implementation or principled-github if they only want the review workflow.

### Negative

- **gh CLI dependency.** Like principled-github, this plugin requires the gh CLI for PR interaction. Teams without gh CLI access cannot use the PR-interactive skills (though local-file-based workflows remain possible).
- **Review overhead.** Generated checklists add ceremony to the review process. For small, obvious changes, a full spec-driven checklist may feel heavy. Mitigation: skills are opt-in, and checklist granularity can be tuned.
- **Plan format coupling.** `/review-checklist` must parse plan task definitions to extract acceptance criteria. Changes to plan format would require script updates. Mitigated by using the same frontmatter/Markdown conventions already established in principled-docs.

### Risks

- **Acceptance criteria quality.** The plugin generates checklists from plan acceptance criteria. If plans have vague or missing criteria, the generated checklists will be low-value. Mitigated by the principled methodology's emphasis on concrete, verifiable acceptance criteria in plans.
- **Review comment parsing.** `/review-coverage` must map free-text review comments to checklist items. This mapping is inherently fuzzy and may produce false positives/negatives. Mitigated by keeping the mapping advisory rather than authoritative.
- **Plugin interdependency precedent.** This is the first plugin that conceptually depends on another (principled-docs). While there's no runtime coupling, it sets a precedent for plugins that assume other plugins' document formats. This relates to RFC-002's Open Question 4 on plugin interdependencies.

## Architecture Impact

- **[Plugin System Architecture](../architecture/plugin-system.md)** — Add principled-quality as a first-party plugin. Document the `quality` category and the review workflow pattern.
- **[Documentation Pipeline](../architecture/documentation-pipeline.md)** — Extend the pipeline diagram to include the review stage between implementation and merge. Document how review checklists link back to plan tasks.

## Open Questions

1. **Checklist persistence.** Should review checklists be stored as PR comments, local files in a `.review/` directory, or both? PR comments are visible to all reviewers but ephemeral. Local files are version-controlled but add repository clutter.

2. **Cross-plugin script sharing.** `check-gh-cli.sh` is canonical in principled-github. Should principled-quality copy it (following the existing drift convention) or should a shared scripts mechanism be established? This is the first case of cross-plugin script reuse.

3. **Review-to-plan feedback loop.** When `/review-coverage` finds uncovered checklist items, should it be able to update the plan's task status or add notes? This would create a write dependency on principled-docs document formats.
