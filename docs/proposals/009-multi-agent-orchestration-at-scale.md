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

**Why one proposal, not seven.** These systems share a common data plane: `.agents/` provides the persistent identity that memory (System 1) requires, that resumability (System 2) references for agent assignment, that GitHub integration (System 3) uses for dispatch routing, that the execution engine (System 4) consults for role assignment, and that the self-improvement loop (System 5) writes back to. Checkpointable criteria (System 6) extend the manifest that resumability reads. The plugin (System 7) is the delivery vehicle for all six. Implementing any system in isolation would require the same foundational data structures — they are architecturally inseparable even though they can be delivered in phases. The phased delivery plan reflects implementation ordering, not conceptual independence.

---

### System 1: Persistent Agent Identity & Memory (The Engram Layer)

**Inspiration:** Yegge's Beads (git-backed persistent identity), Cherny's `CLAUDE.md` as team memory, Anthropic's Agent SDK lifecycle hooks.

#### Design

Introduce a git-backed agent memory system stored in `.agents/` at the repository root:

```
.agents/
  registry.json          # Agent identity registry (JSON — queryable metadata)
  memory/
    global.md            # Shared learnings (YAML frontmatter + markdown body)
    agents/
      orchestrator-001.md   # Per-agent memory (YAML frontmatter + markdown body)
      worker-alpha.md
      reviewer-001.md
  retrospectives/
    2026-02-23-plan-008.md  # Post-execution retrospective (pipeline document)
    2026-02-24-plan-009.md
```

#### Memory format decision

Agent memory files use **YAML frontmatter + markdown body**, consistent with every other document in the principled pipeline (ADR-003, ADR-011). The registry uses JSON because it is a data structure, not a document.

Alternatives considered for memory format:

- **Pure markdown** (no frontmatter): Natural for LLM consumption but not queryable for performance metrics, agent routing, or automated pruning. Rejected because the principled pipeline depends on frontmatter for lifecycle enforcement — memory files without frontmatter would be second-class citizens.
- **Pure JSON/YAML**: Queryable and structured, but unnatural for LLM context injection. LLMs consume markdown more effectively than structured data. Rejected because the primary consumer of memory is the LLM itself.
- **JSONL + SQLite** (Yegge's Beads pattern): Append-only, conflict-resistant, queryable with tooling. Rejected because it introduces a build step (SQLite cache sync) and a second state system alongside the manifest. The principled architecture uses git-native formats exclusively (ADR-008).

The hybrid approach — structured frontmatter for metadata, markdown body for knowledge — follows the same pattern as proposals, plans, and ADRs. Memory files are pipeline documents, subject to the same lifecycle enforcement.

**Agent memory file example:**

```markdown
---
agent_id: "worker-alpha"
role: worker
last_updated: 2026-02-23
session_count: 12
total_tasks: 47
success_rate: 0.91
specializations: ["typescript", "api-design"]
---

# Worker Alpha — Accumulated Knowledge

## Known Patterns

- This codebase uses barrel exports in `src/index.ts` — always
  update the barrel when adding new modules
- Integration tests require `TEST_DB_URL` environment variable;
  check `.env.test` exists before running

## Anti-Patterns

- Do NOT use `any` type in TypeScript — the CI lint rejects it.
  Previous task-3b failed twice on this.
- Avoid modifying `package-lock.json` manually — run `npm install`

## Review Feedback

- PR #42: "Always add JSDoc to exported functions" — recurring
  feedback from reviewer, now a standard practice
```

**Agent Registry** (`registry.json`): Each agent gets a persistent identity with a stable ID, role, creation date, session history, and performance metrics. Like Yegge's "Agent Beads" — the identity survives session death. Hash-based IDs (following Yegge's Beads convention) prevent merge conflicts when multiple agents update the registry.

```json
{
  "version": "1.0.0",
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

**Retrospectives**: After each orchestration run, a retrospective document is automatically generated from the conversation history and manifest outcomes. Retrospectives are pipeline documents with YAML frontmatter (status, plan reference, outcome summary) and a structured markdown body (tasks succeeded/failed, approaches tried, review feedback received, recommendations).

#### Which agents get persistent identity

Not all agents benefit from persistent identity. Only agents that are spawned repeatedly for substantively similar work accumulate useful patterns. Stateless analytical agents that run a single deterministic check don't need memory.

| Agent              | Gets Identity? | Rationale                                                                                                   |
| ------------------ | :------------: | ----------------------------------------------------------------------------------------------------------- |
| `impl-worker`      |      Yes       | Primary beneficiary — accumulates implementation patterns, codebase knowledge, review feedback across tasks |
| `issue-ingester`   |      Yes       | Accumulates triage and classification patterns over time                                                    |
| `pr-reviewer`      |      Yes       | Accumulates review quality patterns, learns recurring feedback themes                                       |
| `module-auditor`   |       No       | Stateless analytical tool — runs `validate-structure.sh` with no learning opportunity                       |
| `decision-auditor` |       No       | Stateless analytical tool — checks supersession chains deterministically                                    |
| `boundary-checker` |       No       | Stateless analytical tool — scans imports against rules with no judgment calls                              |

#### How it connects

- The `/orchestrate` skill reads the orchestrator's memory file at startup and injects it as context
- The `/spawn` skill reads the worker's memory file and injects it into the `impl-worker` prompt
- Post-execution hooks write retrospective summaries back to memory files
- The existing `CLAUDE.md` remains the human-facing configuration; `.agents/memory/` is the agent-facing knowledge base
- Memory files are committed to git (unlike `.claude/agent-memory/` which is gitignored) because they are shared team knowledge, not session-local state

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
    "agent_id": "orch-001",
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
  "tasks": { "...": "..." }
}
```

The `checkpoint` field is a new top-level key in the manifest schema. Existing manifests without this field continue to work — `--continue` already reads task state from the manifest. The checkpoint adds the natural-language reasoning context that task state alone cannot capture.

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

- Extends the existing manifest schema (ADR-008) with a backward-compatible additive field
- Uses the existing worktree isolation (ADR-007) — worktrees survive session death
- Hooks validate checkpoint integrity on write (extend `check-manifest-integrity.sh`)
- Links to System 1 via `agent_id` — the resuming session loads the original orchestrator's memory

---

### System 3: GitHub-Native Agent Collaboration (The Interface Layer)

**Inspiration:** Cherny's multi-session workflow, GitHub Copilot's agent-as-contributor model, principled-github's existing `/triage` and `/sync-issues` skills.

This system has two distinct concerns: a **workflow protocol** that defines how agents interact with GitHub (portable, not platform-specific), and **dispatch infrastructure** that provides a runtime for autonomous execution (GitHub Actions as the first backend, swappable).

#### 3a: Agent Contributor Protocol

The protocol defines how agents behave as GitHub collaborators. It is a workflow pattern — not infrastructure. A team could follow this protocol running agents locally, via GitHub Actions, or on any CI/CD platform.

**Protocol Steps:**

```
1. Issue assigned to agent (label: agent-ready, assignee: agent ID)
2. Agent picks up issue via /triage
3. Agent creates proposal (RFC) via /new-proposal
4. Human reviews & approves proposal (GitHub PR review)
5. Agent creates plan via /new-plan --from-proposal NNN
6. Human reviews & approves plan (GitHub PR review)
7. Agent executes via /orchestrate --mode supervised|autonomous
8. Agent self-reviews via /review-checklist (principled-quality)
9. Agent creates PR via /pr-describe
10. Human reviews PR
11. Agent addresses review comments via /agent-respond
12. Human merges
```

**Agent Governance:**

Following GitHub Copilot's model, agents are treated as outside collaborators with specific constraints:

- Agents cannot approve their own PRs
- Agents create **draft PRs** that require human promotion to ready-for-review
- Agent commits include co-authorship attribution for audit trails
- Protected branch rules apply to agent-created branches
- The agent's PR description links back to the originating issue, proposal, and plan for full traceability

**Review Feedback Loop:**

When a human reviews an agent's PR:

1. Review comments are captured via GitHub API
2. The agent's memory file is updated with the feedback pattern (System 1)
3. If changes are requested, a new session is spawned to address them
4. The PR is updated, review cycle continues

#### 3b: Agent Dispatch Infrastructure

The dispatch layer provides a runtime for autonomous agent execution. GitHub Actions is the first backend, but the dispatch skill abstracts the runtime so it can be replaced.

**GitHub Actions Workflow** (`.github/workflows/agent-dispatch.yml`):

1. Triggered by issues labeled `agent-ready` or `agent-assigned`
2. Dispatches to a Claude Code session (via the Agent SDK) with the issue context
3. The agent runs autonomously through the protocol defined in 3a
4. Posts progress updates as issue comments
5. Creates PRs when implementation is complete
6. On failure, creates a labeled issue (`agent-blocked`) with diagnostic context

**Issue-Driven Backlog:**

```
.agents/
  backlog.json          # Agent work queue synced from GitHub issues
```

Agents maintain a backlog synced with GitHub issues. The `/triage` skill (principled-github) already ingests issues — this extends it to assign issues to agents based on specialization and availability from the agent registry.

#### New skills

| Skill            | Command                                    | Description                                                                  |
| ---------------- | ------------------------------------------ | ---------------------------------------------------------------------------- |
| `agent-dispatch` | `/agent-dispatch <issue-number> [--local]` | Assign an issue to an agent; `--local` runs in current session instead of CI |
| `agent-respond`  | `/agent-respond <pr-number>`               | Address PR review feedback autonomously                                      |
| `agent-status`   | `/agent-status [--all] [--agent <id>]`     | Report on agent workforce status and progress                                |

The `--local` flag on `/agent-dispatch` makes the infrastructure layer optional. A team can use the full contributor protocol without GitHub Actions by running dispatch locally.

#### How it connects

- Builds on principled-github's existing skills (`/triage`, `/ingest-issue`, `/sync-issues`, `/pr-describe`, `/pr-check`)
- Uses principled-quality's `/review-checklist` and `/review-context` for self-review before PR creation
- Uses principled-release's `/release-ready` before tagging
- Protocol is portable; infrastructure is swappable

---

### System 4: Autonomous Execution Engine (The Factory Layer)

**Inspiration:** Yegge's Gas Town (factory vs. workers), Cohen's Claude-Flow (swarm coordination), Anthropic's Agent Teams (TeammateTool).

#### Design

Transform `/orchestrate` from a single-session command into a persistent execution engine that can run unattended:

**Execution Modes:**

| Mode          | Description                                        | Human Involvement      |
| ------------- | -------------------------------------------------- | ---------------------- |
| `interactive` | Current behavior — human monitors and intervenes   | Continuous             |
| `supervised`  | Agent runs autonomously, pauses at decision points | At decision gates      |
| `autonomous`  | Agent runs end-to-end, posts results for review    | Post-completion review |

```
/orchestrate <plan-path> --mode supervised [--phase N] [--continue]
```

**Supervised Mode Protocol:**

1. Agent decomposes the plan and begins execution
2. At each phase boundary, agent posts a GitHub comment summarizing progress and next steps
3. Agent continues to next phase automatically unless:
   - A task has failed more than N retries (configurable, default 2)
   - A decision point requires human input (tagged in the plan)
   - Quality checks reveal systemic issues (>50% task failure rate in a phase)
4. Human can intervene at any time via GitHub issue comments

**Autonomous Mode Protocol:**

1. Full pipeline execution: decompose → spawn → validate → merge → repeat
2. Agent creates a "progress issue" on GitHub with live updates
3. On completion, agent runs `/pr-describe`, `/review-checklist`, and `/release-ready`
4. Posts final summary and opens PR for human review
5. If blocked, creates a labeled issue (`agent-blocked`) and moves to next available work

**Parallel Execution (Agent Teams):**

Build on RFC-008's agent teams proposal with structured roles:

| Role             | Responsibility                                     | Count                                |
| ---------------- | -------------------------------------------------- | ------------------------------------ |
| **Orchestrator** | Decomposes work, assigns tasks, monitors progress  | 1                                    |
| **Workers**      | Execute implementation tasks in isolated worktrees | N (configurable via `--max-workers`) |
| **Reviewer**     | Pre-validates worker output before merge           | 1                                    |
| **Integrator**   | Manages the merge queue, resolves conflicts        | 1                                    |

This maps to Yegge's taxonomy: Orchestrator = The Mayor, Workers = Polecats, Integrator = The Refinery. The Reviewer role is a principled addition — it runs `/check-impl` and `/review-checklist` against each worker's output before the Integrator merges it.

#### How it connects

- Extends the existing `/orchestrate` skill with new `--mode` flag
- Uses existing `impl-worker` agent for the Worker role
- Uses existing `/check-impl` skill for the Reviewer role
- Uses existing `/merge-work` skill for the Integrator role
- Manifest state (ADR-008) tracks all roles and their progress
- Checkpoint data (System 2) enables resume after interruption in any mode

---

### System 5: Self-Improvement Loop (The Retrospective Layer)

**Inspiration:** ICLR 2026 RSI workshop, Anthropic's structured evaluation, Cherny's `@.claude` PR feedback pattern, conversation history analysis.

#### Design

Create a closed-loop system where agents improve from their own performance data:

**Data Sources:**

| Source                 | What It Captures                         | Storage                   |
| ---------------------- | ---------------------------------------- | ------------------------- |
| Conversation histories | Full agent reasoning traces              | User-provided (local)     |
| Local reviews          | Human evaluations of agent work          | User-provided (local)     |
| Manifest outcomes      | Task success/failure rates, retry counts | `.impl/manifest.json`     |
| PR review comments     | Human feedback on code quality           | GitHub API                |
| CI results             | Build/test/lint pass rates               | GitHub Actions            |
| Retrospectives         | Synthesized learnings per execution      | `.agents/retrospectives/` |

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

**Regression Detection:**

If agent performance metrics degrade after a memory update (higher retry rates, more review rejections), the system flags the regression. Memory updates are tracked in git, so they can be reverted to the last known-good state. This prevents circular improvement loops where agents learn bad patterns.

#### New skills

| Skill            | Command                               | Description                                  |
| ---------------- | ------------------------------------- | -------------------------------------------- |
| `retro`          | `/retro [plan-path] [--auto]`         | Generate and analyze retrospective           |
| `ingest-history` | `/ingest-history <path>`              | Extract patterns from conversation histories |
| `agent-metrics`  | `/agent-metrics [--agent <id>]`       | Performance reporting and trend analysis     |
| `improve`        | `/improve [--agent <id>] [--dry-run]` | Synthesize learnings into memory updates     |

#### How it connects

- Retrospectives are pipeline documents — they follow the same frontmatter conventions as proposals, plans, and ADRs
- Memory updates go through the same hook enforcement (required frontmatter, structural validation)
- Performance data feeds into `/release-ready` assessments
- Improvement patterns are shared via the same `CLAUDE.md` mechanism Cherny uses at Anthropic

---

### System 6: Checkpointable Acceptance Criteria (The Granularity Layer)

**Inspiration:** Yegge's MEOW stack (Molecular Expression of Work), Anthropic's "scale effort to complexity" principle.

#### Problem

When an agent crashes mid-task, the current system can only retry the entire task. The manifest tracks task-level state (pending → in_progress → passed → merged), but has no visibility into sub-task progress. A task that was 80% complete before a crash restarts from zero.

#### Design

Rather than adding a fourth hierarchy level (Plan → Phase → Task → Step), extend the existing task model with **individually trackable acceptance criteria**. This preserves the current DDD decomposition contract (ADR-008) while adding crash resilience at sub-task granularity.

The `/decompose` skill already produces tasks with acceptance criteria. The change is that each criterion becomes individually addressable in the manifest:

```json
{
  "tasks": [
    {
      "id": "2.1",
      "phase": 2,
      "description": "Add validation middleware to the API router",
      "status": "in_progress",
      "branch": "impl/plan-008/task-2-1",
      "acceptance_criteria": [
        {
          "description": "Middleware rejects requests without auth header with 401",
          "verified": true,
          "verified_at": "2026-02-23T14:20:00Z"
        },
        {
          "description": "Middleware passes valid tokens to next handler",
          "verified": true,
          "verified_at": "2026-02-23T14:22:00Z"
        },
        {
          "description": "Unit tests cover both cases",
          "verified": false,
          "verified_at": null
        }
      ],
      "estimated_complexity": "medium",
      "retries": 0
    }
  ]
}
```

**How NDI works at criterion level:**

1. `/decompose` produces tasks with acceptance criteria (no change to its interface — criteria are already part of task descriptions, now formalized)
2. The `impl-worker` receives criteria as a checklist
3. After implementing each criterion, the worker runs a verification check and marks it in the manifest
4. If the session crashes, `/resume` reads the manifest and identifies which criteria are already verified
5. The resumed worker skips verified criteria and continues from the first unverified one
6. This is Yegge's NDI at sub-task granularity — the path is chaotic but the criteria are deterministic checkpoints

**What doesn't change:**

- The DDD hierarchy remains Plan → Phase → Task (three levels, per ADR-008)
- `/decompose` continues to produce the same output structure
- The `impl-worker` agent contract is unchanged — it receives task details and acceptance criteria
- `/check-impl` continues to validate at task level (all criteria must pass)

**What changes:**

- The manifest schema adds an `acceptance_criteria` array to each task (backward-compatible — tasks without this field work as before)
- `/decompose` formalizes criteria into the structured array format rather than prose
- `impl-worker` reports per-criterion progress back to the manifest
- `/resume` uses criterion-level state for finer-grained recovery

**Complexity-Aware Routing:**

Tasks (not criteria) are tagged with estimated complexity during decomposition. The orchestrator routes work accordingly:

- `low` complexity: Assign to workers without review gate
- `medium` complexity: Standard flow (worker → reviewer → integrator)
- `high` complexity: Worker generates approach document first, human approves before implementation
- `critical` complexity: Human-in-the-loop throughout

#### How it connects

- Extends the existing manifest schema (ADR-008) with backward-compatible fields
- `/decompose` output structure is enhanced, not replaced
- `impl-worker` contract is unchanged — it receives the same information, now also reports per-criterion progress
- `/check-impl` validates criteria individually, enabling partial-pass reporting
- Complexity routing is an orchestrator concern during assignment, not a decomposition change

---

### System 7: The Principled Agent Plugin (The Integration Layer)

All six systems above are delivered as a new first-party plugin: **principled-agents**.

```
plugins/principled-agents/
  .claude-plugin/
    plugin.json
  skills/
    agent-strategy/        # Background knowledge skill
    agent-dispatch/        # Assign issues to agents (System 3)
    agent-respond/         # Address PR review feedback (System 3)
    agent-status/          # Workforce status reporting (System 3)
    resume/                # Resume interrupted orchestration (System 2)
    retro/                 # Generate retrospectives (System 5)
    ingest-history/        # Process conversation histories (System 5)
    agent-metrics/         # Performance dashboards (System 5)
    improve/               # Synthesize learnings into memory (System 5)
  hooks/
    hooks.json
    scripts/
      check-memory-integrity.sh    # Validate .agents/ structure
      capture-retrospective.sh     # PostToolUse hook after orchestration
      inject-agent-memory.sh       # PreToolUse hook before spawn
  agents/
    autonomous-orchestrator.md     # Agent definition for unattended execution
```

#### Interaction with existing agents

The six agents defined across existing plugins (1 shipped, 5 proposed in RFC-008) interact with the new system as follows:

| Agent              | Plugin                    | Gets Identity? |                        Memory Injection?                         |            Contributes to Retrospectives?            |    Managed by Autonomous Orchestrator?     |
| ------------------ | ------------------------- | :------------: | :--------------------------------------------------------------: | :--------------------------------------------------: | :----------------------------------------: |
| `impl-worker`      | principled-implementation |      Yes       | Yes — memory loaded via `inject-agent-memory.sh` PreToolUse hook |  Yes — task outcomes, retry counts, review feedback  | Yes — spawned by orchestrator in all modes |
| `issue-ingester`   | principled-github         |      Yes       |             Yes — triage patterns loaded on dispatch             |   Yes — classification accuracy, triage throughput   |    Yes — invoked via `/agent-dispatch`     |
| `pr-reviewer`      | principled-quality        |      Yes       |               Yes — review quality patterns loaded               |   Yes — review thoroughness, false positive rates    |       Yes — invoked by Reviewer role       |
| `module-auditor`   | principled-docs           |       No       |                                No                                | No — deterministic analysis, no learning opportunity |       No — invoked by `/docs-audit`        |
| `decision-auditor` | principled-docs           |       No       |                                No                                |             No — deterministic analysis              |       No — invoked by `/docs-audit`        |
| `boundary-checker` | principled-architecture   |       No       |                                No                                |             No — deterministic analysis              |       No — invoked by `/arch-drift`        |

The `autonomous-orchestrator` agent defined in this plugin is a new agent role that wraps the `/orchestrate` skill for unattended execution via the Agent SDK. It is distinct from the `impl-worker` — the orchestrator coordinates; workers implement.

#### Plugin relationships

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

Phases are ordered by dependency chain. Each phase lists its RFC-008 prerequisites (if any).

### Phase 1: Memory & Resumability (Systems 1, 2)

**RFC-008 dependency: None.** Can begin immediately using existing manifest (ADR-008) and worktree isolation (ADR-007).

- Implement `.agents/` directory structure, registry, and memory file conventions
- Add checkpoint data to manifest schema (backward-compatible field)
- Build `/resume` skill
- Add agent memory injection to `/spawn` and `/orchestrate` via `inject-agent-memory.sh` hook
- Build `/retro` skill for manual retrospective generation
- Build `check-memory-integrity.sh` hook for `.agents/` structural validation

### Phase 2: GitHub Integration (System 3)

**RFC-008 dependency: None.** Uses existing principled-github skills (already shipped).

- Define the Agent Contributor Protocol in `agent-strategy` reference docs
- Build `/agent-dispatch` and `/agent-respond` skills
- Build `/agent-status` skill
- Extend `/triage` to support agent assignment from registry
- Implement review feedback capture loop (GitHub API → agent memory)
- Implement `--local` execution path for `/agent-dispatch`

### Phase 3: Autonomous Execution (System 4)

**RFC-008 dependency: Partial.** `interactive` and `supervised` modes require only existing infrastructure. The four-role parallel model (Orchestrator/Worker/Reviewer/Integrator) requires RFC-008's agent teams (Plan-008 Phase 6) and lifecycle hooks (Plan-008 Phase 2).

- Add `--mode` flag to `/orchestrate` (supervised, autonomous)
- Implement supervised mode with GitHub progress comments and decision gates
- Implement autonomous mode with progress issue tracking
- Implement the Reviewer and Integrator agent roles (requires agent teams)
- Create `agent-dispatch.yml` GitHub Actions workflow (dispatch infrastructure)

### Phase 4: Self-Improvement (System 5)

**RFC-008 dependency: None.** Builds on Phase 1's memory system.

- Build `/ingest-history` for conversation history processing
- Build `/improve` for memory synthesis
- Build `/agent-metrics` for performance tracking
- Implement the full capture → analyze → synthesize → inject loop
- Implement regression detection (compare metrics before/after memory updates)
- Add trend tracking to verify improvements

### Phase 5: Checkpointable Criteria (System 6)

**RFC-008 dependency: None.** Extends manifest schema (ADR-008) with backward-compatible fields.

- Extend manifest schema with per-criterion tracking
- Extend `/decompose` to produce structured acceptance criteria arrays
- Extend `impl-worker` to report per-criterion progress
- Extend `/check-impl` for criterion-level validation
- Extend `/resume` to use criterion-level state for finer-grained recovery
- Implement complexity-aware routing in `/orchestrate`

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

Extending ADR-011: the principled documentation pipeline remains the single source of truth. Agents don't have "hidden state" — everything is a document with frontmatter, subject to the same lifecycle enforcement as human-authored documents. Memory files, retrospectives, and checkpoints are all documents.

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

## Alternatives Considered

### Alternative 1: Adopt Beads/Gas Town directly instead of building principled-agents

Use Yegge's Beads for agent identity/memory and Gas Town for orchestration, treating them as the orchestration layer for principled.

**Rejected because:** The principled marketplace already has a manifest-driven state system (ADR-008), a documentation pipeline with frontmatter lifecycle enforcement, and worktree-isolated execution (ADR-007). Adopting Beads would introduce a second state system (JSONL + SQLite) alongside the existing manifest, creating impedance mismatch. Gas Town's orchestration model (Mayor, Polecats, Refinery) would need to be reconciled with the principled pipeline's constraint that all state is expressed as documents with frontmatter. Building on the existing architecture preserves the investment in 10+ enforcement hooks, drift checking, and the specification-first pipeline. We adopt Yegge's _principles_ (NDI, git-backed identity, persistent agent state) but implement them within principled's existing document-centric architecture.

### Alternative 2: Extend principled-implementation rather than creating a 7th plugin

Embed the memory, resumability, GitHub integration, and self-improvement systems directly in principled-implementation.

**Rejected because:** The proposed systems span all six existing plugins. Memory injection affects principled-implementation (workers) and principled-github (issue ingester). GitHub collaboration depends on principled-github, principled-quality, and principled-release. Self-improvement reads from principled-implementation manifests and principled-quality review output. A plugin that composes capabilities from all six plugins is architecturally distinct from a plugin that implements one domain. Embedding these capabilities in principled-implementation would violate the single-responsibility principle that keeps each plugin focused. The marketplace convention (RFC-002) is that plugins are self-contained units of related capability — cross-plugin composition is a new capability that warrants its own plugin.

### Alternative 3: Use MCP servers for inter-agent coordination instead of skills and hooks

Deploy an MCP server that agents connect to for coordination, memory, and dispatch — similar to Claude-Flow's approach.

**Rejected because:** Claude Code's native agent primitives (skills, hooks, agent teams, agent frontmatter) provide tighter integration than MCP servers. Skills are already the unit of capability distribution in the marketplace. Hooks provide deterministic enforcement that MCP tools cannot guarantee (PreToolUse guards can block operations; MCP tools cannot). Agent teams provide peer-to-peer messaging and shared task lists that would need to be reimplemented via MCP. MCP servers add a network coordination layer that increases latency and failure modes without adding capabilities beyond what the native primitives offer. If the principled marketplace later needs to integrate with non-Claude agents, MCP becomes relevant — but that is not the current scope.

### Alternative 4: Skip the new plugin; distribute capabilities across existing plugins

Instead of principled-agents, add memory hooks to principled-implementation, GitHub dispatch to principled-github, retrospectives to principled-quality, etc.

**Rejected because:** This distributes a single coherent design across six plugins, making it impossible to install, version, or reason about as a unit. A team that wants autonomous orchestration would need to update all six plugins simultaneously. The improvement loop requires data from four plugins — spreading it across all of them creates circular cross-plugin dependencies. A dedicated plugin provides a clean installation boundary: `principled-agents` is the one thing you install to get the autonomous workforce. The existing plugins remain unchanged.

## Consequences

### Positive

- **Agents accumulate knowledge.** Persistent memory means agents don't repeat past mistakes. Common patterns, codebase conventions, and review feedback persist across sessions.
- **Orchestration survives crashes.** Checkpoint-based resumability means session death doesn't mean work death. Any session can pick up where the previous one left off.
- **Agents collaborate through GitHub.** Humans and agents work through the same interface — issues, PRs, review comments. No separate tooling or workflow for agent-produced work.
- **Performance is measurable.** Retry counts, failure rates, and review rejection rates provide ground truth for evaluating agent effectiveness. Improvement is demonstrable, not anecdotal.
- **Progressive autonomy is configurable.** Teams control how much autonomy agents have. Start supervised; relax gates as trust is established. No all-or-nothing commitment.
- **Existing plugins are unmodified.** The new plugin composes capabilities from existing plugins without changing them. Teams that don't want autonomous orchestration are unaffected.

### Negative

- **`.agents/` directory adds git repository weight.** Memory files, retrospectives, and the registry are committed to git. Over time, this accumulates. Mitigation: retrospectives are small (1-2 KB); memory files have structured sections that replace rather than append; `/improve --prune` removes stale entries.
- **7th plugin increases marketplace complexity.** The marketplace grows from 6 to 7 first-party plugins. Mitigation: principled-agents is optional and has clear value — it's the only plugin that enables autonomous execution.
- **Cross-plugin composition creates implicit coupling.** principled-agents depends on all six other plugins. If principled-github changes its `/triage` interface, principled-agents must adapt. Mitigation: dependencies are on stable skill interfaces (command signatures), not internal implementations. Skill interfaces are versioned via plugin versioning.
- **Autonomous execution consumes tokens without real-time human oversight.** A runaway autonomous agent could burn significant API credits. Mitigation: `--max-workers` cap, retry limits, automatic escalation to supervised mode when failure rates exceed thresholds, and the mandatory quality gates (`/check-impl`, `/review-checklist`) before any merge.
- **Cost scales with parallelism.** Running 4 agent roles (Orchestrator, Workers, Reviewer, Integrator) uses ~4x the tokens of sequential execution. Mitigation: complexity-aware routing (low-complexity tasks skip the review gate), configurable `--max-workers`, and the ability to run in supervised mode (single agent with pause points) when cost matters more than speed.

### Risks

| Risk                                                   | Likelihood | Impact | Mitigation                                                                                                                                                           |
| ------------------------------------------------------ | :--------: | :----: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Agent memory accumulates noise, degrading performance  |   Medium   | Medium | Structured retrospective format; `/improve` uses analysis not raw append; humans can audit/prune memory; regression detection flags degraded metrics                 |
| Autonomous agents produce low-quality code             |   Medium   |  High  | Progressive autonomy — start supervised; mandatory quality gates before merge; metrics trigger automatic downgrade to supervised mode                                |
| Git-backed state creates merge conflicts               |    Low     | Medium | Hash-based IDs for registry (Yegge's Beads pattern); per-agent memory files minimize contention; append-only retrospective files                                     |
| Conversation history ingestion extracts bad patterns   |   Medium   |  Low   | Pattern extraction is additive — bad extractions don't delete existing memory; all extractions are human-reviewable documents; `/improve --dry-run` previews changes |
| GitHub Actions integration couples to platform         |    Low     |  Low   | Dispatch is abstracted behind the `/agent-dispatch` skill; `--local` flag provides platform-independent path; GitHub Actions is swappable                            |
| Circular improvement loops (agent learns bad patterns) |    Low     |  High  | Performance metrics are ground truth; regression detection compares pre/post-update metrics; git history enables memory rollback to last known-good state            |
| RFC-008 delays block Phase 3                           |   Medium   | Medium | Phases 1, 2, 4, 5 have no RFC-008 dependency; only Phase 3's parallel role model requires agent teams                                                                |

## Architecture Impact

This proposal requires updates to the following existing architecture documents:

- **[Plugin System Architecture](../architecture/plugin-system.md)** — Add principled-agents as the first cross-plugin composition plugin. Document the dependency model (principled-agents depends on all six existing plugins via stable skill interfaces). Update the four-layer diagram to show the new orchestration layer above the marketplace layer.
- **[Documentation Pipeline](../architecture/documentation-pipeline.md)** — Add retrospectives and agent memory files as new document types in the pipeline. Both use YAML frontmatter + markdown body. Retrospectives follow the same lifecycle conventions as other pipeline documents. Memory files have a distinct lifecycle (updated by `/improve`, pruned by humans, no terminal status).
- **[Enforcement System](../architecture/enforcement-system.md)** — Add three new hooks: `check-memory-integrity.sh` (PreToolUse guard for `.agents/` writes), `capture-retrospective.sh` (PostToolUse after orchestration completion), `inject-agent-memory.sh` (PreToolUse before spawn to load agent memory). Document the new hook pattern: memory injection as a PreToolUse hook that adds context to agent prompts.

This proposal motivates the following architectural decisions (to be created during implementation):

- ADR: Agent memory format and lifecycle (YAML frontmatter + markdown, committed to git)
- ADR: Checkpoint schema extension to manifest (backward-compatible additive field)
- ADR: Agent contributor protocol governance (draft PRs, co-authorship, human approval required)

## Prior Art

| System                                                                                                                  | Relationship to This Proposal                                                                                                                                                                             |
| ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Gas Town / Beads](https://github.com/steveyegge/gastown) (Yegge)                                                       | NDI principle, git-backed agent identity, MEOW stack work decomposition. We adopt the philosophy but implement it within principled's existing plugin/manifest architecture rather than an external tool. |
| [Claude-Flow](https://github.com/ruvnet/claude-flow) (Cohen)                                                            | Swarm coordination via MCP, adaptive routing, agent memory. We take the adaptive routing concept but embed it in the principled documentation pipeline rather than a separate orchestration layer.        |
| [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams) (Anthropic)                                      | TeammateTool for peer-to-peer agent coordination. RFC-008 already proposes adoption; this RFC extends it with persistent identity, memory, and autonomous lifecycle.                                      |
| [Anthropic's Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system)            | Production lessons on detailed delegation, effort scaling, and debugging. These lessons directly inform the complexity-aware routing and checkpoint design.                                               |
| [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) (Schluntz & Zhang, Anthropic) | Orchestrator-worker pattern, evaluator-optimizer loop. The four-role system (Orchestrator, Worker, Reviewer, Integrator) extends their two-role pattern.                                                  |
| [Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)                     | Runtime environment with lifecycle hooks. Our hook system (principled-docs, principled-implementation) maps directly to SDK hooks; the new plugin adds memory-injection and retrospective-capture hooks.  |
| [GitHub Copilot Coding Agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent)                          | Agent-as-outside-collaborator governance model: draft PRs, co-authored commits, human approval required, protected branch enforcement. Directly informs the Agent Contributor Protocol.                   |
| [ICLR 2026 RSI Workshop](https://recursive-workshop.github.io/)                                                         | Formalized research on structured self-improvement. Our improvement loop follows their "diagnose → critique → update → verify" pattern.                                                                   |
| [Cherny's Workflow](https://howborisusesclaudecode.com/)                                                                | `CLAUDE.md` as team memory, verification loops, multi-session parallelism. Our agent memory system formalizes and structures the `CLAUDE.md` pattern for machine consumption.                             |

## Success Criteria

All criteria are binary and testable:

1. **Resumability**: Given an orchestration session interrupted mid-phase (simulated by terminating the session), running `/resume` completes the remaining tasks without re-executing tasks whose manifest status is `merged`.

2. **Checkpoint fidelity**: A resumed session's first action references information from the checkpoint's `orchestrator_summary` field (verified by inspecting the conversation transcript).

3. **Memory injection**: An `impl-worker` spawned via `/spawn` receives the content of its memory file in its initial prompt (verified by inspecting the agent's transcript for memory file content).

4. **Autonomous execution**: A plan with 5+ tasks across 2+ phases executes in autonomous mode, producing a draft PR that passes CI, with no human intervention between `/orchestrate` invocation and PR creation.

5. **GitHub collaboration**: An issue labeled `agent-ready` triggers `/agent-dispatch`, flows through the contributor protocol, and produces a draft PR linked to the originating issue — with the full principled pipeline trail (proposal, plan, manifest) in the PR description.

6. **Retrospective generation**: After an orchestration run, `/retro` produces a retrospective document in `.agents/retrospectives/` with valid frontmatter, task outcome summary, and recommendations section.

7. **Memory improvement signal**: After 5+ orchestration runs with `/retro` and `/improve`, the agent memory files contain at least 3 distinct, non-redundant patterns extracted from retrospective analysis.

8. **Regression detection**: When a memory update causes retry rates to increase (measured across 2+ subsequent runs), `/agent-metrics` flags the regression in its output.

9. **Criterion-level resume**: Given a task with 3 acceptance criteria where 2 are verified in the manifest, a resumed worker begins work on the 3rd criterion without re-implementing the first two.

## Open Questions

1. **Conversation history privacy.** Conversation histories may contain sensitive data (API keys, internal URLs, proprietary logic). Should `/ingest-history` extract patterns locally and commit only sanitized findings? Or should raw histories never be processed by the plugin? The current design assumes extracted patterns are safe to commit — but this may need a `--sensitive` flag that keeps patterns in `.gitignore`-d local storage.

2. **Agent identity persistence across forks.** If a repository is forked, should agent identities and memory carry over? The memory is valuable (codebase knowledge transfers), but performance metrics may not apply (different CI environment, different reviewers). A reasonable default: memory files transfer; registry metrics reset on fork.

3. **Multi-repo orchestration.** The current design is single-repo. In a monorepo-of-repos setup where principled plugins are installed in each repo, should the agent workforce coordinate across repositories? This is explicitly out of scope for this RFC — each repo has its own `.agents/` directory and independent workforce. Cross-repo coordination would be a future RFC if demand materializes.

## Relationship to RFC-008

RFC-008 (Hooks, Subagents, and Agent Teams Integration) is a partial prerequisite for this proposal. The dependency is precise:

| RFC-009 Phase                    | RFC-008 Prerequisite | Specific Dependency                                                                                         |
| -------------------------------- | :------------------: | ----------------------------------------------------------------------------------------------------------- |
| Phase 1: Memory & Resumability   |         None         | Uses existing manifest schema (ADR-008), worktree isolation (ADR-007)                                       |
| Phase 2: GitHub Integration      |         None         | Uses existing principled-github skills (shipped in v1.0.0)                                                  |
| Phase 3: Autonomous Execution    | Plan-008 Phases 2, 6 | Requires lifecycle hooks (`SubagentStop`, `TaskCompleted`) and agent teams for the four-role parallel model |
| Phase 4: Self-Improvement        |         None         | Builds on Phase 1's memory system                                                                           |
| Phase 5: Checkpointable Criteria |         None         | Extends manifest schema with backward-compatible fields                                                     |

**Three of five phases can proceed independently of RFC-008.** Only Phase 3's parallel role model (Orchestrator/Worker/Reviewer/Integrator) requires RFC-008's agent teams and lifecycle hooks. The supervised and interactive modes of Phase 3 can also proceed without RFC-008 — they use sequential execution.

If RFC-008 is modified or rejected:

- Phases 1, 2, 4, 5 are unaffected
- Phase 3 falls back to sequential execution with supervised/interactive modes only (no parallel roles)
- The five RFC-008 sub-agents (module-auditor, decision-auditor, issue-ingester, pr-reviewer, boundary-checker) would not exist, but principal-agents' design degrades gracefully — the agent identity table in System 7 shows that only 3 of the 6 agents benefit from persistent identity, and `impl-worker` (the primary beneficiary) is already shipped

This proposal (RFC-009) extends RFC-008's foundation with persistent identity, autonomous lifecycle, and self-improvement — the capabilities needed to scale from "agent tool" to "agent workforce."
