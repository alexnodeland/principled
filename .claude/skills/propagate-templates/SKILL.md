---
name: propagate-templates
description: >
  Propagate canonical templates and scripts to all consuming skills,
  then verify zero drift. Use after updating any canonical template
  or script to keep all copies in sync.
allowed-tools: Bash(cp *), Bash(bash plugins/*)
user-invocable: true
---

# Propagate Templates — Canonical Copy Sync

Propagate canonical templates and scripts to all consuming skills, then verify zero drift.

## Command

```
/propagate-templates
```

## Workflow

### principled-docs — Template Propagation

Copy each canonical template to its consuming skill:

1. `plugins/principled-docs/skills/scaffold/templates/core/proposal.md` → `plugins/principled-docs/skills/new-proposal/templates/proposal.md`
2. `plugins/principled-docs/skills/scaffold/templates/core/plan.md` → `plugins/principled-docs/skills/new-plan/templates/plan.md`
3. `plugins/principled-docs/skills/scaffold/templates/core/decision.md` → `plugins/principled-docs/skills/new-adr/templates/decision.md`
4. `plugins/principled-docs/skills/scaffold/templates/core/architecture.md` → `plugins/principled-docs/skills/new-architecture-doc/templates/architecture.md`

### principled-docs — Script Propagation

Copy each canonical script to its consuming skill:

1. `plugins/principled-docs/skills/new-proposal/scripts/next-number.sh` → `plugins/principled-docs/skills/new-plan/scripts/next-number.sh`
2. `plugins/principled-docs/skills/new-proposal/scripts/next-number.sh` → `plugins/principled-docs/skills/new-adr/scripts/next-number.sh`
3. `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh` → `plugins/principled-docs/skills/validate/scripts/validate-structure.sh`

### principled-implementation — Script Propagation

Copy each canonical script to its consuming skills:

1. `plugins/principled-implementation/skills/decompose/scripts/task-manifest.sh` → `plugins/principled-implementation/skills/spawn/scripts/task-manifest.sh`
2. `plugins/principled-implementation/skills/decompose/scripts/task-manifest.sh` → `plugins/principled-implementation/skills/check-impl/scripts/task-manifest.sh`
3. `plugins/principled-implementation/skills/decompose/scripts/task-manifest.sh` → `plugins/principled-implementation/skills/merge-work/scripts/task-manifest.sh`
4. `plugins/principled-implementation/skills/decompose/scripts/task-manifest.sh` → `plugins/principled-implementation/skills/orchestrate/scripts/task-manifest.sh`
5. `plugins/principled-implementation/skills/decompose/scripts/parse-plan.sh` → `plugins/principled-implementation/skills/orchestrate/scripts/parse-plan.sh`
6. `plugins/principled-implementation/skills/check-impl/scripts/run-checks.sh` → `plugins/principled-implementation/skills/orchestrate/scripts/run-checks.sh`

### principled-implementation — Template Propagation

1. `plugins/principled-implementation/skills/spawn/templates/claude-task.md` → `plugins/principled-implementation/skills/orchestrate/templates/claude-task.md`

### Verification

Run both drift checks:

1. `bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh`
2. `bash plugins/principled-implementation/scripts/check-template-drift.sh`

Confirm all copies are byte-identical to their canonical sources. Report the result per plugin: PASS (zero drift) or FAIL (list drifted files).
