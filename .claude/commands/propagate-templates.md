Propagate canonical templates and scripts to all consuming skills, then verify zero drift.

## Workflow

### Template Propagation

Copy each canonical template to its consuming skill:

1. `skills/scaffold/templates/core/proposal.md` → `skills/new-proposal/templates/proposal.md`
2. `skills/scaffold/templates/core/plan.md` → `skills/new-plan/templates/plan.md`
3. `skills/scaffold/templates/core/decision.md` → `skills/new-adr/templates/decision.md`
4. `skills/scaffold/templates/core/architecture.md` → `skills/new-architecture-doc/templates/architecture.md`

### Script Propagation

Copy each canonical script to its consuming skill:

1. `skills/new-proposal/scripts/next-number.sh` → `skills/new-plan/scripts/next-number.sh`
2. `skills/new-proposal/scripts/next-number.sh` → `skills/new-adr/scripts/next-number.sh`
3. `skills/scaffold/scripts/validate-structure.sh` → `skills/validate/scripts/validate-structure.sh`

### Verification

Run `bash skills/scaffold/scripts/check-template-drift.sh` to confirm all copies are byte-identical to their canonical sources.

Report the result: PASS (zero drift) or FAIL (list drifted files).
