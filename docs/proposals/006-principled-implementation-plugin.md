---
title: "Principled Implementation Plugin"
number: 006
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-22
supersedes: null
superseded_by: null
---

# RFC-006: Principled Implementation Plugin

## Audience

- Teams using the principled methodology who need automated plan execution
- Engineers responsible for implementing DDD-decomposed plans in monorepos
- Plugin maintainers evaluating the implementation orchestration layer
- Contributors to the principled marketplace

## Context

The principled pipeline produces high-quality specifications: proposals define what and why, ADRs record decisions, and plans decompose implementation into phased tasks organized by bounded context. But executing those plans is entirely manual — a developer reads the plan, works through each task sequentially, and tracks progress informally.

This creates several problems:

1. **No isolation between tasks.** When a developer works on multiple plan tasks in the same working tree, changes from one task can interfere with another. A failing test in task 2.1 might be caused by incomplete work in task 1.3, not by task 2.1 itself.

2. **No structured validation.** After implementing a task, a developer must remember to run tests, linters, and other checks. There is no automated validation step that connects plan tasks to project quality gates.

3. **No manifest tracking.** Plan progress is tracked by checking off markdown checkboxes in the plan document itself. There is no machine-readable manifest that records task status, branch names, retry counts, or validation results.

4. **No automated orchestration.** Executing a multi-phase plan with dependencies requires manual coordination: complete phase 1 tasks, verify they pass, merge them, then proceed to phase 2. This is tedious and error-prone.

5. **No agent delegation.** Claude Code supports forked sub-agents with worktree isolation, but there is no plugin that leverages this capability for plan execution. Each task could be delegated to an isolated agent that receives task context, implements the work, and reports results.

The principled-docs plugin produces well-structured plans with phases, dependencies, bounded contexts, and task definitions. What's missing is the automation layer that takes those plans and executes them.

## Proposal

Add a new first-party plugin, `principled-implementation`, to the marketplace. This plugin provides skills, hooks, and an agent for orchestrating DDD plan execution via worktree-isolated Claude Code sub-agents. It bridges specification to implementation by automating decomposition, isolated task execution, validation, and merge.

### 1. Plugin Structure

```
plugins/principled-implementation/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── impl-strategy/          # Background knowledge skill
│   │   ├── SKILL.md
│   │   └── reference/
│   │       ├── task-lifecycle.md
│   │       ├── orchestration-guide.md
│   │       └── manifest-schema.md
│   ├── decompose/              # Parse plan into manifest
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── parse-plan.sh   (CANONICAL)
│   │       └── task-manifest.sh (CANONICAL)
│   ├── spawn/                  # Delegate task to sub-agent
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   └── task-manifest.sh (COPY)
│   │   └── templates/
│   │       └── claude-task.md  (CANONICAL)
│   ├── check-impl/             # Run validation checks
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   ├── task-manifest.sh (COPY)
│   │   │   └── run-checks.sh  (CANONICAL)
│   │   └── reference/
│   │       └── check-discovery.md
│   ├── merge-work/             # Merge validated branch
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── task-manifest.sh (COPY)
│   └── orchestrate/            # End-to-end lifecycle
│       ├── SKILL.md
│       ├── scripts/
│       │   ├── parse-plan.sh   (COPY)
│       │   ├── task-manifest.sh (COPY)
│       │   └── run-checks.sh  (COPY)
│       └── templates/
│           └── claude-task.md  (COPY)
├── agents/
│   └── impl-worker.md
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── check-manifest-integrity.sh
├── scripts/
│   └── check-template-drift.sh
└── README.md
```

### 2. Skills

| Skill           | Command                                             | Category      | Description                                                            |
| --------------- | --------------------------------------------------- | ------------- | ---------------------------------------------------------------------- |
| `impl-strategy` | _(background — not user-invocable)_                 | Knowledge     | Deep context on orchestration strategy, task lifecycle, manifest schema |
| `decompose`     | `/decompose <plan-path>`                            | Analytical    | Parse a DDD plan into a structured `.impl/manifest.json`               |
| `spawn`         | `/spawn <task-id>`                                  | Orchestration | Execute a task in an isolated worktree via the `impl-worker` agent     |
| `check-impl`    | `/check-impl [--task <id>] [--all]`                 | Analytical    | Run project checks against a task's worktree implementation            |
| `merge-work`    | `/merge-work <task-id> [--force] [--no-cleanup]`    | Orchestration | Merge a validated branch back and clean up the worktree                |
| `orchestrate`   | `/orchestrate <plan-path> [--phase N] [--continue]` | Orchestration | End-to-end plan execution: decompose → spawn → validate → merge       |

#### `/decompose`

Parses a DDD plan file and creates a machine-readable manifest:

1. Verifies the plan file exists and has `status: active`
2. Extracts metadata (title, number, originating_proposal) via `parse-plan.sh --metadata`
3. Extracts phases and tasks via `parse-plan.sh --tasks`, parsing:
   - Phase headers: `### Phase N: Title (BC-X, BC-Y)`
   - Dependency lines: `**Depends on:** Phase N`
   - Task lines: `- [ ] **N.M** description`
4. Initializes `.impl/manifest.json` via `task-manifest.sh --init`
5. Populates all tasks with `pending` status
6. Reports decomposition summary

#### `/spawn`

Delegates a single task to the `impl-worker` agent:

- Uses `context: fork` and `agent: impl-worker` frontmatter to create a worktree-isolated sub-agent
- Injects task context via backtick pre-fork commands (task details, plan metadata, related tasks)
- Agent creates branch `impl/<plan-number>/<task-id>`, implements the task, runs available checks, and commits
- Updates manifest status to `in_progress` before delegation

#### `/check-impl`

Runs project quality gates against implementation:

1. Discovers available checks via `run-checks.sh --discover` (auto-detects from package.json, Makefile, pytest, Cargo.toml, go.mod, .pre-commit-config.yaml)
2. Executes checks via `run-checks.sh --execute` with 300-second timeout per check
3. Updates manifest: `passed` if all checks pass, `failed` if any fail
4. Reports per-check results with pass/fail status

#### `/merge-work`

Merges a validated task branch:

1. Verifies task status is `passed` (or `--force` to bypass)
2. Performs `git merge <branch> --no-ff` with structured commit message
3. Detects merge conflicts → sets status to `conflict`, pauses for manual resolution
4. Cleans up worktree and branch (unless `--no-cleanup`)
5. Updates manifest to `merged`

#### `/orchestrate`

End-to-end lifecycle automation:

1. Decomposes plan (or resumes with `--continue`)
2. Iterates phases respecting dependency ordering
3. For each task: spawn → validate → merge (or retry on failure, up to 2 retries)
4. Handles errors: retryable failures re-spawn with failure context, max retries → abandon, merge conflicts → pause
5. Reports phase and overall completion summaries
6. Supports `--dry-run` for planning and `--phase N` for partial execution

### 3. Agent

| Agent         | Isolation  | Tools                                 | Skills         |
| ------------- | ---------- | ------------------------------------- | -------------- |
| `impl-worker` | `worktree` | Read, Write, Edit, Bash, Glob, Grep  | impl-strategy  |

The `impl-worker` agent runs in a git worktree, providing filesystem isolation from the main working tree. It:

- Receives all task context in its prompt (stateless — no access to main worktree)
- Creates a named branch: `impl/<plan-number>/<task-id>`
- Implements the task, runs checks, commits changes
- Documents blockers in `.task-blockers.md` if blocked by out-of-scope issues
- Cannot push, merge, or modify the main branch

### 4. Task Lifecycle State Machine

```
pending → in_progress → validating → passed → merged (TERMINAL)
                │               │         │
                │               │         └→ conflict → merged (after manual resolve)
                │               │
                │               └→ failed → in_progress (retry, max 2)
                │                              │
                │                              └→ abandoned (TERMINAL)
                │
                └→ abandoned (TERMINAL)
```

Eight states: `pending`, `in_progress`, `validating`, `passed`, `failed`, `merged`, `abandoned`, `conflict`. Terminal states: `merged`, `abandoned`.

### 5. Manifest Schema

The `.impl/manifest.json` file is the single source of truth for plan execution state:

```json
{
  "version": "1.0.0",
  "plan": {
    "path": "docs/plans/001-feature.md",
    "number": "001",
    "title": "Feature Title",
    "decomposed_at": "2026-02-22T10:30:00Z"
  },
  "phases": [
    { "number": 1, "depends_on": [], "bounded_contexts": ["BC-auth"] },
    { "number": 2, "depends_on": [1], "bounded_contexts": ["BC-api"] }
  ],
  "tasks": [
    {
      "id": "1.1",
      "phase": 1,
      "description": "Set up database schema",
      "bounded_contexts": ["BC-data"],
      "status": "pending",
      "branch": null,
      "check_results": null,
      "error": null,
      "retries": 0,
      "created_at": "2026-02-22T10:30:00Z",
      "updated_at": "2026-02-22T10:30:00Z"
    }
  ]
}
```

### 6. Hooks

| Hook                        | Event                    | Script                          | Timeout | Behavior |
| --------------------------- | ------------------------ | ------------------------------- | ------- | -------- |
| Manifest Integrity Advisory | PreToolUse (Edit\|Write) | `check-manifest-integrity.sh`   | 10s     | Advisory |

Warns when `.impl/manifest.json` is being edited directly. Always exits 0. Reminds users to use skills (`/decompose`, `/spawn`, `/check-impl`, `/merge-work`) to manage the manifest.

### 7. Script Duplication

Three canonical scripts and one canonical template, with 7 total copy pairs:

| Canonical                             | Copies To                    |
| ------------------------------------- | ---------------------------- |
| `decompose/scripts/parse-plan.sh`     | `orchestrate/scripts/`       |
| `decompose/scripts/task-manifest.sh`  | `spawn/`, `check-impl/`, `merge-work/`, `orchestrate/` scripts |
| `check-impl/scripts/run-checks.sh`   | `orchestrate/scripts/`       |
| `spawn/templates/claude-task.md`      | `orchestrate/templates/`     |

`scripts/check-template-drift.sh` verifies all 7 pairs. Drift = CI failure.

### 8. Marketplace Integration

```json
{
  "name": "principled-implementation",
  "source": "./plugins/principled-implementation",
  "description": "Orchestrate DDD plan execution via worktree-isolated Claude Code agents.",
  "version": "0.1.0",
  "category": "implementation",
  "keywords": ["implementation", "orchestration", "worktree", "sub-agent", "ddd", "automation"]
}
```

### 9. Dependencies

- **Claude Code v2.1.3+** — Required for skills, agents, worktree isolation, and fork context
- **Bash** — All scripts are pure bash
- **Git** — Worktree management and branch operations
- **jq** — Optional; scripts fall back to grep/sed for JSON parsing
- **principled-docs** — Conceptual dependency (reads DDD plans produced by principled-docs). No runtime coupling.

## Alternatives Considered

### Alternative 1: Manual task execution with manifest tracking only

Provide only `/decompose` and manifest management — no agent delegation, no orchestration. Developers execute tasks manually and update the manifest via CLI skills.

**Rejected because:** This reduces the plugin to a task tracker, losing the key value proposition: automated, isolated task execution. The principled pipeline's plans are specifically structured for automated decomposition and execution. Manual execution with manifest tracking is a useful subset but doesn't leverage Claude Code's agent capabilities.

### Alternative 2: Single-agent execution without worktree isolation

Execute tasks in the main working tree using the main Claude Code session, without sub-agents or worktrees.

**Rejected because:** Without isolation, task implementations interfere with each other. A failing task leaves partial changes in the working tree that affect subsequent tasks. Worktree isolation ensures each task starts from a clean state and can be independently validated and merged.

### Alternative 3: Parallel task execution within phases

Spawn all tasks in a phase simultaneously, leveraging Claude Code's ability to run multiple sub-agents in parallel.

**Rejected because:** Claude Code's sub-agent model supports sequential spawning, not parallel. The orchestrator runs inline (not forked) and invokes `/spawn` sequentially. Additionally, parallel merges would create complex merge conflict scenarios. Sequential execution within phases is simpler and more predictable. Tasks within a phase are parallelizable in principle, but the current infrastructure executes them sequentially.

## Consequences

### Positive

- **Automated plan execution.** Teams can go from spec to implementation with a single `/orchestrate` command.
- **Worktree isolation.** Each task runs in its own git worktree, preventing cross-contamination between tasks.
- **Structured validation.** Auto-discovered checks run against each task before merge, catching issues early.
- **Manifest tracking.** Machine-readable state tracking with retry counts, branch names, and check results — far richer than markdown checkboxes.
- **Error recovery.** Automatic retry with failure context, merge conflict detection, and resume capability via `--continue`.
- **Phase-aware orchestration.** Respects dependency ordering from DDD plans, ensuring prerequisite phases complete before dependent phases begin.

### Negative

- **Sub-agent limitations.** Sub-agents cannot spawn sub-agents. The orchestrator must run inline, which means it occupies the main Claude Code session during execution.
- **Git worktree overhead.** Each task creates a full worktree, which uses disk space and requires clean state. Large repos with many tasks may hit storage constraints.
- **Pure bash JSON manipulation.** The `task-manifest.sh` script manipulates JSON using jq (with sed fallback). Complex manifest operations are fragile without a proper JSON library.

### Risks

- **Plan format coupling.** `parse-plan.sh` parses specific markdown patterns (phase headers, task lines, dependency annotations). Changes to principled-docs' plan template would require script updates.
- **Check discovery completeness.** `run-checks.sh` auto-discovers checks from common project configuration files. Projects with non-standard check configurations may have poor coverage.
- **Worktree merge conflicts.** If multiple tasks modify the same files, sequential merges will encounter conflicts. The plugin handles this by pausing, but frequent conflicts degrade the automated workflow.

## Architecture Impact

- **[Plugin System Architecture](../architecture/plugin-system.md)** — Add the implementation layer with its agent model and orchestration pattern.
- **[Documentation Pipeline](../architecture/documentation-pipeline.md)** — Extend the pipeline to include automated execution as the stage after plan creation.

This plugin motivates the following architectural decisions:
- ADR-007: Worktree isolation for sub-agent task execution
- ADR-008: Manifest-driven orchestration state management
- ADR-009: Script duplication across implementation skills

## Open Questions

1. **Sub-agent parallelism.** If Claude Code adds support for parallel sub-agent spawning, should `/orchestrate` be updated to spawn tasks within a phase concurrently? This would require conflict-aware merge strategies.

2. **Cross-plan orchestration.** Should `/orchestrate` support executing multiple related plans in sequence (e.g., when plan B depends on plan A's completion)?

3. **Manifest versioning.** As the manifest schema evolves, how should backward compatibility be handled? Should the version field trigger migrations?
