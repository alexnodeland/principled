# Contributing to Principled

Thank you for your interest in contributing to the Principled plugin marketplace! This guide covers contributing to the marketplace, its plugins, and submitting new plugins.

## Getting Started

### Prerequisites

- **Bash 3.2+** — all scripts are pure bash and must run on stock macOS bash (no `declare -A`, `local -n`, `mapfile`, or `${var,,}`)
- **Git** — version control
- **Node.js 18+** — required for Markdown linting/formatting (`markdownlint-cli2`, `prettier`)
- **ShellCheck** — shell script static analysis
- **shfmt** — shell script formatter
- **pre-commit** — git hook framework (`pip install pre-commit`)
- **jq** (optional) — used by hook scripts with grep fallback

### Setup

```bash
# Clone the repository
git clone https://github.com/alexnodeland/principled.git
cd principled

# Install Node.js dev dependencies (Markdown tooling)
npm install

# Install pre-commit hooks
pre-commit install
```

### Directory Orientation

Read `CLAUDE.md` at the repo root for the full architectural context. The key directories are:

| Directory                         | Purpose                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------- |
| `.claude-plugin/`                 | Marketplace manifest (`marketplace.json`)                                             |
| `plugins/`                        | First-party plugins (maintained by the project)                                       |
| `plugins/principled-docs/skills/` | 9 skill directories, each self-contained with SKILL.md, templates, scripts, reference |
| `plugins/principled-docs/hooks/`  | Enforcement hooks — `hooks.json` config + guard scripts                               |
| `external_plugins/`               | Community plugins (submitted via PR)                                                  |
| `docs/`                           | Marketplace documentation pipeline (proposals, plans, decisions, architecture)        |
| `.claude/`                        | Claude Code project configuration — settings, dev skills                              |

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
- CI pipeline must pass (shell lint, Markdown lint, validation, marketplace validation)
- Reference relevant proposals or plans in PR description

## Marketplace Architecture

The repo is organized as a curated plugin marketplace with two tiers:

1. **Marketplace** (`.claude-plugin/marketplace.json`, `plugins/`, `external_plugins/`) — plugin catalog and directory structure
2. **First-party plugins** (`plugins/`) — plugins maintained by the project
3. **Community plugins** (`external_plugins/`) — plugins contributed by third parties

Each plugin is self-contained with its own `.claude-plugin/plugin.json`, skills, hooks, and documentation.

See `CLAUDE.md` and `docs/architecture/` for deeper context.

## Contributing a First-Party Plugin

First-party plugins live in `plugins/<plugin-name>/`. To add one:

1. Create the plugin directory with the required structure:

   ```
   plugins/<plugin-name>/
   ├── .claude-plugin/
   │   └── plugin.json           # Plugin manifest (required)
   ├── skills/                    # Plugin skills
   │   └── <skill-name>/
   │       ├── SKILL.md
   │       ├── templates/
   │       ├── scripts/
   │       └── reference/
   ├── hooks/                     # Plugin hooks (optional)
   │   ├── hooks.json
   │   └── scripts/
   └── README.md                  # Plugin documentation (required)
   ```

2. Add a `plugin.json` manifest:

   ```json
   {
     "name": "<plugin-name>",
     "version": "0.1.0",
     "description": "What the plugin does.",
     "author": "Author Name",
     "keywords": ["keyword1", "keyword2"]
   }
   ```

3. Add the plugin entry to `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "<plugin-name>",
     "source": "./plugins/<plugin-name>",
     "description": "What the plugin does.",
     "version": "0.1.0",
     "category": "documentation|workflow|quality|architecture"
   }
   ```

4. Ensure all CI checks pass (lint, marketplace validation, plugin validation)

## Submitting an External Plugin

Community plugins live in `external_plugins/<plugin-name>/`. To submit one:

1. Follow the same directory structure as first-party plugins
2. Include `author` and `homepage` or `repository` fields in `plugin.json`
3. Include a `README.md` with installation, usage, and skill/hook documentation
4. Submit a pull request — a maintainer will review and add the entry to `marketplace.json`

### Plugin Review Criteria

External plugins are reviewed for:

- Valid `.claude-plugin/plugin.json` manifest
- Clean lint (ShellCheck, shfmt, markdownlint, Prettier)
- Self-contained skills (no cross-plugin imports)
- Clear documentation (README with usage instructions)
- No security concerns in hook or skill scripts

## Marketplace Manifest Maintenance

The `.claude-plugin/marketplace.json` file is the source of truth for available plugins. When modifying it:

- Every `source` path must point to an existing directory
- Plugin `name` must be unique across all entries
- CI validates the manifest on every PR

## Skill Development

Each skill is a self-contained directory within a plugin:

```
plugins/<plugin-name>/skills/<skill-name>/
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

Hooks are declared in a plugin's `hooks/hooks.json` and run shell scripts:

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
  | bash plugins/principled-docs/hooks/scripts/check-adr-immutability.sh
echo $?  # 0 = allow, 2 = block
```

## Shared Code and Templates

### Shared code lives in `lib/` (ADR-018)

Code used by more than one skill in a plugin lives in that plugin's `lib/` and is
referenced as `${CLAUDE_PLUGIN_ROOT}/lib/<name>`. One copy — nothing to propagate and
nothing that can drift.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/task-manifest.sh" --get-task --task-id 1.1
```

Never reference a script by bare relative path (`bash scripts/foo.sh`) — it only
resolves when the working directory happens to be the skill directory. Never reach into
a sibling skill (`bash ../other-skill/scripts/foo.sh`) — move the script to `lib/`
instead. `scripts/check-skill-references.sh` fails CI on both.

If you find yourself copying a `lib/` script into a skill directory, that is a
regression against ADR-018.

### Two things are still duplicated, deliberately

**Scaffolding templates**, because each generative skill ships the template it writes:

| Canonical                                 | Copy                                             |
| ----------------------------------------- | ------------------------------------------------ |
| `scaffold/templates/core/proposal.md`     | `new-proposal/templates/proposal.md`             |
| `scaffold/templates/core/plan.md`         | `new-plan/templates/plan.md`                     |
| `scaffold/templates/core/decision.md`     | `new-adr/templates/decision.md`                  |
| `scaffold/templates/core/architecture.md` | `new-architecture-doc/templates/architecture.md` |

Paths are relative to `plugins/principled-docs/skills/`.

**`check-gh-cli.sh` across three plugins**, because principled-github,
principled-quality and principled-release install independently and
`${CLAUDE_PLUGIN_ROOT}` cannot cross a plugin boundary:

| Canonical                                       | Copy                                                                 |
| ----------------------------------------------- | -------------------------------------------------------------------- |
| `plugins/principled-github/lib/check-gh-cli.sh` | `plugins/principled-quality/lib/`, `plugins/principled-release/lib/` |

### Propagation workflow (for those two only)

1. Edit the **canonical** version first
2. Copy to all consuming locations, or run `/propagate-templates`
3. Verify:

```bash
bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh
bash scripts/check-cross-plugin-drift.sh
```

Drift = CI failure.

## Testing Locally

```bash
# Everything at once
just ci

# Or individually — drift checks
bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh
bash scripts/check-cross-plugin-drift.sh

# Reference integrity: every referenced script exists and uses a portable path
bash scripts/check-skill-references.sh

# Pipeline audit: declared document state vs. the repository
bash scripts/pipeline-audit.sh

# Test suite (58 tests)
npx bats tests/

# Root structure validation
bash plugins/principled-docs/lib/validate-structure.sh --root

# Shell linting
find . -name '*.sh' -not -path './node_modules/*' | xargs shellcheck --shell=bash
find . -name '*.sh' -not -path './node_modules/*' | xargs shfmt -i 2 -bn -sr -d

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

| Skill                 | Command                | Purpose                                          |
| --------------------- | ---------------------- | ------------------------------------------------ |
| `lint`                | `/lint`                | Run full lint suite                              |
| `test-hooks`          | `/test-hooks`          | Smoke-test enforcement hooks                     |
| `propagate-templates` | `/propagate-templates` | Propagate the two remaining duplicated artifacts |
| `check-ci`            | `/check-ci`            | Run full CI pipeline locally                     |

All seven first-party plugins are self-installed (dogfooding), so all 48 plugin skills and enforcement hooks are active while developing.
