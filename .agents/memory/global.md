---
scope: global
last_updated: 2026-07-28
---

# Global Agent Memory

Knowledge that applies to every agent in this repository. Keep this curated: every
byte here is injected into every agent's context.

## Conventions

- Shared code lives in each plugin's `lib/`, referenced as
  `${CLAUDE_PLUGIN_ROOT}/lib/<name>` (ADR-018). Never copy a `lib/` script into a skill
  directory, and never reference a sibling plugin's `lib/` — plugins install
  independently, so `${CLAUDE_PLUGIN_ROOT}` cannot reach across the boundary.
- `scripts/check-skill-references.sh` fails on a bare relative path as well as a missing
  one. A path only resolves at runtime if it goes through `${CLAUDE_PLUGIN_ROOT}`.

## Shell constraints

- Stock macOS ships bash 3.2. No `declare -A`, no `local -n`, no `mapfile`, no
  `${var,,}`, no `grep -P`.
- **Never use `sed -i`.** BSD sed reads the next argument as a backup suffix, so
  `sed -i <expr> <file>` misparses on macOS while working on Linux. Use `awk` into a
  temp file and `mv`. This silently broke the no-jq path of `task-manifest.sh` for
  every status update and every task after the first.
- `jq` is optional everywhere. Every script needs a working fallback, and the fallback
  must be tested with a PATH that genuinely lacks `jq` — trimming PATH to `/usr/bin:/bin`
  does not work, because `jq` lives in `/usr/bin` on macOS.
- Prefer bash built-ins over subprocesses for validation: `[[ "$v" =~ ^[0-9]+$ ]]` beats
  piping to `grep`, and removes a dependency from the fallback path.

## Hooks

- Guard scripts default to allow. Exit 0 = allow, exit 2 = block. Never exit 1 — that is
  reserved for script errors.
- Advisory hooks always exit 0. A hook on `SubagentStart` that exits non-zero blocks
  agent spawning entirely.

## Pipeline

- Accepted ADRs and terminal-status proposals are immutable and hook-enforced. Make every
  edit to a document _before_ moving it to a terminal status, in the same pass.
