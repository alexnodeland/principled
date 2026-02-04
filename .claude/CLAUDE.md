# Development Context

This file supplements the root `CLAUDE.md` with development-specific guidance for contributors working on the principled-docs plugin itself.

## Dogfooding

This repo installs principled-docs as its own plugin (via `.claude/settings.json`). This means:

- All 9 plugin skills (`/scaffold`, `/validate`, `/new-proposal`, `/new-plan`, `/new-adr`, `/new-architecture-doc`, `/proposal-status`, `/docs-audit`) are available as slash commands
- All enforcement hooks (ADR immutability, proposal lifecycle, structure nudge) are active
- Use the plugin's own skills to manage the plugin's `docs/` directory

## Common Pitfalls

### Editing Hook Scripts

- Hook scripts read JSON from stdin. Always test with `echo '{"tool_input":{"file_path":"..."}}' | bash hooks/scripts/<script>.sh`
- Exit code 0 = allow, exit code 2 = block. Never use exit code 1 (reserved for script errors).
- `parse-frontmatter.sh` is a shared dependency. Changes to it affect both `check-adr-immutability.sh` and `check-proposal-lifecycle.sh`.

### Modifying Templates

- **Always edit the canonical version first** (in `skills/scaffold/templates/`)
- Then propagate to all copies. Use `/propagate-templates` or copy manually.
- Run `bash skills/scaffold/scripts/check-template-drift.sh` to verify zero drift.
- Forgetting to propagate = CI failure.

### Changing Frontmatter Schema

- Any changes to frontmatter field names or status values must be reflected in `hooks/scripts/parse-frontmatter.sh` and the guard scripts that consume it.

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
