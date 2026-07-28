---
name: agent-memory
description: >
  Inspect and curate agent memory: show what an agent has learned, list memory
  sizes against the context budget, record a durable learning, and reset
  performance metrics after a fork. Use when reviewing what agents know or when
  a memory file has grown past its budget.
allowed-tools: Read, Write, Edit, Bash(bash plugins/*), Bash(bash scripts/*), Bash(git add *), Bash(git commit *), Bash(ls *)
user-invocable: true
---

# Agent Memory — Inspect and Curate

View, add to, and prune what agents have learned.

## Command

```
/agent-memory [<agent-id>] [--list] [--learn "<fact>"] [--reset-metrics] [--check]
```

## Arguments

| Argument           | Required | Description                                              |
| ------------------ | -------- | -------------------------------------------------------- |
| `<agent-id>`       | No       | Agent to inspect (e.g. `impl-worker`). Omit to list all  |
| `--list`           | No       | Table of every agent's memory size and metrics           |
| `--learn "<fact>"` | No       | Append a durable fact to the agent's Known Patterns      |
| `--reset-metrics`  | No       | Zero performance counters, leaving knowledge intact      |
| `--check`          | No       | Validate structure and report against the context budget |

## Workflow

### Showing memory

With an agent id and no other flag, display the file:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --show --agent "<agent-id>"
```

Report the metrics from frontmatter, the size against the budget, and the knowledge
body. If the file is over 8 KB, say so and offer to synthesize.

### Listing

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --list
```

Flag any agent over the soft budget as a synthesis candidate.

### Recording a learning

With `--learn`, append to the agent's `## Known Patterns` section using Edit. Before
writing, apply the standard from `agent-strategy`:

- Is it **durable** — still true after every current task closes?
- Is it **certain**? Memory is asserted to future agents as fact. Record a hedge as a
  hedge, or not at all.
- Is it **not already there**? Prefer sharpening an existing line over adding a near
  duplicate; duplicates are how files reach the budget.

Then update metrics if a session is being recorded:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --update-metrics \
  --agent "<agent-id>" --session --tasks <n> --succeeded <n>
```

### Synthesizing an oversized file

When `--check` reports a file over budget, **rewrite rather than truncate**. Read the
whole body, merge overlapping notes into fewer denser statements, drop anything no
longer true, and write it back with Edit. Preserve the frontmatter exactly — metrics are
script-owned.

Never delete the tail of the file to fit. Losing knowledge invisibly is the failure mode
the budget exists to prevent, not a way to satisfy it.

### Resetting metrics after a fork

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --reset-metrics [--agent "<agent-id>"]
```

Knowledge transfers across a fork because it describes code the fork still has.
Performance history does not, because it was earned against a different repository.

## Reporting

State plainly what changed, what the file now weighs against the budget, and — for a
`--learn` — the exact line added, so it can be reviewed or reverted.

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh` — memory and registry interface (ADR-018)
