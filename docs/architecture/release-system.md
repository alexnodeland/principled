---
title: "Release System Architecture"
last_updated: 2026-02-22
related_adrs: [013]
---

# Release System Architecture

## Purpose

Describes the architecture of the principled-release plugin: how it synthesizes changelogs from the documentation pipeline, verifies release readiness, coordinates version bumps, and governs the release lifecycle. Intended for contributors who need to understand or extend the release plugin, and for teams evaluating how principled releases connect specification to delivery.

## Overview

The release system bridges the gap between the principled documentation pipeline and the delivery boundary. It operates on the output of the existing pipeline (proposals, plans, ADRs, PRs) to produce release artifacts (changelogs, version bumps, release notes, tags).

```
┌───────────────────────────────────────────────────────────────┐
│                    RELEASE LIFECYCLE                           │
│                                                               │
│  /release-plan ──▶ /changelog ──▶ /release-ready ──▶ /tag    │
│    (draft)          (generate)      (verify)         (ship)   │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│                    INPUT: PIPELINE ARTIFACTS                   │
│                                                               │
│  Proposals (why)  ──┐                                         │
│  Plans (how)      ──┼──▶  Change mapping  ──▶  Changelog      │
│  ADRs (decisions) ──┤                                         │
│  PRs (references) ──┘                                         │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│                    OUTPUT: RELEASE ARTIFACTS                   │
│                                                               │
│  Changelog entries, version bumps, release notes, git tags    │
└───────────────────────────────────────────────────────────────┘
```

## Key Abstractions

### Change Mapping

The core abstraction is the **change map**: a data structure that links git commits to their governing pipeline documents. Change mapping resolves through three mechanisms, in priority order:

1. **PR description references** — The `/pr-describe` skill (principled-github) embeds structured references to proposals, plans, and ADRs in PR bodies. These are the most reliable source.
2. **Commit message references** — Direct references like `RFC-001`, `Plan-001`, `ADR-005` in commit messages.
3. **Branch naming conventions** — Branch names like `plan-001/task-3` imply a link to Plan-001, Task 3.

Changes that match no pipeline document are classified as "uncategorized."

### Release Readiness

A **readiness check** verifies that all pipeline documents referenced by merged changes have reached terminal status:

- Plans referenced by merged PRs must be `complete` (or `abandoned` with justification)
- Proposals referenced by merged code must be `accepted` (not `draft` or `in-review`)
- ADRs referenced by merged code must be `accepted`

Readiness has two modes: default (warnings) and strict (hard failures).

### Version Bump Heuristics

Version bumps are derived from the nature of changes:

| Change Signal                       | Bump Type |
| ----------------------------------- | --------- |
| ADR or proposal marked `supersedes` | major     |
| Accepted proposal (new capability)  | minor     |
| Plan tasks (improvements, fixes)    | patch     |

The `--type` flag overrides automatic detection. Module-scoped bumps are supported via `--module`.

## Component Relationships

```
                      /release-plan
                           │
              drafts summary of pending changes
                           │
                           ▼
                      /changelog ◄──── collect-changes.sh
                           │               │
              generates entries from        scans git log,
              pipeline references           resolves PR refs
                           │
                           ▼
                    /release-ready ◄──── check-readiness.sh
                           │                │
              verifies all plans/          reads frontmatter
              proposals/ADRs are          status of referenced
              in terminal status           documents
                           │
                           ▼
                     /tag-release ◄──── validate-tag.sh
                           │                │
              creates git tag,            checks tag format,
              generates release           prevents duplicate
              notes, optionally           tags
              creates GH release
                           │
                           ▼
                    /version-bump ◄──── detect-modules.sh
                                            │
              bumps version manifests      finds CLAUDE.md
              (package.json, etc.)         declarations,
                                           identifies version
                                           manifest files
```

## Data Flow

### Changelog Generation Flow

```
git log --since=<last-tag>
       │
       ▼
Collect commit SHAs
       │
       ▼
For each commit, resolve PR ──▶ gh pr view
       │
       ▼
Parse PR body for pipeline references
(RFC-NNN, Plan-NNN, ADR-NNN patterns)
       │
       ▼
Group changes by category:
  ├── Features (from accepted proposals)
  ├── Improvements (from plan tasks)
  ├── Decisions (from ADRs)
  └── Uncategorized (no pipeline reference)
       │
       ▼
Render via changelog-entry.md template
       │
       ▼
Output: Markdown changelog section
```

### Release Readiness Flow

```
Collect all pipeline refs from merged PRs since <tag>
       │
       ▼
For each referenced document:
  ├── Proposal: read frontmatter status
  │   ├── accepted ──▶ OK
  │   ├── draft/in-review ──▶ WARNING (or FAIL in strict)
  │   └── rejected/superseded ──▶ OK (but flagged)
  │
  ├── Plan: read frontmatter status
  │   ├── complete ──▶ OK
  │   ├── active ──▶ WARNING (or FAIL in strict)
  │   └── abandoned ──▶ OK (flagged for review)
  │
  └── ADR: read frontmatter status
      ├── accepted ──▶ OK
      ├── proposed ──▶ WARNING (or FAIL in strict)
      └── deprecated/superseded ──▶ OK (flagged)
       │
       ▼
Output: Pass/fail summary with details
```

## Key Decisions

- [ADR-013: Pipeline-Based Changelog Generation](../decisions/013-pipeline-based-changelog-generation.md) — Changelogs are synthesized from the documentation pipeline rather than from commit messages or CI automation.

## Constraints and Invariants

1. **Documents are the source of truth.** Changelogs reference pipeline documents; they do not replace them. The changelog is a synthesis artifact, not a primary record.
2. **Interactive, not autonomous.** Release skills generate drafts for human review. `/tag-release` is the only skill that makes irreversible changes (git tags), and it supports `--dry-run`.
3. **Release stops at the tag.** The plugin creates git tags and release notes but does not handle deployment, environment promotion, or rollback. This boundary is intentional.
4. **Uncategorized changes are visible.** Changes without pipeline references appear in the changelog as "uncategorized" rather than being hidden. This preserves completeness and creates pressure to improve reference discipline.
5. **Version manifests are detected, not configured.** `/version-bump` discovers version files (package.json, Cargo.toml, etc.) from module structure rather than requiring explicit configuration.
