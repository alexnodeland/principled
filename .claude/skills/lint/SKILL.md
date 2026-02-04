---
name: lint
description: >
  Run the full lint suite for this repository: shell formatting (shfmt),
  shell lint (ShellCheck), Markdown lint (markdownlint-cli2), and Markdown
  formatting (Prettier). Use before committing to ensure code quality.
allowed-tools: Bash(shfmt *), Bash(shellcheck *), Bash(find *), Bash(npx markdownlint-cli2 *), Bash(npx prettier *)
user-invocable: true
---

# Lint — Full Quality Suite

Run the full lint suite for this repository and report results.

## Command

```
/lint
```

## Workflow

1. **Shell formatting check** — run `shfmt -i 2 -bn -sr -d` on all `.sh` files under `skills/` and `hooks/`. Report any files that need formatting.

2. **Shell lint** — run `shellcheck --shell=bash` on all `.sh` files under `skills/` and `hooks/`. Report any warnings or errors.

3. **Markdown lint** — run `npx markdownlint-cli2 '**/*.md'`. Report any rule violations.

4. **Markdown formatting check** — run `npx prettier --check '**/*.md'`. Report any files that need formatting.

5. **Summary** — report the total number of errors per tool and list all affected files. If everything passes, confirm the repo is lint-clean.

If any tool reports errors, suggest the fix command (e.g., `shfmt -w`, `prettier --write`).
