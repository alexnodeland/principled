---
title: "Principled Release Plugin"
number: 004
status: draft
author: Alex
created: 2026-02-22
updated: 2026-02-22
supersedes: null
superseded_by: null
---

# RFC-004: Principled Release Plugin

## Audience

- Teams using the principled methodology who need structured release coordination
- Plugin maintainers evaluating the marketplace's expansion roadmap
- Engineers responsible for versioning, changelogs, and release governance in monorepos
- Contributors to the principled marketplace

## Context

The principled pipeline governs the lifecycle from specification through implementation and merge, but it stops at the repository boundary. Once code is merged, the pipeline offers no guidance or tooling for what happens next: versioning, changelog generation, release coordination, or deployment readiness.

This creates several problems:

1. **No link between releases and specifications.** When cutting a release, teams must manually trace which proposals, plans, and ADRs are included. There is no automated way to generate a changelog entry like "Added event sourcing support (RFC-001, Plan-001, ADR-001)" from the documentation pipeline.

2. **No release readiness checks.** A release might ship with incomplete plan tasks or unresolved proposal dependencies. Nothing in the pipeline verifies that all plans referenced by merged PRs have reached `complete` status before a release is tagged.

3. **Version coordination in monorepos.** In monorepos with multiple modules, each module may have its own versioning cadence. The principled pipeline tracks modules via `CLAUDE.md` declarations (ADR-003) but provides no tooling for coordinating version bumps across modules.

4. **Changelog drift.** Manually maintained changelogs diverge from the actual documentation pipeline. Proposals describe the "why," plans describe the "how," and ADRs record decisions — but changelogs must synthesize all of these into user-facing release notes. This synthesis is error-prone when done manually.

5. **No release governance.** There is no mechanism to enforce that releases go through a preparation phase (changelog review, version bump, release notes draft) before being tagged and published.

The principled methodology already has all the raw material for excellent releases — proposals explain features, plans detail implementation, ADRs record decisions. What's missing is the automation to synthesize these into release artifacts and the governance to ensure release readiness.

## Proposal

Add a new first-party plugin, `principled-release`, to the marketplace. This plugin provides skills for generating changelogs from the documentation pipeline, verifying release readiness, coordinating version bumps, and governing the release lifecycle.

### 1. Plugin Structure

```
plugins/principled-release/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── release-strategy/          # Background knowledge skill
│   │   └── SKILL.md
│   ├── changelog/                 # Generate changelog from pipeline docs
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   │   └── changelog-entry.md
│   │   └── scripts/
│   │       └── collect-changes.sh
│   ├── release-ready/             # Check release readiness
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── check-readiness.sh
│   ├── version-bump/              # Coordinate version bumps
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── detect-modules.sh
│   ├── release-plan/              # Draft release plan from pending changes
│   │   ├── SKILL.md
│   │   └── templates/
│   │       └── release-plan.md
│   └── tag-release/               # Tag and finalize a release
│       ├── SKILL.md
│       └── scripts/
│           └── validate-tag.sh
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── check-release-readiness.sh
└── README.md
```

### 2. Skills

| Skill              | Command                                                        | Category      | Description                                                                               |
| ------------------ | -------------------------------------------------------------- | ------------- | ----------------------------------------------------------------------------------------- |
| `release-strategy` | _(background — not user-invocable)_                            | Knowledge     | Provides context about release conventions and the release plugin's approach              |
| `changelog`        | `/changelog [--since <tag>] [--module <path>]`                 | Generative    | Generate changelog entries from proposals, plans, and ADRs merged since the last release  |
| `release-ready`    | `/release-ready [--tag <version>] [--strict]`                  | Analytical    | Verify all plans are complete, no draft proposals are referenced, and docs are consistent |
| `version-bump`     | `/version-bump [--module <path>] [--type major\|minor\|patch]` | Generative    | Coordinate version bumps across module manifests (package.json, Cargo.toml, etc.)         |
| `release-plan`     | `/release-plan [--since <tag>]`                                | Generative    | Draft a release plan summarizing all changes, grouped by module and category              |
| `tag-release`      | `/tag-release <version> [--dry-run]`                           | Orchestration | Validate, tag, and finalize a release with generated release notes                        |

#### `/changelog`

The core generative skill. It:

1. Identifies the last release tag (or accepts `--since <tag>`)
2. Collects all commits since that tag
3. Maps commits to proposals, plans, and ADRs via:
   - PR description references (principled-github's `/pr-describe` format)
   - Commit message references (e.g., `RFC-001`, `Plan-001`)
   - Branch naming conventions (e.g., `plan-001/task-3`)
4. Groups changes by category (features from accepted proposals, fixes from plans, decisions from ADRs)
5. Generates Markdown changelog entries using the `changelog-entry.md` template
6. Optionally scopes to a single module via `--module <path>`

Output format:

```markdown
## [0.4.0] - 2026-02-22

### Features

- **Event sourcing support** — Switched persistence layer to event sourcing
  (RFC-001, Plan-001). Decided on append-only log with snapshot compaction
  (ADR-001).

### Improvements

- **Documentation pipeline enforcement** — Added lifecycle guards for
  proposals and ADR immutability (Plan-000, tasks 8-10).

### Decisions

- ADR-005: Pre-commit framework for git hooks
- ADR-006: Structural plugin validation in CI
```

#### `/release-ready`

A pre-release gate. It:

1. Identifies all plans referenced by PRs merged since the last release
2. Checks that each referenced plan has status `complete` (or `abandoned` with justification)
3. Checks that no merged PRs reference `draft` or `in-review` proposals
4. Verifies that all ADRs referenced by merged code have status `accepted`
5. Optionally runs structure validation (`validate-structure.sh`) on all affected modules
6. Reports a pass/fail summary with details on any blocking items

In `--strict` mode, any incomplete plan or draft proposal is a hard failure. In default mode, incomplete items are warnings.

#### `/version-bump`

Coordinates version changes across a monorepo:

1. Detects modules via `CLAUDE.md` declarations (per ADR-003)
2. For each module, identifies the version manifest (package.json, Cargo.toml, pyproject.toml, etc.)
3. Determines bump type from the changes: breaking changes (from ADRs or proposals marked `supersedes`) → major, new features (from accepted proposals) → minor, fixes/improvements → patch
4. Applies the version bump to the manifest file
5. Reports what was bumped and why

The `--type` flag overrides automatic detection. The `--module` flag scopes to a single module.

#### `/release-plan`

Drafts a human-reviewable release plan:

1. Collects all changes since the last tag (same logic as `/changelog`)
2. Groups by module, then by category
3. Generates a Markdown document listing:
   - Modules affected and their proposed version bumps
   - Features included (with proposal references)
   - Decisions included (with ADR references)
   - Outstanding items (incomplete plans, open questions)
   - Suggested release timeline and steps
4. Writes to a local file for team review before proceeding

#### `/tag-release`

The final orchestration step:

1. Runs `/release-ready --strict` to verify readiness
2. Generates final changelog via `/changelog`
3. Creates a git tag with the specified version
4. Generates release notes (combining changelog + release plan summary)
5. In `--dry-run` mode, shows what would happen without making changes
6. Without `--dry-run`, creates the tag and optionally creates a GitHub release via `gh release create`

### 3. Hooks

| Hook                       | Event              | Script                       | Timeout | Behavior |
| -------------------------- | ------------------ | ---------------------------- | ------- | -------- |
| Release Readiness Advisory | PostToolUse (Bash) | `check-release-readiness.sh` | 10s     | Advisory |

The hook triggers when `git tag` commands are detected. It reminds the user to run `/release-ready` before tagging if readiness hasn't been verified. Advisory only — always exits 0.

### 4. Marketplace Integration

Add to `.claude-plugin/marketplace.json`:

```json
{
  "name": "principled-release",
  "source": "./plugins/principled-release",
  "description": "Generate changelogs from the documentation pipeline, verify release readiness, and coordinate versioned releases.",
  "version": "0.1.0",
  "category": "workflow",
  "keywords": [
    "release",
    "changelog",
    "versioning",
    "semver",
    "release-management"
  ]
}
```

### 5. Dependencies

- **Git** — Required for tag operations, commit history traversal, and release creation
- **gh CLI** — Optional; required only for GitHub release creation via `/tag-release` and PR reference resolution
- **principled-docs** — Conceptual dependency (reads proposals, plans, ADRs). No runtime coupling. The plugin reads Markdown files and parses frontmatter using the same conventions.

### 6. Changelog Template

The `changelog-entry.md` template follows [Keep a Changelog](https://keepachangelog.com/) conventions adapted for the principled pipeline:

- Entries are grouped by: Added, Changed, Deprecated, Removed, Fixed, Security
- Each entry includes a parenthetical reference to the originating RFC, Plan, or ADR
- Module scope is indicated when the change is module-specific

### 7. Script Conventions

All scripts follow marketplace conventions:

- Pure bash, no external dependencies beyond git and optionally gh
- Frontmatter parsing reuses the same approach as principled-docs (`parse-frontmatter.sh` pattern)
- jq with grep fallback for JSON parsing
- Exit codes: 0 = success/allow, 2 = block (hooks only), 1 = script error

## Alternatives Considered

### Alternative 1: Extend principled-docs with release skills

Add `/changelog` and `/release-ready` as additional skills in the principled-docs plugin.

**Rejected because:** principled-docs is about document structure and authoring — creating and enforcing documentation. Release management is a distinct workflow concern that operates _across_ documents rather than _on_ documents. It reads from the documentation pipeline but its output is release artifacts (changelogs, tags, release notes), not documentation pipeline documents. Separate plugins keep each focused on its domain.

### Alternative 2: CI-only release automation

Instead of Claude Code skills, implement release checks and changelog generation as GitHub Actions workflows that run on tag push or release branch creation.

**Rejected because:** CI-based release automation is complementary but not sufficient. The principled approach requires human review of release plans and changelogs — these are specification artifacts that should be reviewed before being finalized. Claude Code skills allow interactive, iterative release preparation: generate a changelog draft, review it, adjust, then finalize. CI can _validate_ the result but shouldn't _generate_ it autonomously. That said, `/release-ready` checks could additionally run in CI as a gate.

### Alternative 3: Conventional Commits instead of pipeline-based changelogs

Adopt Conventional Commits (feat:, fix:, etc.) for commit messages and generate changelogs from commit messages rather than from the documentation pipeline.

**Rejected because:** The principled methodology already has richer change metadata in proposals, plans, and ADRs than commit messages can convey. A commit message says "add event sourcing"; a proposal explains _why_ event sourcing was chosen, what alternatives were considered, and what the consequences are. Pipeline-based changelogs are strictly more informative than commit-based changelogs. However, Conventional Commits could be supported as a fallback for changes that lack pipeline references.

## Consequences

### Positive

- **Closes the release gap.** The principled pipeline extends from specification through release, with each stage linked to its documentation.
- **Automated traceability.** Changelogs automatically reference the proposals, plans, and ADRs that drove each change, creating a complete audit trail.
- **Release governance.** `/release-ready` prevents releasing with incomplete plans or unresolved specifications, maintaining pipeline integrity through the release boundary.
- **Monorepo-aware.** Version bumps and changelogs understand module boundaries via ADR-003's CLAUDE.md declarations, supporting independent module release cadences.
- **Interactive workflow.** Skills allow iterative release preparation (draft → review → adjust → finalize) rather than fully automated releases that bypass human judgment.

### Negative

- **Pipeline reference requirement.** The plugin is most valuable when PRs and commits reference pipeline documents. Teams that don't consistently reference proposals/plans in their PRs will get sparse changelogs. Mitigated by principled-github's `/pr-describe`, which auto-generates references.
- **Version manifest diversity.** `/version-bump` must understand multiple manifest formats (package.json, Cargo.toml, pyproject.toml, etc.). Initial implementation may support only a subset, with others added over time.
- **Tag workflow assumption.** The plugin assumes git tags are the release mechanism. Teams using other release mechanisms (GitHub releases without tags, deployment pipelines, etc.) may need adaptation.

### Risks

- **Frontmatter parsing fragility.** The plugin parses plan/proposal frontmatter to determine status. Changes to frontmatter conventions in principled-docs would break the release plugin's status checks. Mitigated by using the same parsing approach and conventions.
- **PR reference resolution.** Mapping commits to pipeline documents depends on consistent references in PR descriptions or commit messages. If references are missing, changes appear as "uncategorized" in changelogs. Mitigated by making uncategorized changes visible rather than hidden, prompting teams to improve their reference discipline.
- **Scope creep into CD.** Release management borders on continuous deployment. This plugin intentionally stops at "tag and release notes" — it does not handle deployment, environment promotion, or rollback. This boundary should be maintained.

## Architecture Impact

- **[Plugin System Architecture](../architecture/plugin-system.md)** — Add principled-release as a first-party plugin. Document the `workflow` category and the release lifecycle pattern.
- **[Documentation Pipeline](../architecture/documentation-pipeline.md)** — Extend the pipeline to include the release stage after merge. Document how changelogs synthesize from proposals, plans, and ADRs.

A new ADR may be needed to formalize:

- The changelog entry format and its relationship to Keep a Changelog
- The release readiness criteria (what constitutes "ready")
- The version bump heuristics (how change type maps to semver bump)

## Open Questions

1. **Changelog file management.** Should the plugin maintain a single `CHANGELOG.md` at the repo root, per-module changelogs, or generate changelog entries without persisting them? A single file risks merge conflicts; per-module files add complexity; ephemeral generation loses history.

2. **Release branch workflow.** Should `/release-plan` create a release branch, or should it assume the team's existing branching strategy? Some teams use release branches, others tag from main. The plugin should be workflow-agnostic, but the skill ergonomics differ.

3. **Pre-release versions.** How should the plugin handle pre-release versions (alpha, beta, rc)? Should `/version-bump` support `--pre <label>`, or is pre-release versioning out of scope for v0.1.0?

4. **Cross-module dependency tracking.** When module A depends on module B and module B gets a major version bump, should `/version-bump` flag that module A may need updating? This requires dependency graph awareness that may be too complex for v0.1.0.
