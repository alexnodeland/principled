---
name: test-hooks
description: >
  Run the enforcement hook test suite and interpret failures. Covers all 11 hooks
  across the seven plugins, including the no-jq fallback path that a naive PATH
  restriction fails to exercise.
allowed-tools: Bash(npx bats *), Bash(just *), Bash(echo *), Bash(bash plugins/*), Read
user-invocable: true
---

# Test Hooks — Enforcement Hook Test Suite

Hook behaviour is covered by `tests/hooks.bats`. This skill runs it and helps interpret
what a failure means.

## Command

```
/test-hooks
```

## Workflow

### 1. Run the suite

```bash
npx bats tests/hooks.bats
```

Or the whole suite (hooks plus the task graph library):

```bash
just test
```

### 2. Interpret the result

The suite has four groups. Which one fails tells you what broke.

**Guard behaviour** — an accepted ADR must block (exit 2), a non-decision file must
allow (exit 0). A failure here means the guard's frontmatter parsing or path matching
regressed.

**No-jq fallback** — the same assertions with `jq` genuinely absent. A failure here
means the grep/sed fallback broke while the jq path still works, so it will pass on any
machine that has jq and fail silently for everyone else.

> The suite builds a directory of symlinks to the tools hooks need, excluding jq, and
> points `PATH` at it. Trimming `PATH` to `/usr/bin:/bin` does **not** work — jq lives
> at `/usr/bin/jq`, so the hook takes the jq branch and the fallback goes untested.
> That is how PCRE-only `grep -oP` fallbacks survived in five plugins.

**Hostile input** — empty, malformed, and missing-field payloads. Every hook must exit
0 or 2, never 1. Exit 1 means the script itself errored.

**Corpus-wide** — every accepted ADR is blocked, every terminal-status proposal is
blocked, every draft proposal is editable, every pipeline document passes the
frontmatter guard. A failure here usually means one document has a frontmatter shape
the guard does not handle, rather than a broken guard.

### 3. Reproduce a single case by hand

```bash
echo '{"tool_input":{"file_path":"docs/decisions/001-frontmatter-parsing-strategy.md"}}' \
  | bash plugins/principled-docs/hooks/scripts/check-adr-immutability.sh
echo $?   # 0 = allow, 2 = block, 1 = the script errored (always a bug)
```

Advisory hooks take `tool_input.command` instead:

```bash
echo '{"tool_input":{"command":"gh pr create --title x"}}' \
  | bash plugins/principled-github/hooks/scripts/check-pr-references.sh
```

## Conventions

- **Exit 0 = allow, exit 2 = block. Never exit 1** — that is reserved for script errors.
- **Guards default to allow.** They block only when they can positively confirm a
  violation. This is deliberate, and it is why the tests matter: a broken guard fails
  open and silent, with no symptom until something slips through.
- **`jq` is optional.** Every hook has a grep/sed fallback, and it must be POSIX —
  `grep -P` is unavailable on stock macOS.
