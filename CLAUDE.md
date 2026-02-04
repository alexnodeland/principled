# principled-docs — Claude Code Context

## Module Type

core

## What This Is

This repo is the **Principled methodology plugin marketplace** (v1.0.0). It hosts Claude Code plugins for specification-first development, organized as a curated directory with two tiers: first-party plugins in `plugins/` and community plugins in `external_plugins/`. The flagship plugin is `principled-docs` (v0.3.1), which scaffolds, authors, and enforces module documentation structure for monorepos.

## Architecture

Four layers, top to bottom:

| Layer              | Location                                                           | Role                                                                                                                 |
| ------------------ | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| **Marketplace**    | `.claude-plugin/marketplace.json`, `plugins/`, `external_plugins/` | Plugin catalog, directory structure, plugin discovery and distribution                                               |
| **Plugin: Skills** | `plugins/principled-docs/skills/` (9 directories)                  | Generative workflows — each skill is a slash command with its own `SKILL.md`, templates, scripts, and reference docs |
| **Plugin: Hooks**  | `plugins/principled-docs/hooks/`                                   | Deterministic guardrails — `hooks.json` declares PreToolUse/PostToolUse triggers that run shell scripts              |
| **Dev DX**         | `.claude/`, config files, `.github/workflows/`                     | Project-level Claude Code settings, dev skills, CI pipeline, linting config                                          |

## Skills

The principled-docs plugin provides 9 skills:

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

Each skill directory is **self-contained**. No cross-skill imports. If a template or script is needed by multiple skills, each maintains its own copy.

## Key Conventions

### Template Duplication

- Canonical templates live in `plugins/principled-docs/skills/scaffold/templates/{core,lib,app}/`.
- Consuming skills (new-proposal, new-plan, new-adr, new-architecture-doc) keep byte-identical copies.
- `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh` verifies copies match canonical. Drift = CI failure.
- When updating a template, update the canonical version first, then propagate to all copies.

### Script Duplication

- `next-number.sh` is canonical in `plugins/principled-docs/skills/new-proposal/scripts/`, copied to `new-plan` and `new-adr`.
- `validate-structure.sh` is canonical in `plugins/principled-docs/skills/scaffold/scripts/`, copied to `plugins/principled-docs/skills/validate/scripts/`.
- Same drift rules apply — copies must be byte-identical.

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
- `docs/architecture/` — Living design docs.
  - plugin-system.md, documentation-pipeline.md, enforcement-system.md

## Contributing

See `CONTRIBUTING.md` for the full contributor guide. Key points:

- **Pre-commit hooks** enforce shell and Markdown lint on every commit (`pre-commit install`)
- **CI pipeline** (`.github/workflows/ci.yml`) runs shell lint, Markdown lint, template drift, structure validation, and marketplace/plugin manifest validation on every PR
- **`.claude/` directory** provides project-level Claude Code settings and dev skills (`/lint`, `/test-hooks`, `/propagate-templates`, `/check-ci`)

## Dogfooding

This repo installs the principled-docs plugin from `plugins/principled-docs/` (via `.claude/settings.json`). All 9 skills and enforcement hooks are active during development. See `.claude/CLAUDE.md` for development-specific context.

## Pipeline

Proposals → Plans → Decisions.

- **Proposals** are strategic (what/why). Status: `draft → in-review → accepted|rejected|superseded`.
- **Plans** are tactical (how, via DDD). Status: `active → complete|abandoned`. Require an accepted proposal.
- **Decisions** are the permanent record. Status: `proposed → accepted → deprecated|superseded`. Immutable after acceptance.

## Important Constraints

- **Proposals** with terminal status (`accepted`, `rejected`, `superseded`) must NOT be modified. Enforced by `check-proposal-lifecycle.sh`.
- **ADRs** with status `accepted` must NOT be modified, except the `superseded_by` field. Enforced by `check-adr-immutability.sh`.
- **Plans** require an accepted proposal (`--from-proposal NNN`).
- **Skills and hooks never overlap.** Skills create/modify documents. Hooks enforce rules.
- **Guard scripts default to allow.** They only block when they can positively confirm a violation.
- **Guard exit codes:** `0` = allow, `2` = block.
- **jq is optional.** Hook scripts fall back to `grep` for JSON parsing when `jq` is unavailable.

## Enforcement Hooks

Declared in `plugins/principled-docs/hooks/hooks.json`:

| Hook                     | Event                    | Script                                                                             | Timeout |
| ------------------------ | ------------------------ | ---------------------------------------------------------------------------------- | ------- |
| ADR Immutability Guard   | PreToolUse (Edit\|Write) | `plugins/principled-docs/hooks/scripts/check-adr-immutability.sh`                  | 10s     |
| Proposal Lifecycle Guard | PreToolUse (Edit\|Write) | `plugins/principled-docs/hooks/scripts/check-proposal-lifecycle.sh`                | 10s     |
| Structure Nudge          | PostToolUse (Write)      | `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --on-write` | 15s     |

Both guard scripts depend on `plugins/principled-docs/hooks/scripts/parse-frontmatter.sh` for YAML field extraction.

## Testing

- **Template drift:** `plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh` — exits non-zero if any copy diverges from canonical.
- **Structure validation:** `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --module-path <path> [--type <type>] [--strict] [--json]` — checks a module's docs structure.
- **Root validation:** `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --root` — checks repo-level docs structure.
- **Hook testing:** Feed JSON with `tool_input.file_path` to guard scripts via stdin. Exit 0 = allow, exit 2 = block.
- **Shell lint:** `shellcheck --shell=bash` and `shfmt -i 2 -bn -sr -d` on all `.sh` files.
- **Markdown lint:** `npx markdownlint-cli2 '**/*.md'` and `npx prettier --check '**/*.md'`.
- **Marketplace validation:** Verify `.claude-plugin/marketplace.json` is valid and all plugin source directories exist.
- **All at once:** `pre-commit run --all-files` or `/check-ci`.

## Dependencies

- **Claude Code v2.1.3+** (skills/commands unification)
- **Bash** (all plugin scripts are pure bash)
- **Git** (for repository context)
- **jq** (optional — scripts fall back to grep-based extraction)
- **Node.js 18+** (dev tooling only — markdownlint-cli2, prettier)
- **ShellCheck** (dev tooling — shell script static analysis)
- **shfmt** (dev tooling — shell script formatting)
- **pre-commit** (dev tooling — git hook framework)
