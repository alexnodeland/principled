# principled — Claude Code Context

## Module Type

core

## What This Is

This repo is the **Principled methodology plugin marketplace** (v1.0.0). It hosts Claude Code plugins for specification-first development, organized as a curated directory with two tiers: first-party plugins in `plugins/` and community plugins in `external_plugins/`. Three first-party plugins ship today:

- **principled-docs** (v0.3.1) — Scaffold, author, and enforce module documentation structure for monorepos.
- **principled-implementation** (v0.1.0) — Orchestrate DDD plan execution via worktree-isolated Claude Code agents.
- **principled-github** (v0.1.0) — Integrate the principled workflow with GitHub native features: issues, PRs, templates, actions, CODEOWNERS, and labels.
- **principled-quality** (v0.1.0) — Connect code reviews to the principled documentation pipeline with spec-driven checklists, coverage assessment, and review summaries.

## Architecture

Six layers, top to bottom:

| Layer                   | Location                                                           | Role                                                                                                                 |
| ----------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| **Marketplace**         | `.claude-plugin/marketplace.json`, `plugins/`, `external_plugins/` | Plugin catalog, directory structure, plugin discovery and distribution                                               |
| **Docs: Skills**        | `plugins/principled-docs/skills/` (9 directories)                  | Generative workflows — each skill is a slash command with its own `SKILL.md`, templates, scripts, and reference docs |
| **Docs: Hooks**         | `plugins/principled-docs/hooks/`                                   | Deterministic guardrails — `hooks.json` declares PreToolUse/PostToolUse triggers that run shell scripts              |
| **Implementation: All** | `plugins/principled-implementation/`                               | Skills (6), hooks (1), agents (1) for plan execution via worktree-isolated sub-agents                                |
| **GitHub: All**         | `plugins/principled-github/`                                       | Skills (9), hooks (1) for GitHub integration: issues, PRs, templates, CODEOWNERS, labels                             |
| **Quality: All**        | `plugins/principled-quality/`                                      | Skills (5), hooks (1) for spec-driven code review: checklists, context, coverage, summaries                          |
| **Dev DX**              | `.claude/`, config files, `.github/workflows/`                     | Project-level Claude Code settings, dev skills, CI pipeline, linting config                                          |

## Skills

### principled-docs (9 skills)

| Skill                  | Command                                  | Category   |
| ---------------------- | ---------------------------------------- | ---------- |
| `docs-strategy`        | _(background — not user-invocable)_      | Knowledge  |
| `scaffold`             | `/scaffold <path> --type core\|lib\|app` | Generative |
| `validate`             | `/validate [path] --type <type>`         | Analytical |
| `docs-audit`           | `/docs-audit`                            | Analytical |
| `new-proposal`         | `/new-proposal <title>`                  | Generative |
| `new-plan`             | `/new-plan <title> --from-proposal NNN`  | Generative |
| `new-adr`              | `/new-adr <title>`                       | Generative |
| `new-architecture-doc` | `/new-architecture-doc <title>`          | Generative |
| `proposal-status`      | `/proposal-status NNN <status>`          | Analytical |

### principled-implementation (6 skills)

| Skill           | Command                                             | Category      |
| --------------- | --------------------------------------------------- | ------------- |
| `impl-strategy` | _(background — not user-invocable)_                 | Knowledge     |
| `decompose`     | `/decompose <plan-path>`                            | Analytical    |
| `spawn`         | `/spawn <task-id>`                                  | Orchestration |
| `check-impl`    | `/check-impl [--task <id>] [--all]`                 | Analytical    |
| `merge-work`    | `/merge-work <task-id> [--force] [--no-cleanup]`    | Orchestration |
| `orchestrate`   | `/orchestrate <plan-path> [--phase N] [--continue]` | Orchestration |

### principled-github (9 skills)

| Skill             | Command                                            | Category      |
| ----------------- | -------------------------------------------------- | ------------- |
| `github-strategy` | _(background — not user-invocable)_                | Knowledge     |
| `triage`          | `/triage [--limit N] [--label <filter>]`           | Orchestration |
| `ingest-issue`    | `/ingest-issue <number>`                           | Generative    |
| `sync-issues`     | `/sync-issues [<doc-path>] [--all-proposals]`      | Sync          |
| `pr-describe`     | `/pr-describe [<task-id>] [--plan <path>]`         | Generative    |
| `gh-scaffold`     | `/gh-scaffold [--templates] [--workflows] [--all]` | Generative    |
| `gen-codeowners`  | `/gen-codeowners [--modules-dir <path>]`           | Generative    |
| `sync-labels`     | `/sync-labels [--dry-run] [--prune]`               | Sync          |
| `pr-check`        | `/pr-check [<pr-number>] [--strict]`               | Analytical    |

### principled-quality (5 skills)

| Skill              | Command                                         | Category   |
| ------------------ | ----------------------------------------------- | ---------- |
| `quality-strategy` | _(background — not user-invocable)_             | Knowledge  |
| `review-checklist` | `/review-checklist <pr-number> [--plan <path>]` | Generative |
| `review-context`   | `/review-context <pr-number>`                   | Analytical |
| `review-coverage`  | `/review-coverage <pr-number>`                  | Analytical |
| `review-summary`   | `/review-summary <pr-number>`                   | Generative |

Each skill directory is **self-contained**. No cross-skill imports. If a template or script is needed by multiple skills, each maintains its own copy.

## Agents

The principled-implementation plugin defines one agent:

| Agent         | Isolation  | Description                                                    |
| ------------- | ---------- | -------------------------------------------------------------- |
| `impl-worker` | `worktree` | Executes a single task from a DDD plan in an isolated worktree |

The `spawn` skill delegates to `impl-worker` via `context: fork` + `agent: impl-worker` frontmatter. The orchestrator invokes `/spawn` from inline context (no fork) to coordinate multiple sub-agent spawns sequentially.

## Key Conventions

### Template Duplication (principled-docs)

- Canonical templates live in `plugins/principled-docs/skills/scaffold/templates/{core,lib,app}/`.
- Consuming skills (new-proposal, new-plan, new-adr, new-architecture-doc) keep byte-identical copies.
- `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh` verifies copies match canonical. Drift = CI failure.
- When updating a template, update the canonical version first, then propagate to all copies.

### Script Duplication (principled-docs)

- `next-number.sh` is canonical in `plugins/principled-docs/skills/new-proposal/scripts/`, copied to `new-plan` and `new-adr`.
- `validate-structure.sh` is canonical in `plugins/principled-docs/skills/scaffold/scripts/`, copied to `plugins/principled-docs/skills/validate/scripts/`.
- Same drift rules apply — copies must be byte-identical.

### Script/Template Duplication (principled-implementation)

- `task-manifest.sh` is canonical in `plugins/principled-implementation/skills/decompose/scripts/`, copied to `spawn`, `check-impl`, `merge-work`, and `orchestrate`.
- `parse-plan.sh` is canonical in `plugins/principled-implementation/skills/decompose/scripts/`, copied to `orchestrate`.
- `run-checks.sh` is canonical in `plugins/principled-implementation/skills/check-impl/scripts/`, copied to `orchestrate`.
- `claude-task.md` is canonical in `plugins/principled-implementation/skills/spawn/templates/`, copied to `orchestrate`.
- `plugins/principled-implementation/scripts/check-template-drift.sh` verifies all 7 pairs. Drift = CI failure.

### Script Duplication (principled-github)

- `check-gh-cli.sh` is canonical in `plugins/principled-github/skills/sync-issues/scripts/`, copied to `sync-labels`, `pr-check`, `gh-scaffold`, `ingest-issue`, `triage`, and `pr-describe`.
- `plugins/principled-github/scripts/check-template-drift.sh` verifies all 6 pairs. Drift = CI failure.

### Cross-Plugin Script Duplication (principled-quality)

- `check-gh-cli.sh` canonical remains in `plugins/principled-github/skills/sync-issues/scripts/`, copied to `review-checklist`, `review-context`, `review-coverage`, and `review-summary` in principled-quality.
- `plugins/principled-quality/scripts/check-template-drift.sh` verifies all 4 cross-plugin pairs. Drift = CI failure.
- This is the first cross-plugin copy in the marketplace. The drift checker navigates to the sibling plugin via `$REPO_ROOT`.

### Naming Patterns

- Documents: `NNN-short-title.md` (e.g., `001-switch-to-event-sourcing.md`)
- `NNN` is zero-padded to 3 digits, independently sequenced per directory per scope
- Numbers are never reused; gaps are not backfilled

### Frontmatter

All pipeline documents (proposals, plans, decisions) use YAML frontmatter between `---` delimiters. The `status` field drives lifecycle enforcement.

## Documentation Structure

This repo uses its own documentation pipeline at the root level (governing the marketplace):

- `docs/proposals/` — RFCs. RFC-000 is the plugin's own PRD. RFC-002 established the marketplace.
- `docs/plans/` — DDD implementation plans. Plan-000 tracks the plugin build.
- `docs/decisions/` — ADRs (immutable after acceptance).
  - 001: Pure bash frontmatter parsing strategy
  - 002: Claude-mediated template placeholder replacement
  - 003: Module type declaration via CLAUDE.md
  - 004: Node.js dev tooling boundary
  - 005: pre-commit framework for git hooks
  - 006: Structural plugin validation in CI
  - 007: Worktree isolation for task execution
  - 008: Manifest-driven orchestration state
  - 009: Script duplication across implementation skills
  - 010: gh CLI as GitHub interface
  - 011: Documents as source of truth in sync
  - 012: Dual storage for review checklists
- `docs/architecture/` — Living design docs.
  - plugin-system.md, documentation-pipeline.md, enforcement-system.md

## Contributing

See `CONTRIBUTING.md` for the full contributor guide. Key points:

- **Pre-commit hooks** enforce shell and Markdown lint on every commit (`pre-commit install`)
- **CI pipeline** (`.github/workflows/ci.yml`) runs shell lint, Markdown lint, template drift (all four plugins), structure validation, and marketplace/plugin manifest validation on every PR
- **`.claude/` directory** provides project-level Claude Code settings and dev skills (`/lint`, `/test-hooks`, `/propagate-templates`, `/check-ci`)

## Dogfooding

This repo installs all four first-party plugins (via `.claude/settings.json`):

- **principled-docs** — All 9 skills and 3 enforcement hooks are active during development.
- **principled-implementation** — All 6 skills, the `impl-worker` agent, and 1 advisory hook are active during development.
- **principled-github** — All 9 skills and 1 advisory hook are active during development.
- **principled-quality** — All 5 skills and 1 advisory hook are active during development.

See `.claude/CLAUDE.md` for development-specific context.

## Pipeline

Proposals → Decisions → Plans → Implementation.

- **Proposals** are strategic (what/why). Status: `draft → in-review → accepted|rejected|superseded`.
- **Decisions** are the permanent record. Status: `proposed → accepted → deprecated|superseded`. Immutable after acceptance.
- **Plans** are tactical (how, via DDD). Status: `active → complete|abandoned`. Require an accepted proposal (`--from-proposal NNN`).
- **Implementation** is automated execution. `/orchestrate` decomposes a plan, spawns worktree-isolated agents, validates results, and merges back.

## Important Constraints

- **Proposals** with terminal status (`accepted`, `rejected`, `superseded`) must NOT be modified. Enforced by `check-proposal-lifecycle.sh`.
- **ADRs** with status `accepted` must NOT be modified, except the `superseded_by` field. Enforced by `check-adr-immutability.sh`.
- **Plans** require an accepted proposal (`--from-proposal NNN`).
- **Skills and hooks never overlap.** Skills create/modify documents. Hooks enforce rules.
- **Guard scripts default to allow.** They only block when they can positively confirm a violation.
- **Guard exit codes:** `0` = allow, `2` = block.
- **jq is optional.** Hook scripts fall back to `grep` for JSON parsing when `jq` is unavailable.
- **Subagents cannot spawn subagents.** The orchestrator runs inline to coordinate multiple `/spawn` calls sequentially.
- **Worktree agents cannot access main worktree files.** Task details are embedded in the agent prompt via `!` backtick pre-fork commands.

## Enforcement Hooks

### principled-docs

Declared in `plugins/principled-docs/hooks/hooks.json`:

| Hook                     | Event                    | Script                                                                             | Timeout |
| ------------------------ | ------------------------ | ---------------------------------------------------------------------------------- | ------- |
| ADR Immutability Guard   | PreToolUse (Edit\|Write) | `plugins/principled-docs/hooks/scripts/check-adr-immutability.sh`                  | 10s     |
| Proposal Lifecycle Guard | PreToolUse (Edit\|Write) | `plugins/principled-docs/hooks/scripts/check-proposal-lifecycle.sh`                | 10s     |
| Structure Nudge          | PostToolUse (Write)      | `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --on-write` | 15s     |

Both guard scripts depend on `plugins/principled-docs/hooks/scripts/parse-frontmatter.sh` for YAML field extraction.

### principled-implementation

Declared in `plugins/principled-implementation/hooks/hooks.json`:

| Hook                        | Event                    | Script                                                                        | Timeout |
| --------------------------- | ------------------------ | ----------------------------------------------------------------------------- | ------- |
| Manifest Integrity Advisory | PreToolUse (Edit\|Write) | `plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh` | 10s     |

Advisory only — warns when `.impl/manifest.json` is being edited directly but never blocks (always exits 0).

### principled-github

Declared in `plugins/principled-github/hooks/hooks.json`:

| Hook               | Event              | Script                                                           | Timeout |
| ------------------ | ------------------ | ---------------------------------------------------------------- | ------- |
| PR Reference Nudge | PostToolUse (Bash) | `plugins/principled-github/hooks/scripts/check-pr-references.sh` | 10s     |

Advisory only — reminds when `gh pr create` is run without principled document references (always exits 0).

### principled-quality

Declared in `plugins/principled-quality/hooks/hooks.json`:

| Hook                      | Event              | Script                                                               | Timeout |
| ------------------------- | ------------------ | -------------------------------------------------------------------- | ------- |
| Review Checklist Advisory | PostToolUse (Bash) | `plugins/principled-quality/hooks/scripts/check-review-checklist.sh` | 10s     |

Advisory only — reminds when `gh pr review` or `gh pr merge` is run without a review checklist (always exits 0).

## Testing

- **Template drift (docs):** `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh` — exits non-zero if any copy diverges from canonical.
- **Template drift (impl):** `plugins/principled-implementation/scripts/check-template-drift.sh` — exits non-zero if any of 7 pairs diverge.
- **Template drift (github):** `plugins/principled-github/scripts/check-template-drift.sh` — exits non-zero if any of 6 pairs diverge.
- **Template drift (quality):** `plugins/principled-quality/scripts/check-template-drift.sh` — exits non-zero if any of 4 cross-plugin pairs diverge.
- **Structure validation:** `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --module-path <path> [--type <type>] [--strict] [--json]` — checks a module's docs structure.
- **Root validation:** `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --root` — checks repo-level docs structure.
- **Hook testing (docs):** Feed JSON with `tool_input.file_path` to guard scripts via stdin. Exit 0 = allow, exit 2 = block.
- **Hook testing (impl):** Feed JSON with `tool_input.file_path` to `check-manifest-integrity.sh` via stdin. Always exits 0 (advisory).
- **Hook testing (github):** Feed JSON with `tool_input.command` to `check-pr-references.sh` via stdin. Always exits 0 (advisory).
- **Hook testing (quality):** Feed JSON with `tool_input.command` to `check-review-checklist.sh` via stdin. Always exits 0 (advisory).
- **Shell lint:** `shellcheck --shell=bash` and `shfmt -i 2 -bn -sr -d` on all `.sh` files.
- **Markdown lint:** `npx markdownlint-cli2 '**/*.md'` and `npx prettier --check '**/*.md'`.
- **Marketplace validation:** Verify `.claude-plugin/marketplace.json` is valid and all plugin source directories exist.
- **All at once:** `pre-commit run --all-files` or `/check-ci`.

## Dependencies

- **Claude Code v2.1.3+** (skills/commands unification, agent support)
- **Bash** (all plugin scripts are pure bash)
- **Git** (for repository context and worktree management)
- **jq** (optional — scripts fall back to grep-based extraction)
- **gh CLI** (optional — required for principled-github plugin operations)
- **Node.js 18+** (dev tooling only — markdownlint-cli2, prettier)
- **ShellCheck** (dev tooling — shell script static analysis)
- **shfmt** (dev tooling — shell script formatting)
- **pre-commit** (dev tooling — git hook framework)
