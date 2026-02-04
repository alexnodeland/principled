# Development Context

This file supplements the root `CLAUDE.md` with development-specific guidance for contributors working on the principled-docs marketplace and its plugins.

## Dogfooding

This repo installs the principled-docs plugin from `plugins/principled-docs/` (via `.claude/settings.json`). This means:

- All 9 plugin skills (`/scaffold`, `/validate`, `/new-proposal`, `/new-plan`, `/new-adr`, `/new-architecture-doc`, `/proposal-status`, `/docs-audit`) are available as slash commands
- All enforcement hooks (ADR immutability, proposal lifecycle, structure nudge) are active
- Use the plugin's own skills to manage the marketplace's `docs/` directory

## Common Pitfalls

### Editing Hook Scripts

- Hook scripts read JSON from stdin. Always test with `echo '{"tool_input":{"file_path":"..."}}' | bash plugins/principled-docs/hooks/scripts/<script>.sh`
- Exit code 0 = allow, exit code 2 = block. Never use exit code 1 (reserved for script errors).
- `parse-frontmatter.sh` is a shared dependency. Changes to it affect both `check-adr-immutability.sh` and `check-proposal-lifecycle.sh`.

### Modifying Templates

- **Always edit the canonical version first** (in `plugins/principled-docs/skills/scaffold/templates/`)
- Then propagate to all copies. Use `/propagate-templates` or copy manually.
- Run `bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh` to verify zero drift.
- Forgetting to propagate = CI failure.

### Changing Frontmatter Schema

- Any changes to frontmatter field names or status values must be reflected in `plugins/principled-docs/hooks/scripts/parse-frontmatter.sh` and the guard scripts that consume it.

### Marketplace Manifest

- When adding a plugin to `plugins/` or `external_plugins/`, remember to add its entry to `.claude-plugin/marketplace.json`.
- CI validates that every `source` path in the manifest exists on disk.

## Before Committing

1. Run `/lint` or `pre-commit run --all-files` to check formatting and lint
2. Run `/validate --root` to check root structure (plugin skill, from dogfooding)
3. If you modified templates, run `/propagate-templates` first

## Dev Skills

These supplement the 9 plugin skills available via dogfooding:

| Skill                 | Command                | What It Does                                                   |
| --------------------- | ---------------------- | -------------------------------------------------------------- |
| `lint`                | `/lint`                | Full lint suite (ShellCheck + shfmt + markdownlint + Prettier) |
| `test-hooks`          | `/test-hooks`          | Smoke-test enforcement hooks with known inputs                 |
| `propagate-templates` | `/propagate-templates` | Copy canonical templates/scripts to consuming skills           |
| `check-ci`            | `/check-ci`            | Run the full CI pipeline locally                               |
