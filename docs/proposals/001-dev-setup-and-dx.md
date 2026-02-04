---
title: "Developer Setup and DX Infrastructure"
number: 001
status: draft
author: Alex
created: 2026-02-04
updated: 2026-02-04
supersedes: null
superseded_by: null
---

# RFC-001: Developer Setup and DX Infrastructure

## Audience

- Plugin contributors (current and future)
- Maintainers responsible for code quality and CI
- Claude Code users who install or fork this plugin

## Context

principled-docs is a working Claude Code plugin (v0.3.1) with a well-defined architecture, skill system, and enforcement hooks. However, the repository currently lacks standard open-source project infrastructure:

1. **No contribution guide.** New contributors have no onboarding path — conventions, branching strategy, commit message format, and PR expectations are undocumented.
2. **No license file.** The repo has no explicit license, which creates legal ambiguity for adoption and contribution.
3. **No linting or formatting standards.** Shell scripts (the entire codebase) have no automated style enforcement. Inconsistencies can creep in across 9 skill directories, hook scripts, and utility scripts. Markdown files — the primary output artifact of this plugin — also have no lint or format enforcement.
4. **No dogfooding.** principled-docs is a Claude Code plugin for enforcing documentation structure, yet the repo does not install itself as a plugin. We should eat our own cooking.
5. **No pre-commit hooks for code quality.** The existing hooks system enforces *document* integrity (ADR immutability, proposal lifecycle), but nothing enforces *code* quality on commit.
6. **No CI pipeline.** Template drift checks and structure validation exist as scripts but are not wired into a PR-gated pipeline.
7. **No `.claude/` directory.** The repo lacks Claude Code local configuration (settings, skills, hooks, commands) that would improve the development experience for contributors using Claude Code.

These gaps increase friction for contributors and risk inconsistent code quality as the plugin grows.

## Proposal

Add developer setup and DX infrastructure in six areas:

### 1. CONTRIBUTING.md

Create a root-level `CONTRIBUTING.md` covering:

- **Getting started** — clone, prerequisites (Bash 4+, Git, optional jq), directory orientation
- **Development workflow** — branching strategy, commit message conventions, PR process
- **Plugin architecture overview** — pointer to `CLAUDE.md` and `docs/architecture/` for deeper context
- **Skill development** — how to add or modify a skill (directory structure, SKILL.md, templates, scripts)
- **Hook development** — how to add or modify enforcement hooks (hooks.json schema, script conventions, exit codes)
- **Template management** — canonical vs. copy, drift checking, propagation workflow
- **Testing** — how to run validation scripts, hook tests, and drift checks locally
- **Code style** — shell script conventions (see linting section below)

### 2. MIT License

Add a root-level `LICENSE` file with the MIT license. MIT is appropriate because:

- The plugin is a developer tool with no proprietary logic
- MIT is maximally permissive and widely understood
- It allows adoption in both open-source and commercial monorepos without license compatibility concerns

### 3. Linting, Formatting, and Git Hooks

#### Shell: ShellCheck + shfmt

All code in this repo is pure Bash. The standard toolchain for Bash quality is:

- **[ShellCheck](https://www.shellcheck.net/)** — static analysis for shell scripts. Catches common bugs, portability issues, and bad practices.
- **[shfmt](https://github.com/mvdan/sh)** — formatter for shell scripts. Enforces consistent indentation, spacing, and style.

#### Markdown: markdownlint + Prettier

Markdown is the primary output artifact of this plugin — every template, proposal, plan, ADR, and architecture doc is Markdown. Enforcing consistent Markdown style is just as important as enforcing shell script quality.

- **[markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2)** — linter for Markdown files. Catches inconsistent heading levels, trailing whitespace, line length issues, and structural problems.
- **[Prettier](https://prettier.io/)** — opinionated formatter with first-class Markdown support. Normalizes list indentation, table alignment, and wrapping.

Configuration:

- `.markdownlint.jsonc` at repo root — markdownlint rules (e.g., disable line-length for long tables, allow HTML in Mermaid blocks)
- `.prettierrc` at repo root — Prettier configuration scoped to Markdown (prose wrap, tab width)
- `.prettierignore` — exclude generated files or vendored content if needed

#### General Configuration

- `.shellcheckrc` at repo root — project-wide ShellCheck configuration (shell directive, any disabled checks)
- `.editorconfig` at repo root — editor-agnostic formatting defaults (indent style/size, end-of-line, trailing whitespace)

#### Pre-commit Hook

Add a Git pre-commit hook using a lightweight framework:

- **Option A: [pre-commit](https://pre-commit.com/)** — `.pre-commit-config.yaml` declaring ShellCheck and shfmt hooks. Mature ecosystem, language-agnostic.
- **Option B: Raw Git hook** — `scripts/pre-commit.sh` installed via a setup script. Zero external dependencies beyond ShellCheck/shfmt themselves.

**Recommendation:** Option A (pre-commit framework). It handles hook installation, version pinning, and caching. Contributors run `pre-commit install` once. The config file also serves as documentation of what checks run.

The pre-commit hook should run:

1. `shfmt --diff` — fail if any staged `.sh` file is not formatted
2. `shellcheck` — fail if any staged `.sh` file has lint errors
3. `markdownlint-cli2` — fail if any staged `.md` file has lint errors
4. `prettier --check` — fail if any staged `.md` file is not formatted
5. Existing template drift check — `skills/scaffold/scripts/check-template-drift.sh`

#### Shell Formatting Standards

- **Indent:** 2 spaces (consistent with existing scripts)
- **Binary operators:** at the beginning of the next line
- **Redirect operators:** followed by a space
- **Shell dialect:** `bash` (not `sh` or `posix`)

#### Markdown Formatting Standards

- **Prose wrap:** preserve (don't rewrap existing lines; let authors choose line breaks)
- **List indent:** 2 spaces
- **Emphasis marker:** `*` (asterisks, not underscores)
- **Heading style:** ATX (`#` prefixed, not underline)
- **Fenced code blocks:** backticks (not tildes)
- **YAML frontmatter:** preserved as-is (Prettier handles this natively)

### 4. CI Pipeline

Add a GitHub Actions workflow (`.github/workflows/ci.yml`) that runs on every PR and push to main:

```yaml
jobs:
  lint-shell:
    # ShellCheck all .sh files
    # shfmt --diff all .sh files

  lint-markdown:
    # markdownlint-cli2 all .md files
    # prettier --check all .md files

  validate:
    # Template drift check (check-template-drift.sh)
    # Full root structure validation (validate-structure.sh --root)
    # Hook script smoke tests (feed known inputs, assert exit codes)
```

This formalizes the checks that already exist as scripts into an automated gate, and adds Markdown quality enforcement alongside shell script checks.

### 5. `.claude/` Directory Setup

Create a `.claude/` directory with project-level Claude Code configuration to give contributors a batteries-included development experience:

#### `settings.json`

- **Permissions** — pre-approve common tools (Bash, Read, Edit, Write, Glob, Grep) to reduce approval friction during development
- **Environment context** — set `CLAUDE_PLUGIN_ROOT` so hook scripts resolve correctly during development

#### `commands/`

Custom slash commands (as `.md` prompt files) for common developer workflows in this repo. Each file in `.claude/commands/` becomes a user-invocable `/project:<name>` command — the same mechanism as plugin skills, but scoped to this repo's development needs rather than the plugin's consumer-facing features.

| Command | File | Purpose |
|---|---|---|
| `/project:lint` | `commands/lint.md` | Run the full lint suite (ShellCheck + shfmt + markdownlint + Prettier) and report results |
| `/project:validate` | `commands/validate.md` | Run template drift check and full structure validation (`--root`) |
| `/project:test-hooks` | `commands/test-hooks.md` | Smoke-test enforcement hooks by feeding known good/bad inputs and asserting exit codes |
| `/project:propagate-templates` | `commands/propagate-templates.md` | Copy canonical templates to all consuming skills and verify drift-free |
| `/project:check-ci` | `commands/check-ci.md` | Run the full CI pipeline locally (all lint + validate steps) |

Each command file contains a prompt with workflow instructions — the same pattern used by plugin skills in their `SKILL.md` files. This encodes tribal knowledge about "how do I check my work" into discoverable, one-step operations.

#### `CLAUDE.md` (project-level)

The existing root `CLAUDE.md` already provides plugin context. The `.claude/CLAUDE.md` can supplement it with development-specific guidance:

- Common pitfalls when editing hook scripts
- Reminder to propagate templates after modifying canonical copies
- Pointer to run lint/validate before committing

### 6. Dogfooding: Install principled-docs as Its Own Plugin

principled-docs is a Claude Code plugin that enforces documentation structure. This repo has its own documentation structure (`docs/proposals/`, `docs/plans/`, `docs/decisions/`, `docs/architecture/`). We should install the plugin on itself.

#### How

The `.claude/settings.json` should reference the repo root as a plugin source:

```json
{
  "plugins": [
    {
      "path": "."
    }
  ]
}
```

This means contributors developing the plugin with Claude Code will automatically get:

- **All 9 skills** — `/scaffold`, `/validate`, `/docs-audit`, `/new-proposal`, `/new-plan`, `/new-adr`, `/new-architecture-doc`, `/proposal-status` available as slash commands for managing the plugin's own docs
- **All enforcement hooks** — ADR immutability and proposal lifecycle guards active while editing the plugin's own proposals and decisions
- **Structure nudge** — PostToolUse validation fires when writing files in `docs/`

#### Why This Matters

- **Catches plugin bugs early.** If a skill or hook breaks, the developers using it on this repo will notice immediately.
- **Validates the DX.** The plugin's UX is tested continuously by its own maintainers.
- **Keeps docs consistent.** The plugin's own documentation follows the same standards it enforces on consumers.
- **Living reference.** The repo's `docs/` directory serves as a working example of what the plugin produces.

This improves DX for anyone developing the plugin with Claude Code itself, and ensures the plugin remains its own best advertisement.

## Alternatives Considered

### Alternative 1: Skip linting, rely on code review

Relying on manual review for shell script quality is error-prone. ShellCheck catches real bugs (unquoted variables, incorrect test operators, POSIX compatibility issues) that are easy to miss in review. Automated enforcement is strictly better.

### Alternative 2: Use Bats for shell testing instead of smoke tests

[Bats](https://github.com/bats-core/bats-core) is a full testing framework for Bash. While valuable, it's a heavier addition. The existing validation scripts already serve as integration tests. Bats can be introduced in a future RFC if more comprehensive test coverage is needed.

### Alternative 3: Use a different license (Apache-2.0, GPL)

Apache-2.0 adds patent grant provisions but is more complex. GPL would restrict commercial use in proprietary monorepos. MIT is the simplest choice that maximizes adoption for a developer tool.

### Alternative 4: Skip Markdown linting, only lint shell

Markdown is the plugin's primary output artifact. Leaving it unformatted while enforcing shell style would be inconsistent. markdownlint + Prettier have negligible setup cost given we're already adopting pre-commit.

### Alternative 5: Don't dogfood, test the plugin only on external repos

Testing externally doesn't catch integration issues with the plugin's own docs structure. Dogfooding provides continuous, zero-cost validation and keeps the repo as a living reference implementation.

## Consequences

### Positive

- **Lower contribution barrier** — CONTRIBUTING.md gives new contributors a clear onboarding path
- **Legal clarity** — MIT license removes ambiguity for adoption
- **Automated quality** — shell and Markdown linting catches bugs and inconsistencies before they land; formatting eliminates style debates
- **CI gate** — template drift, structure violations, and lint failures are caught in PRs, not after merge
- **Better Claude Code DX** — `.claude/` with settings, commands, and self-installed plugin gives contributors a batteries-included experience
- **Dogfooding catches bugs** — using the plugin on its own repo provides continuous validation of skills, hooks, and templates
- **Living reference** — the repo's own `docs/` directory serves as a working example of plugin output

### Negative

- **Pre-commit adds dependencies** — contributors need to install the pre-commit framework, ShellCheck, shfmt, markdownlint-cli2, and Prettier (or a subset for Option B)
- **CI adds maintenance** — GitHub Actions workflow needs updates as new scripts/checks are added
- **Initial formatting churn** — running shfmt and Prettier on existing files may produce large reformatting diffs
- **Node.js dependency for Markdown tooling** — markdownlint-cli2 and Prettier require Node.js, adding a runtime dependency to a previously pure-bash project (scoped to dev tooling only, not plugin runtime)

### Risks

- **ShellCheck false positives** — some checks may be overly strict for this codebase. Mitigated by `.shellcheckrc` to disable specific rules as needed.
- **Pre-commit friction** — developers unfamiliar with pre-commit may find it annoying. Mitigated by clear setup instructions in CONTRIBUTING.md.

## Architecture Impact

- No new plugin skills or hooks are created by this RFC. The plugin architecture is unchanged.
- `.github/workflows/ci.yml` is a new infrastructure component outside the plugin architecture.
- `.claude/` directory adds project-level Claude Code configuration: settings, dev commands, and self-referencing plugin installation. This should be documented in CLAUDE.md.
- Dogfooding (installing the plugin on itself) means all plugin hooks and skills are active during development. This is intentional and desirable — it validates the plugin continuously.
- CLAUDE.md should be updated to reference CONTRIBUTING.md, CI pipeline, and `.claude/` directory.
- `package.json` may be introduced at root for Markdown tooling (`markdownlint-cli2`, `prettier`) as dev dependencies. This does not affect the plugin runtime, which remains pure bash.

## Decisions

The following questions were raised during drafting and have been resolved:

1. **CI runs the full `validate-structure.sh --root` check**, not just template drift. Both are included in the `validate` job.
2. **Use latest versions** of ShellCheck, shfmt, markdownlint-cli2, and Prettier in CI. No version pinning needed initially.
3. **All ShellCheck rules enabled by default.** No project-wide disables at the start. Specific rules can be disabled later via `.shellcheckrc` if justified.
4. **`.claude/settings.json` is committed.** It contains project-level configuration (dogfooding plugin path, permissions, environment) that all contributors should share.
5. **markdownlint rules to relax:**
   - MD013 (line length) — disabled for tables and long URLs, which are common in this repo's templates and architecture docs
   - MD033 (inline HTML) — disabled to allow Mermaid diagram containers and other structural HTML
   - All other rules enabled by default
6. **Prettier prose wrap set to `preserve`.** Respects author line breaks; less disruptive than hard-wrapping.
7. **Dogfooding uses a relative path (`"."`)** in `.claude/settings.json`. Simplest approach, no symlinks or circular dependency concerns.
8. **`.claude/commands/` are prompt-based skills** (`.md` files with workflow instructions), following the same pattern as plugin skills in `SKILL.md` files. They are user-invocable via `/project:<name>`.

## Open Questions

None — all questions resolved.
