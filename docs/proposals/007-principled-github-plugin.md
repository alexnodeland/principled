---
title: "Principled GitHub Plugin"
number: 007
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-22
supersedes: null
superseded_by: null
---

# RFC-007: Principled GitHub Plugin

## Audience

- Teams using the principled methodology who host their repositories on GitHub
- Engineers responsible for issue triage, PR workflows, and repository configuration
- Plugin maintainers evaluating the marketplace's integration layer
- Contributors to the principled marketplace

## Context

The principled pipeline produces proposals, ADRs, and DDD plans as markdown files within the repository. GitHub, meanwhile, provides its own parallel system for tracking work: issues, pull requests, labels, templates, and workflows. Teams using both face a synchronization gap:

1. **Issues and proposals are disconnected.** A GitHub issue describes a bug or feature request. A principled proposal (RFC) describes the same thing in spec-first detail. But there is no automated link between them — a team member must manually create a proposal from an issue, or create an issue from a proposal, and keep them in sync.

2. **PRs lack spec context.** When a developer opens a PR implementing a plan task, the PR description is typically ad hoc. It may or may not reference the proposal, plan, or ADRs that drove the change. Reviewers must hunt for this context manually.

3. **Labels don't reflect the pipeline.** GitHub labels are freeform. Teams using the principled methodology want labels that mirror pipeline stages (proposal-draft, plan-active, etc.), but there is no standard label set or tooling to maintain it.

4. **Repository scaffolding is manual.** Setting up `.github/` with issue templates, PR templates, workflows, and CODEOWNERS that align with the principled methodology requires manual configuration.

5. **Issue triage is unbatched.** New issues arrive on GitHub but aren't automatically routed into the principled pipeline. A maintainer must manually review each issue, decide if it warrants a proposal, and create the appropriate documents.

6. **CODEOWNERS doesn't leverage module structure.** The principled methodology defines module boundaries via `CLAUDE.md` declarations (ADR-003), but CODEOWNERS files are maintained separately without reference to this module structure.

The principled-docs plugin manages documents. The principled-implementation plugin executes plans. What's missing is the integration layer that connects these to GitHub's native features.

## Proposal

Add a new first-party plugin, `principled-github`, to the marketplace. This plugin provides skills and a hook for bidirectional integration between the principled documentation pipeline and GitHub's native features: issues, pull requests, labels, templates, workflows, and CODEOWNERS.

### 1. Plugin Structure

```
plugins/principled-github/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── github-strategy/           # Background knowledge skill
│   │   ├── SKILL.md
│   │   └── reference/
│   │       ├── github-mapping.md
│   │       ├── label-taxonomy.md
│   │       └── sync-model.md
│   ├── triage/                    # Batch issue processing
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── check-gh-cli.sh
│   ├── ingest-issue/              # Single issue ingestion
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── check-gh-cli.sh   (COPY)
│   ├── sync-issues/               # Push docs to GitHub issues
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── check-gh-cli.sh   (CANONICAL)
│   │       └── extract-doc-metadata.sh
│   ├── pr-describe/               # Generate PR descriptions
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── check-gh-cli.sh   (COPY)
│   ├── gh-scaffold/               # Scaffold .github/ directory
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   └── check-gh-cli.sh   (COPY)
│   │   └── templates/
│   │       ├── issue-templates/
│   │       ├── pull-request-template.md
│   │       └── workflows/
│   ├── gen-codeowners/            # Generate CODEOWNERS
│   │   ├── SKILL.md
│   │   └── scripts/
│   ├── sync-labels/               # Sync label taxonomy
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── check-gh-cli.sh   (COPY)
│   └── pr-check/                  # Validate PR conventions
│       ├── SKILL.md
│       └── scripts/
│           └── check-gh-cli.sh   (COPY)
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── check-pr-references.sh
├── scripts/
│   └── check-template-drift.sh
└── README.md
```

### 2. Skills

| Skill             | Command                                            | Category      | Description                                                                    |
| ----------------- | -------------------------------------------------- | ------------- | ------------------------------------------------------------------------------ |
| `github-strategy` | _(background — not user-invocable)_                | Knowledge     | Deep context on GitHub-principled mapping, label taxonomy, and sync model      |
| `triage`          | `/triage [--limit N] [--label <filter>]`           | Orchestration | Batch-process open GitHub issues into the principled pipeline                  |
| `ingest-issue`    | `/ingest-issue <number>`                           | Generative    | Fetch a single GitHub issue and create proposal/plan documents from it         |
| `sync-issues`     | `/sync-issues [<doc-path>] [--all-proposals]`      | Sync          | Push proposals/plans to GitHub issues with bidirectional references            |
| `pr-describe`     | `/pr-describe [<task-id>] [--plan <path>]`         | Generative    | Generate structured PR description with spec cross-references                  |
| `gh-scaffold`     | `/gh-scaffold [--templates] [--workflows] [--all]` | Generative    | Scaffold `.github/` with principled-aligned templates, workflows, CODEOWNERS   |
| `gen-codeowners`  | `/gen-codeowners [--modules-dir <path>]`           | Generative    | Generate CODEOWNERS from module structure and git history                       |
| `sync-labels`     | `/sync-labels [--dry-run] [--prune]`               | Sync          | Create/sync GitHub labels for principled lifecycle stages                       |
| `pr-check`        | `/pr-check [<pr-number>] [--strict]`               | Analytical    | Validate PR follows principled conventions (references, labels, description)    |

#### `/triage`

Batch processes open GitHub issues:

1. Lists open issues via `gh issue list` (optionally filtered by label or limit)
2. For each issue, determines if it warrants a proposal, plan, or neither
3. Invokes `/ingest-issue` for qualifying issues
4. Applies appropriate labels (e.g., `principled:triaged`)
5. Reports a summary: issues processed, proposals created, issues skipped

#### `/ingest-issue`

Ingests a single GitHub issue into the principled pipeline:

1. Fetches issue details via `gh issue view`
2. Analyzes issue content to determine appropriate documents (proposal, plan, or both)
3. Creates proposal/plan pre-populated with issue content, linked via issue number
4. Adds a comment to the GitHub issue referencing the created document(s)
5. Applies labels to reflect pipeline status

#### `/sync-issues`

Pushes principled documents to GitHub issues:

1. Reads proposal/plan frontmatter (title, status, number)
2. Searches for existing GitHub issue linked to the document
3. If found: updates issue title, body, and labels to reflect current document state
4. If not found: creates new GitHub issue from document content
5. Maintains bidirectional references: document references issue number, issue references document path
6. Documents remain the source of truth; GitHub issues are the synchronized view

#### `/pr-describe`

Generates structured PR descriptions:

1. Identifies the plan task being implemented (from task-id argument, branch name, or manifest)
2. Reads the plan, originating proposal, and relevant ADRs
3. Generates a PR description with sections: Summary, Plan Reference, Changes, ADR Compliance, Test Plan
4. Optionally creates the PR directly via `gh pr create` with `--create` flag

#### `/gh-scaffold`

Scaffolds GitHub-specific configuration:

1. Creates `.github/ISSUE_TEMPLATE/` with principled-aligned issue templates (bug report, feature request, proposal)
2. Creates `.github/PULL_REQUEST_TEMPLATE.md` with structured sections
3. Creates `.github/workflows/` with principled CI workflow (PR validation)
4. Creates `CODEOWNERS` via `/gen-codeowners`
5. Supports selective scaffolding via `--templates`, `--workflows`, `--codeowners` flags

#### `/gen-codeowners`

Generates CODEOWNERS from module structure:

1. Discovers modules via `CLAUDE.md` files (per ADR-003)
2. Analyzes git log to identify most active contributors per module
3. Maps module paths to CODEOWNERS entries
4. Supports `--modules-dir` to scope discovery and `--output` for custom path

#### `/sync-labels`

Synchronizes the principled label taxonomy:

1. Defines the standard label set: lifecycle labels (`proposal:draft`, `proposal:accepted`, `plan:active`, etc.), type labels, priority labels
2. Creates missing labels via `gh label create`
3. Updates labels with incorrect colors or descriptions
4. With `--prune`: removes labels not in the taxonomy
5. With `--dry-run`: reports what would change without making changes

#### `/pr-check`

Validates PR compliance with principled conventions:

1. Reads PR description, labels, and linked issues
2. Checks for: non-empty description, summary section, test plan section, issue references, plan/proposal references
3. Reports pass/fail per check with advisory or error severity
4. In `--strict` mode: any missing reference is a failure
5. Supports `--json` output for CI integration

### 3. Hooks

| Hook               | Event              | Script                     | Timeout | Behavior |
| ------------------ | ------------------ | -------------------------- | ------- | -------- |
| PR Reference Nudge | PostToolUse (Bash) | `check-pr-references.sh`   | 10s     | Advisory |

Triggers when `gh pr create` commands are detected. Checks if the command includes principled document references (Plan-NNN, RFC-NNN, ADR-NNN). If not, emits an advisory reminding the user to use `/pr-describe`. Always exits 0.

### 4. Script Duplication

One canonical script with 6 copies:

| Canonical                                    | Copies To                                                    |
| -------------------------------------------- | ------------------------------------------------------------ |
| `sync-issues/scripts/check-gh-cli.sh`        | `sync-labels/`, `pr-check/`, `gh-scaffold/`, `ingest-issue/`, `triage/`, `pr-describe/` scripts |

`scripts/check-template-drift.sh` verifies all 6 pairs. Drift = CI failure.

The `check-gh-cli.sh` script verifies that the `gh` CLI is installed and authenticated before skill execution. Each skill that requires `gh` runs this check first.

### 5. Background Knowledge

The `github-strategy` skill provides three reference documents:

- **github-mapping.md** — How principled concepts map to GitHub features (proposals ↔ issues, plans ↔ milestones, ADRs ↔ discussions, etc.)
- **label-taxonomy.md** — The standard label set with names, colors, and descriptions for principled lifecycle stages
- **sync-model.md** — The bidirectional sync model: documents are source of truth, GitHub issues are the synchronized view, conflict resolution rules

### 6. Marketplace Integration

```json
{
  "name": "principled-github",
  "source": "./plugins/principled-github",
  "description": "Integrate the Principled specification-first workflow with GitHub native features: issues, PRs, templates, actions, CODEOWNERS, and labels.",
  "version": "0.1.0",
  "category": "integration",
  "keywords": ["github", "issues", "pull-requests", "templates", "codeowners", "labels", "workflow", "integration"]
}
```

### 7. Dependencies

- **gh CLI** — Required for all GitHub API interactions (issues, PRs, labels, releases)
- **Git** — For repository context, branch detection, and commit history (CODEOWNERS generation)
- **Bash** — All scripts are pure bash
- **jq** — Optional; scripts fall back to grep for JSON parsing
- **principled-docs** — Conceptual dependency (reads proposals, plans, ADRs). No runtime coupling.

## Alternatives Considered

### Alternative 1: GitHub Actions only (no Claude Code plugin)

Implement all GitHub integration as GitHub Actions workflows that run on issue creation, PR opening, and label changes.

**Rejected because:** GitHub Actions are event-driven and automated, but the principled workflow requires human judgment at key points: deciding whether an issue warrants a proposal, reviewing generated PR descriptions, choosing which documents to sync. Claude Code skills provide interactive, iterative workflows that GitHub Actions cannot. However, Actions are complementary — `/gh-scaffold` generates a PR validation workflow that runs in CI.

### Alternative 2: Extend principled-docs with GitHub skills

Add `/sync-issues`, `/pr-describe`, and related skills to the principled-docs plugin.

**Rejected because:** principled-docs is about document authoring and structure. GitHub integration is a distinct concern: API interactions, label management, template generation, CODEOWNERS maintenance. Teams that don't use GitHub shouldn't carry GitHub-specific skills. Separate plugins allow platform-specific integrations to be adopted independently.

### Alternative 3: Use GitHub's built-in project boards for tracking

Rely on GitHub Projects to track proposals and plans instead of bidirectional sync.

**Rejected because:** GitHub Projects tracks items but doesn't understand the principled pipeline's document structure, frontmatter metadata, or lifecycle rules. The principled pipeline's documents are richer than GitHub issue/project metadata. Sync ensures GitHub reflects the pipeline state without replacing the pipeline.

## Consequences

### Positive

- **Bidirectional GitHub integration.** Issues flow into the pipeline via `/triage` and `/ingest-issue`; documents flow back via `/sync-issues`. Both directions maintain cross-references.
- **Structured PRs.** `/pr-describe` generates PR descriptions with full spec context, improving review quality.
- **Standard label taxonomy.** `/sync-labels` ensures consistent labeling across teams, reflecting principled lifecycle stages.
- **Repository scaffolding.** `/gh-scaffold` provides one-command setup for principled-aligned GitHub configuration.
- **Module-aware CODEOWNERS.** `/gen-codeowners` leverages principled module structure (ADR-003) for accurate ownership mapping.
- **Independent adoption.** Teams can install principled-github without principled-implementation if they only want the GitHub integration layer.

### Negative

- **gh CLI dependency.** All skills require the gh CLI, which must be installed and authenticated. Teams without gh CLI access cannot use this plugin.
- **GitHub-specific.** This plugin is inherently platform-specific. Teams on GitLab, Bitbucket, or other platforms need different plugins.
- **Sync complexity.** Bidirectional sync between documents and issues introduces potential for drift if one side is updated without syncing.

### Risks

- **gh CLI API changes.** The plugin depends on `gh` CLI command syntax. Major gh CLI updates could break skill scripts.
- **GitHub API rate limits.** `/triage` processing many issues in batch could hit rate limits. Mitigated by `--limit` flag.
- **Label naming conflicts.** If a repository already has labels that conflict with the principled taxonomy, `/sync-labels` must handle conflicts gracefully (update description/color, not duplicate).

## Architecture Impact

- **[Plugin System Architecture](../architecture/plugin-system.md)** — Add the GitHub integration layer. Document the `integration` category and the sync model pattern.
- **[Documentation Pipeline](../architecture/documentation-pipeline.md)** — Extend the pipeline diagram to show GitHub as an external integration point with bidirectional sync.

This plugin motivates the following architectural decisions:
- ADR-010: gh CLI as the GitHub integration interface
- ADR-011: Documents as source of truth in bidirectional sync

## Open Questions

1. **Sync conflict resolution.** When a document and its linked GitHub issue diverge (e.g., title changed in both), which wins? The current design says "documents are source of truth," but should `/sync-issues` warn about divergence before overwriting?

2. **Multi-repo support.** Should `/sync-issues` support syncing documents to issues in a different repository? Some teams separate their spec repo from their code repo.

3. **GitHub Discussions integration.** Should ADRs be synced to GitHub Discussions rather than issues? Discussions better match the ADR use case (permanent record, threaded conversation) than issues (trackable work items).
