---
title: "Hooks, Subagents, and Agent Teams Integration"
number: "008"
status: active
author: Alex
created: 2026-02-23
updated: 2026-02-23
originating_proposal: "008"
related_adrs: "015, 016"
---

# Plan-008: Hooks, Subagents, and Agent Teams Integration

## Objective

Implements [RFC-008](../proposals/008-hooks-subagents-agent-teams-integration.md).

Expand the principled marketplace's automation layer across all six first-party plugins: add guard and lifecycle hooks for deterministic enforcement, define new subagents for context-protected parallel analysis, integrate agent teams for concurrent plan execution, and upgrade existing agent definitions with new frontmatter capabilities.

---

## Related Decisions

- [ADR-015: Event-Driven Lifecycle Hooks for Pipeline Enforcement](../decisions/015-event-driven-lifecycle-hooks.md) — governs the hook expansion strategy
- [ADR-016: Agent Teams for Parallel Plan Execution](../decisions/016-agent-teams-for-parallel-execution.md) — governs the agent teams integration model
- [ADR-001: Pure Bash Frontmatter Parsing Strategy](../decisions/001-frontmatter-parsing-strategy.md) — parsing utility that new guard hooks depend on
- [ADR-007: Worktree Isolation for Task Execution](../decisions/007-worktree-isolation-for-task-execution.md) — isolation model for agents
- [ADR-008: Manifest-Driven Orchestration State](../decisions/008-manifest-driven-orchestration-state.md) — state model that persists alongside agent teams
- [ADR-009: Script Duplication Across Implementation Skills](../decisions/009-script-duplication-across-implementation-skills.md) — copy-with-drift convention for new shared scripts
- [ADR-014: Heuristic Architecture Governance](../decisions/014-heuristic-architecture-governance.md) — governance model the boundary-checker agent builds upon

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **6 bounded contexts**, each representing a distinct area of domain responsibility:

| #    | Bounded Context                | Responsibility                                                                     | Key Artifacts                                                          |
| ---- | ------------------------------ | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| BC-1 | **Document Enforcement**       | Guard hooks for pipeline document creation: frontmatter, numbering, proposal links | 3 guard scripts, updated `hooks.json` in principled-docs               |
| BC-2 | **Lifecycle Hooks**            | Event-driven hooks for worktree and subagent lifecycle management                  | 4 lifecycle scripts, updated `hooks.json` in principled-implementation |
| BC-3 | **Async & Advisory Hooks**     | Background drift checking and ADR supersession validation                          | 2 hook scripts, async hook configuration across plugins                |
| BC-4 | **Subagent Definitions**       | New agent definitions for parallel analytical work                                 | 5 agent `.md` files across 4 plugins                                   |
| BC-5 | **Agent Frontmatter Upgrades** | Upgrade impl-worker and configure new agents with modern frontmatter fields        | Updated `impl-worker.md`, agent memory configuration                   |
| BC-6 | **Agent Teams Integration**    | Parallel orchestration via agent teams with fallback to sequential execution       | Updated `orchestrate/SKILL.md`, team lifecycle hooks, settings         |

### Aggregates

#### BC-1: Document Enforcement

| Aggregate             | Root Entity                     | Description                                             |
| --------------------- | ------------------------------- | ------------------------------------------------------- |
| **PlanProposalGuard** | `check-plan-proposal-link.sh`   | Validates plans reference an accepted proposal          |
| **FrontmatterGuard**  | `check-required-frontmatter.sh` | Validates required frontmatter fields per document type |
| **NumberingGuard**    | `check-doc-numbering.sh`        | Validates document number uniqueness within directories |

#### BC-2: Lifecycle Hooks

| Aggregate               | Root Entity                     | Description                                                 |
| ----------------------- | ------------------------------- | ----------------------------------------------------------- |
| **WorktreeSetup**       | `setup-impl-worktree.sh`        | Initializes task state in new worktrees on `WorktreeCreate` |
| **WorktreeCleanup**     | `cleanup-impl-worktree.sh`      | Archives state and updates manifest on `WorktreeRemove`     |
| **CompletionValidator** | `validate-worker-completion.sh` | Ensures impl-worker updated manifest on `SubagentStop`      |
| **TaskGate**            | `gate-task-completion.sh`       | Enforces quality checks before task completion              |

#### BC-3: Async & Advisory Hooks

| Aggregate                 | Root Entity                 | Description                                          |
| ------------------------- | --------------------------- | ---------------------------------------------------- |
| **AsyncDriftChecker**     | `async-drift-check.sh`      | Background drift detection on template/script writes |
| **SupersessionValidator** | `check-adr-supersession.sh` | Validates ADR supersession chain integrity           |

#### BC-4: Subagent Definitions

| Aggregate           | Root Entity           | Description                                                |
| ------------------- | --------------------- | ---------------------------------------------------------- |
| **ModuleAuditor**   | `module-auditor.md`   | Batch module validation agent for principled-docs          |
| **IssueIngester**   | `issue-ingester.md`   | Single-issue triage agent for principled-github            |
| **PRReviewer**      | `pr-reviewer.md`      | Comprehensive PR review agent for principled-quality       |
| **BoundaryChecker** | `boundary-checker.md` | Module boundary scanning agent for principled-architecture |
| **DecisionAuditor** | `decision-auditor.md` | ADR consistency audit agent for principled-docs            |

#### BC-5: Agent Frontmatter Upgrades

| Aggregate             | Root Entity          | Description                                                     |
| --------------------- | -------------------- | --------------------------------------------------------------- |
| **ImplWorkerUpgrade** | `impl-worker.md`     | Add maxTurns, memory, scoped hooks to existing agent definition |
| **AgentMemoryConfig** | `.gitignore` updates | Configure agent memory directory handling                       |

#### BC-6: Agent Teams Integration

| Aggregate              | Root Entity               | Description                                                   |
| ---------------------- | ------------------------- | ------------------------------------------------------------- |
| **TeamOrchestrator**   | `orchestrate/SKILL.md`    | Refactored orchestrator with agent teams support and fallback |
| **TeamSettings**       | `.claude/settings.json`   | Environment variable configuration for agent teams enablement |
| **TeamLifecycleHooks** | `gate-task-completion.sh` | TaskCompleted and TeammateIdle hooks for team coordination    |

### Domain Events

| Event                      | Source Context      | Target Context(s) | Description                                                 |
| -------------------------- | ------------------- | ----------------- | ----------------------------------------------------------- |
| **DocumentWriteAttempted** | User/Skill          | BC-1              | Pipeline document write triggers guard hook validation      |
| **WorktreeCreated**        | Claude Code runtime | BC-2              | Worktree lifecycle event triggers setup hook                |
| **WorktreeRemoved**        | Claude Code runtime | BC-2              | Worktree lifecycle event triggers cleanup hook              |
| **WorkerCompleted**        | impl-worker agent   | BC-2              | SubagentStop event triggers completion validation           |
| **TaskMarkedComplete**     | Agent teams runtime | BC-2, BC-6        | TaskCompleted event triggers quality gate                   |
| **TemplateFileWritten**    | User/Skill          | BC-3              | Script/template write triggers async drift check            |
| **ADRSuperseded**          | User/Skill          | BC-3              | ADR superseded_by update triggers chain validation          |
| **AuditRequested**         | /docs-audit skill   | BC-4              | Module auditor agents spawned for parallel validation       |
| **TriageRequested**        | /triage skill       | BC-4              | Issue ingester agents spawned for parallel processing       |
| **PhaseExecutionStarted**  | orchestrate skill   | BC-6              | Phase begins: populate team task list or spawn sequentially |
| **TeammateIdled**          | Agent teams runtime | BC-6              | Idle teammate reassigned to review or cleanup               |

---

## Implementation Tasks

Tasks are organized by phase, with each phase mapping to one or more bounded contexts. Dependencies between phases are explicit.

### Phase 1: Document Enforcement Guard Hooks (BC-1)

**Goal:** Close the three critical enforcement gaps in pipeline document creation.

- [ ] **1.1** Implement `plugins/principled-docs/hooks/scripts/check-plan-proposal-link.sh`:
  - Read stdin JSON, extract `file_path` (jq with grep fallback)
  - Check if file is in `*/plans/*.md`; exit 0 if not
  - Check if file already exists; exit 0 if new file creation (let frontmatter guard handle field presence)
  - Extract `originating_proposal` from the file being written via `parse-frontmatter.sh`
  - Resolve the referenced proposal file (zero-padded number lookup in `*/proposals/`)
  - Extract proposal `status` via `parse-frontmatter.sh`
  - Exit 2 if proposal doesn't exist or status is not `accepted`; exit 0 otherwise

- [ ] **1.2** Implement `plugins/principled-docs/hooks/scripts/check-required-frontmatter.sh`:
  - Read stdin JSON, extract `file_path`
  - Determine document type from path: `*/proposals/*.md`, `*/plans/*.md`, `*/decisions/*.md`
  - Exit 0 if file doesn't match any pipeline document pattern
  - Read the file content being written (from `tool_input.content` for Write, or file on disk for Edit)
  - Extract and validate required fields per type using `parse-frontmatter.sh`:
    - Proposals: `status` in `(draft|in-review|accepted|rejected|superseded)`
    - Plans: `status` in `(active|complete|abandoned)`, `originating_proposal` present
    - Decisions: `status` in `(proposed|accepted|deprecated|superseded)`
  - Exit 2 with descriptive message listing missing/invalid fields; exit 0 if valid

- [ ] **1.3** Implement `plugins/principled-docs/hooks/scripts/check-doc-numbering.sh`:
  - Read stdin JSON, extract `file_path`
  - Check if file matches `*/proposals/NNN-*.md`, `*/plans/NNN-*.md`, or `*/decisions/NNN-*.md`
  - Exit 0 if pattern doesn't match
  - Extract the NNN prefix from the filename
  - Scan the parent directory for other files with the same NNN prefix
  - Exit 0 if no duplicates found or if the only match is the file itself (re-write)
  - Exit 2 if a different file with the same number exists

- [ ] **1.4** Update `plugins/principled-docs/hooks/hooks.json`:
  - Add `check-plan-proposal-link.sh` as PreToolUse guard on `Write`
  - Add `check-required-frontmatter.sh` as PreToolUse guard on `Edit|Write`
  - Add `check-doc-numbering.sh` as PreToolUse guard on `Write`
  - Preserve existing ADR immutability and proposal lifecycle guards

- [ ] **1.5** Write tests for all three guard hooks:
  - Test each hook with valid and invalid inputs
  - Verify exit codes: 0 for allow, 2 for block
  - Test edge cases: non-pipeline files, new file creation, re-write of same file
  - Test jq and grep fallback paths

### Phase 2: Implementation Lifecycle Hooks (BC-2)

**Goal:** Add event-driven lifecycle management for worktrees and subagent completion.

**Depends on:** Phase 1

- [ ] **2.1** Implement `plugins/principled-implementation/hooks/scripts/setup-impl-worktree.sh`:
  - Read stdin JSON (WorktreeCreate event context)
  - Check if an active `.impl/manifest.json` exists in the main worktree
  - If manifest exists, create `.impl/` directory in the new worktree with a symlink or copy of the manifest
  - Always exit 0 (advisory, never blocks worktree creation)

- [ ] **2.2** Implement `plugins/principled-implementation/hooks/scripts/cleanup-impl-worktree.sh`:
  - Read stdin JSON (WorktreeRemove event context)
  - Extract worktree path
  - If `.impl/` exists in the worktree, archive any logs to main worktree's `.impl/logs/`
  - Update manifest if a task was associated with this worktree
  - Always exit 0 (advisory)

- [ ] **2.3** Implement `plugins/principled-implementation/hooks/scripts/validate-worker-completion.sh`:
  - Read stdin JSON (SubagentStop event context with agent name)
  - Filter: only act on `impl-worker` agents, exit 0 for others
  - Check manifest for tasks in `in_progress` status that match the completed agent's context
  - If tasks remain `in_progress` with no status update, exit 2 with message explaining the worker failed to update the manifest
  - If tasks were properly transitioned, exit 0

- [ ] **2.4** Implement `plugins/principled-implementation/hooks/scripts/gate-task-completion.sh`:
  - Read stdin JSON (TaskCompleted event context with `task_id`)
  - Look up task in `.impl/manifest.json`
  - Verify `check_results` field is populated and all checks passed
  - Exit 2 if checks haven't run or failed; exit 0 if checks passed
  - Only active when agent teams are enabled

- [ ] **2.5** Update `plugins/principled-implementation/hooks/hooks.json`:
  - Add `setup-impl-worktree.sh` on `WorktreeCreate`
  - Add `cleanup-impl-worktree.sh` on `WorktreeRemove`
  - Add `validate-worker-completion.sh` on `SubagentStop`
  - Add `gate-task-completion.sh` on `TaskCompleted`
  - Preserve existing manifest integrity advisory

- [ ] **2.6** Write tests for lifecycle hooks:
  - Test WorktreeCreate with and without active manifest
  - Test WorktreeRemove cleanup behavior
  - Test SubagentStop with proper and improper task transitions
  - Test TaskCompleted with passing and failing check results

### Phase 3: Async & Advisory Hooks (BC-3)

**Goal:** Add background drift checking and ADR supersession validation.

**Depends on:** Phase 1

- [ ] **3.1** Implement `plugins/principled-docs/hooks/scripts/async-drift-check.sh`:
  - Read stdin JSON, extract `file_path` from PostToolUse Write response
  - Check if file is within `plugins/*/skills/*/scripts/` or `plugins/*/skills/*/templates/`
  - Exit 0 immediately if not a template/script path
  - Determine which plugin the file belongs to
  - Run that plugin's `check-template-drift.sh` script
  - Output drift warnings to stderr (surfaced on next conversation turn via async)
  - Always exit 0 (advisory)

- [ ] **3.2** Configure async drift hook in `plugins/principled-docs/hooks/hooks.json`:
  - Add PostToolUse hook on `Write` with `async: true`
  - Matcher: `Write` tool
  - Script: `async-drift-check.sh`

- [ ] **3.3** Implement `plugins/principled-docs/hooks/scripts/check-adr-supersession.sh`:
  - Read stdin JSON, extract `file_path` from PostToolUse Write response
  - Check if file is in `*/decisions/*.md`; exit 0 if not
  - Extract `superseded_by` field via `parse-frontmatter.sh`
  - Exit 0 if field is `null` or empty
  - Resolve the referenced ADR file (zero-padded number lookup)
  - Check that the superseding ADR exists and has status `accepted`
  - Check for circular chains (A superseded_by B, B superseded_by A)
  - Output warnings to stderr (advisory)
  - Always exit 0

- [ ] **3.4** Add `check-adr-supersession.sh` to `plugins/principled-docs/hooks/hooks.json` as PostToolUse advisory on `Write`

### Phase 4: Subagent Definitions (BC-4)

**Goal:** Define 5 new subagents across 4 plugins for parallel analytical work.

**Depends on:** Phase 1

- [ ] **4.1** Create `plugins/principled-docs/agents/module-auditor.md`:
  - Frontmatter: name, description, tools (Read, Glob, Grep, Bash), model (haiku), background (true), maxTurns (50)
  - System prompt: validate documentation structure for assigned modules, run `validate-structure.sh`, report per-module compliance
  - Reference the module type system (ADR-003) and validation criteria

- [ ] **4.2** Create `plugins/principled-docs/agents/decision-auditor.md`:
  - Frontmatter: name, description, tools (Read, Glob, Grep), model (haiku), background (true), maxTurns (30)
  - System prompt: scan all ADRs, check supersession chains, detect orphaned references, validate status transitions
  - Reference ADR lifecycle rules

- [ ] **4.3** Create `plugins/principled-github/agents/issue-ingester.md`:
  - Frontmatter: name, description, tools (Read, Write, Bash, Glob, Grep), model (inherit), maxTurns (30), skills (github-strategy)
  - System prompt: process a single GitHub issue through the triage pipeline — normalize, classify, create documents, apply labels

- [ ] **4.4** Create `plugins/principled-quality/agents/pr-reviewer.md`:
  - Frontmatter: name, description, tools (Read, Glob, Grep, Bash), model (inherit), background (true), maxTurns (50), skills (quality-strategy)
  - System prompt: perform comprehensive review of a single PR — checklist, context, coverage, summary — and return synthesized report

- [ ] **4.5** Create `plugins/principled-architecture/agents/boundary-checker.md`:
  - Frontmatter: name, description, tools (Read, Glob, Grep), model (haiku), background (true), maxTurns (30)
  - System prompt: scan assigned modules for architectural boundary violations using import analysis, report violations with ADR references
  - Reference the heuristic governance model (ADR-014)

- [ ] **4.6** Update each plugin's `.claude-plugin/plugin.json` to reference their new agents directory (if not already present)

### Phase 5: Agent Frontmatter Upgrades (BC-5)

**Goal:** Upgrade impl-worker and configure agent memory across the ecosystem.

**Depends on:** Phases 2, 4

- [ ] **5.1** Update `plugins/principled-implementation/agents/impl-worker.md`:
  - Add `maxTurns: 100` to prevent runaway execution
  - Add `memory: project` for cross-session knowledge accumulation
  - Add scoped `hooks` with Stop event for `validate-worker-completion.sh`
  - Use `$CLAUDE_PLUGIN_ROOT` for portable script paths
  - Preserve existing fields: name, description, isolation, tools, skills

- [ ] **5.2** Add `.claude/agent-memory/` to `.gitignore`:
  - Agent memory is session-local knowledge, not shared repository state
  - Add comment explaining the entry

- [ ] **5.3** Document agent memory governance in root `CLAUDE.md`:
  - Add section explaining `memory: project` field and its purpose
  - Note that memory files are gitignored and session-local
  - Recommend periodic pruning for long-running projects

### Phase 6: Agent Teams Integration (BC-6)

**Goal:** Enable parallel orchestration via agent teams with graceful fallback.

**Depends on:** Phases 2, 4, 5

- [ ] **6.1** Update `.claude/settings.json` to document agent teams configuration:
  - Add commented `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` entry in env section
  - Document the opt-in nature and fallback behavior

- [ ] **6.2** Refactor `plugins/principled-implementation/skills/orchestrate/SKILL.md`:
  - Add detection logic: check if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set
  - When enabled: populate agent teams task list from manifest, spawn teammates per independent task, use task dependency tracking for ordering
  - When disabled: use existing sequential `/spawn` loop (no behavior change)
  - Add documentation section explaining both execution modes
  - Reference ADR-016 for the architectural decision

- [ ] **6.3** Add `TeammateIdle` handling to orchestrate skill:
  - When a teammate finishes its task and others are still running, reassign to review or cleanup work
  - Document the reassignment strategy in the skill's reference docs

- [ ] **6.4** Update `plugins/principled-implementation/skills/impl-strategy/reference/orchestration-guide.md`:
  - Add section on agent teams execution mode
  - Document the dual state model (task list + manifest)
  - Explain the fallback guarantee
  - Add decision framework: when to use agent teams vs. sequential

- [ ] **6.5** Update root `CLAUDE.md`:
  - Add agent teams to the Architecture table
  - Update the Agents section to list all 6 agents (1 existing + 5 new)
  - Update the Hooks section to reflect new hook events and counts
  - Update the Dogfooding section to note agent teams availability
  - Reference RFC-008, ADR-015, ADR-016

### Phase 7: Documentation & Validation (BC-1 through BC-6)

**Goal:** Update all documentation, run validation, ensure CI readiness.

**Depends on:** Phase 6

- [ ] **7.1** Update `plugins/principled-docs/README.md`:
  - Document 3 new guard hooks with trigger conditions and behavior
  - Document async drift advisory hook
  - Document ADR supersession advisory hook
  - Document 2 new agents (module-auditor, decision-auditor)

- [ ] **7.2** Update `plugins/principled-implementation/README.md`:
  - Document 4 new lifecycle hooks
  - Document agent teams integration and fallback behavior
  - Document impl-worker frontmatter upgrades
  - Update task lifecycle state machine if needed

- [ ] **7.3** Update `plugins/principled-github/README.md`:
  - Document issue-ingester agent

- [ ] **7.4** Update `plugins/principled-quality/README.md`:
  - Document pr-reviewer agent

- [ ] **7.5** Update `plugins/principled-architecture/README.md`:
  - Document boundary-checker agent

- [ ] **7.6** Run full CI validation:
  - ShellCheck and shfmt on all new `.sh` files
  - markdownlint-cli2 and Prettier on all new `.md` files
  - Template drift checks for all 6 plugins
  - Structure validation via `/validate --root`
  - Marketplace manifest validation

- [ ] **7.7** Update `/test-hooks` skill to include test cases for all new hooks:
  - Plan-proposal link guard: valid/invalid proposal references
  - Required frontmatter guard: complete/incomplete frontmatter per doc type
  - Document numbering guard: unique/duplicate numbers
  - Lifecycle hooks: WorktreeCreate, WorktreeRemove, SubagentStop, TaskCompleted
  - Async drift check: template file write triggers background check
  - ADR supersession: valid/invalid/circular chains

---

## Dependencies

| Dependency                                   | Required By              | Status                   |
| -------------------------------------------- | ------------------------ | ------------------------ |
| Claude Code v2.1.3+ (agents, fork)           | All phases               | Available                |
| Claude Code v2.1.50+ (WorktreeCreate/Remove) | Phase 2                  | Available                |
| Claude Code agent teams (experimental)       | Phase 6                  | Available (experimental) |
| Bash shell                                   | All hook scripts         | Available                |
| Git (worktrees, branches)                    | Phase 2, 6               | Available                |
| jq (optional, with grep/sed fallback)        | All hook scripts         | Optional                 |
| `parse-frontmatter.sh` (principled-docs)     | Phase 1                  | Available (v0.3.1)       |
| `validate-structure.sh` (principled-docs)    | Phase 4 (module-auditor) | Available (v0.3.1)       |
| Marketplace structure (RFC-002)              | Plugin locations         | Complete (Plan-002)      |
| principled-implementation plugin (RFC-006)   | Phase 2, 5, 6            | Complete (Plan-003)      |

---

## Acceptance Criteria

- [ ] `check-plan-proposal-link.sh` blocks writing a plan without an accepted proposal (exit 2) and allows valid plans (exit 0)
- [ ] `check-required-frontmatter.sh` blocks documents with missing or invalid frontmatter and allows valid documents
- [ ] `check-doc-numbering.sh` blocks duplicate document numbers and allows unique numbers and re-writes
- [ ] `setup-impl-worktree.sh` initializes `.impl/` in new worktrees when a manifest exists
- [ ] `cleanup-impl-worktree.sh` archives state when worktrees are removed
- [ ] `validate-worker-completion.sh` rejects impl-worker completion when tasks are orphaned in `in_progress`
- [ ] `gate-task-completion.sh` rejects task completion when quality checks have not passed
- [ ] `async-drift-check.sh` runs drift checks in the background after template/script writes
- [ ] `check-adr-supersession.sh` warns about invalid or circular supersession chains
- [ ] All 5 new agents are loadable via `/agents` command and have valid frontmatter
- [ ] `impl-worker.md` includes `maxTurns`, `memory`, and scoped hooks
- [ ] `/orchestrate` uses agent teams when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set
- [ ] `/orchestrate` falls back to sequential execution when agent teams are disabled
- [ ] All new hook scripts pass ShellCheck and shfmt
- [ ] All new markdown files pass markdownlint-cli2 and Prettier
- [ ] Template drift checks pass for all 6 plugins
- [ ] `/test-hooks` includes test cases for all new hooks
