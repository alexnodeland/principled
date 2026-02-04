---
name: check-ci
description: >
  Run the full CI pipeline locally, mirroring the checks in
  .github/workflows/ci.yml. Use to verify everything passes before
  pushing.
allowed-tools: Bash(shfmt *), Bash(shellcheck *), Bash(find *), Bash(npx markdownlint-cli2 *), Bash(npx prettier *), Bash(bash skills/*), Bash(bash hooks/*), Bash(echo *)
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

### 5. Template Drift (validate)

```bash
bash skills/scaffold/scripts/check-template-drift.sh
```

### 6. Root Structure Validation (validate)

```bash
bash skills/scaffold/scripts/validate-structure.sh --root
```

### Summary

Report pass/fail for each step. If all pass, confirm the repo is CI-clean. If any fail, list the failures and suggest fixes.
