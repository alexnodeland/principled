# Development Context

This file supplements the root `CLAUDE.md` with development-specific guidance for contributors working on the principled marketplace and its plugins.

## Dogfooding

All eight first-party plugins are installed via `.claude/settings.json`. See root `CLAUDE.md` § Dogfooding for the full list of available skills and active hooks.

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

### Modifying Shared Code (`lib/`)

Every plugin now uses the `lib/` pattern (ADR-018) — one copy, no propagation:

- `plugins/principled-implementation/lib/{task-manifest,parse-plan,run-checks}.sh`
- `plugins/principled-implementation/lib/templates/claude-task.md`
- `plugins/principled-tasks/lib/task-db.sh`
- `plugins/principled-agent/lib/agent-memory.sh`

Edit in place. Skills reference them as `${CLAUDE_PLUGIN_ROOT}/lib/<name>`.

- Run `bash scripts/check-skill-references.sh` to verify every reference still resolves.
- Referencing a file that does not exist = CI failure. This is what caught
  `spawn/SKILL.md` invoking a `parse-plan.sh` that was never copied into `spawn`.

### Editing Hook Scripts (principled-github)

- Uses stdin JSON with `tool_input.command`: `echo '{"tool_input":{"command":"gh pr create ..."}}' | bash plugins/principled-github/hooks/scripts/check-pr-references.sh`
- Advisory only --- always exits 0. Never blocks.

### Modifying `check-gh-cli.sh` (cross-plugin)

This is the only script still duplicated across plugins. principled-github,
principled-quality and principled-release install independently, so
`${CLAUDE_PLUGIN_ROOT}` cannot reach across the boundary and each needs its own copy.
Three copies, down from fifteen.

- **Canonical:** `plugins/principled-github/lib/check-gh-cli.sh`
- Propagate to `plugins/principled-quality/lib/` and `plugins/principled-release/lib/`
  (or run `/propagate-templates`).
- Verify with `bash scripts/check-cross-plugin-drift.sh`.
- Forgetting to propagate = CI failure.

Within a single plugin, shared code lives in `lib/` with one copy — nothing to
propagate. Copying a `lib/` script into a skill directory is a regression against
ADR-018.

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

### Editing Hook Scripts (principled-agent)

- Injection reads an agent id from stdin JSON, trying `agent_id`, `subagent_type`,
  `agent_type`, then `agent` — the field name has varied across Claude Code versions:
  `echo '{"agent_id":"impl-worker"}' | bash plugins/principled-agent/hooks/scripts/inject-agent-memory.sh`
- Integrity uses `tool_input.file_path` and only reacts to paths under `.agents/`.
- Both always exit 0. Injection runs on `SubagentStart`, so a non-zero exit would block
  agent spawning outright.
- **Never make injection truncate.** An agent handed a silently halved memory file has a
  confidently incomplete picture and no way to notice. Oversized memory is reported by
  the integrity hook; it is never trimmed on the way in.

### Editing the Manifest Schema (principled-implementation)

- `checkpoint` and `acceptance_criteria` are additive and optional (ADR-021). Every
  consumer must tolerate their absence and ignore unknown fields.
- **Do not use `sed -i`.** BSD sed reads the next argument as a backup suffix, so
  `sed -i <expr> <file>` misparses on stock macOS. The no-jq fallback was broken this way
  for the second task onward and for every status update. Use `awk` into a temp file and
  `mv`, which behaves identically on both platforms.
- Test both paths. `tests/manifest-checkpoint.bats` runs each operation with jq and with
  a PATH that genuinely lacks it, then validates the result with the real jq.

### Changing Frontmatter Schema

- Any changes to frontmatter field names or status values must be reflected in `plugins/principled-docs/hooks/scripts/parse-frontmatter.sh` and the guard scripts that consume it.

### Marketplace Manifest

- When adding a plugin to `plugins/` or `external_plugins/`, remember to add its entry to `.claude-plugin/marketplace.json`.
- CI validates that every `source` path in the manifest exists on disk.

## Before Committing

1. Run `/lint` or `pre-commit run --all-files` to check formatting and lint
2. Run `/validate --root` to check root structure (plugin skill, from dogfooding)
3. If you modified shared code in a `lib/`, run `just refs` to confirm references resolve
4. If you modified a drift-checked template (principled-docs scaffolding, or the
   cross-plugin `check-gh-cli.sh`), propagate copies first and run `just drift`
5. Run `just test` for the bats suite

## Dev Skills

These supplement the 48 plugin skills available via dogfooding:

| Skill                 | Command                | What It Does                                                   |
| --------------------- | ---------------------- | -------------------------------------------------------------- |
| `lint`                | `/lint`                | Full lint suite (ShellCheck + shfmt + markdownlint + Prettier) |
| `test-hooks`          | `/test-hooks`          | Smoke-test enforcement hooks with known inputs                 |
| `propagate-templates` | `/propagate-templates` | Copy canonical templates/scripts to consuming skills           |
| `check-ci`            | `/check-ci`            | Run the full CI pipeline locally                               |
