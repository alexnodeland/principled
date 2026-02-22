# Development Context

This file supplements the root `CLAUDE.md` with development-specific guidance for contributors working on the principled marketplace and its plugins.

## Dogfooding

This repo installs all four first-party plugins (via `.claude/settings.json`). This means:

### principled-docs

- All 9 plugin skills (`/scaffold`, `/validate`, `/new-proposal`, `/new-plan`, `/new-adr`, `/new-architecture-doc`, `/proposal-status`, `/docs-audit`) are available as slash commands
- All enforcement hooks (ADR immutability, proposal lifecycle, structure nudge) are active
- Use the plugin's own skills to manage the marketplace's `docs/` directory

### principled-implementation

- All 6 plugin skills (`/decompose`, `/spawn`, `/check-impl`, `/merge-work`, `/orchestrate`) are available as slash commands
- The `impl-worker` agent is available for worktree-isolated task execution
- The manifest integrity advisory hook is active
- Use `/orchestrate` against DDD plans in `docs/plans/` to execute implementation tasks

### principled-github

- All 9 plugin skills (`/triage`, `/ingest-issue`, `/sync-issues`, `/pr-describe`, `/gh-scaffold`, `/gen-codeowners`, `/sync-labels`, `/pr-check`) are available as slash commands
- The PR reference advisory hook is active
- Use `/triage` to batch-process all open untriaged issues into the principled pipeline
- Use `/ingest-issue` to pull a single GitHub issue into the pipeline (normalizes metadata, creates proposals/plans)
- Use `/sync-issues` to push proposals/plans to GitHub issues
- Use `/gh-scaffold` to set up `.github/` directory with principled-aligned templates

### principled-quality

- All 5 plugin skills (`/review-checklist`, `/review-context`, `/review-coverage`, `/review-summary`) are available as slash commands
- The review checklist advisory hook is active
- Use `/review-checklist` to generate spec-driven review checklists for PRs
- Use `/review-context` to surface relevant specifications for a PR's changed files
- Use `/review-coverage` to assess review completeness against checklist items
- Use `/review-summary` to generate structured review summaries

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
- Run `bash plugins/principled-github/scripts/check-template-drift.sh` to verify zero drift within principled-github.
- Run `bash plugins/principled-quality/scripts/check-template-drift.sh` to verify zero cross-plugin drift.
- Forgetting to propagate = CI failure.

### Editing Hook Scripts (principled-quality)

- Uses stdin JSON with `tool_input.command`: `echo '{"tool_input":{"command":"gh pr review 42"}}' | bash plugins/principled-quality/hooks/scripts/check-review-checklist.sh`
- Advisory only --- always exits 0. Never blocks.
- Triggers on `gh pr review` and `gh pr merge` commands.

### Changing Frontmatter Schema

- Any changes to frontmatter field names or status values must be reflected in `plugins/principled-docs/hooks/scripts/parse-frontmatter.sh` and the guard scripts that consume it.

### Marketplace Manifest

- When adding a plugin to `plugins/` or `external_plugins/`, remember to add its entry to `.claude-plugin/marketplace.json`.
- CI validates that every `source` path in the manifest exists on disk.

## Before Committing

1. Run `/lint` or `pre-commit run --all-files` to check formatting and lint
2. Run `/validate --root` to check root structure (plugin skill, from dogfooding)
3. If you modified templates or scripts, propagate copies first and run drift checks for all four plugins

## Dev Skills

These supplement the 29 plugin skills available via dogfooding:

| Skill                 | Command                | What It Does                                                   |
| --------------------- | ---------------------- | -------------------------------------------------------------- |
| `lint`                | `/lint`                | Full lint suite (ShellCheck + shfmt + markdownlint + Prettier) |
| `test-hooks`          | `/test-hooks`          | Smoke-test enforcement hooks with known inputs                 |
| `propagate-templates` | `/propagate-templates` | Copy canonical templates/scripts to consuming skills           |
| `check-ci`            | `/check-ci`            | Run the full CI pipeline locally                               |
