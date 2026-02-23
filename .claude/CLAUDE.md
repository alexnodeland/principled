# Development Context

This file supplements the root `CLAUDE.md` with development-specific guidance for contributors working on the principled marketplace and its plugins.

## Dogfooding

All six first-party plugins are installed via `.claude/settings.json`. See root `CLAUDE.md` § Dogfooding for the full list of available skills and active hooks.

## Common Pitfalls

### Editing Hook Scripts (principled-docs)

- Hook scripts read JSON from stdin. Always test with `echo '{"tool_input":{"file_path":"..."}}' | bash plugins/principled-docs/hooks/scripts/<script>.sh`
- Exit code 0 = allow, exit code 2 = block. Never use exit code 1 (reserved for script errors).
- `parse-frontmatter.sh` is a shared dependency. Changes to it affect both `check-adr-immutability.sh` and `check-proposal-lifecycle.sh`.

### Editing Hook Scripts (principled-implementation)

- Same stdin JSON format: `echo '{"tool_input":{"file_path":"..."}}' | bash plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh`
- Advisory only — always exits 0. Never blocks.
- Uses jq with grep fallback for JSON parsing.

### Modifying Templates (principled-docs)

- **Always edit the canonical version first** (in `plugins/principled-docs/skills/scaffold/templates/`)
- Then propagate to all copies. Use `/propagate-templates` or copy manually.
- Run `bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh` to verify zero drift.
- Forgetting to propagate = CI failure.

### Modifying Scripts/Templates (principled-implementation)

- **Always edit the canonical version first:**
  - `task-manifest.sh` → canonical in `plugins/principled-implementation/skills/decompose/scripts/`
  - `parse-plan.sh` → canonical in `plugins/principled-implementation/skills/decompose/scripts/`
  - `run-checks.sh` → canonical in `plugins/principled-implementation/skills/check-impl/scripts/`
  - `claude-task.md` → canonical in `plugins/principled-implementation/skills/spawn/templates/`
- Then propagate copies to consuming skills.
- Run `bash plugins/principled-implementation/scripts/check-template-drift.sh` to verify zero drift.
- Forgetting to propagate = CI failure.

### Editing Hook Scripts (principled-github)

- Uses stdin JSON with `tool_input.command`: `echo '{"tool_input":{"command":"gh pr create ..."}}' | bash plugins/principled-github/hooks/scripts/check-pr-references.sh`
- Advisory only --- always exits 0. Never blocks.

### Modifying Scripts (principled-github)

- **Always edit the canonical version first:**
  - `check-gh-cli.sh` -> canonical in `plugins/principled-github/skills/sync-issues/scripts/`
- Then propagate copies to `sync-labels`, `pr-check`, `gh-scaffold`, `ingest-issue`, `triage`, and `pr-describe`.
- **Also propagate to principled-quality:** `review-checklist`, `review-context`, `review-coverage`, and `review-summary`.
- **Also propagate to principled-release:** `changelog`, `release-ready`, `release-plan`, and `tag-release`.
- Run `bash plugins/principled-github/scripts/check-template-drift.sh` to verify zero drift within principled-github.
- Run `bash plugins/principled-quality/scripts/check-template-drift.sh` to verify zero cross-plugin drift.
- Run `bash plugins/principled-release/scripts/check-template-drift.sh` to verify zero cross-plugin drift.
- Forgetting to propagate = CI failure.

### Editing Hook Scripts (principled-quality)

- Uses stdin JSON with `tool_input.command`: `echo '{"tool_input":{"command":"gh pr review 42"}}' | bash plugins/principled-quality/hooks/scripts/check-review-checklist.sh`
- Advisory only --- always exits 0. Never blocks.
- Triggers on `gh pr review` and `gh pr merge` commands.

### Editing Hook Scripts (principled-release)

- Uses stdin JSON with `tool_input.command`: `echo '{"tool_input":{"command":"git tag v1.0.0"}}' | bash plugins/principled-release/hooks/scripts/check-release-readiness.sh`
- Advisory only --- always exits 0. Never blocks.
- Triggers on `git tag` commands (excludes `git tag -l` and `git tag -d`).

### Editing Hook Scripts (principled-architecture)

- Uses stdin JSON with `tool_input.file_path`: `echo '{"tool_input":{"file_path":"src/index.ts"}}' | bash plugins/principled-architecture/hooks/scripts/check-boundary-violation.sh`
- Advisory only --- always exits 0. Never blocks.
- Triggers on Write of source files (`.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.go`, `.rs`, `.java`).
- Checks for module dependency direction violations by scanning imports against the module type system (ADR-003, ADR-014).

### Changing Frontmatter Schema

- Any changes to frontmatter field names or status values must be reflected in `plugins/principled-docs/hooks/scripts/parse-frontmatter.sh` and the guard scripts that consume it.

### Marketplace Manifest

- When adding a plugin to `plugins/` or `external_plugins/`, remember to add its entry to `.claude-plugin/marketplace.json`.
- CI validates that every `source` path in the manifest exists on disk.

## Before Committing

1. Run `/lint` or `pre-commit run --all-files` to check formatting and lint
2. Run `/validate --root` to check root structure (plugin skill, from dogfooding)
3. If you modified templates or scripts, propagate copies first and run drift checks for all six plugins

## Dev Skills

These supplement the 41 plugin skills available via dogfooding:

| Skill                 | Command                | What It Does                                                   |
| --------------------- | ---------------------- | -------------------------------------------------------------- |
| `lint`                | `/lint`                | Full lint suite (ShellCheck + shfmt + markdownlint + Prettier) |
| `test-hooks`          | `/test-hooks`          | Smoke-test enforcement hooks with known inputs                 |
| `propagate-templates` | `/propagate-templates` | Copy canonical templates/scripts to consuming skills           |
| `check-ci`            | `/check-ci`            | Run the full CI pipeline locally                               |
