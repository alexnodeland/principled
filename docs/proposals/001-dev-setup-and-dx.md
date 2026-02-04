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
3. **No linting or formatting standards.** Shell scripts (the entire codebase) have no automated style enforcement. Inconsistencies can creep in across 9 skill directories, hook scripts, and utility scripts.
4. **No pre-commit hooks for code quality.** The existing hooks system enforces *document* integrity (ADR immutability, proposal lifecycle), but nothing enforces *code* quality on commit.
5. **No CI pipeline.** Template drift checks and structure validation exist as scripts but are not wired into a PR-gated pipeline.
6. **No `.claude/` directory.** The repo lacks Claude Code local configuration (settings, commands) that would improve the development experience for contributors using Claude Code.

These gaps increase friction for contributors and risk inconsistent code quality as the plugin grows.

## Proposal

Add developer setup and DX infrastructure in four areas:

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

#### Tool: ShellCheck + shfmt

All code in this repo is pure Bash. The standard toolchain for Bash quality is:

- **[ShellCheck](https://www.shellcheck.net/)** — static analysis for shell scripts. Catches common bugs, portability issues, and bad practices.
- **[shfmt](https://github.com/mvdan/sh)** — formatter for shell scripts. Enforces consistent indentation, spacing, and style.

#### Configuration

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
3. Existing template drift check — `skills/scaffold/scripts/check-template-drift.sh`

#### Formatting Standards

- **Indent:** 2 spaces (consistent with existing scripts)
- **Binary operators:** at the beginning of the next line
- **Redirect operators:** followed by a space
- **Shell dialect:** `bash` (not `sh` or `posix`)

### 4. CI Pipeline

Add a GitHub Actions workflow (`.github/workflows/ci.yml`) that runs on every PR and push to main:

```yaml
jobs:
  lint:
    # ShellCheck all .sh files
    # shfmt --diff all .sh files

  validate:
    # Template drift check
    # Root structure validation
    # Hook script smoke tests (feed known inputs, assert exit codes)
```

This formalizes the checks that already exist as scripts into an automated gate.

### 5. `.claude/` Directory Setup

Create `.claude/settings.json` with project-level Claude Code configuration:

- **Permissions** — pre-approve common tools (Bash, Read, Edit, Write, Glob, Grep) to reduce approval friction during development
- **Environment context** — set `CLAUDE_PLUGIN_ROOT` so hook scripts resolve correctly during development

This improves DX for anyone developing the plugin with Claude Code itself.

## Alternatives Considered

### Alternative 1: Skip linting, rely on code review

Relying on manual review for shell script quality is error-prone. ShellCheck catches real bugs (unquoted variables, incorrect test operators, POSIX compatibility issues) that are easy to miss in review. Automated enforcement is strictly better.

### Alternative 2: Use Bats for shell testing instead of smoke tests

[Bats](https://github.com/bats-core/bats-core) is a full testing framework for Bash. While valuable, it's a heavier addition. The existing validation scripts already serve as integration tests. Bats can be introduced in a future RFC if more comprehensive test coverage is needed.

### Alternative 3: Use a different license (Apache-2.0, GPL)

Apache-2.0 adds patent grant provisions but is more complex. GPL would restrict commercial use in proprietary monorepos. MIT is the simplest choice that maximizes adoption for a developer tool.

## Consequences

### Positive

- **Lower contribution barrier** — CONTRIBUTING.md gives new contributors a clear onboarding path
- **Legal clarity** — MIT license removes ambiguity for adoption
- **Automated quality** — linting catches bugs before they land; formatting eliminates style debates
- **CI gate** — template drift and structure violations are caught in PRs, not after merge
- **Better Claude Code DX** — `.claude/` configuration reduces friction for plugin developers

### Negative

- **Pre-commit adds a dependency** — contributors need to install the pre-commit framework (or ShellCheck/shfmt directly for Option B)
- **CI adds maintenance** — GitHub Actions workflow needs updates as new scripts/checks are added
- **Initial formatting churn** — running shfmt on existing scripts may produce a large reformatting diff

### Risks

- **ShellCheck false positives** — some checks may be overly strict for this codebase. Mitigated by `.shellcheckrc` to disable specific rules as needed.
- **Pre-commit friction** — developers unfamiliar with pre-commit may find it annoying. Mitigated by clear setup instructions in CONTRIBUTING.md.

## Architecture Impact

- No new skills or hooks are created by this RFC.
- `.github/workflows/ci.yml` is a new infrastructure component outside the plugin architecture.
- `.claude/settings.json` is a new configuration surface that should be documented in CLAUDE.md.
- CLAUDE.md should be updated to reference CONTRIBUTING.md and CI pipeline.

## Open Questions

1. Should the CI pipeline also run the full `validate-structure.sh --root` check, or is template drift sufficient?
2. Should we pin specific versions of ShellCheck and shfmt in CI, or use latest?
3. Are there any ShellCheck rules that should be disabled project-wide from the start (e.g., SC2034 for unused variables in sourced scripts)?
4. Should `.claude/settings.json` be committed or `.gitignore`-d (since it may contain user-specific preferences)?
