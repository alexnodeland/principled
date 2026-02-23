---
title: "Multi-Agent Orchestration at Scale"
number: 009
status: draft
author: Alex
created: 2026-02-23
updated: 2026-02-23
supersedes: null
superseded_by: null
---

# RFC-009: Multi-Agent Orchestration at Scale

## Audience

- Teams using the principled methodology who want to run autonomous, self-improving agent workforces
- Engineers managing complex codebases where sequential single-agent execution is a throughput bottleneck
- Organizations seeking GitHub-native collaboration between human developers and AI agents
- Plugin maintainers extending the principled marketplace's orchestration capabilities
- Leaders evaluating production-grade multi-agent systems for specification-first development

## Context

The principled marketplace (v1.0.0) has established a rigorous pipeline from specification to implementation: Proposals define strategy, Plans decompose tactics via DDD, and the `/orchestrate` skill drives execution through worktree-isolated `impl-worker` sub-agents with manifest-driven state tracking. RFC-008 proposes expanding this with agent teams for parallel execution, additional enforcement hooks, and five new analytical sub-agents.

This foundation is sound. But it was designed for a world where a single human operator drives a single orchestration session, monitors progress synchronously, and agents start fresh each time. The field has moved far beyond this model.

### What the leaders are building

**Boris Cherny** (creator, Claude Code at Anthropic) runs 5+ simultaneous Claude Code sessions across separate git checkouts, managing them like an engineering department. He chains verification loops where agents test their own work, uses shared `CLAUDE.md` files as persistent team memory that accumulates learnings from every PR, and treats agents as infrastructure — not assistants. His workflow demonstrates that a single human can operate with the output capacity of a small engineering department when agents are properly systematized.

**Steve Yegge** (creator, Gas Town & Beads) built an orchestration system that coordinates 20-30 parallel Claude Code agents. His key innovations:

- **Beads**: A git-backed graph issue tracker purpose-built for agents. Work units ("beads") are stored as JSONL in git, cached in SQLite, with hash-based IDs designed to prevent merge conflicts. Agents have persistent identities stored as beads — they survive session crashes.
- **Gas Town**: "Kubernetes for AI coding agents." It introduces role-based agent hierarchies (The Mayor as coordinator, Polecats as ephemeral workers, The Refinery as merge queue manager) and a principle called **Nondeterministic Idempotence (NDI)** — accepting that agent paths are chaotic but outcomes must converge, because workflow definitions and acceptance criteria persist in git.
- **MEOW Stack** (Molecular Expression of Work): All work is expressed as "molecules" — chained sequences of small tasks stored as beads. If an agent crashes mid-step, the next session picks up where it left off.

**Reuven Cohen** (creator, Claude-Flow) built an enterprise-grade orchestration platform that deploys agent swarms via MCP protocol. Claude-Flow introduces adaptive routing that learns from task execution history, prevents catastrophic forgetting of successful patterns, and intelligently routes work to specialized experts. It demonstrates that 150k+ lines of code can be produced by a coordinated swarm in days.

**Anthropic's multi-agent research system** uses the orchestrator-worker pattern at production scale, with key findings: detailed delegation is critical (each sub-agent needs objectives, output formats, tool guidance, and task boundaries), effort must scale to complexity, and full production tracing is essential for debugging non-deterministic agent behavior.

The **ICLR 2026 Workshop on Recursive Self-Improvement** has formalized the research direction: agents that diagnose their failures, critique their behavior, update internal representations, and modify external tools. This is no longer speculative — it's a concrete systems problem.

### The five gaps in principled today

1. **No persistent agent identity.** Agents start fresh every session. There's no memory of what worked, what failed, or what patterns to prefer. Every orchestration run is "50 First Dates."

2. **No autonomous lifecycle.** Agents require a human operator to initiate, monitor, and intervene. There's no way to kick off work and have agents operate autonomously through GitHub issues and PRs.

3. **No resumability.** If a session crashes, context is lost. The manifest tracks task state, but the agent's reasoning, approach, and partial progress evaporate.

4. **No learning loop.** Conversation histories and local reviews exist but are never fed back into agent behavior. Agents don't improve from experience.

5. **No GitHub-native collaboration.** Humans and agents can't collaborate through the same GitHub workflow. Agents don't create issues, respond to review comments, or pick up work from a shared backlog.

## Proposal

### Vision

Transform the principled orchestration layer from a single-session, human-driven tool into an **autonomous, self-improving agent workforce** that collaborates with humans through GitHub, maintains persistent memory, resumes interrupted work, and continuously improves from its own performance history.

This proposal introduces seven interconnected systems that build on the existing principled infrastructure (manifest-driven state, worktree isolation, hook enforcement, the documentation pipeline) without replacing any of it.

---

### System 1: Persistent Agent Identity & Memory (The Engram Layer)

**Inspiration:** Yegge's Beads (git-backed persistent identity), Cherny's `CLAUDE.md` as team memory, Anthropic's Agent SDK lifecycle hooks.

#### Design

Introduce a git-backed agent memory system stored in `.agents/` at the repository root:

```
.agents/
  registry.json          # Agent identity registry
  memory/
    global.md            # Shared learnings (like CLAUDE.md but structured)
    agents/
      orchestrator-001.md   # Per-agent memory file
      worker-alpha.md       # Accumulated over sessions
      reviewer-001.md
  retrospectives/
    2026-02-23-plan-008.md  # Post-execution retrospective
    2026-02-24-plan-009.md
```

**Agent Registry** (`registry.json`): Each agent gets a persistent identity with a stable ID, role, creation date, session history, and performance metrics. Like Yegge's "Agent Beads" — the identity survives session death.

```json
{
  "agents": [
    {
      "id": "orch-001",
      "role": "orchestrator",
      "created": "2026-02-23",
      "total_sessions": 47,
      "total_tasks_completed": 312,
      "success_rate": 0.94,
      "specializations": ["typescript", "api-design"],
      "last_active": "2026-02-23T14:30:00Z"
    }
  ]
}
```

**Agent Memory Files**: Markdown files that accumulate learnings across sessions. Structured with sections for: known patterns (what works), anti-patterns (what fails), codebase knowledge (module relationships, common pitfalls), and review feedback (extracted from PR reviews and conversation histories).

**Retrospectives**: After each orchestration run, a retrospective document is automatically generated from the conversation history and manifest outcomes. This captures: what tasks succeeded/failed, what approaches were tried, what review feedback was received, and what should be done differently.

#### How it connects

- The `/orchestrate` skill reads the orchestrator's memory file at startup and injects it as context
- The `/spawn` skill reads the worker's memory file and injects it into the `impl-worker` prompt
- Post-execution hooks write retrospective summaries back to memory files
- The existing `CLAUDE.md` remains the human-facing configuration; `.agents/memory/` is the agent-facing knowledge base

---

### System 2: Resumable Orchestration (The Checkpoint Layer)

**Inspiration:** Yegge's Nondeterministic Idempotence (NDI), Anthropic's "effective harnesses for long-running agents."

#### Design

Extend the existing manifest (`.impl/manifest.json`) with checkpoint data that allows any session to pick up where a previous one left off:

```json
{
  "plan": "docs/plans/008-example.md",
  "checkpoint": {
    "session_id": "sess-abc123",
    "phase": 2,
    "timestamp": "2026-02-23T14:30:00Z",
    "orchestrator_summary": "Completed phase 1 (3/3 tasks merged). Phase 2 in progress: task-2a passed checks, task-2b failed on test suite — retry needed with adjusted approach. task-2c pending.",
    "pending_decisions": [
      "task-2b: API response format — choose between envelope pattern and flat response. Blocked on review feedback."
    ],
    "environment_state": {
      "active_worktrees": ["task-2a", "task-2b"],
      "branches": {
        "task-2a": "impl/plan-008/task-2a",
        "task-2b": "impl/plan-008/task-2b-retry-1"
      }
    }
  },
  "tasks": { ... }
}
```

**Checkpoint Protocol:**

1. After each significant state transition (task completion, phase boundary, failure + decision point), the orchestrator writes a checkpoint to the manifest
2. The checkpoint includes a natural-language summary of progress and pending decisions — this is the "reasoning state" that normally dies with the session
3. On resume, a new session reads the checkpoint, ingests the summary, and continues from the recorded state
4. This implements NDI: the path is nondeterministic (different session, different agent reasoning), but the outcome converges because the manifest state and checkpoint summary are deterministic anchors

#### New skill: `/resume`

```
/resume [plan-path] [--from-checkpoint] [--replan]
```

- `--from-checkpoint`: Pick up from the last checkpoint (default)
- `--replan`: Re-read the plan, reconcile with manifest state, and potentially re-decompose remaining work

#### How it connects

- Extends the existing manifest schema (ADR-008) without breaking it
- Uses the existing worktree isolation (ADR-007) — worktrees survive session death
- Hooks validate checkpoint integrity on write (extend `check-manifest-integrity.sh`)

---

### System 3: GitHub-Native Agent Collaboration (The Interface Layer)

**Inspiration:** Cherny's multi-session workflow, principled-github's existing `/triage` and `/sync-issues` skills, the Agent SDK's SubagentStop hook.

#### Design

Create a bidirectional bridge where agents operate as first-class GitHub collaborators:

**Agent-as-Contributor Workflow:**

```
GitHub Issue (assigned to agent)
  → Agent picks up issue via /triage
  → Agent creates proposal (RFC) via /new-proposal
  → Human reviews & approves proposal
  → Agent creates plan via /new-plan
  → Human reviews & approves plan
  → Agent executes via /orchestrate
  → Agent creates PR via /pr-describe
  → Human reviews PR
  → Agent addresses review comments
  → Human merges
```

**GitHub Actions Integration:**

A new GitHub Actions workflow (`.github/workflows/agent-dispatch.yml`) that:

1. Watches for issues labeled `agent-ready` or `agent-assigned`
2. Dispatches to a Claude Code session (via the Agent SDK) with the issue context
3. The agent runs autonomously through the principled pipeline
4. Posts progress updates as issue comments
5. Creates PRs when implementation is complete
6. Responds to PR review comments by spawning fix-up sessions

**Issue-Driven Backlog:**

```
.agents/
  backlog.json          # Agent work queue synced from GitHub issues
```

Agents maintain a backlog synced with GitHub issues. The `/triage` skill (principled-github) already ingests issues — this extends it to assign issues to agents based on specialization and availability.

**Review Feedback Loop:**

When a human reviews an agent's PR:
1. Review comments are captured
2. The agent's memory file is updated with the feedback pattern
3. If changes are requested, a new session is spawned to address them
4. The PR is updated, review cycle continues

#### New skills

| Skill | Command | Description |
|-------|---------|-------------|
| `agent-dispatch` | `/agent-dispatch <issue-number>` | Assign an issue to an agent and begin autonomous execution |
| `agent-respond` | `/agent-respond <pr-number>` | Address PR review feedback autonomously |
| `agent-status` | `/agent-status [--all] [--agent <id>]` | Report on agent workforce status and progress |

#### How it connects

- Builds on principled-github's existing skills (`/triage`, `/ingest-issue`, `/sync-issues`, `/pr-describe`, `/pr-check`)
- Uses principled-quality's `/review-checklist` and `/review-context` for self-review before PR creation
- Uses principled-release's `/release-ready` before tagging

---

### System 4: Autonomous Execution Engine (The Factory Layer)

**Inspiration:** Yegge's Gas Town (factory vs. workers), Cohen's Claude-Flow (swarm coordination), Anthropic's Agent Teams (TeammateTool).

#### Design

Transform `/orchestrate` from a single-session command into a persistent execution engine that can run unattended:

**Execution Modes:**

| Mode | Description | Human Involvement |
|------|-------------|-------------------|
| `interactive` | Current behavior — human monitors and intervenes | Continuous |
| `supervised` | Agent runs autonomously, pauses at decision points | At decision gates |
| `autonomous` | Agent runs end-to-end, posts results for review | Post-completion review |

```
/orchestrate <plan-path> --mode supervised [--phase N] [--continue]
```

**Supervised Mode Protocol:**

1. Agent decomposes the plan and begins execution
2. At each phase boundary, agent posts a GitHub comment summarizing progress and next steps
3. Agent continues to next phase automatically unless:
   - A task has failed more than N retries (configurable)
   - A decision point requires human input (tagged in the plan)
   - Quality checks reveal systemic issues
4. Human can intervene at any time via GitHub issue comments

**Autonomous Mode Protocol:**

1. Full pipeline execution: decompose → spawn → validate → merge → repeat
2. Agent creates a "progress issue" on GitHub with live updates
3. On completion, agent runs `/pr-describe`, `/review-checklist`, and `/release-ready`
4. Posts final summary and opens PR for human review
5. If blocked, creates a labeled issue (`agent-blocked`) and moves to next available work

**Parallel Execution (Agent Teams):**

Build on RFC-008's agent teams proposal with structured roles:

| Role | Responsibility | Count |
|------|---------------|-------|
| **Orchestrator** | Decomposes work, assigns tasks, monitors progress | 1 |
| **Workers** | Execute implementation tasks in isolated worktrees | N (configurable) |
| **Reviewer** | Pre-validates worker output before merge | 1 |
| **Integrator** | Manages the merge queue, resolves conflicts | 1 |

This maps to Yegge's taxonomy: Orchestrator = The Mayor, Workers = Polecats, Integrator = The Refinery. The Reviewer role is a principled addition — it runs `/check-impl` and `/review-checklist` against each worker's output before the Integrator merges it.

#### How it connects

- Extends the existing `/orchestrate` skill with new `--mode` flag
- Uses existing `impl-worker` agent for the Worker role
- Uses existing `/check-impl` skill for the Reviewer role
- Uses existing `/merge-work` skill for the Integrator role
- Manifest state (ADR-008) tracks all roles and their progress

---

### System 5: Self-Improvement Loop (The Retrospective Layer)

**Inspiration:** ICLR 2026 RSI workshop, Anthropic's structured evaluation, Cherny's `@.claude` PR feedback pattern, conversation history analysis.

#### Design

Create a closed-loop system where agents improve from their own performance data:

**Data Sources:**

| Source | What It Captures | Storage |
|--------|-----------------|---------|
| Conversation histories | Full agent reasoning traces | User-provided (local) |
| Local reviews | Human evaluations of agent work | User-provided (local) |
| Manifest outcomes | Task success/failure rates, retry counts | `.impl/manifest.json` |
| PR review comments | Human feedback on code quality | GitHub API |
| CI results | Build/test/lint pass rates | GitHub Actions |
| Retrospectives | Synthesized learnings per execution | `.agents/retrospectives/` |

**The Improvement Cycle:**

```
Execute → Capture → Analyze → Synthesize → Inject → Execute (improved)
```

1. **Capture**: Every orchestration run generates a retrospective document from the manifest outcomes, conversation summaries, and review feedback
2. **Analyze**: A dedicated `/retro` skill processes retrospectives to identify patterns:
   - Which task types consistently fail on first attempt?
   - Which review feedback recurs?
   - Which codebase areas cause the most retries?
   - What prompt patterns produce better results?
3. **Synthesize**: Findings are distilled into agent memory updates:
   - Global memory (`global.md`): Patterns that apply to all agents
   - Agent-specific memory: Patterns specific to a role or specialization
   - Anti-pattern registry: Approaches to explicitly avoid
4. **Inject**: On the next execution, memory is loaded into agent context
5. **Verify**: Track whether improvements actually reduce failure rates over time

**Conversation History Integration:**

Users keep conversation histories — this is gold. A new skill processes these:

```
/ingest-history <path-to-history> [--agent <id>] [--extract-patterns]
```

This parses conversation histories to extract:
- Successful problem-solving approaches
- Common errors and their resolutions
- Codebase-specific knowledge gained during sessions
- Human correction patterns (where the human redirected the agent)

**Performance Dashboard:**

```
/agent-metrics [--agent <id>] [--since <date>]
```

Outputs:
- Tasks completed / failed / retried
- Average retries per task type
- Review feedback frequency by category
- Improvement trend over time (are failure rates decreasing?)

#### New skills

| Skill | Command | Description |
|-------|---------|-------------|
| `retro` | `/retro [plan-path] [--auto]` | Generate and analyze retrospective |
| `ingest-history` | `/ingest-history <path>` | Extract patterns from conversation histories |
| `agent-metrics` | `/agent-metrics [--agent <id>]` | Performance reporting and trend analysis |
| `improve` | `/improve [--agent <id>] [--dry-run]` | Synthesize learnings into memory updates |

#### How it connects

- Retrospectives are pipeline documents — they follow the same frontmatter conventions
- Memory updates go through the same hook enforcement (required frontmatter, structural validation)
- Performance data feeds into `/release-ready` assessments
- Improvement patterns are shared via the same `CLAUDE.md` mechanism Cherny uses at Anthropic

---

### System 6: Work Unit Decomposition (The Molecule Layer)

**Inspiration:** Yegge's MEOW stack (Molecular Expression of Work), Anthropic's "scale effort to complexity" principle.

#### Design

Formalize work decomposition beyond the current plan → task model into a three-level hierarchy:

```
Plan (strategic)
  → Phase (dependency boundary)
    → Task (implementable unit — current granularity)
      → Step (atomic operation with acceptance criteria)
```

**Steps** are the new primitive. Each step has:

```json
{
  "id": "task-2a.step-3",
  "description": "Add validation middleware to the API router",
  "acceptance_criteria": [
    "Middleware rejects requests without auth header with 401",
    "Middleware passes valid tokens to next handler",
    "Unit tests cover both cases"
  ],
  "estimated_complexity": "low",
  "verification_command": "npm test -- --grep 'validation middleware'"
}
```

**Why steps matter for NDI:** When an agent crashes mid-task, the current system can only retry the entire task. With steps, a resumed agent can identify which steps are already complete (by running acceptance criteria) and continue from the next incomplete step. This is Yegge's NDI applied at a finer granularity — the path is chaotic but the acceptance criteria are deterministic checkpoints.

**Complexity-Aware Routing:**

Steps are tagged with estimated complexity. The orchestrator routes work accordingly:
- `low` complexity: Assign to workers without review gate
- `medium` complexity: Standard flow (worker → reviewer → integrator)
- `high` complexity: Worker generates approach document first, human approves before implementation
- `critical` complexity: Human-in-the-loop throughout

#### How it connects

- Steps are embedded in the existing manifest schema (nested under tasks)
- The `/decompose` skill is extended to produce step-level breakdowns
- The `impl-worker` agent receives steps as a checklist with acceptance criteria
- `/check-impl` validates step-level acceptance criteria, not just task-level checks

---

### System 7: The Principled Agent Plugin (The Integration Layer)

All six systems above are delivered as a new first-party plugin: **principled-agents**.

```
plugins/principled-agents/
  PLUGIN.md
  skills/
    agent-strategy/        # Background knowledge skill
    agent-dispatch/        # Assign issues to agents
    agent-respond/         # Address PR review feedback
    agent-status/          # Workforce status reporting
    resume/                # Resume interrupted orchestration
    retro/                 # Generate retrospectives
    ingest-history/        # Process conversation histories
    agent-metrics/         # Performance dashboards
    improve/               # Synthesize learnings into memory
  hooks/
    hooks.json
    scripts/
      check-memory-integrity.sh    # Validate .agents/ structure
      capture-retrospective.sh     # PostToolUse hook after orchestration
      inject-agent-memory.sh       # PreToolUse hook before spawn
  agents/
    autonomous-orchestrator.md     # Agent definition for unattended execution
```

**Plugin Relationships:**

```
principled-agents (new)
  ├── depends on: principled-implementation (orchestration, worktrees, manifest)
  ├── depends on: principled-github (issue triage, PR creation, sync)
  ├── depends on: principled-quality (review checklists, coverage)
  ├── depends on: principled-release (readiness checks)
  ├── depends on: principled-docs (proposals, plans, pipeline enforcement)
  └── depends on: principled-architecture (boundary checking)
```

This is the first plugin that composes capabilities from all six existing plugins. It is the **orchestration ceiling** — the layer that turns individual plugin capabilities into an autonomous workforce.

---

## Phased Delivery

### Phase 1: Memory & Resumability

- Implement `.agents/` directory structure and registry
- Add checkpoint data to manifest schema
- Build `/resume` skill
- Add agent memory injection to `/spawn` and `/orchestrate`
- Build `/retro` skill for manual retrospective generation

### Phase 2: GitHub Integration

- Build `/agent-dispatch` and `/agent-respond` skills
- Create `agent-dispatch.yml` GitHub Actions workflow
- Extend `/triage` to support agent assignment
- Build `/agent-status` skill
- Implement review feedback capture loop

### Phase 3: Autonomous Execution

- Add `--mode` flag to `/orchestrate` (supervised, autonomous)
- Implement the Reviewer and Integrator agent roles
- Build progress reporting via GitHub issue comments
- Implement decision-point gating and human escalation

### Phase 4: Self-Improvement

- Build `/ingest-history` for conversation history processing
- Build `/improve` for memory synthesis
- Build `/agent-metrics` for performance tracking
- Implement the full capture → analyze → synthesize → inject loop
- Add trend tracking to verify improvements

### Phase 5: Fine-Grained Decomposition

- Extend manifest schema with step-level data
- Extend `/decompose` to produce steps with acceptance criteria
- Implement complexity-aware routing
- Extend `/check-impl` for step-level validation
- Implement NDI at step granularity (resume from last passing step)

## Architectural Principles

These principles govern the design across all seven systems:

### 1. Git as the Data Plane

All agent state lives in git — identities, memory, checkpoints, retrospectives, backlog. No external databases, no ephemeral state stores. If it's not in git, it doesn't exist. This follows Yegge's core insight: git is the only state that reliably survives agent crashes, session restarts, and infrastructure changes.

### 2. Nondeterministic Idempotence

Accept that agents take unpredictable paths. Design for convergent outcomes by:
- Persisting work definitions and acceptance criteria
- Making all state transitions recoverable
- Allowing any agent to resume any other agent's work
- Testing outcomes, not processes

### 3. Documents as Source of Truth

Extending ADR-011: the principled documentation pipeline remains the single source of truth. Agents don't have "hidden state" — everything is a document with frontmatter, subject to the same lifecycle enforcement as human-authored documents.

### 4. Composability Over Monolith

The new plugin composes existing plugin capabilities. It doesn't duplicate them. `/agent-dispatch` calls `/triage` and `/orchestrate`. `/retro` reads manifests produced by principled-implementation. The improvement loop feeds into `CLAUDE.md` (principled-docs) and `.agents/memory/` (principled-agents).

### 5. Progressive Autonomy

Start supervised, earn autonomy. Agents begin in supervised mode where humans approve at every gate. As performance metrics improve and trust is established, gates can be relaxed. This is not philosophical — it's a configuration:

```json
{
  "autonomy_level": "supervised",
  "auto_approve_phases": false,
  "max_retries_before_escalation": 3,
  "require_human_review_for": ["critical", "high"]
}
```

### 6. Structured Self-Improvement Only

Agents improve through structured, auditable loops — not opaque self-modification. Every improvement is a document: retrospectives are markdown, memory updates are tracked in git, performance metrics are queryable. Humans can audit and override any "learning."

### 7. The Factory Mindset

As Yegge argues: "We don't need more coding agents. We need management agents." This proposal adds management infrastructure — scheduling, memory, routing, review, integration — to the existing worker infrastructure. The principled marketplace already has the workers (impl-worker, module-auditor, boundary-checker, etc.). This RFC adds the factory.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Agent memory accumulates noise | Structured retrospective format with explicit sections; `/improve` uses analysis not raw append; humans can audit/prune memory |
| Autonomous agents produce low-quality code | Progressive autonomy — start supervised; mandatory `/check-impl` + `/review-checklist` gates before any merge; quality metrics trigger automatic downgrade to supervised mode |
| Git-backed state creates merge conflicts | Hash-based IDs for agent registry (following Yegge's Beads pattern); append-only retrospective files; per-agent memory files to minimize contention |
| Conversation history ingestion is unreliable | Pattern extraction is additive — bad extractions don't delete existing memory; all extractions are human-reviewable documents |
| Cost of running parallel agents | Complexity-aware routing sends only appropriate work to expensive agents; low-complexity steps bypass review gates; `--max-workers` cap on `/orchestrate` |
| GitHub Actions integration couples to platform | Agent dispatch is abstracted behind skills — the skill implementations can target any CI/CD platform; GitHub is the first backend, not the only one |
| Circular improvement loops (agent learns bad patterns) | Performance metrics are ground truth; if metrics degrade after an improvement cycle, the system flags the regression and rolls back memory changes |

## Prior Art

| System | Relationship to This Proposal |
|--------|-------------------------------|
| [Gas Town / Beads](https://github.com/steveyegge/gastown) (Yegge) | NDI principle, git-backed agent identity, MEOW stack molecule decomposition. We adopt the philosophy but implement it within principled's existing plugin/manifest architecture rather than an external tool. |
| [Claude-Flow](https://github.com/ruvnet/claude-flow) (Cohen) | Swarm coordination via MCP, adaptive routing, agent memory. We take the adaptive routing concept but embed it in the principled documentation pipeline rather than a separate orchestration layer. |
| [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams) (Anthropic) | TeammateTool for peer-to-peer agent coordination. RFC-008 already proposes adoption; this RFC extends it with persistent identity, memory, and autonomous lifecycle. |
| [Anthropic's Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system) | Production lessons on detailed delegation, effort scaling, and debugging. These lessons directly inform the Step decomposition and complexity-aware routing. |
| [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) (Schluntz & Zhang, Anthropic) | Orchestrator-worker pattern, evaluator-optimizer loop. The four-role system (Orchestrator, Worker, Reviewer, Integrator) extends their two-role pattern. |
| [Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk) | Runtime environment with lifecycle hooks. Our hook system (principled-docs, principled-implementation) maps directly to SDK hooks; the new plugin adds memory-injection and retrospective-capture hooks. |
| [ICLR 2026 RSI Workshop](https://recursive-workshop.github.io/) | Formalized research on structured self-improvement. Our improvement loop follows their "diagnose → critique → update → verify" pattern. |
| [Cherny's Workflow](https://howborisusesclaudecode.com/) | `CLAUDE.md` as team memory, verification loops, multi-session parallelism. Our agent memory system formalizes and structures the `CLAUDE.md` pattern for machine consumption. |

## Success Criteria

1. **Resumability**: An orchestration session that crashes mid-phase can be resumed by a new session with <5 minutes of re-orientation time, completing the remaining work without re-doing completed tasks.

2. **Autonomous Execution**: A plan with 10+ tasks across 3+ phases can be executed in autonomous mode with zero human intervention during execution, producing a PR that passes CI and review checklist.

3. **GitHub Collaboration**: A GitHub issue labeled `agent-ready` is picked up by an agent, flows through the full principled pipeline (proposal → plan → implementation → PR), and is ready for human review within a single automated cycle.

4. **Measurable Improvement**: Agent failure rates on recurring task types decrease by 20%+ over 10 orchestration runs, as measured by retry counts and review rejection rates.

5. **Memory Utility**: Agent memory files contain actionable, non-redundant knowledge that demonstrably influences agent behavior (verified by comparing agent output with and without memory injection).

## Open Questions

1. **Memory format**: Should agent memory be structured YAML/JSON or freeform markdown? Structured is more parseable but markdown is more natural for LLM consumption. Current proposal uses markdown for maximum flexibility.

2. **Conversation history privacy**: Conversation histories may contain sensitive data. Should `/ingest-history` run locally only, or should extracted patterns be safe to commit to git?

3. **Agent identity persistence across forks**: If a repository is forked, should agent identities carry over? The memory is valuable but the metrics may not apply to a different codebase.

4. **Cost governance**: Running autonomous agent workforces is expensive. Should the plugin enforce spending limits, or is that an infrastructure concern outside scope?

5. **Multi-repo orchestration**: The current design is single-repo. Should the agent workforce be able to coordinate across repositories in a monorepo-of-repos setup?

## Relationship to RFC-008

RFC-008 (Hooks, Subagents, and Agent Teams Integration) is a prerequisite for this proposal. RFC-008 establishes:

- Agent teams for parallel execution (System 4 builds on this)
- New analytical sub-agents (the improvement loop analyzes their output)
- Expanded enforcement hooks (autonomous agents need stronger guardrails)

This proposal (RFC-009) extends RFC-008's foundation with persistent identity, autonomous lifecycle, and self-improvement — the capabilities needed to scale from "agent tool" to "agent workforce."
