# Storage and Schema Reference

The task graph has two files with different roles (ADR-017):

| File                      | Role                         | In Git?    | Rebuildable?              |
| ------------------------- | ---------------------------- | ---------- | ------------------------- |
| `.principled/tasks.jsonl` | Append-only event log        | Committed  | No — this is the record   |
| `.impl/tasks.db`          | SQLite cache folded from log | Gitignored | Yes — `task-db.sh --sync` |

**The log is the source of truth. The database is a disposable index.** Delete `.impl/`
at any time and `--sync` reconstructs identical state. Never edit either file by hand;
go through `task-db.sh` so the log stays the authoritative record.

## Why an event log

An earlier design committed the SQLite file itself. That cannot work for parallel
agents: a binary database conflicts on every concurrent write, and `.impl/` is
gitignored, so the "committed" database was in fact never committed at all.

An append-only text log fixes both. Each mutation appends one line, so two agents on
separate branches touch different lines and git merges them cleanly.

## Merge behavior

`--init` registers a union merge driver in `.gitattributes`:

```
.principled/tasks.jsonl merge=union
```

Union merge keeps lines from both sides instead of raising a conflict — exactly right
for an append-only log. Without it, two agents appending on separate branches conflict
at the end of the file. If you clone a repo with an existing log, verify this line is
present before running parallel agents.

## Event log format

One JSON object per line. Events are written by sqlite3's `json_object()`, so titles
containing quotes, backslashes, pipes, or newlines round-trip safely.

| `op`     | Fields                                                             | Effect                      |
| -------- | ------------------------------------------------------------------ | --------------------------- |
| `open`   | `id`, `title`, `ts`, `plan`, `agent`, `task_id`, `discovered_from` | Creates a task, status open |
| `update` | `id`, `ts`, and any of `status`, `notes`, `agent`                  | Applies the last-wins value |
| `close`  | `id`, `ts`, `status` (`done`\|`abandoned`), `notes`                | Closes the task             |
| `edge`   | `from_id`, `to_id`, `kind`, `ts`                                   | Adds a typed edge           |

Example:

```json
{"op":"open","id":"task-e295b1b1","title":"fix parser","ts":"2026-07-28T13:11:00Z","plan":"007","agent":"alpha","task_id":"","discovered_from":""}
{"op":"edge","from_id":"task-230927f6","to_id":"task-e295b1b1","kind":"blocks","ts":"2026-07-28T13:11:00Z"}
{"op":"close","id":"task-e295b1b1","status":"done","notes":"shipped","ts":"2026-07-28T13:11:10Z"}
```

State is the ordered fold of these events, so replaying the same log always yields the
same graph. Two clones with the same log agree on the same state.

## Derived cache schema

### tasks

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('open','in_progress','done','blocked','abandoned')),
  agent TEXT,
  plan TEXT,
  task_id TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  closed_at TEXT,
  discovered_from TEXT
);
```

| Column            | Type | Description                                                |
| ----------------- | ---- | ---------------------------------------------------------- |
| `id`              | TEXT | Unique identifier, format: `task-XXXXXXXX` (8 hex chars)   |
| `title`           | TEXT | Human-readable task description                            |
| `status`          | TEXT | Current state: open, in_progress, done, blocked, abandoned |
| `agent`           | TEXT | Name of the agent that worked on this task (nullable)      |
| `plan`            | TEXT | Originating plan number, e.g. "003" (nullable)             |
| `task_id`         | TEXT | Task ID from plan manifest, e.g. "1.1" (nullable)          |
| `notes`           | TEXT | Freeform notes, typically set at close time (nullable)     |
| `created_at`      | TEXT | ISO 8601 UTC timestamp from the `open` event               |
| `updated_at`      | TEXT | ISO 8601 UTC timestamp of the most recent mutation         |
| `closed_at`       | TEXT | ISO 8601 UTC timestamp of closure (nullable)               |
| `discovered_from` | TEXT | Task ID that led to discovery of this task (nullable)      |

IDs are the first 8 hex characters of a SHA-256 over title, timestamp, PID, and a
random value, checked against the log for collisions. A shorter ID space collides in
practice once a few hundred tasks exist, which matters precisely when many agents are
opening tasks at once.

### task_edges

```sql
CREATE TABLE task_edges (
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('blocks','spawned_by','part_of','related_to')),
  PRIMARY KEY (from_id, to_id, kind)
);
```

| Column    | Type | Description                                        |
| --------- | ---- | -------------------------------------------------- |
| `from_id` | TEXT | Source task ID                                     |
| `to_id`   | TEXT | Target task ID                                     |
| `kind`    | TEXT | Edge type: blocks, spawned_by, part_of, related_to |

The composite primary key `(from_id, to_id, kind)` allows multiple edge types between
the same pair of tasks.

## Common Queries

Query the cache directly with `sqlite3 .impl/tasks.db`. Run `task-db.sh --sync` first
if you have just pulled changes.

### List all open tasks for a plan

```sql
SELECT id, title, status, agent
FROM tasks
WHERE plan = '003' AND status IN ('open', 'in_progress', 'blocked')
ORDER BY created_at;
```

### Find all tasks blocking a specific task

```sql
SELECT t.id, t.title, t.status
FROM tasks t
JOIN task_edges e ON t.id = e.from_id
WHERE e.to_id = 'task-001a3f2b' AND e.kind = 'blocks';
```

### Discovery chain from a task

```sql
SELECT t.id, t.title, t.discovered_from
FROM tasks t
WHERE t.discovered_from IS NOT NULL
ORDER BY t.created_at;
```

### Agent workload summary

```sql
SELECT agent,
       COUNT(*) as total,
       SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as done,
       SUM(CASE WHEN status IN ('open','in_progress') THEN 1 ELSE 0 END) as active
FROM tasks
WHERE agent IS NOT NULL
GROUP BY agent
ORDER BY total DESC;
```

### Orphan tasks (no edges)

```sql
SELECT id, title, status
FROM tasks
WHERE id NOT IN (
  SELECT from_id FROM task_edges
  UNION
  SELECT to_id FROM task_edges
);
```
