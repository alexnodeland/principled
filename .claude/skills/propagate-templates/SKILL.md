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

### Template Propagation

Copy each canonical template to its consuming skill:

1. `plugins/principled-docs/skills/scaffold/templates/core/proposal.md` → `plugins/principled-docs/skills/new-proposal/templates/proposal.md`
2. `plugins/principled-docs/skills/scaffold/templates/core/plan.md` → `plugins/principled-docs/skills/new-plan/templates/plan.md`
3. `plugins/principled-docs/skills/scaffold/templates/core/decision.md` → `plugins/principled-docs/skills/new-adr/templates/decision.md`
4. `plugins/principled-docs/skills/scaffold/templates/core/architecture.md` → `plugins/principled-docs/skills/new-architecture-doc/templates/architecture.md`

### Script Propagation

Copy each canonical script to its consuming skill:

1. `plugins/principled-docs/skills/new-proposal/scripts/next-number.sh` → `plugins/principled-docs/skills/new-plan/scripts/next-number.sh`
2. `plugins/principled-docs/skills/new-proposal/scripts/next-number.sh` → `plugins/principled-docs/skills/new-adr/scripts/next-number.sh`
3. `plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh` → `plugins/principled-docs/skills/validate/scripts/validate-structure.sh`

### Verification

Run `bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh` to confirm all copies are byte-identical to their canonical sources.

Report the result: PASS (zero drift) or FAIL (list drifted files).
