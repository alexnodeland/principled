---
title: "Hooks, Subagents, and Agent Teams Integration"
number: 008
status: draft
author: Alex
created: 2026-02-23
updated: 2026-02-23
supersedes: null
superseded_by: null
---

# RFC-008: Hooks, Subagents, and Agent Teams Integration

## Audience

- Teams using the principled methodology who want stronger deterministic enforcement and faster parallel execution
- Plugin maintainers responsible for the six first-party plugins
- Contributors evaluating the principled marketplace's automation layer
- Engineers managing large monorepos where sequential validation and execution are bottlenecks

## Context

The principled marketplace (v1.0.0) ships six first-party plugins with 41 skills, 10 hooks, and 1 subagent. The ecosystem is heavily skill-driven: users invoke slash commands for validation, generation, analysis, and orchestration. Hooks and subagents play supporting roles — hooks provide lightweight guardrails, and the single `impl-worker` agent handles isolated task execution.

Three structural gaps have emerged:

### 1. Enforcement gaps in the hook layer

The 10 existing hooks cover only a subset of the principled methodology's constraints. Two guard hooks protect document immutability (ADR and proposal lifecycle), and eight advisory hooks nudge toward best practices. But several critical policies are unenforced:

- **Plans can be created without an accepted proposal.** The `/new-plan` skill requires `--from-proposal NNN`, but nothing prevents writing a plan file manually without that link.
- **Pipeline documents can be created without required frontmatter.** A proposal with no `status` field silently bypasses lifecycle guards.
- **Document numbers can be duplicated.** The `next-number.sh` script prevents this during skill-based creation, but manual file creation has no guardrail.
- **Subagent completion is unvalidated.** When `impl-worker` finishes, nothing ensures it actually committed changes or updated the manifest. Orphaned in-progress tasks can result.
- **Worktree lifecycle is manual.** Setup and teardown of `.impl/` directories and worktree state are embedded in skill scripts rather than handled by lifecycle events.

### 2. Single subagent, sequential execution

Only `principled-implementation` defines a subagent (`impl-worker`). The remaining five plugins process all work inline in the main session, which creates two problems:

- **Context window pressure.** Skills like `/docs-audit`, `/triage`, `/arch-drift`, and `/review-coverage` perform extensive read-heavy analysis that fills the main context window. When a user chains multiple analytical skills in a session, compaction becomes frequent and context is lost.
- **Sequential bottleneck.** The `/orchestrate` skill spawns tasks sequentially within each phase, even when tasks within a phase have no interdependencies. Similarly, `/triage` processes issues one at a time, and `/docs-audit` validates modules sequentially.

### 3. Platform capabilities are underutilized

Claude Code has evolved significantly since the principled plugins were built. The platform now offers:

- **17 hook events** (up from 3 used): `SubagentStart`, `SubagentStop`, `WorktreeCreate`, `WorktreeRemove`, `TaskCompleted`, `TeammateIdle`, `SessionStart`, `UserPromptSubmit`, `PermissionRequest`, `ConfigChange`, and more.
- **3 hook handler types**: `command` (shell scripts, currently used), `prompt` (single-turn LLM evaluation), and `agent` (multi-turn subagent with tool access).
- **Agent teams**: Multi-session parallel execution with shared task lists, dependency tracking, inter-agent messaging, and file-lock-based task claiming.
- **Agent frontmatter fields**: `maxTurns`, `memory`, `background`, `isolation: worktree`, scoped `hooks`, and `skills` preloading.
- **Async hooks**: Background execution that doesn't block the user.

None of these capabilities are used in the current plugin ecosystem.

## Proposal

Expand the principled marketplace's use of hooks, subagents, and agent teams across all six plugins. This proposal has three layers:

### Layer 1: Hook Expansion — Deterministic Enforcement

Add new hooks that close enforcement gaps and leverage new hook events. All hooks follow the existing philosophy: guards block only when confident of a violation; advisories nudge without gating.

#### 1.1 New Guard Hooks (principled-docs)

**Plan-Proposal Link Guard** — `check-plan-proposal-link.sh`

- Event: `PreToolUse` matching `Write`
- Triggers on: files in `*/plans/*.md`
- Validates: `originating_proposal` frontmatter field exists and references a proposal with `status: accepted`
- Blocks: creation of plans without a valid accepted proposal
- Uses: `parse-frontmatter.sh` (existing shared utility)

**Required Frontmatter Guard** — `check-required-frontmatter.sh`

- Event: `PreToolUse` matching `Write`
- Triggers on: files in `*/proposals/*.md`, `*/plans/*.md`, `*/decisions/*.md`
- Validates per document type:
  - Proposals: `status` must be one of `draft`, `in-review`, `accepted`, `rejected`, `superseded`
  - Plans: `status` must be one of `active`, `complete`, `abandoned`; `originating_proposal` must be present
  - Decisions: `status` must be one of `proposed`, `accepted`, `deprecated`, `superseded`
- Blocks: documents with missing or invalid required frontmatter fields
- Uses: `parse-frontmatter.sh`

**Document Number Uniqueness Guard** — `check-doc-numbering.sh`

- Event: `PreToolUse` matching `Write`
- Triggers on: files matching `*/proposals/NNN-*.md`, `*/plans/NNN-*.md`, `*/decisions/NNN-*.md`
- Validates: the `NNN` prefix is unique within its directory (allows re-writing the same file)
- Blocks: creation of a file with a duplicate number

#### 1.2 New Lifecycle Hooks (principled-implementation)

**Worktree Setup Hook** — `setup-impl-worktree.sh`

- Event: `WorktreeCreate`
- Triggers on: all worktree creation events
- Action: initializes `.impl/` directory in the new worktree if the current plan context requires it
- Non-blocking (always exits 0)

**Worktree Cleanup Hook** — `cleanup-impl-worktree.sh`

- Event: `WorktreeRemove`
- Triggers on: all worktree removal events
- Action: archives worktree-specific logs and updates manifest to reflect worktree removal
- Non-blocking

**Subagent Completion Validator** — `validate-worker-completion.sh`

- Event: `SubagentStop` matching `impl-worker`
- Action: verifies that the impl-worker:
  - Created at least one commit on its task branch
  - Updated the manifest status from `in_progress` to a terminal state (`passed`, `failed`, `abandoned`)
- Exits 2 to reject completion if the worker left tasks in `in_progress` without updating status

**Task Completion Gate** — `gate-task-completion.sh`

- Event: `TaskCompleted`
- Action: when orchestrating via agent teams, ensures quality checks passed before a task can be marked complete
- Exits 2 to reject completion if checks haven't been run or if they failed

#### 1.3 Async Advisory Hooks (cross-plugin)

**Async Template Drift Check** — `async-drift-check.sh`

- Event: `PostToolUse` matching `Write`, with `async: true`
- Triggers on: writes to `.sh` or `.md` files within `plugins/*/skills/*/scripts/` or `plugins/*/skills/*/templates/`
- Action: runs the relevant plugin's `check-template-drift.sh` in the background
- Surfaces drift warnings on the next conversation turn without blocking the write
- Benefits all six plugins

#### 1.4 ADR Supersession Validator (principled-docs)

**ADR Supersession Chain Advisory** — `check-adr-supersession.sh`

- Event: `PostToolUse` matching `Write`
- Triggers on: ADR files with a `superseded_by` field
- Validates: the referenced superseding ADR exists and has status `accepted`; no circular chains
- Advisory only (exits 0), since the `superseded_by` update is the one exception allowed through the immutability guard

### Layer 2: Subagent Expansion — Context Protection

Define new subagents that offload read-heavy analytical work from the main context window. Each agent runs in its own context, performs focused analysis, and returns a summary — protecting the main session from compaction pressure.

#### 2.1 Module Auditor (principled-docs)

```yaml
---
name: module-auditor
description: Validates documentation structure for a batch of modules
tools: Read, Glob, Grep, Bash
model: haiku
background: true
maxTurns: 50
---
```

- Invoked by `/docs-audit` to validate modules in parallel batches
- Receives module paths and type expectations
- Runs `validate-structure.sh` per module
- Returns per-module compliance results as structured summary
- Background execution lets the user continue working

#### 2.2 Issue Ingester (principled-github)

```yaml
---
name: issue-ingester
description: Processes a single GitHub issue through the principled triage pipeline
tools: Read, Write, Bash, Glob, Grep
model: inherit
maxTurns: 30
skills: github-strategy
---
```

- Invoked by `/triage` for parallel issue processing
- Receives issue number and repository context
- Normalizes metadata, classifies, creates documents, applies labels
- Returns created document paths and classification results

#### 2.3 PR Reviewer (principled-quality)

```yaml
---
name: pr-reviewer
description: Performs comprehensive review analysis of a single pull request
tools: Read, Glob, Grep, Bash
model: inherit
background: true
maxTurns: 50
skills: quality-strategy
---
```

- Invoked by a new `/review-batch` skill or directly by the user
- Runs all four review dimensions: checklist, context, coverage, summary
- Returns a synthesized review report
- Background execution for non-blocking analysis

#### 2.4 Boundary Checker (principled-architecture)

```yaml
---
name: boundary-checker
description: Scans modules for architectural boundary violations
tools: Read, Glob, Grep
model: haiku
background: true
maxTurns: 30
---
```

- Invoked by `/arch-drift` for parallel module scanning
- Receives module paths and dependency rules
- Scans imports against module type hierarchy (ADR-003, ADR-014)
- Returns violations with severity and ADR references

#### 2.5 Decision Auditor (principled-docs)

```yaml
---
name: decision-auditor
description: Audits ADR consistency across the repository
tools: Read, Glob, Grep
model: haiku
background: true
maxTurns: 30
---
```

- New capability with no existing skill equivalent
- Scans all ADRs for supersession chain integrity
- Detects orphaned references, invalid status transitions, circular chains
- Returns a consistency report

### Layer 3: Agent Teams — Parallel Orchestration

Adopt Claude Code's experimental agent teams feature for multi-task parallel execution. This directly addresses the sequential bottleneck in `/orchestrate` and opens new patterns for cross-plugin coordination.

#### 3.1 Parallel Plan Execution (principled-implementation)

Refactor `/orchestrate` to use agent teams when executing tasks within a phase:

- **Team lead**: the orchestrator session, responsible for decomposition, phase transitions, and result synthesis
- **Teammates**: one per task within the current phase, each working in its own worktree
- **Task list**: populated from the DDD plan's phase structure, with dependency tracking
- **Lifecycle hooks**: `TaskCompleted` enforces quality gates; `TeammateIdle` reassigns finished teammates to review or cleanup work

Current sequential flow:

```
Lead → spawn(task-1) → wait → spawn(task-2) → wait → spawn(task-3) → merge-all
```

Agent teams flow:

```
Lead → spawn teammates → task-1, task-2, task-3 run in parallel → merge-all
```

The task list's built-in dependency tracking handles ordering automatically. Tasks that depend on earlier phases remain blocked until those phases complete.

#### 3.2 Multi-PR Review (principled-quality)

Enable parallel review of multiple PRs:

- **Team lead**: assigns PRs to teammates
- **Teammates**: each runs the full review suite for one PR
- **Mailbox**: teammates share findings that may affect other PRs (e.g., discovering a shared dependency issue)

#### 3.3 Monorepo Audit (principled-docs)

Enable parallel module validation:

- **Team lead**: discovers all modules, partitions into batches
- **Teammates**: each validates a batch of modules
- **Task list**: one task per module, all independent (no dependencies)
- **Result synthesis**: lead aggregates per-module results into the audit report

#### 3.4 Configuration

Enable agent teams via settings:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Skills that support agent teams should gracefully fall back to sequential execution when agent teams are disabled, ensuring backward compatibility.

### Layer 4: Agent Frontmatter Upgrades

Upgrade existing and new agent definitions with newly available frontmatter fields:

#### 4.1 impl-worker Upgrades

```yaml
---
name: impl-worker
description: Executes a single DDD task in an isolated worktree
isolation: worktree
tools: Read, Write, Edit, Bash, Glob, Grep
skills: impl-strategy
model: inherit
maxTurns: 100
memory: project
hooks:
  - event: Stop
    command: "bash $CLAUDE_PLUGIN_ROOT/hooks/scripts/validate-worker-completion.sh"
---
```

- `maxTurns: 100` — prevents runaway agents from consuming unlimited context
- `memory: project` — accumulates implementation patterns, common test failures, and project conventions in `.claude/agent-memory/impl-worker/MEMORY.md`
- Scoped `Stop` hook — validates task completion before the agent finishes
- `$CLAUDE_PLUGIN_ROOT` — portable script references within the plugin

#### 4.2 All New Agents

All new agents defined in Layer 2 use:

- `maxTurns` — bounded execution to prevent runaway behavior
- `background: true` — where appropriate, for non-blocking analysis
- `model: haiku` — for read-heavy analysis agents where speed and cost matter more than generation quality
- Scoped tool restrictions — read-only agents get only `Read`, `Glob`, `Grep`

## Alternatives Considered

### Alternative 1: Skills-only approach — no hook or subagent expansion

Continue using skills for all validation and analysis. Add more skills rather than hooks or agents.

**Rejected because:** Skills require explicit user invocation. The enforcement gaps identified (plan-proposal linking, required frontmatter, document numbering) need deterministic validation that fires automatically on every write, not on-demand checking. Similarly, context window pressure from analytical skills cannot be solved by adding more skills — it requires delegation to separate context windows.

### Alternative 2: Expand hooks but not subagents

Add the new guard and lifecycle hooks but keep all analysis inline.

**Rejected because:** This addresses determinism but not the context pressure and performance problems. A `/docs-audit` across 50 modules still runs sequentially in the main context, causing compaction. Hooks alone cannot parallelize analytical work.

### Alternative 3: Agent teams only, skip hook expansion

Adopt agent teams for parallel execution without expanding the hook layer.

**Rejected because:** Agent teams solve the parallelism problem but don't address enforcement gaps. Without guard hooks for frontmatter validation and plan-proposal linking, the methodology's constraints remain unenforced. Hooks and agent teams solve different problems and should be adopted together.

### Alternative 4: Replace sequential orchestration with agent teams immediately

Skip the subagent expansion and jump directly to agent teams for all parallelization.

**Rejected because:** Agent teams are experimental and use 3-4x the tokens of sequential execution. A phased approach — first expand subagents for focused delegation, then adopt agent teams for orchestration — reduces risk and cost. Skills should gracefully fall back to sequential execution when agent teams are disabled.

## Consequences

### Positive

- **Stronger determinism.** Three new guard hooks close the most critical enforcement gaps in the documentation pipeline. Plans cannot exist without accepted proposals. Documents cannot lack required frontmatter. Numbers cannot be duplicated.
- **Context protection.** Five new subagents offload read-heavy analysis to separate context windows, reducing compaction pressure in the main session.
- **Parallel execution.** Agent teams enable concurrent task execution within phases, with potential 3-5x speedup for independent tasks.
- **Lifecycle automation.** `WorktreeCreate`, `WorktreeRemove`, `SubagentStop`, and `TaskCompleted` hooks replace manual setup/teardown logic currently embedded in skill scripts.
- **Background analysis.** Async hooks and background agents enable non-blocking validation, surfacing drift warnings and audit results without interrupting the user.
- **Backward compatibility.** Agent teams are opt-in via environment variable. All skills fall back to sequential execution when teams are disabled.

### Negative

- **Increased complexity.** More hooks, agents, and configuration increase the surface area for bugs and maintenance.
- **Token cost.** Agent teams and parallel subagents use more tokens than sequential execution. Cost scales with the number of concurrent agents.
- **Experimental dependency.** Agent teams are experimental. Breaking changes in the feature could require refactoring the orchestration layer.
- **Hook interaction complexity.** With 10+ hooks active, interaction between guards and advisories becomes harder to reason about. A write to a plan file could trigger 3-4 hooks sequentially.
- **Script duplication growth.** New hook scripts in principled-docs (3 guards + 1 advisory) increase the number of shared utilities and potential drift surfaces.

### Risks

- **Agent teams stability.** The feature is experimental and disabled by default. Anthropic may change the API, coordination model, or task list format before GA.
- **Hook performance.** Multiple guard hooks on `PreToolUse(Write)` for pipeline documents could add latency. Each hook has a 10s timeout, and they execute sequentially.
- **Memory accumulation.** Agent memory (`memory: project`) persists across sessions. Without governance, memory files could grow unbounded or accumulate stale patterns.
- **Cross-plugin hook ordering.** When multiple plugins define hooks on the same event, execution order may be non-deterministic. Guard hooks from different plugins could interact unexpectedly.

## Architecture Impact

- **[Enforcement System](../architecture/enforcement-system.md)** — Significant expansion: 3 new guard hooks, 4 lifecycle hooks, 1 async advisory, 1 chain validator. Document the new hook types (`prompt`, `agent`) and async execution model.
- **[Plugin System](../architecture/plugin-system.md)** — Add 5 new subagent definitions across 4 plugins. Document agent frontmatter upgrades and agent teams integration pattern.
- **[Documentation Pipeline](../architecture/documentation-pipeline.md)** — Enforcement layer now validates document creation (frontmatter, numbering, proposal linkage), not just modification (immutability, lifecycle).

This proposal motivates the following architectural decisions:

- ADR-015: Event-driven lifecycle hooks for pipeline enforcement
- ADR-016: Agent teams for parallel plan execution

## Open Questions

1. **Hook ordering guarantees.** When a plan file write triggers both `check-plan-proposal-link.sh` and `check-required-frontmatter.sh`, is the execution order guaranteed? Should these be merged into a single hook script to avoid ordering ambiguity?

2. **Agent teams fallback granularity.** Should the fallback from agent teams to sequential execution be per-skill (e.g., `/orchestrate` falls back but `/triage` doesn't) or global (all skills fall back together)?

3. **Memory governance.** How should agent memory files (`.claude/agent-memory/*/MEMORY.md`) be managed? Should they be gitignored, committed, or periodically pruned? Should there be a size cap?

4. **Prompt hook adoption.** The proposal includes only `command` type hooks. Should any of the new guards use `prompt` type (LLM evaluation) for semantic validation that shell scripts cannot easily perform, such as detecting substantive vs. cosmetic ADR changes?

5. **Cross-plugin hook coordination.** With principled-docs, principled-implementation, and potentially principled-quality all defining `PreToolUse(Write)` hooks, how should cross-plugin interaction be governed? Should there be a priority or dependency order?
