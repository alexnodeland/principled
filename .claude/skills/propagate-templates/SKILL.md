---
name: propagate-templates
description: >
  Propagate the two remaining duplicated artifacts — principled-docs scaffolding
  templates and the cross-plugin check-gh-cli.sh — then verify zero drift. Use
  after editing either canonical source.
allowed-tools: Bash(cp *), Bash(bash plugins/*), Bash(bash scripts/*)
user-invocable: true
---

# Propagate Templates — Canonical Copy Sync

Most shared code no longer needs propagating. ADR-018 moved same-plugin shared scripts
into each plugin's `lib/`, referenced as `${CLAUDE_PLUGIN_ROOT}/lib/<name>` — one copy,
so there is nothing to sync and nothing that can drift.

Two cases genuinely still need copies, and this skill covers exactly those.

## Command

```
/propagate-templates
```

## Workflow

### 1. principled-docs scaffolding templates

Each generative skill ships the template it writes, so the scaffold templates are
duplicated on purpose. Copy each canonical template to its consuming skill:

1. `plugins/principled-docs/skills/scaffold/templates/core/proposal.md` → `plugins/principled-docs/skills/new-proposal/templates/proposal.md`
2. `plugins/principled-docs/skills/scaffold/templates/core/plan.md` → `plugins/principled-docs/skills/new-plan/templates/plan.md`
3. `plugins/principled-docs/skills/scaffold/templates/core/decision.md` → `plugins/principled-docs/skills/new-adr/templates/decision.md`
4. `plugins/principled-docs/skills/scaffold/templates/core/architecture.md` → `plugins/principled-docs/skills/new-architecture-doc/templates/architecture.md`

### 2. Cross-plugin `check-gh-cli.sh`

principled-github, principled-quality and principled-release install independently, and
`${CLAUDE_PLUGIN_ROOT}` resolves to a single plugin, so a script all three need has to
exist three times. Canonical lives in principled-github:

1. `plugins/principled-github/lib/check-gh-cli.sh` → `plugins/principled-quality/lib/check-gh-cli.sh`
2. `plugins/principled-github/lib/check-gh-cli.sh` → `plugins/principled-release/lib/check-gh-cli.sh`

### 3. Verify

```bash
bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh
bash scripts/check-cross-plugin-drift.sh
```

Both must report `PASS`.

Then confirm nothing references a path that no longer exists:

```bash
bash scripts/check-skill-references.sh
```

## What this skill does NOT cover

`lib/` contents in any plugin — `task-manifest.sh`, `parse-plan.sh`, `run-checks.sh`,
`task-db.sh`, `next-number.sh`, `validate-structure.sh`, `check-gh-cli.sh` within
principled-github. These have one copy each. Edit them in place; there is nothing to
propagate. If you find yourself copying one of these into a skill directory, that is a
regression against ADR-018.
