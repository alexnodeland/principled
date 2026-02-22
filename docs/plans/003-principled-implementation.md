---
title: "Principled Implementation Plugin"
number: "003"
status: complete
author: Alex
created: 2026-02-22
updated: 2026-02-22
originating_proposal: "006"
---

# Plan-003: Principled Implementation Plugin

## Objective

Implements [RFC-006](../proposals/006-principled-implementation-plugin.md).

Build the `principled-implementation` Claude Code plugin end-to-end: plugin infrastructure, all 6 skills, 1 agent definition, 1 advisory hook, 3 canonical scripts, 1 canonical template, drift detection, and a plugin README — following the directory layout and conventions established in the marketplace.

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **6 bounded contexts**, each representing a distinct area of domain responsibility within the plugin:

| #    | Bounded Context           | Responsibility                                                                            | Key Artifacts                                               |
| ---- | ------------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| BC-1 | **Plugin Infrastructure** | Plugin manifest, directory skeleton, marketplace integration                              | `plugin.json`, directory tree, marketplace.json entry       |
| BC-2 | **Plan Parsing**          | Extract metadata, phases, tasks, and dependencies from DDD plan markdown                  | `parse-plan.sh`, `decompose/SKILL.md`                       |
| BC-3 | **Manifest Management**   | Initialize, read, update, and query the `.impl/manifest.json` state file                  | `task-manifest.sh`, manifest schema, advisory hook          |
| BC-4 | **Agent & Spawning**      | Worktree-isolated sub-agent definition and task delegation                                | `impl-worker.md`, `spawn/SKILL.md`, `claude-task.md`        |
| BC-5 | **Validation**            | Discover and execute project checks against worktree implementations                      | `run-checks.sh`, `check-impl/SKILL.md`, check-discovery ref |
| BC-6 | **Orchestration**         | End-to-end lifecycle: decompose → spawn → validate → merge, with retry and error recovery | `orchestrate/SKILL.md`, `merge-work/SKILL.md`               |

### Aggregates

#### BC-1: Plugin Infrastructure

| Aggregate          | Root Entity   | Description                                                            |
| ------------------ | ------------- | ---------------------------------------------------------------------- |
| **PluginManifest** | `plugin.json` | Plugin identity, version, metadata, agent directory reference          |
| **DirectoryTree**  | Plugin root   | Complete directory skeleton for all skills, agents, hooks, and scripts |

#### BC-2: Plan Parsing

| Aggregate          | Root Entity          | Description                                                                              |
| ------------------ | -------------------- | ---------------------------------------------------------------------------------------- |
| **PlanParser**     | `parse-plan.sh`      | Extracts YAML frontmatter metadata and structured task data from DDD plan markdown files |
| **DecomposeSkill** | `decompose/SKILL.md` | User-facing skill that invokes plan parsing and manifest initialization                  |

#### BC-3: Manifest Management

| Aggregate          | Root Entity                   | Description                                                                                                          |
| ------------------ | ----------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **ManifestEngine** | `task-manifest.sh`            | CRUD interface for `.impl/manifest.json`: init, add-task, get-task, update-status, list-tasks, phase-status, summary |
| **ManifestGuard**  | `check-manifest-integrity.sh` | Advisory hook that warns against direct manifest edits                                                               |
| **KnowledgeBase**  | `impl-strategy/SKILL.md`      | Background knowledge for orchestration strategy, lifecycle, and manifest schema                                      |

#### BC-4: Agent & Spawning

| Aggregate        | Root Entity      | Description                                                                       |
| ---------------- | ---------------- | --------------------------------------------------------------------------------- |
| **AgentDef**     | `impl-worker.md` | Worktree-isolated agent with tools and skills for implementing a single plan task |
| **TaskTemplate** | `claude-task.md` | Sub-agent instruction template with placeholders for task context                 |
| **SpawnSkill**   | `spawn/SKILL.md` | Delegates a task to the `impl-worker` agent with pre-fork context injection       |

#### BC-5: Validation

| Aggregate          | Root Entity           | Description                                                                      |
| ------------------ | --------------------- | -------------------------------------------------------------------------------- |
| **CheckRunner**    | `run-checks.sh`       | Discovers and executes project checks (Node, Python, Rust, Go, Make, pre-commit) |
| **CheckImplSkill** | `check-impl/SKILL.md` | User-facing skill that runs checks and updates manifest status                   |

#### BC-6: Orchestration

| Aggregate            | Root Entity            | Description                                                                           |
| -------------------- | ---------------------- | ------------------------------------------------------------------------------------- |
| **MergeWorkSkill**   | `merge-work/SKILL.md`  | Merges validated branches, handles conflicts, cleans up worktrees                     |
| **OrchestrateSkill** | `orchestrate/SKILL.md` | End-to-end lifecycle: decomposes plan, iterates phases, spawns/validates/merges tasks |

### Domain Events

| Event                   | Source Context          | Target Context(s)    | Description                                                  |
| ----------------------- | ----------------------- | -------------------- | ------------------------------------------------------------ |
| **PlanDecomposed**      | BC-2 (Plan Parsing)     | BC-3, BC-6           | Plan parsed into manifest; tasks ready for execution         |
| **ManifestInitialized** | BC-3 (Manifest)         | BC-4, BC-5, BC-6     | Manifest created; spawning and validation can begin          |
| **TaskSpawned**         | BC-4 (Agent & Spawning) | BC-5 (Validation)    | Agent completed task; branch ready for validation            |
| **TaskValidated**       | BC-5 (Validation)       | BC-6 (Orchestration) | Checks passed/failed; orchestrator decides on merge or retry |
| **TaskMerged**          | BC-6 (Orchestration)    | BC-3 (Manifest)      | Branch merged; manifest updates to terminal state            |
| **TaskFailed**          | BC-5 (Validation)       | BC-6 (Orchestration) | Checks failed; orchestrator decides on retry or abandon      |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Plugin Skeleton & Infrastructure (BC-1)

**Goal:** Create the complete directory tree and plugin manifest.

- [x] **1.1** Create `plugins/principled-implementation/.claude-plugin/plugin.json` with name, version, description, author, homepage, keywords, agents directory reference
- [x] **1.2** Create the full directory skeleton: all skill directories, agent directory, hook directory, scripts directory, reference directories, template directories
- [x] **1.3** Add plugin entry to `.claude-plugin/marketplace.json` with category `implementation`

### Phase 2: Core Scripts & Knowledge Base (BC-2, BC-3)

**Goal:** Implement canonical scripts and background knowledge.

**Depends on:** Phase 1

- [x] **2.1** Implement `decompose/scripts/parse-plan.sh` (CANONICAL):
  - `--file <path> --metadata` mode: extract YAML frontmatter as key=value pairs
  - `--file <path> --tasks` mode: extract phases and tasks as pipe-delimited rows
  - `--file <path> --task-ids` mode: list task IDs only
  - Parse phase headers, dependency lines, task checkbox lines, bounded contexts
- [x] **2.2** Implement `decompose/scripts/task-manifest.sh` (CANONICAL):
  - `--init` with `--plan-path`, `--plan-number`, `--plan-title`
  - `--add-task` with `--task-id`, `--phase`, `--description`, optional `--depends-on`, `--bounded-contexts`
  - `--get-task`, `--get-plan-path`, `--update-status`, `--list-tasks`, `--phase-status`, `--summary`
  - jq primary with sed fallback for JSON operations
  - 8 task statuses: pending, in_progress, validating, passed, failed, merged, abandoned, conflict
- [x] **2.3** Implement `check-impl/scripts/run-checks.sh` (CANONICAL):
  - `--discover` mode: find available checks from package.json, Makefile, pytest, Cargo.toml, go.mod, .pre-commit-config.yaml
  - `--execute` mode: run discovered checks with 300s timeout per check
  - Pipe-delimited output format for discovery, PASS/FAIL reporting for execution
- [x] **2.4** Write `impl-strategy/reference/task-lifecycle.md`: 8-state machine with valid transitions, retry behavior, terminal states
- [x] **2.5** Write `impl-strategy/reference/orchestration-guide.md`: full lifecycle walkthrough, phase iteration, error recovery, decision framework
- [x] **2.6** Write `impl-strategy/reference/manifest-schema.md`: JSON schema, field descriptions, status values, script interface
- [x] **2.7** Write `check-impl/reference/check-discovery.md`: supported project types and their check commands

### Phase 3: SKILL.md Files & Agent Definition (BC-2, BC-3, BC-4, BC-5)

**Goal:** Write skill definitions and the agent.

**Depends on:** Phase 2

- [x] **3.1** Write `impl-strategy/SKILL.md`: background knowledge, non-invocable, references all three reference docs
- [x] **3.2** Write `decompose/SKILL.md`: user-invocable, parse plan and create manifest
- [x] **3.3** Write `spawn/SKILL.md`: user-invocable, `context: fork`, `agent: impl-worker`, backtick pre-fork commands for context injection
- [x] **3.4** Write `spawn/templates/claude-task.md` (CANONICAL): sub-agent instruction template with placeholders
- [x] **3.5** Write `agents/impl-worker.md`: worktree-isolated agent with tools and skills
- [x] **3.6** Write `check-impl/SKILL.md`: user-invocable, discover and execute checks, update manifest

### Phase 4: Orchestration & Merge Skills (BC-6)

**Goal:** Implement the orchestrator and merge skills.

**Depends on:** Phase 3

- [x] **4.1** Write `merge-work/SKILL.md`: user-invocable, merge validated branch, handle conflicts, cleanup worktree
- [x] **4.2** Write `orchestrate/SKILL.md`: user-invocable, end-to-end lifecycle with `--phase`, `--continue`, `--dry-run` support

### Phase 5: Hooks, Drift Detection & Script Propagation (BC-1, BC-3)

**Goal:** Implement advisory hook, propagate script copies, set up drift detection.

**Depends on:** Phase 3

- [x] **5.1** Implement `hooks/scripts/check-manifest-integrity.sh`: advisory hook, reads stdin JSON, warns on direct `.impl/manifest.json` edits, always exits 0
- [x] **5.2** Write `hooks/hooks.json`: PreToolUse hook for Edit|Write targeting manifest integrity script
- [x] **5.3** Propagate script copies:
  - `task-manifest.sh` → spawn, check-impl, merge-work, orchestrate (4 copies)
  - `parse-plan.sh` → orchestrate (1 copy)
  - `run-checks.sh` → orchestrate (1 copy)
  - `claude-task.md` → orchestrate (1 copy)
- [x] **5.4** Implement `scripts/check-template-drift.sh`: verify all 7 canonical-copy pairs, exit non-zero on drift

### Phase 6: Documentation (BC-1)

**Goal:** Write plugin README and finalize.

**Depends on:** Phases 4, 5

- [x] **6.1** Write plugin `README.md`:
  - Installation instructions
  - All 6 skills with command syntax and descriptions
  - Agent documentation (impl-worker, worktree isolation)
  - Hook documentation (manifest integrity advisory)
  - Task lifecycle state machine
  - Manifest schema overview
  - Script duplication and drift detection

---

## Decisions Required

Architectural decisions resolved during implementation:

1. **Task isolation strategy.** → ADR-007: Worktree isolation via `context: fork` + `agent: impl-worker`.
2. **Orchestration state management.** → ADR-008: JSON manifest at `.impl/manifest.json` managed by `task-manifest.sh`.
3. **Script sharing across skills.** → ADR-009: Copy-with-drift-detection, consistent with principled-docs convention.

---

## Dependencies

| Dependency                         | Required By        | Status              |
| ---------------------------------- | ------------------ | ------------------- |
| Claude Code v2.1.3+ (agents, fork) | spawn, impl-worker | Available           |
| Bash shell                         | All scripts        | Available           |
| Git (worktrees, branches)          | spawn, merge-work  | Available           |
| jq (optional, with sed fallback)   | task-manifest.sh   | Optional            |
| principled-docs plan format        | parse-plan.sh      | Stable (v0.3.1)     |
| Marketplace structure (RFC-002)    | Plugin location    | Complete (Plan-002) |

---

## Acceptance Criteria

- [x] `/decompose docs/plans/000-principled-docs.md` parses the plan and creates `.impl/manifest.json` with correct phases, tasks, and dependencies
- [x] `/spawn 1.1` creates a worktree, delegates to `impl-worker`, and produces a branch `impl/<plan>/1-1`
- [x] `/check-impl --task 1.1` discovers and runs available checks against the task's worktree
- [x] `/merge-work 1.1` merges the validated branch with a structured commit message and cleans up the worktree
- [x] `/orchestrate docs/plans/000-principled-docs.md --dry-run` decomposes the plan and reports without executing
- [x] `/orchestrate docs/plans/000-principled-docs.md` executes the full lifecycle: decompose → spawn → validate → merge for all tasks
- [x] `/orchestrate ... --continue` resumes from the last known manifest state
- [x] `check-manifest-integrity.sh` warns when editing `.impl/manifest.json` directly (advisory, never blocks)
- [x] `check-template-drift.sh` passes when all 7 copy pairs match canonical sources
- [x] `check-template-drift.sh` fails when any copy diverges
- [x] Plugin README documents all skills, agent, hook, and conventions
