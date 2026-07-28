---
title: "Event Log as Record, SQLite as Cache"
number: "017"
status: proposed
author: Alex
created: 2026-02-27
updated: 2026-07-28
from_proposal: "009"
supersedes: null
superseded_by: null
---

# ADR-017: Event Log as Record, SQLite as Cache

## Status

Proposed

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-tasks plugin needs persistent storage for a graph-structured task
tracker. Tasks form a directed graph with typed edges (`blocks`, `spawned_by`,
`part_of`, `related_to`). The storage must be:

1. **Queryable** — filtering, aggregation, and graph traversal
2. **Git-native** — survives session crashes; the repository is the state
3. **Zero-dependency** — no server process, no external service
4. **CLI-accessible** — usable from bash without a language runtime
5. **Mergeable under parallel writes** — the plugin exists to coordinate concurrent
   agents, so two agents opening tasks on separate branches must merge cleanly

Requirement 5 is the binding constraint, and it is the one an earlier draft of this
ADR failed to satisfy.

### Why the first design did not work

The original decision was to commit `.impl/tasks.db` — the SQLite file itself — to Git
after every write. Two problems surfaced when the implementation was exercised:

- **`.impl/` is in `.gitignore`.** The database was never committed by anything. The
  `--commit` operation ran `git add .impl/tasks.db` on an ignored path, which fails.
  The "persistent, Git-backed" task graph was in practice local, ephemeral, and lost
  on clone. The ADR and the repository contradicted each other.
- **A binary file cannot be merged.** Even with the ignore rule removed, every pair of
  agents that opened a task on separate branches would conflict, and the conflict
  could only be resolved by regenerating one side — discarding work. This defeats the
  plugin's stated purpose.

Storing a binary database and coordinating parallel agents are mutually exclusive.
The record has to be text, and it has to be append-only.

## Decision

Split storage into a **committed record** and a **derived index**:

| Path                      | Role                         | Git        | Rebuildable |
| ------------------------- | ---------------------------- | ---------- | ----------- |
| `.principled/tasks.jsonl` | Append-only event log        | Committed  | No          |
| `.impl/tasks.db`          | SQLite cache folded from log | Gitignored | Yes         |

Every mutation appends exactly one JSON object to the log, then rebuilds the cache.
State is the ordered fold of the log, so the cache is always reconstructible and two
clones holding the same log agree on the same state. `task-db.sh --sync` rebuilds it.

Events are `open`, `update`, `close`, and `edge`. JSON is produced by sqlite3's
`json_object()` and read with `json_extract()`, so escaping is handled by sqlite3
rather than by hand, and `jq` is not required.

`--init` registers a union merge driver in `.gitattributes`:

```
.principled/tasks.jsonl merge=union
```

Union merge keeps both sides' lines rather than raising a conflict, which is the
correct semantics for an append-only log and makes parallel agent branches merge
without intervention.

This keeps SQLite for everything it is genuinely good at — SQL filtering, aggregation,
and multi-hop graph traversal — while removing it from the durability path entirely.

## Options Considered

### Option 1: Append-only JSONL log + SQLite cache (chosen)

Text log is the record; SQLite is a materialized view.

**Pros:**

- Merges cleanly under concurrent writes via `merge=union` — the requirement that
  decides this ADR
- Human-readable Git diffs; the log doubles as an audit trail
- Full SQL query power retained through the derived cache
- Cache corruption or deletion is harmless — `--sync` rebuilds it
- No `jq` dependency: sqlite3's JSON functions handle both encode and decode

**Cons:**

- Two files instead of one
- Cache rebuild is O(events); needs log compaction if a repository accumulates very
  large numbers of events (see Open Questions)
- Requires `sqlite3` 3.38+ for JSON functions

### Option 2: Commit the SQLite database (previously chosen, rejected)

A single `.impl/tasks.db` committed after every write.

**Pros:**

- One file, no fold step
- Atomic transactions

**Cons:**

- **Unmergeable.** Every concurrent write conflicts; resolution means discarding one
  agent's work. Disqualifying for a plugin whose purpose is parallel coordination.
- Opaque binary diffs — no reviewable history of what changed
- As written, contradicted `.gitignore` and never actually persisted anything

### Option 3: Single JSON document

One `.impl/tasks.json` holding nodes and edges arrays.

**Pros:**

- Human-readable diffs, no external tool needed to inspect

**Cons:**

- Whole-document rewrites conflict on nearly every concurrent change — the same
  merge problem as Option 2, in text form
- No query language; graph traversal requires custom code
- Concurrent writes risk corruption without locking

### Option 4: Markdown file per task

One `.md` file per task in `.impl/tasks/`, YAML frontmatter for metadata.

**Pros:**

- Human-readable, Git-friendly, consistent with "documents as source of truth"
- Per-file granularity merges well

**Cons:**

- Graph traversal across files requires cross-referencing by filename
- Querying hundreds of files means find + parse loops
- Aggregation requires custom scripting; no indexing
- Filename collisions between agents reintroduce the conflict problem

## Consequences

### Positive

- Parallel agents can open, update, and close tasks on separate branches and merge
  without conflict — the capability the plugin was built for
- The task graph genuinely survives clones, crashes, and worktree removal
- Git history becomes a readable audit log of task lifecycle
- The cache can be deleted, corrupted, or schema-migrated without data loss
- Removing the durability requirement from SQLite lets the schema evolve freely:
  changing the cache shape only requires a re-fold, not a migration

### Negative

- Log growth is unbounded within a repository's lifetime; very large logs slow the
  rebuild, and compaction is not yet implemented
- A repository cloned before `.gitattributes` existed will not have the union merge
  rule and can still conflict until `--init` is re-run
- Two storage paths is marginally more to explain than one

### Neutral

- `sqlite3` remains a hard dependency, now for querying rather than storage
- The `.principled/` directory is new; it is the first committed state directory the
  methodology introduces outside `docs/`

## Open Questions

- **Log compaction.** At what event count does rebuild latency justify a compaction
  step that rewrites the log to one `open` event per live task? Compaction rewrites
  history and therefore reintroduces merge conflicts, so it should be a deliberate,
  low-frequency maintenance operation rather than automatic.
- **Cross-referencing `.impl/manifest.json`.** Tasks carry `plan` and `task_id` fields
  intended to correlate with principled-implementation's manifest, but nothing
  enforces or verifies that correspondence yet.
