---
name: check-ci
description: >
  Run the full CI pipeline locally, mirroring the checks in
  .github/workflows/ci.yml. Use to verify everything passes before
  pushing.
allowed-tools: Bash(shfmt *), Bash(shellcheck *), Bash(find *), Bash(npx markdownlint-cli2 *), Bash(npx prettier *), Bash(bash plugins/*), Bash(echo *), Bash(jq *), Bash(python3 *)
user-invocable: true
---

# Check CI — Local CI Pipeline

Run the full CI pipeline locally, mirroring the checks in `.github/workflows/ci.yml`.

## Command

```
/check-ci
```

## Workflow

Run each check in sequence. Stop and report if any check fails.

### 1. Shell Formatting (lint-shell)

```bash
find . -name '*.sh' -not -path './node_modules/*' | xargs shfmt -i 2 -bn -sr -d
```

### 2. Shell Lint (lint-shell)

```bash
find . -name '*.sh' -not -path './node_modules/*' | xargs shellcheck --shell=bash
```

### 3. Markdown Lint (lint-markdown)

```bash
npx markdownlint-cli2 '**/*.md'
```

### 4. Markdown Formatting (lint-markdown)

```bash
npx prettier --check '**/*.md'
```

### 5. Template Drift — principled-docs (validate)

```bash
bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh
```

### 6. Template Drift — principled-implementation (validate)

```bash
bash plugins/principled-implementation/scripts/check-template-drift.sh
```

### 7. Template Drift — principled-github (validate)

```bash
bash plugins/principled-github/scripts/check-template-drift.sh
```

### 8. Template Drift — principled-quality (validate)

```bash
bash plugins/principled-quality/scripts/check-template-drift.sh
```

### 9. Template Drift — principled-release (validate)

```bash
bash plugins/principled-release/scripts/check-template-drift.sh
```

### 10. Root Structure Validation (validate)

```bash
bash plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --root
```

### 11. Marketplace Manifest Validation (validate)

Verify `.claude-plugin/marketplace.json` is valid JSON and all plugin source directories exist.

### 12. Plugin Manifest Validation (validate)

Verify every plugin in `plugins/*/` and `external_plugins/*/` has a valid `.claude-plugin/plugin.json`.

### 13. Smoke-test ADR Immutability Hook (validate)

For each `docs/decisions/*.md` with `status: accepted`, feed its path to `check-adr-immutability.sh` and verify exit code 2 (block). Also test a non-decision file and verify exit code 0 (allow).

### 14. Smoke-test Proposal Lifecycle Hook (validate)

For each `docs/proposals/*.md` with terminal status, feed its path to `check-proposal-lifecycle.sh` and verify exit code 2. For draft proposals, verify exit code 0.

### 15. Smoke-test Manifest Integrity Hook (validate)

Feed `.impl/manifest.json` path to `check-manifest-integrity.sh` and verify exit code 0 (advisory). Feed an unrelated path and verify exit code 0 (silent passthrough).

### 16. Smoke-test PR Reference Hook (validate)

Feed `gh pr create --title "test" --body "test"` command to `check-pr-references.sh` and verify exit code 0 (advisory). Feed an unrelated command and verify exit code 0 (silent passthrough).

### 17. Smoke-test Review Checklist Hook (validate)

Feed `gh pr review 42` and `gh pr merge 42` commands to `check-review-checklist.sh` and verify exit code 0 (advisory). Feed an unrelated command and verify exit code 0 (silent passthrough).

### 18. Smoke-test Release Readiness Hook (validate)

Feed `git tag v1.0.0` command to `check-release-readiness.sh` and verify exit code 0 (advisory). Feed `git tag -l` and verify exit code 0 (silent passthrough). Feed an unrelated command and verify exit code 0 (silent passthrough).

### Summary

Report pass/fail for each step. If all pass, confirm the repo is CI-clean. If any fail, list the failures and suggest fixes.
