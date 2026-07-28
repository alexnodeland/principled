---
agent_id: "impl-worker"
role: worker
last_updated: 2026-07-28
session_count: 2
total_tasks: 5
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
- A test that mutates state the same way the code inspects it proves agreement, not
  correctness. `check-skill-references.sh` compared a path plugin-wide while its test
  renamed the path plugin-wide, so twelve green tests hid a live defect. When writing a
  test for a checker, break the thing in a way the checker was _not_ written to see.

## Pitfalls

- Do not build JSON test payloads with `echo`: zsh expands `\n` and corrupts them, and a
  hook that appears to "allow" may simply have received garbage. Use
  `python3 -c 'json.dumps'` into a file.
- A `case " $list " in *" $item "*)` membership test needs **space** separators. `sort -u`
  and `grep -o` emit newlines, so the glob silently never matches. Normalize with
  `tr '\n' ' '` first.
