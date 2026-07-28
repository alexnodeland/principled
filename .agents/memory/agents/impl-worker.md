---
agent_id: "impl-worker"
role: worker
last_updated: 2026-07-28
session_count: 1
total_tasks: 4
success_rate: 1.00
specializations: []
---

# impl-worker — Accumulated Knowledge

## Known Patterns

- A `.md` reference is functional coupling here, not documentation: a SKILL.md
  instructing the model to read a path _is_ the read. Scoping a search to `.sh` misses
  the real readers.
- Prettier reflows markdown table column widths whenever a cell's length changes. Parse
  tables by cell content, never by column position — and never trust a string-replace
  against a table row to have applied, because a no-op replace fails silently.

## Pitfalls

- Do not build JSON test payloads with `echo`: zsh expands `\n` and corrupts them, and a
  hook that appears to "allow" may simply have received garbage. Use
  `python3 -c 'json.dumps'` into a file.
- A `case " $list " in *" $item "*)` membership test needs **space** separators. `sort -u`
  and `grep -o` emit newlines, so the glob silently never matches. Normalize with
  `tr '\n' ' '` first.
- Never use `sed -i` — BSD sed reads the next argument as a backup suffix, so the same
  invocation behaves differently on macOS and Linux. Use `awk` into a temp file and `mv`.
