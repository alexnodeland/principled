# SQLite Schema Reference

The task database lives at `.impl/tasks.db`. It contains two tables that model a directed graph of tasks (beads) with typed edges.

## Tables

### beads

```sql
CREATE TABLE beads (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('open','in_progress','done','blocked','abandoned')),
  agent TEXT,
  plan TEXT,
  task_id TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  closed_at TEXT,
  discovered_from TEXT
);
```

| Column            | Type | Description                                                |
| ----------------- | ---- | ---------------------------------------------------------- |
| `id`              | TEXT | Unique identifier, format: `bead-XXXX` (hex)               |
| `title`           | TEXT | Human-readable task description                            |
| `status`          | TEXT | Current state: open, in_progress, done, blocked, abandoned |
| `agent`           | TEXT | Name of the agent that worked on this bead (nullable)      |
| `plan`            | TEXT | Originating plan number, e.g. "003" (nullable)             |
| `task_id`         | TEXT | Task ID from plan manifest, e.g. "1.1" (nullable)          |
| `notes`           | TEXT | Freeform notes, typically set at close time (nullable)     |
| `created_at`      | TEXT | ISO 8601 UTC timestamp of creation                         |
| `closed_at`       | TEXT | ISO 8601 UTC timestamp of closure (nullable)               |
| `discovered_from` | TEXT | Bead ID that led to discovery of this bead (nullable)      |

### bead_edges

```sql
CREATE TABLE bead_edges (
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('blocks','spawned_by','part_of','related_to')),
  PRIMARY KEY (from_id, to_id, kind)
);
```

| Column    | Type | Description                                        |
| --------- | ---- | -------------------------------------------------- |
| `from_id` | TEXT | Source bead ID                                     |
| `to_id`   | TEXT | Target bead ID                                     |
| `kind`    | TEXT | Edge type: blocks, spawned_by, part_of, related_to |

The composite primary key `(from_id, to_id, kind)` allows multiple edge types between the same pair of beads.

## Common Queries

### List all open beads for a plan

```sql
SELECT id, title, status, agent
FROM beads
WHERE plan = '003' AND status IN ('open', 'in_progress', 'blocked')
ORDER BY created_at;
```

### Find all beads blocking a specific bead

```sql
SELECT b.id, b.title, b.status
FROM beads b
JOIN bead_edges e ON b.id = e.from_id
WHERE e.to_id = 'bead-001a' AND e.kind = 'blocks';
```

### Discovery chain from a bead

```sql
SELECT b.id, b.title, b.discovered_from
FROM beads b
WHERE b.discovered_from IS NOT NULL
ORDER BY b.created_at;
```

### Agent workload summary

```sql
SELECT agent,
       COUNT(*) as total,
       SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as done,
       SUM(CASE WHEN status IN ('open','in_progress') THEN 1 ELSE 0 END) as active
FROM beads
WHERE agent IS NOT NULL
GROUP BY agent
ORDER BY total DESC;
```

### Orphan beads (no edges)

```sql
SELECT id, title, status
FROM beads
WHERE id NOT IN (
  SELECT from_id FROM bead_edges
  UNION
  SELECT to_id FROM bead_edges
);
```
