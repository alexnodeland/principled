---
name: decompose
description: >
  Decompose a DDD plan into executable tasks with dependency ordering.
  Reads a plan file, extracts phases, bounded contexts, and individual
  tasks, then creates a task manifest for orchestration. Use when you
  have an active DDD plan ready for implementation.
allowed-tools: Read, Write, Bash(ls *), Bash(grep *), Bash(find *), Bash(mkdir *), Bash(bash plugins/*)
user-invocable: true
---

# Decompose — DDD Plan Task Extraction

Extract concrete, executable tasks from a DDD implementation plan and create a task manifest for orchestrated execution.

## Command

```
/decompose <plan-path>
```

## Arguments

| Argument      | Required | Description                                                    |
| ------------- | -------- | -------------------------------------------------------------- |
| `<plan-path>` | Yes      | Path to a DDD plan file (e.g., `docs/plans/001-my-feature.md`) |

## Workflow

1. **Parse arguments.** Extract `<plan-path>` from `$ARGUMENTS`.

2. **Verify the plan.** Read the plan file and confirm:
   - File exists and has YAML frontmatter
   - `status` is `active` (do not decompose `complete` or `abandoned` plans)
   - If not active, report: _"Cannot decompose plan: status is '\<status\>'. Only active plans can be decomposed."_

3. **Extract plan metadata.** Run:

   ```bash
   bash scripts/parse-plan.sh --file <plan-path> --metadata
   ```

   Captures: title, number, originating_proposal.

4. **Extract phases and tasks.** Run:

   ```bash
   bash scripts/parse-plan.sh --file <plan-path> --tasks
   ```

   Outputs pipe-delimited structured data: phase number, task ID, description, dependencies, and bounded contexts per task.

5. **Create `.impl/` directory** if it does not exist:

   ```bash
   mkdir -p .impl
   ```

6. **Initialize task manifest.** Run:

   ```bash
   bash scripts/task-manifest.sh --init \
     --plan-path <plan-path> \
     --plan-number <number> \
     --plan-title "<title>"
   ```

7. **Add each task to the manifest.** For each extracted task:

   ```bash
   bash scripts/task-manifest.sh --add-task \
     --task-id <phase.task> \
     --phase <phase-number> \
     --description "<task description>" \
     --depends-on "<comma-separated-phase-deps>" \
     --bounded-contexts "<BC-N,BC-M>"
   ```

8. **Report results.** Display:
   - Plan title and number
   - Number of phases extracted
   - Number of tasks per phase
   - Dependency graph summary (which phases depend on which)
   - Path to manifest: `.impl/manifest.json`
   - Next step: _"Run `/spawn <task-id>` to execute a single task, or `/orchestrate <plan-path>` for automated execution."_

## Scripts

- `scripts/parse-plan.sh` — Extract metadata and tasks from DDD plan markdown (canonical copy)
- `scripts/task-manifest.sh` — Initialize and populate task manifest (canonical copy)
