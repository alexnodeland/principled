---
title: "Principled Tasks Plugin"
number: 009
status: accepted
author: Alex
created: 2026-02-27
updated: 2026-02-27
supersedes: null
superseded_by: null
---

# RFC-009: Principled Tasks Plugin

## Audience

- Teams using the principled methodology who need persistent, graph-structured task tracking
- Engineers orchestrating multi-phase plans who need visibility into task dependencies and status
- Plugin maintainers evaluating the task management layer
- Contributors to the principled marketplace

## Context

The principled-implementation plugin tracks task state in `.impl/manifest.json` — a flat JSON file that records task status, branch names, and validation results. This works well for a single plan execution but has limitations:

1. **No cross-plan visibility.** Each plan execution creates its own manifest. There is no unified view of all tasks across plans, making it hard to answer questions like "what tasks are blocked?" or "what did agent X work on?"

2. **No graph structure.** The manifest tracks phase-level dependencies but not fine-grained task relationships: which task blocks which, which task was spawned by which, which tasks are part of a larger effort. These relationships exist implicitly in the plan markdown but are not queryable.

3. **No discovery tracking.** During implementation, agents frequently discover additional work — new tasks, follow-up fixes, refactoring needs. These discoveries have no home in the current manifest; they're lost between sessions unless manually tracked.

4. **No persistent history.** The manifest is overwritten on each `/decompose` run. Historical task data — what was completed, when, by which agent — is not preserved across plan lifecycles.

5. **No natural-language querying.** Answering questions about task status requires reading JSON and filtering manually. There is no way to ask "show me all blocked tasks for plan 003" in natural language.

SQLite addresses all of these: it is a single file, supports relational queries, handles graph structures via edge tables, and is Git-committable. The `sqlite3` CLI is available on virtually every development machine.

## Proposal

Add a new first-party plugin, `principled-tasks`, to the marketplace. This plugin provides a SQLite-backed, Git-committed, graph-structured task tracking system for principled orchestration. Tasks (called "beads" after the Beads methodology) form a directed graph with typed edges, enabling dependency tracking, discovery chains, and cross-plan visibility.

### 1. Plugin Structure

```
plugins/principled-tasks/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── check-db-integrity.sh
├── scripts/
│   └── check-template-drift.sh
└── skills/
    ├── task-strategy/
    │   ├── SKILL.md
    │   └── reference/
    │       ├── bead-model.md
    │       └── schema.md
    ├── task-open/
    │   ├── SKILL.md
    │   └── scripts/
    │       └── task-db.sh          (CANONICAL)
    ├── task-close/
    │   ├── SKILL.md
    │   └── scripts/
    │       └── task-db.sh          (COPY)
    ├── task-graph/
    │   ├── SKILL.md
    │   └── scripts/
    │       └── task-db.sh          (COPY)
    ├── task-audit/
    │   ├── SKILL.md
    │   └── scripts/
    │       └── task-db.sh          (COPY)
    └── task-query/
        ├── SKILL.md
        └── scripts/
            └── task-db.sh          (COPY)
```

### 2. Data Model

The database lives at `.impl/tasks.db` and is committed to Git after every write operation.

**Beads table** — each row is a task:

| Column            | Type | Constraints                                                  |
| ----------------- | ---- | ------------------------------------------------------------ |
| `id`              | TEXT | PRIMARY KEY                                                  |
| `title`           | TEXT | NOT NULL                                                     |
| `status`          | TEXT | NOT NULL, CHECK(IN open, in_progress, done, blocked, abandoned) |
| `agent`           | TEXT | Nullable — which agent worked on it                          |
| `plan`            | TEXT | Nullable — originating plan number                           |
| `task_id`         | TEXT | Nullable — task ID from plan manifest                        |
| `notes`           | TEXT | Nullable — freeform notes                                    |
| `created_at`      | TEXT | NOT NULL — ISO 8601 timestamp                                |
| `closed_at`       | TEXT | Nullable — when status became done/abandoned                 |
| `discovered_from` | TEXT | Nullable — bead ID that led to discovery of this one         |

**Bead edges table** — typed directed edges between beads:

| Column    | Type | Constraints                                               |
| --------- | ---- | --------------------------------------------------------- |
| `from_id` | TEXT | NOT NULL                                                  |
| `to_id`   | TEXT | NOT NULL                                                  |
| `kind`    | TEXT | NOT NULL, CHECK(IN blocks, spawned_by, part_of, related_to) |
| PRIMARY KEY | — | `(from_id, to_id, kind)`                                  |

### 3. Skills

| Skill        | Command                                                      | Category   |
| ------------ | ------------------------------------------------------------ | ---------- |
| task-strategy | _(background — not user-invocable)_                         | Knowledge  |
| task-open    | `/task-open <title> [--plan NNN] [--blocks <id>] [--discovered-from <id>]` | Generative |
| task-close   | `/task-close <id> [--notes <text>]`                          | Generative |
| task-graph   | `/task-graph [--plan NNN] [--open] [--dot]`                  | Analytical |
| task-audit   | `/task-audit [--plan NNN] [--agent <name>]`                  | Analytical |
| task-query   | `/task-query "<natural language question>"`                   | Analytical |

### 4. Hook

One advisory hook monitors direct edits to `tasks.db`:

| Hook                    | Event                    | Behavior                                                  |
| ----------------------- | ------------------------ | --------------------------------------------------------- |
| DB Integrity Advisory   | PreToolUse (Edit\|Write) | Warns when `.impl/tasks.db` is edited directly. Advisory only (exit 0). |

### 5. Script Duplication

| Script       | Canonical Location                          | Copies                                               |
| ------------ | ------------------------------------------- | ---------------------------------------------------- |
| `task-db.sh` | `skills/task-open/scripts/task-db.sh`       | task-close, task-graph, task-audit, task-query        |

Drift is verified by `scripts/check-template-drift.sh`.

### 6. Git Commitment

After every write operation (open, close, status change), the skill runs:

```bash
git add .impl/tasks.db && git commit -m "tasks: <action description>"
```

This ensures the task graph is version-controlled and visible in diffs.

## Alternatives Considered

### 1. Extend manifest.json

Add graph fields to the existing `.impl/manifest.json` used by principled-implementation.

**Rejected** because: JSON is not queryable, the manifest is already complex, and cross-plan tracking requires a separate data store. The manifest serves orchestration state; the task graph serves historical visibility.

### 2. Markdown-based task tracking

Track tasks as markdown files (one per task) in a `.impl/tasks/` directory.

**Rejected** because: graph relationships between files are cumbersome, querying across hundreds of task files is slow, and aggregation requires custom parsing.

### 3. JSON graph file

A single `.impl/tasks.json` with nodes and edges arrays.

**Rejected** because: JSON has no query language. Every read requires parsing the entire file. SQLite gives us SQL for free.

## Consequences

### Positive

- Unified cross-plan task visibility via SQL queries
- Typed graph edges enable dependency analysis, discovery tracking, and audit
- SQLite is zero-dependency (the `sqlite3` CLI ships with macOS and most Linux distributions)
- Git-committed DB provides full version history
- Natural-language queries via Claude's SQL generation

### Negative

- Binary file in Git (SQLite DB) produces opaque diffs
- Additional disk usage (minimal — SQLite is compact)
- New dependency on `sqlite3` CLI (widely available but not guaranteed)

## Architecture Impact

- `.impl/` directory gains a new file: `tasks.db`
- principled-tasks operates independently of principled-implementation; future integration could link manifest tasks to beads
- No changes to existing plugins required

## Decisions

- ADR-017: SQLite as the task graph storage engine
