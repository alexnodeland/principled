---
name: agent-init
description: >
  Scaffold the .agents/ directory in a repository: identity registry, global and
  per-agent memory files, and the retrospectives directory. Idempotent — safe to
  run on a repository that is already initialized. Use when setting up agent
  memory for the first time.
allowed-tools: Read, Write, Bash(bash plugins/*), Bash(bash scripts/*), Bash(git add *), Bash(git commit *), Bash(mkdir *), Bash(ls *)
user-invocable: true
---

# Agent Init — Scaffold `.agents/`

Create the agent identity and memory structure at the repository root.

## Command

```
/agent-init [--commit]
```

## Arguments

| Argument   | Required | Description                           |
| ---------- | -------- | ------------------------------------- |
| `--commit` | No       | Commit the scaffold after creating it |

## What gets created

```
.agents/
  registry.json          # Agent identity registry — who exists, who carries memory
  memory/
    global.md            # Knowledge applying to every agent
    agents/
      impl-worker.md     # One file per memory-bearing agent
      issue-ingester.md
      pr-reviewer.md
  retrospectives/        # Post-execution retrospectives
```

`.agents/` is **committed to git**, unlike `.claude/agent-memory/` which is gitignored.
It is shared team knowledge reviewable in pull requests, not session-local scratch.

## Workflow

1. **Scaffold.** Idempotent — existing files are left untouched:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --init
   ```

2. **Verify.** Confirm the registry parses and every `memory: true` agent has a file:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --check
   ```

3. **Seed global memory (optional but recommended).** The scaffold leaves
   `.agents/memory/global.md` with an empty Conventions section. Fill it with
   repository-wide facts every agent should not have to rediscover — build commands,
   language and runtime constraints, layout conventions.

   Keep it short. Global memory is injected for _every_ agent, so it is the most
   expensive place to put anything.

4. **Commit** when `--commit` is passed:

   ```bash
   git add .agents/
   git commit -m "chore: scaffold agent memory (.agents/)"
   ```

5. **Report.** Show the created tree, which agents carry memory and which do not (with
   the registry's rationale), and point to `/agent-memory <id>` for viewing and editing.

## Notes

- Safe to re-run. Existing memory files are never overwritten.
- Adding a new memory-bearing agent means adding it to `registry.json` with
  `"memory": true` and re-running `/agent-init` to seed its file.

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh` — memory and registry interface (ADR-018)
