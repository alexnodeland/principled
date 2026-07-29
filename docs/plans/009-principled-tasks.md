---
title: "Principled Tasks Plugin"
number: "009"
status: complete
author: Alex
created: 2026-02-27
updated: 2026-07-29
originating_proposal: "009"
---

# Plan-009: Principled Tasks Plugin

## Objective

Implements [RFC-009](../proposals/009-principled-tasks.md).

Build the `principled-tasks` Claude Code plugin end-to-end: plugin infrastructure, 6 skills (1 background + 5 user-invocable), 1 advisory hook, 1 canonical script with 4 copies, drift detection, reference documentation, and a plugin README — following the directory layout and conventions established in the marketplace.

---

## Domain Analysis

### Bounded Contexts

This implementation decomposes into **5 bounded contexts**, each representing a distinct area of domain responsibility within the plugin:

| #    | Bounded Context           | Responsibility                                                     | Key Artifacts                                         |
| ---- | ------------------------- | ------------------------------------------------------------------ | ----------------------------------------------------- |
| BC-1 | **Plugin Infrastructure** | Plugin manifest, directory skeleton, marketplace integration       | `plugin.json`, directory tree, marketplace.json entry |
| BC-2 | **Database Engine**       | SQLite schema initialization, CRUD operations, Git commitment      | `task-db.sh`, schema definition                       |
| BC-3 | **Knowledge System**      | Background knowledge: task model, schema reference, edge semantics | `task-strategy/SKILL.md`, reference docs              |
| BC-4 | **Write Skills**          | Creating and closing beads with edges and Git commits              | `task-open/SKILL.md`, `task-close/SKILL.md`           |
| BC-5 | **Read Skills**           | Graph visualization, audit reporting, natural-language querying    | `task-graph/`, `task-audit/`, `task-query/` skills    |

### Aggregates

#### BC-1: Plugin Infrastructure

| Aggregate          | Root Entity   | Description                                                    |
| ------------------ | ------------- | -------------------------------------------------------------- |
| **PluginManifest** | `plugin.json` | Plugin identity, version, metadata                             |
| **DirectoryTree**  | Plugin root   | Complete directory skeleton for all skills, hooks, and scripts |

#### BC-2: Database Engine

| Aggregate        | Root Entity  | Description                                                                                |
| ---------------- | ------------ | ------------------------------------------------------------------------------------------ |
| **TaskDB**       | `task-db.sh` | SQLite interface: init schema, insert beads, update status, add edges, query, export graph |
| **GitCommitter** | `task-db.sh` | After-write hook within the script that stages and commits `.impl/tasks.db`                |

#### BC-3: Knowledge System

| Aggregate       | Root Entity               | Description                                                         |
| --------------- | ------------------------- | ------------------------------------------------------------------- |
| **BeadModel**   | `reference/task-model.md` | Bead lifecycle, edge semantics, discovery chains                    |
| **SchemaRef**   | `reference/schema.md`     | Complete SQLite schema with field descriptions and constraints      |
| **StrategyDef** | `task-strategy/SKILL.md`  | Background knowledge for Claude when task-related context is active |

#### BC-4: Write Skills

| Aggregate          | Root Entity           | Description                                                          |
| ------------------ | --------------------- | -------------------------------------------------------------------- |
| **TaskOpenSkill**  | `task-open/SKILL.md`  | Creates beads with optional plan link, blocking edges, discovery ref |
| **TaskCloseSkill** | `task-close/SKILL.md` | Closes beads with notes, sets closed_at timestamp                    |

#### BC-5: Read Skills

| Aggregate          | Root Entity           | Description                                                    |
| ------------------ | --------------------- | -------------------------------------------------------------- |
| **TaskGraphSkill** | `task-graph/SKILL.md` | Visualize the bead graph, filter by plan or status, DOT export |
| **TaskAuditSkill** | `task-audit/SKILL.md` | Audit bead health: orphans, cycles, stale in_progress          |
| **TaskQuerySkill** | `task-query/SKILL.md` | Natural-language to SQL translation for ad-hoc queries         |

### Domain Events

| Event                     | Source Context        | Target Context(s)      | Description                                                |
| ------------------------- | --------------------- | ---------------------- | ---------------------------------------------------------- |
| **PluginSkeletonCreated** | BC-1 (Infrastructure) | BC-2, BC-3, BC-4, BC-5 | Directory tree exists; all contexts can populate artifacts |
| **SchemaReady**           | BC-2 (Database)       | BC-4, BC-5             | task-db.sh --init works; write and read skills can operate |
| **KnowledgeComplete**     | BC-3 (Knowledge)      | BC-4, BC-5             | Reference docs available for skills to consult             |
| **BeadCreated**           | BC-4 (Write)          | BC-5 (Read)            | New bead in DB; graph/audit/query reflect it               |
| **BeadClosed**            | BC-4 (Write)          | BC-5 (Read)            | Bead status updated; graph/audit/query reflect it          |
| **DBCommitted**           | BC-2 (Database)       | Git                    | tasks.db staged and committed after every write            |

---

## Implementation Tasks

### Phase 1: Plugin Skeleton & Database Engine (BC-1, BC-2)

**Goal:** Create the complete directory tree, plugin manifest, and canonical task-db.sh script.

- [x] **1.1** Create `.claude-plugin/plugin.json` with name, version, description, author, homepage, keywords
- [x] **1.2** Create the full directory skeleton: all skill directories, hook directory, scripts directory
- [x] **1.3** Implement `task-db.sh` (shipped at `lib/task-db.sh`, not under a skill — see Completion Record):
  - [x] `--init` — Create `.impl/tasks.db` with beads and bead_edges tables
  - [x] `--open` — Insert a new bead with generated ID, title, status, timestamps
  - [x] `--close` — Update bead status to done/abandoned, set closed_at
  - [x] `--add-edge` — Insert a typed edge between two beads
  - [x] `--get` — Retrieve a single bead by ID
  - [x] `--list` — List beads with optional filters (plan, status, agent)
  - [x] `--graph` — Output bead graph (optional DOT format)
  - [x] `--audit` — Run audit queries (orphans, stale, cycles)
  - [x] `--commit` — Git add and commit tasks.db
- ~~**1.4** Copy `task-db.sh` to: task-close, task-graph, task-audit, task-query~~ — **superseded by [ADR-018](../decisions/018-shared-plugin-lib-over-copies.md).** One copy in `lib/`; nothing to propagate.
- ~~**1.5** Implement `scripts/check-template-drift.sh` for all 4 copy pairs~~ — **superseded by [ADR-018](../decisions/018-shared-plugin-lib-over-copies.md).** With no copies there is no drift to detect; `scripts/check-skill-references.sh` verifies the `${CLAUDE_PLUGIN_ROOT}/lib/` reference instead.

### Phase 2: Knowledge System & Hook (BC-3, Hook)

**Goal:** Build reference documentation and advisory hook.

**Depends on:** Phase 1 (directory skeleton exists)

- [x] **2.1** Write `skills/task-strategy/reference/task-model.md`:
  - [x] Bead lifecycle: open → in_progress → done/blocked/abandoned
  - [x] Edge semantics: blocks, spawned_by, part_of, related_to
  - [x] Discovery chains: how discovered_from links tasks
  - [x] Integration with principled-implementation manifests
- [x] **2.2** Write `skills/task-strategy/reference/schema.md`:
  - [x] Complete CREATE TABLE statements with commentary
  - [x] Field descriptions, constraints, indexing notes
  - [x] Example queries for common operations
- [x] **2.3** Write `skills/task-strategy/SKILL.md`:
  - [x] Background knowledge skill (not user-invocable)
  - [x] When to consult, reference documentation pointers
- [x] **2.4** Implement `hooks/scripts/check-db-integrity.sh`:
  - [x] Read JSON from stdin (tool_input.file_path)
  - [x] Warn if path matches `.impl/tasks.db`
  - [x] Advisory only — always exit 0
- [x] **2.5** Write `hooks/hooks.json` with PreToolUse advisory hook

### Phase 3: Write Skills (BC-4)

**Goal:** Implement task-open and task-close skills.

**Depends on:** Phase 1 (task-db.sh canonical exists)

- [x] **3.1** Write `skills/task-open/SKILL.md`:
  - [x] Parse arguments: title, --plan, --blocks, --discovered-from
  - [x] Initialize DB if needed
  - [x] Generate bead ID, insert bead, add edges
  - [x] Git commit after write
  - [x] Report created bead
- [x] **3.2** Write `skills/task-close/SKILL.md`:
  - [x] Parse arguments: id, --notes
  - [x] Update bead status to done, set closed_at and notes
  - [x] Git commit after write
  - [x] Report closed bead

### Phase 4: Read Skills (BC-5)

**Goal:** Implement task-graph, task-audit, and task-query skills.

**Depends on:** Phase 1 (task-db.sh canonical exists)

- [x] **4.1** Write `skills/task-graph/SKILL.md`:
  - [x] Parse arguments: --plan, --open, --dot
  - [x] Query beads and edges, filter as requested
  - [x] Render as table or DOT graph
- [x] **4.2** Write `skills/task-audit/SKILL.md`:
  - [x] Parse arguments: --plan, --agent
  - [x] Run audit queries: orphan beads, stale in_progress, blocked chains, agent workload
  - [x] Report findings with recommendations
- [x] **4.3** Write `skills/task-query/SKILL.md`:
  - [x] Parse natural-language question
  - [x] Translate to SQL using schema knowledge
  - [x] Execute and format results

### Phase 5: Documentation & Integration (Plugin Docs)

**Goal:** Write README, register in marketplace, finalize.

**Depends on:** Phases 1–4

- [x] **5.1** Write plugin `README.md` with badges, quick start, skills table, hook description, architecture
- [x] **5.2** Register plugin in `.claude-plugin/marketplace.json`

---

## Decisions Required

1. **SQLite as task graph storage.** Decided in ADR-017. SQLite provides SQL querying, graph modeling via edge tables, single-file storage, and Git compatibility.

---

## Dependencies

| Dependency                         | Required By           | Status            |
| ---------------------------------- | --------------------- | ----------------- |
| Claude Code v2.1.3+ plugin system  | Entire implementation | Assumed available |
| Bash shell with standard utilities | All scripts           | Assumed available |
| `sqlite3` CLI                      | task-db.sh            | Required          |
| Git                                | DB commitment         | Assumed available |
| `jq` (optional)                    | JSON output modes     | Optional fallback |

---

## Acceptance Criteria

- [x] `/task-open "Fix login bug" --plan 003` creates a bead in `.impl/tasks.db` and commits
- [x] `/task-open "Refactor auth" --blocks bead-001 --discovered-from bead-002` creates bead with edges
- [x] `/task-close bead-001 --notes "Resolved via PR #42"` updates status and commits
- [x] `/task-graph` displays all beads and edges as a formatted table
- [x] `/task-graph --plan 003 --open --dot` outputs DOT format filtered to plan 003 open beads
- [x] `/task-audit` reports orphan beads, stale in_progress, and agent workload
- [x] `/task-query "what tasks are blocked?"` translates to SQL and returns results
- [x] `check-db-integrity.sh` warns on direct `.impl/tasks.db` edits (exit 0) — and on `.principled/tasks.jsonl`, the record it turned out to matter more to protect
- ~~`check-template-drift.sh` passes when all task-db.sh copies match canonical~~ — **superseded by [ADR-018](../decisions/018-shared-plugin-lib-over-copies.md).**
- ~~`check-template-drift.sh` fails when a copy diverges~~ — **superseded by [ADR-018](../decisions/018-shared-plugin-lib-over-copies.md).**
- [x] Plugin registered in marketplace.json with correct source path
- ~~All skills are self-contained with their own SKILL.md and scripts~~ — **superseded by [ADR-018](../decisions/018-shared-plugin-lib-over-copies.md).** Every skill has its own SKILL.md; shared code is referenced from `lib/`, not copied into each skill.

---

## Cross-Reference Map

| RFC Section            | Plan Phase | Key Tasks |
| ---------------------- | ---------- | --------- |
| §1 Plugin Structure    | Phase 1    | 1.1, 1.2  |
| §2 Data Model          | Phase 1    | 1.3       |
| §5 Script Duplication  | Phase 1    | 1.4, 1.5  |
| §3 Skills (background) | Phase 2    | 2.1–2.3   |
| §4 Hook                | Phase 2    | 2.4, 2.5  |
| §3 Skills (write)      | Phase 3    | 3.1, 3.2  |
| §3 Skills (read)       | Phase 4    | 4.1–4.3   |
| §6 Git Commitment      | Phase 3, 4 | 3.1, 3.2  |
| Plugin Docs            | Phase 5    | 5.1, 5.2  |

---

## Completion Record

Verified 2026-07-29 against the repository. The boxes above were ticked from that
verification, not from memory of the work.

**Evidence.** All 7 skills present under `plugins/principled-tasks/skills/` (the plan
scoped 6; `task-update` was added during implementation). `lib/task-db.sh` implements
every operation the plan listed — `--init`, `--open`, `--close`, `--add-edge`, `--get`,
`--list`, `--graph`, `--audit`, `--commit` — plus `--update` and `--sync`. Reference docs,
`hooks/hooks.json`, `hooks/scripts/check-db-integrity.sh`, the plugin README, and the
`marketplace.json` entry all exist. `tests/task-db.bats` covers the library end to end and
passes.

**Divergences from the plan as written.** Three, all deliberate:

1. **Storage.** The plan says "bead in `.impl/tasks.db`". [ADR-017](../decisions/017-event-log-task-graph.md)
   made `.principled/tasks.jsonl` the record and SQLite a derived cache, so writes append
   to the log and commit it; the cache is rebuilt and gitignored. The plan's "bead"
   vocabulary became "task" throughout.
2. **Shared code.** Tasks 1.4, 1.5 and two acceptance criteria described a canonical
   script copied into four skills with a drift checker. [ADR-018](../decisions/018-shared-plugin-lib-over-copies.md)
   replaced that with a single `lib/task-db.sh`. Those items are struck through above
   rather than ticked: the work was not done, and should not have been.
3. **Skill count.** 7 shipped against 6 planned.
