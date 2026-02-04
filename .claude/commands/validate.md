Run template drift check and full structure validation for this repository.

## Workflow

1. **Template drift check** — run `bash skills/scaffold/scripts/check-template-drift.sh`. This verifies all template copies are byte-identical to their canonical sources.

2. **Root structure validation** — run `bash skills/scaffold/scripts/validate-structure.sh --root`. This checks that the repo-level `docs/` directory has the expected structure (proposals, plans, decisions, architecture).

3. **Summary** — report pass/fail for each check. If template drift is detected, list the drifted files and their canonical sources. If structure validation fails, list missing directories or files.
