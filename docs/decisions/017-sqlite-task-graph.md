---
title: "SQLite Task Graph Storage"
number: "017"
status: accepted
author: Alex
created: 2026-02-27
updated: 2026-02-27
from_proposal: "009"
supersedes: null
superseded_by: null
---

# ADR-017: SQLite Task Graph Storage

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-tasks plugin needs a persistent storage engine for a graph-structured task tracking system. Tasks (beads) form a directed graph with typed edges representing relationships like "blocks", "spawned_by", "part_of", and "related_to". The storage must be:

1. **Queryable** — support filtering, aggregation, and graph traversal
2. **Single-file** — committable to Git alongside code
3. **Zero-dependency** — no server process, no external service
4. **CLI-accessible** — usable from bash scripts without a programming language runtime

Four storage approaches were evaluated.

## Decision

Use SQLite via the `sqlite3` CLI for task graph storage. The database file lives at `.impl/tasks.db` and is committed to Git after every write operation. Two tables model the graph: `beads` (nodes) and `bead_edges` (typed directed edges). All database operations go through a canonical bash script (`task-db.sh`) that wraps `sqlite3` commands.

## Options Considered

### Option 1: SQLite (chosen)

A single `.impl/tasks.db` file accessed via the `sqlite3` CLI.

**Pros:**

- Full SQL query language — filtering, joins, aggregation, subqueries
- Graph modeling via edge table with composite primary key
- Single binary file, compact storage, no server process
- `sqlite3` ships with macOS and most Linux distributions
- Git-committable (binary, but small and compressible)
- Atomic transactions prevent corruption
- Mature, battle-tested (used by Firefox, Android, iOS, etc.)

**Cons:**

- Binary file produces opaque Git diffs (mitigated by small size and structured commit messages)
- Requires `sqlite3` CLI (not available on all minimal Docker images)
- Merge conflicts on binary files must be resolved by regeneration, not textual merge

### Option 2: JSON file

A single `.impl/tasks.json` with nodes and edges arrays.

**Pros:**

- Human-readable Git diffs
- No external tool dependency
- Simple to parse with `jq`

**Cons:**

- No query language — every read parses the entire file
- Graph traversal requires custom code
- File grows linearly; no indexing
- Concurrent writes risk corruption without locking
- `jq` is optional in this ecosystem (fallback to grep is fragile for nested JSON)

### Option 3: Markdown files

One `.md` file per task in `.impl/tasks/`, with YAML frontmatter for metadata and links.

**Pros:**

- Human-readable
- Git-friendly diffs
- Follows the principled pattern of "documents as source of truth"

**Cons:**

- Graph relationships across files require cross-referencing by filename
- Querying across hundreds of task files is slow (requires find + parse loop)
- Aggregation (counts, filters, grouping) requires custom scripting
- No transactional guarantees

### Option 4: JSON with jq queries

Like Option 2, but with `jq` as the query engine.

**Pros:**

- `jq` supports filtering, mapping, and basic aggregation
- Better query capability than raw grep

**Cons:**

- `jq` is optional in this ecosystem — scripts must fall back to grep
- `jq` graph traversal is extremely verbose
- Still no indexing, still parses entire file per query
- Complex queries (multi-hop graph traversal) are impractical in `jq`

## Consequences

### Positive

- SQL enables expressive queries: "show all blocked tasks for plan 003", "count tasks per agent", "find orphan beads with no edges"
- Edge table with composite primary key naturally models a directed multigraph
- Single file commitment means task history is in Git log
- `sqlite3` CLI is pre-installed on macOS and available via package managers everywhere
- Atomic transactions prevent partial writes from corrupting the graph

### Negative

- Binary file in Git — diffs show only "binary file changed" (mitigated by descriptive commit messages)
- Merge conflicts require manual resolution: the "winning" branch's DB must be accepted or the DB regenerated
- `sqlite3` CLI is a hard dependency — scripts must check for it and fail gracefully if missing

### Risks

- If the DB grows very large (thousands of beads), Git performance may degrade — mitigated by the expectation that task graphs are small relative to code
- WAL mode (write-ahead logging) can create `-wal` and `-shm` files that should not be committed — mitigated by using default journal mode

## References

- [RFC-009: Principled Tasks Plugin](../proposals/009-principled-tasks.md)
- SQLite documentation: https://www.sqlite.org/docs.html
- ADR-008: Manifest-driven orchestration state (prior art for `.impl/` directory usage)
