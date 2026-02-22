---
title: "Principled GitHub Plugin"
number: "004"
status: complete
author: Alex
created: 2026-02-22
updated: 2026-02-22
originating_proposal: "007"
---

# Plan-004: Principled GitHub Plugin

## Objective

Implements [RFC-007](../proposals/007-principled-github-plugin.md).

Build the `principled-github` Claude Code plugin end-to-end: plugin infrastructure, all 9 skills, 1 advisory hook, 1 canonical script with 6 copies, GitHub templates and workflows, drift detection, and a plugin README — following the directory layout and conventions established in the marketplace.

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **7 bounded contexts**, each representing a distinct area of domain responsibility within the plugin:

| #    | Bounded Context            | Responsibility                                                                    | Key Artifacts                                         |
| ---- | -------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------- |
| BC-1 | **Plugin Infrastructure**  | Plugin manifest, directory skeleton, marketplace integration                      | `plugin.json`, directory tree, marketplace.json entry |
| BC-2 | **Knowledge System**       | Background knowledge on GitHub-principled mapping, label taxonomy, sync model     | `github-strategy/` skill with reference docs          |
| BC-3 | **Issue Pipeline**         | Ingest issues into principled pipeline, triage in batch, sync documents to issues | `ingest-issue/`, `triage/`, `sync-issues/` skills     |
| BC-4 | **PR Integration**         | Generate structured PR descriptions, validate PR conventions                      | `pr-describe/`, `pr-check/` skills                    |
| BC-5 | **Repository Scaffolding** | Scaffold `.github/` with templates, workflows, and CODEOWNERS                     | `gh-scaffold/`, `gen-codeowners/` skills              |
| BC-6 | **Label Management**       | Define and sync the principled label taxonomy to GitHub                           | `sync-labels/` skill                                  |
| BC-7 | **Enforcement & Drift**    | Advisory hook for PR references, script drift detection                           | `check-pr-references.sh`, `check-template-drift.sh`   |

### Aggregates

#### BC-1: Plugin Infrastructure

| Aggregate          | Root Entity   | Description                                                               |
| ------------------ | ------------- | ------------------------------------------------------------------------- |
| **PluginManifest** | `plugin.json` | Plugin identity, version, metadata                                        |
| **DirectoryTree**  | Plugin root   | Complete directory skeleton for all skills, hooks, scripts, and templates |

#### BC-2: Knowledge System

| Aggregate         | Root Entity         | Description                                                               |
| ----------------- | ------------------- | ------------------------------------------------------------------------- |
| **GitHubMapping** | `github-mapping.md` | How principled concepts map to GitHub features                            |
| **LabelTaxonomy** | `label-taxonomy.md` | Standard label set with names, colors, descriptions for lifecycle stages  |
| **SyncModel**     | `sync-model.md`     | Bidirectional sync rules: documents as source of truth, conflict handling |

#### BC-3: Issue Pipeline

| Aggregate             | Root Entity               | Description                                                            |
| --------------------- | ------------------------- | ---------------------------------------------------------------------- |
| **IssueIngester**     | `ingest-issue/SKILL.md`   | Fetches a GitHub issue and creates principled documents from it        |
| **BatchTriager**      | `triage/SKILL.md`         | Processes multiple open issues through the pipeline in one invocation  |
| **IssueSyncer**       | `sync-issues/SKILL.md`    | Pushes document state to GitHub issues, maintaining bidirectional refs |
| **MetadataExtractor** | `extract-doc-metadata.sh` | Extracts frontmatter fields from documents for sync operations         |

#### BC-4: PR Integration

| Aggregate       | Root Entity            | Description                                                                 |
| --------------- | ---------------------- | --------------------------------------------------------------------------- |
| **PRDescriber** | `pr-describe/SKILL.md` | Generates structured PR descriptions with spec cross-references             |
| **PRChecker**   | `pr-check/SKILL.md`    | Validates PRs against principled conventions (references, labels, sections) |

#### BC-5: Repository Scaffolding

| Aggregate          | Root Entity                          | Description                                                        |
| ------------------ | ------------------------------------ | ------------------------------------------------------------------ |
| **GHScaffolder**   | `gh-scaffold/SKILL.md`               | Creates `.github/` directory with templates, workflows, CODEOWNERS |
| **IssueTemplates** | `templates/issue-templates/`         | Bug report, feature request, and proposal issue templates          |
| **PRTemplate**     | `templates/pull-request-template.md` | PR template with principled sections                               |
| **CIWorkflow**     | `templates/workflows/`               | GitHub Actions workflow for PR validation                          |
| **CODEOWNERSGen**  | `gen-codeowners/SKILL.md`            | Generates CODEOWNERS from module structure and git history         |

#### BC-6: Label Management

| Aggregate       | Root Entity            | Description                                                             |
| --------------- | ---------------------- | ----------------------------------------------------------------------- |
| **LabelSyncer** | `sync-labels/SKILL.md` | Creates, updates, and optionally prunes GitHub labels to match taxonomy |

#### BC-7: Enforcement & Drift

| Aggregate            | Root Entity               | Description                                                |
| -------------------- | ------------------------- | ---------------------------------------------------------- |
| **PRReferenceNudge** | `check-pr-references.sh`  | Advisory hook reminding about principled references in PRs |
| **GHCLICheck**       | `check-gh-cli.sh`         | Verifies gh CLI availability, duplicated across 7 skills   |
| **DriftChecker**     | `check-template-drift.sh` | Verifies all 6 script copies match canonical source        |

### Domain Events

| Event                      | Source Context          | Target Context(s)  | Description                                               |
| -------------------------- | ----------------------- | ------------------ | --------------------------------------------------------- |
| **IssueIngested**          | BC-3 (Issue Pipeline)   | BC-6 (Label Mgmt)  | Issue converted to document; labels should be applied     |
| **BatchTriageComplete**    | BC-3 (Issue Pipeline)   | BC-6 (Label Mgmt)  | All qualifying issues processed; summary labels updated   |
| **DocumentSynced**         | BC-3 (Issue Pipeline)   | BC-6 (Label Mgmt)  | Document pushed to GitHub issue; lifecycle labels updated |
| **PRDescriptionGenerated** | BC-4 (PR Integration)   | BC-7 (Enforcement) | PR created with references; hook should not fire          |
| **RepositoryScaffolded**   | BC-5 (Repo Scaffolding) | BC-6 (Label Mgmt)  | GitHub config created; labels should be synced            |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Plugin Skeleton & Infrastructure (BC-1)

**Goal:** Create the complete directory tree and plugin manifest.

- [x] **1.1** Create `plugins/principled-github/.claude-plugin/plugin.json` with name, version, description, author, homepage, keywords
- [x] **1.2** Create the full directory skeleton: all 9 skill directories, hook directory, scripts directory, template directories, reference directories
- [x] **1.3** Add plugin entry to `.claude-plugin/marketplace.json` with category `integration`

### Phase 2: Shared Scripts & Knowledge Base (BC-2, BC-7)

**Goal:** Implement shared utilities and background knowledge.

**Depends on:** Phase 1

- [x] **2.1** Implement `sync-issues/scripts/check-gh-cli.sh` (CANONICAL): verify `gh` is installed and authenticated, report version, exit 1 if missing
- [x] **2.2** Implement `sync-issues/scripts/extract-doc-metadata.sh`: extract frontmatter fields from principled documents for sync operations
- [x] **2.3** Write `github-strategy/reference/github-mapping.md`: proposals ↔ issues, plans ↔ milestones, ADRs ↔ discussions, pipeline stages ↔ labels
- [x] **2.4** Write `github-strategy/reference/label-taxonomy.md`: standard label names, colors, descriptions for proposal/plan/ADR lifecycle stages
- [x] **2.5** Write `github-strategy/reference/sync-model.md`: bidirectional sync rules, documents as source of truth, conflict handling, reference format
- [x] **2.6** Write `github-strategy/SKILL.md`: background knowledge, non-invocable, references all three reference docs

### Phase 3: Issue Pipeline Skills (BC-3)

**Goal:** Implement issue ingestion, triage, and sync skills.

**Depends on:** Phase 2

- [x] **3.1** Write `ingest-issue/SKILL.md`: user-invocable, fetch issue via `gh`, analyze content, create proposal/plan, add comment, apply labels
- [x] **3.2** Write `triage/SKILL.md`: user-invocable, batch process open issues with `--limit` and `--label` filters, invoke ingest per issue, report summary
- [x] **3.3** Write `sync-issues/SKILL.md`: user-invocable, push document state to GitHub issues, create or update issues, maintain bidirectional references, `--dry-run` and `--all-proposals` support

### Phase 4: PR Integration Skills (BC-4)

**Goal:** Implement PR description generation and validation.

**Depends on:** Phase 2

- [x] **4.1** Write `pr-describe/SKILL.md`: user-invocable, generate structured PR description from plan task, cross-reference proposals/ADRs, optional `--create` flag
- [x] **4.2** Write `pr-check/SKILL.md`: user-invocable, validate PR against principled conventions, `--strict` and `--json` modes

### Phase 5: Repository Scaffolding & Labels (BC-5, BC-6)

**Goal:** Implement GitHub scaffolding, CODEOWNERS generation, and label sync.

**Depends on:** Phase 2

- [x] **5.1** Create `gh-scaffold/templates/issue-templates/`: bug report, feature request, and proposal issue templates
- [x] **5.2** Create `gh-scaffold/templates/pull-request-template.md`: structured PR template with Summary, Plan Reference, Changes, Test Plan sections
- [x] **5.3** Create `gh-scaffold/templates/workflows/`: GitHub Actions workflow for principled PR validation
- [x] **5.4** Write `gh-scaffold/SKILL.md`: user-invocable, scaffold `.github/` with selective flags (`--templates`, `--workflows`, `--codeowners`, `--all`)
- [x] **5.5** Write `gen-codeowners/SKILL.md`: user-invocable, discover modules via CLAUDE.md, analyze git history, generate CODEOWNERS
- [x] **5.6** Write `sync-labels/SKILL.md`: user-invocable, create/update/prune GitHub labels, `--dry-run` and `--prune` support

### Phase 6: Hooks, Drift Detection & Documentation (BC-7, BC-1)

**Goal:** Implement advisory hook, propagate script copies, write README.

**Depends on:** Phases 3, 4, 5

- [x] **6.1** Implement `hooks/scripts/check-pr-references.sh`: PostToolUse hook, reads stdin JSON, checks for `gh pr create`, warns if no principled references, always exits 0
- [x] **6.2** Write `hooks/hooks.json`: PostToolUse hook for Bash targeting PR reference check script
- [x] **6.3** Propagate `check-gh-cli.sh` copies:
  - Canonical `sync-issues/scripts/` → `sync-labels/`, `pr-check/`, `gh-scaffold/`, `ingest-issue/`, `triage/`, `pr-describe/` (6 copies)
- [x] **6.4** Implement `scripts/check-template-drift.sh`: verify all 6 canonical-copy pairs, exit non-zero on drift
- [x] **6.5** Write plugin `README.md`:
  - Installation and gh CLI prerequisites
  - All 9 skills with command syntax and descriptions
  - Hook documentation (PR reference advisory)
  - Label taxonomy reference
  - Script duplication and drift detection
  - Integration with principled-docs and principled-implementation

---

## Decisions Required

Architectural decisions resolved during implementation:

1. **GitHub API interface.** → ADR-010: Use the gh CLI for all GitHub API interactions.
2. **Sync data consistency.** → ADR-011: Documents are source of truth; GitHub issues are a synchronized view.

---

## Dependencies

| Dependency                           | Required By                      | Status              |
| ------------------------------------ | -------------------------------- | ------------------- |
| gh CLI (installed and authenticated) | All skills except gen-codeowners | Required            |
| Bash shell                           | All scripts                      | Available           |
| Git                                  | gen-codeowners, pr-describe      | Available           |
| jq (optional, with grep fallback)    | check-pr-references.sh           | Optional            |
| principled-docs document format      | sync-issues, pr-describe         | Stable (v0.3.1)     |
| Marketplace structure (RFC-002)      | Plugin location                  | Complete (Plan-002) |

---

## Acceptance Criteria

- [x] `/triage --limit 5` fetches up to 5 open issues and processes them through the pipeline
- [x] `/ingest-issue 42` fetches issue #42, creates a proposal pre-populated with issue content, and comments on the issue
- [x] `/sync-issues docs/proposals/001-feature.md` creates or updates a GitHub issue from the proposal
- [x] `/sync-issues --all-proposals` syncs all proposals to GitHub issues
- [x] `/pr-describe 1.1 --plan docs/plans/001-feature.md` generates a structured PR description
- [x] `/pr-describe --create` generates and creates the PR in one step
- [x] `/pr-check` validates the current PR against principled conventions
- [x] `/pr-check --strict` fails if any reference is missing
- [x] `/gh-scaffold --all` creates issue templates, PR template, workflows, and CODEOWNERS
- [x] `/gen-codeowners` generates CODEOWNERS from module structure
- [x] `/sync-labels --dry-run` reports what labels would be created/updated
- [x] `/sync-labels` creates all principled lifecycle labels
- [x] `check-pr-references.sh` warns when `gh pr create` is run without document references (advisory, never blocks)
- [x] `check-template-drift.sh` passes when all 6 copy pairs match canonical source
- [x] `check-template-drift.sh` fails when any copy diverges
- [x] Plugin README documents all skills, hook, and conventions
