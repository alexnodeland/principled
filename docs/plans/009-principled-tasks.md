---
title: "Principled Tasks Plugin"
number: "009"
status: active
author: Alex
created: 2026-02-27
updated: 2026-02-27
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

- [ ] **1.1** Create `.claude-plugin/plugin.json` with name, version, description, author, homepage, keywords
- [ ] **1.2** Create the full directory skeleton: all skill directories, hook directory, scripts directory
- [ ] **1.3** Implement `skills/task-open/scripts/task-db.sh` (canonical):
  - [ ] `--init` — Create `.impl/tasks.db` with beads and bead_edges tables
  - [ ] `--open` — Insert a new bead with generated ID, title, status, timestamps
  - [ ] `--close` — Update bead status to done/abandoned, set closed_at
  - [ ] `--add-edge` — Insert a typed edge between two beads
  - [ ] `--get` — Retrieve a single bead by ID
  - [ ] `--list` — List beads with optional filters (plan, status, agent)
  - [ ] `--graph` — Output bead graph (optional DOT format)
  - [ ] `--audit` — Run audit queries (orphans, stale, cycles)
  - [ ] `--commit` — Git add and commit tasks.db
- [ ] **1.4** Copy `task-db.sh` to: task-close, task-graph, task-audit, task-query
- [ ] **1.5** Implement `scripts/check-template-drift.sh` for all 4 copy pairs

### Phase 2: Knowledge System & Hook (BC-3, Hook)

**Goal:** Build reference documentation and advisory hook.

**Depends on:** Phase 1 (directory skeleton exists)

- [ ] **2.1** Write `skills/task-strategy/reference/task-model.md`:
  - [ ] Bead lifecycle: open → in_progress → done/blocked/abandoned
  - [ ] Edge semantics: blocks, spawned_by, part_of, related_to
  - [ ] Discovery chains: how discovered_from links tasks
  - [ ] Integration with principled-implementation manifests
- [ ] **2.2** Write `skills/task-strategy/reference/schema.md`:
  - [ ] Complete CREATE TABLE statements with commentary
  - [ ] Field descriptions, constraints, indexing notes
  - [ ] Example queries for common operations
- [ ] **2.3** Write `skills/task-strategy/SKILL.md`:
  - [ ] Background knowledge skill (not user-invocable)
  - [ ] When to consult, reference documentation pointers
- [ ] **2.4** Implement `hooks/scripts/check-db-integrity.sh`:
  - [ ] Read JSON from stdin (tool_input.file_path)
  - [ ] Warn if path matches `.impl/tasks.db`
  - [ ] Advisory only — always exit 0
- [ ] **2.5** Write `hooks/hooks.json` with PreToolUse advisory hook

### Phase 3: Write Skills (BC-4)

**Goal:** Implement task-open and task-close skills.

**Depends on:** Phase 1 (task-db.sh canonical exists)

- [ ] **3.1** Write `skills/task-open/SKILL.md`:
  - [ ] Parse arguments: title, --plan, --blocks, --discovered-from
  - [ ] Initialize DB if needed
  - [ ] Generate bead ID, insert bead, add edges
  - [ ] Git commit after write
  - [ ] Report created bead
- [ ] **3.2** Write `skills/task-close/SKILL.md`:
  - [ ] Parse arguments: id, --notes
  - [ ] Update bead status to done, set closed_at and notes
  - [ ] Git commit after write
  - [ ] Report closed bead

### Phase 4: Read Skills (BC-5)

**Goal:** Implement task-graph, task-audit, and task-query skills.

**Depends on:** Phase 1 (task-db.sh canonical exists)

- [ ] **4.1** Write `skills/task-graph/SKILL.md`:
  - [ ] Parse arguments: --plan, --open, --dot
  - [ ] Query beads and edges, filter as requested
  - [ ] Render as table or DOT graph
- [ ] **4.2** Write `skills/task-audit/SKILL.md`:
  - [ ] Parse arguments: --plan, --agent
  - [ ] Run audit queries: orphan beads, stale in_progress, blocked chains, agent workload
  - [ ] Report findings with recommendations
- [ ] **4.3** Write `skills/task-query/SKILL.md`:
  - [ ] Parse natural-language question
  - [ ] Translate to SQL using schema knowledge
  - [ ] Execute and format results

### Phase 5: Documentation & Integration (Plugin Docs)

**Goal:** Write README, register in marketplace, finalize.

**Depends on:** Phases 1–4

- [ ] **5.1** Write plugin `README.md` with badges, quick start, skills table, hook description, architecture
- [ ] **5.2** Register plugin in `.claude-plugin/marketplace.json`

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

- [ ] `/task-open "Fix login bug" --plan 003` creates a bead in `.impl/tasks.db` and commits
- [ ] `/task-open "Refactor auth" --blocks bead-001 --discovered-from bead-002` creates bead with edges
- [ ] `/task-close bead-001 --notes "Resolved via PR #42"` updates status and commits
- [ ] `/task-graph` displays all beads and edges as a formatted table
- [ ] `/task-graph --plan 003 --open --dot` outputs DOT format filtered to plan 003 open beads
- [ ] `/task-audit` reports orphan beads, stale in_progress, and agent workload
- [ ] `/task-query "what tasks are blocked?"` translates to SQL and returns results
- [ ] `check-db-integrity.sh` warns on direct `.impl/tasks.db` edits (exit 0)
- [ ] `check-template-drift.sh` passes when all task-db.sh copies match canonical
- [ ] `check-template-drift.sh` fails when a copy diverges
- [ ] Plugin registered in marketplace.json with correct source path
- [ ] All skills are self-contained with their own SKILL.md and scripts

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
