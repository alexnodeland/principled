# Contributing to principled-docs

Thank you for your interest in contributing to principled-docs! This guide covers everything you need to get started.

## Getting Started

### Prerequisites

- **Bash 4+** — all scripts are pure bash
- **Git** — version control
- **Node.js 18+** — required for Markdown linting/formatting (`markdownlint-cli2`, `prettier`)
- **ShellCheck** — shell script static analysis
- **shfmt** — shell script formatter
- **pre-commit** — git hook framework (`pip install pre-commit`)
- **jq** (optional) — used by hook scripts with grep fallback

### Setup

```bash
# Clone the repository
git clone https://github.com/alexnodeland/principled-docs.git
cd principled-docs

# Install Node.js dev dependencies (Markdown tooling)
npm install

# Install pre-commit hooks
pre-commit install
```

### Directory Orientation

Read `CLAUDE.md` at the repo root for the full architectural context. The key directories are:

| Directory         | Purpose                                                                               |
| ----------------- | ------------------------------------------------------------------------------------- |
| `skills/`         | 9 skill directories, each self-contained with SKILL.md, templates, scripts, reference |
| `hooks/`          | Enforcement hooks — `hooks.json` config + guard scripts                               |
| `.claude-plugin/` | Plugin manifest (`plugin.json`)                                                       |
| `docs/`           | The plugin's own documentation pipeline (proposals, plans, decisions, architecture)   |
| `.claude/`        | Claude Code project configuration — settings, dev skills                              |

## Development Workflow

### Branching

- Work on feature branches off `main`
- Branch naming: `<author>/<short-description>` or `claude/<description>`

### Commit Messages

Use the format: `type: description`

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`

Examples:

- `feat: add new-architecture-doc skill`
- `fix: handle empty directory in next-number.sh`
- `docs: update CLAUDE.md with new skill reference`

### Pull Requests

- Ensure all pre-commit hooks pass locally before pushing
- CI pipeline must pass (shell lint, Markdown lint, validation)
- Reference relevant proposals or plans in PR description

## Plugin Architecture Overview

principled-docs has three layers:

1. **Skills** (`skills/`) — generative workflows (slash commands)
2. **Hooks** (`hooks/`) — deterministic guardrails (pre/post tool use)
3. **Foundation** (`.claude-plugin/`, templates, scripts) — plugin manifest and shared infrastructure

See `CLAUDE.md` and `docs/architecture/` for deeper context.

## Skill Development

Each skill is a self-contained directory:

```
skills/<skill-name>/
├── SKILL.md              # Command definition and workflow
├── templates/            # Document templates (if generative)
├── scripts/              # Bash scripts (if needed)
└── reference/            # Supporting documentation
```

### SKILL.md Format

The `SKILL.md` file uses YAML frontmatter:

```yaml
---
name: <skill-name>
description: >
  Human-readable description
allowed-tools: Tool1, Tool2, Bash(pattern)
user-invocable: true|false
---
```

The body contains workflow instructions as prose that Claude interprets directly:

- `## Command` — usage syntax
- `## Arguments` — parameter table
- `## Workflow` — step-by-step instructions
- `## Templates` / `## Scripts` — file references

### Key Rule: No Cross-Skill Imports

Skills are self-contained. If multiple skills need the same template or script, each maintains its own copy. See "Template Management" below.

## Hook Development

Hooks are declared in `hooks/hooks.json` and run shell scripts:

```json
{
  "PreToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/<script>.sh",
          "timeout": 10
        }
      ]
    }
  ]
}
```

### Hook Script Conventions

- **Exit 0** — allow the operation
- **Exit 2** — block the operation (with descriptive message on stderr)
- **Default to allow** — only block when you can positively confirm a violation
- Read tool input JSON from stdin (contains `tool_input.file_path`)
- Use `hooks/scripts/parse-frontmatter.sh` for YAML field extraction
- **jq is optional** — always provide a `grep` fallback

### Testing Hooks

Feed JSON to hook scripts via stdin:

```bash
echo '{"tool_input":{"file_path":"docs/decisions/001-example.md"}}' \
  | bash hooks/scripts/check-adr-immutability.sh
echo $?  # 0 = allow, 2 = block
```

## Template Management

### Canonical Sources

All canonical templates live in `skills/scaffold/templates/{core,lib,app}/`.

### Copy Rules

Consuming skills keep byte-identical copies:

| Canonical                                 | Copy                                             |
| ----------------------------------------- | ------------------------------------------------ |
| `scaffold/templates/core/proposal.md`     | `new-proposal/templates/proposal.md`             |
| `scaffold/templates/core/plan.md`         | `new-plan/templates/plan.md`                     |
| `scaffold/templates/core/decision.md`     | `new-adr/templates/decision.md`                  |
| `scaffold/templates/core/architecture.md` | `new-architecture-doc/templates/architecture.md` |

Scripts with copies:

| Canonical                                | Copy                                                                |
| ---------------------------------------- | ------------------------------------------------------------------- |
| `new-proposal/scripts/next-number.sh`    | `new-plan/scripts/next-number.sh`, `new-adr/scripts/next-number.sh` |
| `scaffold/scripts/validate-structure.sh` | `validate/scripts/validate-structure.sh`                            |

### Propagation Workflow

1. Edit the **canonical** version first
2. Copy to all consuming locations
3. Run `skills/scaffold/scripts/check-template-drift.sh` to verify
4. Or use `/propagate-templates` if working with Claude Code

Drift = CI failure. Always propagate after modifying canonical sources.

## Testing Locally

```bash
# Template drift check
bash skills/scaffold/scripts/check-template-drift.sh

# Root structure validation
bash skills/scaffold/scripts/validate-structure.sh --root

# Shell linting
shellcheck skills/**/*.sh hooks/**/*.sh
shfmt --diff skills/**/*.sh hooks/**/*.sh

# Markdown linting
npx markdownlint-cli2 '**/*.md'
npx prettier --check '**/*.md'

# All pre-commit checks at once
pre-commit run --all-files
```

## Code Style

### Shell Scripts

- **Indent:** 2 spaces
- **Shell dialect:** `bash` (not `sh` or `posix`)
- **Binary operators:** at the beginning of the next line
- **Redirect operators:** followed by a space
- **All ShellCheck rules enabled** — see `.shellcheckrc`
- Enforced by `shfmt` and `shellcheck` via pre-commit

### Markdown

- **Heading style:** ATX (`#` prefixed)
- **Fenced code blocks:** backticks (not tildes)
- **Emphasis marker:** `*` (asterisks, not underscores)
- **Prose wrap:** preserve (author chooses line breaks)
- **List indent:** 2 spaces
- Enforced by `markdownlint-cli2` and `prettier` via pre-commit
- See `.markdownlint.jsonc` and `.prettierrc` for configuration

## Pre-commit Hooks

After running `pre-commit install`, the following checks run automatically on each commit:

1. `shfmt` — shell script formatting
2. `shellcheck` — shell script lint
3. `markdownlint-cli2` — Markdown lint
4. `prettier` — Markdown formatting
5. Template drift check

To bypass in emergencies: `git commit --no-verify` (use sparingly).

## Claude Code Dev Skills

If you develop with Claude Code, the `.claude/skills/` directory provides project-specific dev skills:

| Skill                 | Command                | Purpose                                 |
| --------------------- | ---------------------- | --------------------------------------- |
| `lint`                | `/lint`                | Run full lint suite                     |
| `test-hooks`          | `/test-hooks`          | Smoke-test enforcement hooks            |
| `propagate-templates` | `/propagate-templates` | Propagate canonical templates to copies |
| `check-ci`            | `/check-ci`            | Run full CI pipeline locally            |

The plugin is also self-installed (dogfooding), so all 9 plugin skills and enforcement hooks are active while developing.
