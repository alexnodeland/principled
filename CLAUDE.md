# principled — Claude Code Context

## Module Type

core

## What This Is

This repo is the **Principled methodology plugin marketplace** (v0.4.0, pre-1.0). It hosts Claude Code plugins for specification-first development, organized as a curated directory with two tiers: first-party plugins in `plugins/` and community plugins in `external_plugins/`. Eight first-party plugins ship today:

- **principled-docs** (v0.3.1) — Scaffold, author, and enforce module documentation structure for monorepos.
- **principled-implementation** (v0.1.0) — Orchestrate DDD plan execution via worktree-isolated Claude Code agents.
- **principled-github** (v0.1.0) — Integrate the principled workflow with GitHub native features: issues, PRs, templates, actions, CODEOWNERS, and labels.
- **principled-quality** (v0.1.0) — Connect code reviews to the principled documentation pipeline with spec-driven checklists, coverage assessment, and review summaries.
- **principled-release** (v0.1.0) — Generate changelogs from the documentation pipeline, verify release readiness, coordinate version bumps, and govern the release lifecycle.
- **principled-architecture** (v0.1.0) — Map code to architectural decisions, detect drift, audit decision coverage, and keep architecture documents synchronized.
- **principled-tasks** (v0.1.0) — Git-native, graph-linked task tracking backed by an append-only event log — open, close, update, query, audit, and visualize tasks across agent workflows.
- **principled-agent** (v0.1.0) — Persistent agent identity and memory: git-committed knowledge injected at spawn and revised in pull requests.

## Architecture

Eleven layers, top to bottom:

| Layer                   | Location                                                           | Role                                                                                                                 |
| ----------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| **Marketplace**         | `.claude-plugin/marketplace.json`, `plugins/`, `external_plugins/` | Plugin catalog, directory structure, plugin discovery and distribution                                               |
| **Docs: Skills**        | `plugins/principled-docs/skills/` (9 directories)                  | Generative workflows — each skill is a slash command with its own `SKILL.md`, templates, scripts, and reference docs |
| **Docs: Hooks**         | `plugins/principled-docs/hooks/`                                   | Deterministic guardrails — `hooks.json` declares PreToolUse/PostToolUse triggers that run shell scripts              |
| **Implementation: All** | `plugins/principled-implementation/`                               | Skills (7), hooks (5), agents (1) for plan execution via worktree-isolated sub-agents and agent teams                |
| **GitHub: All**         | `plugins/principled-github/`                                       | Skills (9), hooks (1), agents (1) for GitHub integration: issues, PRs, templates, CODEOWNERS, labels                 |
| **Quality: All**        | `plugins/principled-quality/`                                      | Skills (5), hooks (1), agents (1) for spec-driven code review: checklists, context, coverage, summaries              |
| **Release: All**        | `plugins/principled-release/`                                      | Skills (6), hooks (1) for release lifecycle: changelogs, readiness, version bumps, tagging                           |
| **Architecture: All**   | `plugins/principled-architecture/`                                 | Skills (6), hooks (1), agents (1) for architecture governance: mapping, drift detection, auditing, sync              |
| **Tasks: All**          | `plugins/principled-tasks/`                                        | Skills (7), 1 hook, and `lib/task-db.sh` for the event-log task graph: open, close, update, query, audit, visualize  |
| **Agent: All**          | `plugins/principled-agent/`                                        | Skills (4), 2 hooks, and `lib/agent-memory.sh` for `.agents/` identity, memory injection, and integrity              |
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

### principled-implementation (7 skills)

| Skill           | Command                                                | Category      |
| --------------- | ------------------------------------------------------ | ------------- |
| `impl-strategy` | _(background — not user-invocable)_                    | Knowledge     |
| `decompose`     | `/decompose <plan-path>`                               | Analytical    |
| `spawn`         | `/spawn <task-id>`                                     | Orchestration |
| `check-impl`    | `/check-impl [--task <id>] [--all]`                    | Analytical    |
| `merge-work`    | `/merge-work <task-id> [--force] [--no-cleanup]`       | Orchestration |
| `orchestrate`   | `/orchestrate <plan-path> [--phase N] [--continue]`    | Orchestration |
| `resume`        | `/resume [<plan-path>] [--from-checkpoint] [--replan]` | Orchestration |

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

### principled-release (6 skills)

| Skill              | Command                                                        | Category      |
| ------------------ | -------------------------------------------------------------- | ------------- |
| `release-strategy` | _(background — not user-invocable)_                            | Knowledge     |
| `changelog`        | `/changelog [--since <tag>] [--module <path>]`                 | Generative    |
| `release-ready`    | `/release-ready [--tag <version>] [--strict]`                  | Analytical    |
| `version-bump`     | `/version-bump [--module <path>] [--type major\|minor\|patch]` | Generative    |
| `release-plan`     | `/release-plan [--since <tag>]`                                | Generative    |
| `tag-release`      | `/tag-release <version> [--dry-run]`                           | Orchestration |

### principled-architecture (6 skills)

| Skill           | Command                                         | Category   |
| --------------- | ----------------------------------------------- | ---------- |
| `arch-strategy` | _(background — not user-invocable)_             | Knowledge  |
| `arch-map`      | `/arch-map [--module <path>] [--output <path>]` | Analytical |
| `arch-drift`    | `/arch-drift [--module <path>] [--strict]`      | Analytical |
| `arch-audit`    | `/arch-audit [--module <path>]`                 | Analytical |
| `arch-sync`     | `/arch-sync [--doc <path>] [--all]`             | Generative |
| `arch-query`    | `/arch-query "<question>"`                      | Analytical |

### principled-tasks (7 skills)

| Skill           | Command                                                     | Category   |
| --------------- | ----------------------------------------------------------- | ---------- |
| `task-strategy` | _(background — not user-invocable)_                         | Knowledge  |
| `task-open`     | `/task-open --title <title> [--plan <id>] [--blocks <id>]`  | Generative |
| `task-close`    | `/task-close --id <id> [--notes <text>] [--status done]`    | Generative |
| `task-update`   | `/task-update --id <id> --status <status> [--notes <text>]` | Generative |
| `task-query`    | `/task-query [--status <status>] [--agent <name>]`          | Analytical |
| `task-audit`    | `/task-audit [--all]`                                       | Analytical |
| `task-graph`    | `/task-graph [--format dot\|text] [--status <status>]`      | Analytical |

### principled-agent (7 skills)

| Skill            | Command                                             | Category   |
| ---------------- | --------------------------------------------------- | ---------- |
| `agent-strategy` | _(background — not user-invocable)_                 | Knowledge  |
| `agent-init`     | `/agent-init [--commit]`                            | Generative |
| `agent-memory`   | `/agent-memory [<id>] [--list] [--learn] [--check]` | Analytical |
| `agent-retro`    | `/agent-retro [<plan-path>] [--promote]`            | Generative |

Skills own their own prompts and templates. Code shared by more than one skill in a
plugin lives in that plugin's `lib/` and is referenced as `${CLAUDE_PLUGIN_ROOT}/lib/...`
— one copy, no drift checker (ADR-018). The migration off ADR-009's
copy-with-drift-detection scheme is complete: no script under `skills/*/scripts/` is
referenced by more than one SKILL.md in its plugin. Scripts that remain in a skill
directory are used by that skill alone, which is where they belong.

## Agents

Six agents across four plugins:

| Agent              | Plugin                    | Isolation  | Model   | Background | Description                                                    |
| ------------------ | ------------------------- | ---------- | ------- | ---------- | -------------------------------------------------------------- |
| `impl-worker`      | principled-implementation | `worktree` | inherit | no         | Executes a single task from a DDD plan in an isolated worktree |
| `module-auditor`   | principled-docs           | —          | haiku   | yes        | Validates documentation structure for batches of modules       |
| `decision-auditor` | principled-docs           | —          | haiku   | yes        | Audits ADR consistency: supersession chains, orphaned refs     |
| `issue-ingester`   | principled-github         | —          | inherit | no         | Processes a single GitHub issue through the triage pipeline    |
| `pr-reviewer`      | principled-quality        | —          | inherit | yes        | Comprehensive 4-dimension PR review analysis                   |
| `boundary-checker` | principled-architecture   | —          | haiku   | yes        | Scans modules for architectural boundary violations            |

The `spawn` skill delegates to `impl-worker` via `context: fork` + `agent: impl-worker` frontmatter. The orchestrator invokes `/spawn` from inline context (no fork) to coordinate multiple sub-agent spawns — sequentially by default, or in parallel via agent teams when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set.

## Key Conventions

### Shared Code: `lib/` (ADR-018)

Code used by more than one skill in a plugin lives in that plugin's `lib/` and is
referenced as `${CLAUDE_PLUGIN_ROOT}/lib/<name>`. One copy, no propagation step, no
drift checker — drift is impossible rather than detected.

| Plugin                    | `lib/` contents                                                                               |
| ------------------------- | --------------------------------------------------------------------------------------------- |
| principled-docs           | `validate-structure.sh`, `next-number.sh`                                                     |
| principled-implementation | `task-manifest.sh`, `parse-plan.sh`, `run-checks.sh`, `templates/claude-task.md`              |
| principled-github         | `check-gh-cli.sh`                                                                             |
| principled-quality        | `check-gh-cli.sh` (vendored)                                                                  |
| principled-release        | `check-gh-cli.sh` (vendored), `collect-changes.sh`, `check-readiness.sh`, `detect-modules.sh` |
| principled-architecture   | `scan-modules.sh`                                                                             |
| principled-tasks          | `task-db.sh`                                                                                  |
| principled-agent          | `agent-memory.sh`, `agent-governance.sh`, `check-gh-cli.sh` (vendored)                        |

`scripts/check-skill-references.sh` verifies every referenced path resolves **and**
that it uses `${CLAUDE_PLUGIN_ROOT}`. Both halves matter. The old drift checkers
compared copies that existed and never noticed a referenced file that was missing; and
a bare relative path like `bash scripts/foo.sh` only resolves when the working
directory happens to be the skill directory, which nothing guarantees at runtime.
Cross-skill `../sibling/` paths fail the check too — that is what `lib/` replaces.

### What is still duplicated, and why

Two cases remain, both deliberate:

- **Scaffolding templates (principled-docs).** Canonical in
  `skills/scaffold/templates/{core,lib,app}/`; each generative skill ships the
  template it writes. Verified by
  `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh`.
- **`check-gh-cli.sh` across four plugins.** principled-github, principled-quality,
  principled-release and principled-agent install independently, and
  `${CLAUDE_PLUGIN_ROOT}` resolves to one plugin, so a genuinely shared script must
  exist four times. Fifteen copies became four. Verified by
  `scripts/check-cross-plugin-drift.sh`.

When updating either, edit the canonical version first, then propagate.

### Canonical Source Convention

New shared code goes in the owning plugin's `lib/` — no canonical-plus-copies
declaration needed. The convention only applies to the two remaining duplicated
cases above: scaffolding templates (canonical in `skills/scaffold/templates/`) and
`check-gh-cli.sh` (canonical in `principled-github/lib/`).

### Naming Patterns

- Documents: `NNN-short-title.md` (e.g., `001-switch-to-event-sourcing.md`)
- `NNN` is zero-padded to 3 digits, independently sequenced per directory per scope
- Numbers are never reused; gaps are not backfilled

### Frontmatter

All pipeline documents (proposals, plans, decisions) use YAML frontmatter between `---` delimiters. The `status` field drives lifecycle enforcement.

## Documentation Structure

This repo uses its own documentation pipeline at the root level (governing the marketplace):

- `docs/proposals/` — RFCs. RFC-000 is the plugin's own PRD. RFC-002 established the marketplace.
  - RFC-010 (multi-agent orchestration) is `superseded`: it covered seven systems in
    one document and was split into RFC-011 (agent memory and resumability), RFC-012
    (GitHub-native collaboration and autonomous execution), and RFC-013 (self-improvement
    loop). RFC-010 is retained as the strategic vision.
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
  - 013: Pipeline-based changelog generation
  - 014: Heuristic architecture governance
  - 015: Event-driven lifecycle hooks for pipeline enforcement
  - 016: Agent teams for parallel plan execution
  - 017: Event log as record, SQLite as cache (principled-tasks storage)
  - 018: Shared plugin `lib/` over copy-with-drift-detection (supersedes 009)
  - 019: Bats for shell testing
  - 020: Agent memory as a frontmatter document (not an event log)
  - 021: Manifest checkpoint and criterion-level acceptance tracking
  - 022: Agent governance constraints for autonomous execution
  - 023: GitHub Actions as the first dispatch backend, shipped opt-in
- `docs/architecture/` — Living design docs.
  - plugin-system.md, documentation-pipeline.md, enforcement-system.md,
    architecture-governance.md, release-system.md, agent-memory.md,
    agent-collaboration.md

## Versioning

The marketplace and its plugins are pre-1.0. Nothing here promises a stable interface
yet: skill flags, manifest schemas, and storage formats can still change without a
major bump.

- **Marketplace version** tracks the catalog itself — plugins added or removed.
- **Plugin versions** are independent and follow semver within their own surface:
  skill names and flags, hook contracts, script CLIs, and on-disk formats.

The marketplace previously read `1.0.0` while every plugin sat at `0.1.0`. That was
not a defensible claim: the first automated tests landed in July 2026 and immediately
surfaced correctness bugs in shipped skills, and two of the governing ADRs (017, 018)
are still `proposed`. `0.4.0` reflects a catalog of seven plugins that works and is
still moving.

Reach 1.0 per plugin when its interface has stopped changing, it has test coverage,
and its governing ADRs are `accepted`.

## Contributing

See `CONTRIBUTING.md` for the full contributor guide. Key points:

- **Pre-commit hooks** enforce shell and Markdown lint on every commit (`pre-commit install`)
- **CI pipeline** (`.github/workflows/ci.yml`) runs shell lint, Markdown lint, template drift (all six plugins), structure validation, and marketplace/plugin manifest validation on every PR
- **`.claude/` directory** provides project-level Claude Code settings and dev skills (`/lint`, `/test-hooks`, `/propagate-templates`, `/check-ci`)

## Dogfooding

This repo installs all eight first-party plugins (via `.claude/settings.json`):

- **principled-docs** — All 9 skills, 8 enforcement hooks, and 2 agents are active during development.
- **principled-implementation** — All 7 skills (including `/orchestrate --mode`), the `impl-worker` agent, and 5 hooks (1 advisory + 4 lifecycle) are active during development. Agent teams available when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
- **principled-github** — All 9 skills, 1 advisory hook, and the `issue-ingester` agent are active during development.
- **principled-quality** — All 5 skills, 1 advisory hook, and the `pr-reviewer` agent are active during development.
- **principled-release** — All 6 skills and 1 advisory hook are active during development.
- **principled-architecture** — All 6 skills, 1 advisory hook, and the `boundary-checker` agent are active during development.
- **principled-tasks** — All 7 skills and 1 advisory hook are active during development. Shared code lives in `lib/task-db.sh` (ADR-018).
- **principled-agent** — All 7 skills and 3 hooks are active during development. Shared code lives in `lib/agent-memory.sh` and `lib/agent-governance.sh` (ADR-018). The dispatch workflow is **not** installed: it ships as an opt-in template (ADR-023).

See `.claude/CLAUDE.md` for development-specific context.

## Pipeline

Proposals → Plans → Implementation. Decisions (ADRs) at any point.

- **Proposals** are strategic (what/why). Status: `draft → in-review → accepted|rejected|superseded`.
- **Plans** are tactical (how, via DDD). Status: `active → complete|abandoned`. Require an accepted proposal (`--from-proposal NNN`).
- **Decisions** are the permanent record of significant choices, created at any point during the pipeline. Status: `proposed → accepted → deprecated|superseded`. Immutable after acceptance.
- **Implementation** is automated execution. `/orchestrate` decomposes a plan, spawns worktree-isolated agents, validates results, and merges back.

## Important Constraints

- **Proposals** with terminal status (`accepted`, `rejected`, `superseded`) must NOT be modified. Enforced by `check-proposal-lifecycle.sh`.
- **ADRs** with status `accepted` must NOT be modified, except to record supersession: the `superseded_by` field, the `status` transition to `superseded`, and a pointer in the Status section. The reasoning body stays as written. Enforced by `check-adr-immutability.sh`; the chain is validated by `scripts/pipeline-audit.sh`.
- **Plans** require an accepted proposal (`--from-proposal NNN`). Enforced by `check-plan-proposal-link.sh`.
- **Pipeline documents** must have valid frontmatter. Enforced by `check-required-frontmatter.sh`.
- **Document numbers** must be unique within their directory. Enforced by `check-doc-numbering.sh`.
- **Skills and hooks never overlap.** Skills create/modify documents. Hooks enforce rules.
- **Guard scripts default to allow.** They only block when they can positively confirm a violation.
- **Guard exit codes:** `0` = allow, `2` = block.
- **jq is optional.** Hook scripts fall back to `grep` for JSON parsing when `jq` is unavailable.
- **Subagents cannot spawn subagents.** The orchestrator runs inline to coordinate multiple `/spawn` calls (sequentially by default, or in parallel via agent teams).
- **Worktree agents cannot access main worktree files.** Task details are embedded in the agent prompt via `!` backtick pre-fork commands.

## Enforcement Hooks

### principled-docs

Declared in `plugins/principled-docs/hooks/hooks.json`:

| Hook                       | Event                    | Script                                                                | Timeout |
| -------------------------- | ------------------------ | --------------------------------------------------------------------- | ------- |
| ADR Immutability Guard     | PreToolUse (Edit\|Write) | `plugins/principled-docs/hooks/scripts/check-adr-immutability.sh`     | 10s     |
| Proposal Lifecycle Guard   | PreToolUse (Edit\|Write) | `plugins/principled-docs/hooks/scripts/check-proposal-lifecycle.sh`   | 10s     |
| Plan-Proposal Link Guard   | PreToolUse (Write)       | `plugins/principled-docs/hooks/scripts/check-plan-proposal-link.sh`   | 10s     |
| Required Frontmatter Guard | PreToolUse (Edit\|Write) | `plugins/principled-docs/hooks/scripts/check-required-frontmatter.sh` | 10s     |
| Document Numbering Guard   | PreToolUse (Write)       | `plugins/principled-docs/hooks/scripts/check-doc-numbering.sh`        | 10s     |
| Structure Nudge            | PostToolUse (Write)      | `plugins/principled-docs/lib/validate-structure.sh --on-write`        | 15s     |
| Async Drift Check          | PostToolUse (Write)      | `plugins/principled-docs/hooks/scripts/async-drift-check.sh`          | 30s     |
| ADR Supersession Validator | PostToolUse (Write)      | `plugins/principled-docs/hooks/scripts/check-adr-supersession.sh`     | 10s     |

Guard scripts depend on `plugins/principled-docs/hooks/scripts/parse-frontmatter.sh` for YAML field extraction.

### principled-implementation

Declared in `plugins/principled-implementation/hooks/hooks.json`:

| Hook                        | Event                    | Script                                                                          | Timeout |
| --------------------------- | ------------------------ | ------------------------------------------------------------------------------- | ------- |
| Manifest Integrity Advisory | PreToolUse (Edit\|Write) | `plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh`   | 10s     |
| Worktree Setup              | WorktreeCreate           | `plugins/principled-implementation/hooks/scripts/setup-impl-worktree.sh`        | 10s     |
| Worktree Cleanup            | WorktreeRemove           | `plugins/principled-implementation/hooks/scripts/cleanup-impl-worktree.sh`      | 10s     |
| Worker Completion Validator | SubagentStop             | `plugins/principled-implementation/hooks/scripts/validate-worker-completion.sh` | 10s     |
| Task Completion Gate        | TaskCompleted            | `plugins/principled-implementation/hooks/scripts/gate-task-completion.sh`       | 10s     |

- Manifest Integrity Advisory: warns when `.impl/manifest.json` is edited directly (always exits 0).
- Worktree Setup/Cleanup: initialize and archive worktree state (always exit 0).
- Worker Completion Validator: blocks impl-worker completion when tasks are orphaned in `in_progress` (exit 2).
- Task Completion Gate: blocks task completion when quality checks haven't passed; only active when agent teams are enabled (exit 2).

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

### principled-release

Declared in `plugins/principled-release/hooks/hooks.json`:

| Hook                       | Event              | Script                                                                | Timeout |
| -------------------------- | ------------------ | --------------------------------------------------------------------- | ------- |
| Release Readiness Advisory | PostToolUse (Bash) | `plugins/principled-release/hooks/scripts/check-release-readiness.sh` | 10s     |

Advisory only — reminds when `git tag` is run without prior `/release-ready` check (always exits 0).

### principled-architecture

Declared in `plugins/principled-architecture/hooks/hooks.json`:

| Hook                        | Event               | Script                                                                      | Timeout |
| --------------------------- | ------------------- | --------------------------------------------------------------------------- | ------- |
| Boundary Violation Advisory | PostToolUse (Write) | `plugins/principled-architecture/hooks/scripts/check-boundary-violation.sh` | 10s     |

Advisory only — warns when a written source file contains imports violating module dependency direction rules (always exits 0).

### principled-tasks

Declared in `plugins/principled-tasks/hooks/hooks.json`:

| Hook                  | Event                    | Script                                                         | Timeout |
| --------------------- | ------------------------ | -------------------------------------------------------------- | ------- |
| DB Integrity Advisory | PreToolUse (Edit\|Write) | `plugins/principled-tasks/hooks/scripts/check-db-integrity.sh` | 10s     |

Advisory only — warns on direct edits to `.principled/tasks.jsonl` (the record) or
`.impl/tasks.db` (the derived cache). Always exits 0.

### principled-agent

Declared in `plugins/principled-agent/hooks/hooks.json`:

| Hook                      | Event                     | Script                                                             | Timeout |
| ------------------------- | ------------------------- | ------------------------------------------------------------------ | ------- |
| Agent Memory Injection    | SubagentStart             | `plugins/principled-agent/hooks/scripts/inject-agent-memory.sh`    | 10s     |
| Memory Integrity Advisory | PostToolUse (Edit\|Write) | `plugins/principled-agent/hooks/scripts/check-memory-integrity.sh` | 10s     |
| Governance Advisory       | PostToolUse (Bash)        | `plugins/principled-agent/hooks/scripts/check-agent-governance.sh` | 10s     |

- Agent Memory Injection: emits global and per-agent memory to stderr at spawn. Only
  agents the registry marks `memory: true` receive anything. Never truncates, always
  exits 0 — a memory problem must not stop an agent running.
- Memory Integrity Advisory: validates frontmatter and reports against the 8 KB / 16 KB
  context budget on writes under `.agents/`. Always exits 0.
- Governance Advisory: warns on non-draft agent PRs, self-approval, merge, and
  ready-for-review promotion, and surfaces an engaged halt switch on dispatch commands.
  Always exits 0 — PostToolUse fires after the command has run, so the authoritative
  gate is `agent-governance.sh --can-dispatch` before a run starts (ADR-022).

## Testing

- **Template drift (docs):** `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh` — exits non-zero if any copy diverges from canonical.
- **Cross-plugin drift:** `scripts/check-cross-plugin-drift.sh` — exits non-zero if a vendored `check-gh-cli.sh` diverges from canonical.
- **Pipeline audit:** `scripts/pipeline-audit.sh` — reconciles declared document state against the repository (numbering, plan/proposal links, statuses, supersession chains).
- **Reference integrity:** `scripts/check-skill-references.sh` — exits non-zero if any script or template referenced by a SKILL.md or hooks.json does not exist.
- **Tests:** `npx bats tests/` — bats suite covering the task graph library, agent memory, agent governance, the manifest checkpoint and criteria, and every hook. Also run on macOS bash 3.2 in CI.
- **Structure validation:** `plugins/principled-docs/lib/validate-structure.sh --module-path <path> [--type <type>] [--strict] [--json]` — checks a module's docs structure.
- **Root validation:** `plugins/principled-docs/lib/validate-structure.sh --root` — checks repo-level docs structure.
- **Hook testing (docs):** Feed JSON with `tool_input.file_path` to guard scripts via stdin. Exit 0 = allow, exit 2 = block.
- **Hook testing (impl):** Feed JSON with `tool_input.file_path` to `check-manifest-integrity.sh` via stdin. Always exits 0 (advisory).
- **Hook testing (github):** Feed JSON with `tool_input.command` to `check-pr-references.sh` via stdin. Always exits 0 (advisory).
- **Hook testing (quality):** Feed JSON with `tool_input.command` to `check-review-checklist.sh` via stdin. Always exits 0 (advisory).
- **Hook testing (release):** Feed JSON with `tool_input.command` to `check-release-readiness.sh` via stdin. Always exits 0 (advisory).
- **Hook testing (architecture):** Feed JSON with `tool_input.file_path` to `check-boundary-violation.sh` via stdin. Always exits 0 (advisory).
- **Hook testing (tasks):** Feed JSON with `tool_input.file_path` to `check-db-integrity.sh` via stdin. Always exits 0 (advisory).
- **Hook testing (agent):** Feed JSON with an agent id to `inject-agent-memory.sh`, or `tool_input.file_path` to `check-memory-integrity.sh`, via stdin. Both always exit 0.
- **Hook testing (all):** `npx bats tests/hooks.bats` — 57 tests covering allow, block, malformed input, and the no-jq fallback path for every hook.
- **Shell lint:** `shellcheck --shell=bash` and `shfmt -i 2 -bn -sr -d` on all `.sh` files.
- **Markdown lint:** `npx markdownlint-cli2 '**/*.md'` and `npx prettier --check '**/*.md'`.
- **Marketplace validation:** Verify `.claude-plugin/marketplace.json` is valid and all plugin source directories exist.
- **All at once:** `pre-commit run --all-files` or `/check-ci`.

## Dependencies

- **Claude Code v2.1.3+** (skills/commands unification, agent support)
- **Bash 3.2+** (all plugin scripts are pure bash and must run on stock macOS bash — no `declare -A`, `local -n`, `mapfile`, or `${var,,}`)
- **Git** (for repository context and worktree management)
- **jq** (optional — scripts fall back to grep-based extraction)
- **gh CLI** (optional — required for principled-github plugin operations)
- **Node.js 18+** (dev tooling only — markdownlint-cli2, prettier)
- **ShellCheck** (dev tooling — shell script static analysis)
- **shfmt** (dev tooling — shell script formatting)
- **pre-commit** (dev tooling — git hook framework)
