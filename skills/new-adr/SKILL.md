---
name: new-adr
description: >
  Create a new Architectural Decision Record (ADR).
  Use when recording an architectural decision, either standalone
  or linked to an accepted proposal. Handles numbering and cross-referencing.
  ADRs are immutable after acceptance except for the superseded_by field.
allowed-tools: Read, Write, Bash(ls *), Bash(grep *)
user-invocable: true
---

# New ADR — Architectural Decision Record Creation

Create a new ADR, either standalone or linked to an accepted proposal.

## Command

```
/new-adr <short-title> [--from-proposal NNN] [--module <path>] [--root]
```

## Arguments

| Argument | Required | Description |
|---|---|---|
| `<short-title>` | Yes | Short, hyphenated title for the decision |
| `--from-proposal NNN` | No | Link to an originating proposal (must be `accepted`) |
| `--module <path>` | No | Target module path |
| `--root` | No | Create at repo root level |

## Workflow

### With `--from-proposal NNN`

1. **Parse arguments.** Extract title, proposal number, and target.

2. **Locate and verify the proposal.** Find proposal NNN and verify its status is `accepted`. If not accepted, report: *"Cannot link ADR to proposal NNN: proposal has status '<status>'. Only accepted proposals can be linked."*

3. **Get next sequence number.** Run:
   ```bash
   bash scripts/next-number.sh --dir <target-decisions-dir>
   ```

4. **Create the ADR file.** Read `templates/decision.md` and create `<target>/NNN-<short-title>.md`.

5. **Populate frontmatter:**

   | Field | Value |
   |---|---|
   | `title` | Derived from short title |
   | `number` | NNN from step 3 |
   | `status` | `proposed` |
   | `author` | Git user name or prompt |
   | `created` | Today's date |
   | `originating_proposal` | The proposal number |
   | `superseded_by` | `null` |

6. **Pre-populate from proposal.** Copy relevant context from the proposal to seed the ADR's Context section.

7. **Identify related architecture docs** that should reference this ADR once accepted.

### Without `--from-proposal` (standalone)

1. **Parse arguments.** Extract title and target.
2. **Get next sequence number.**
3. **Create ADR from template** with `originating_proposal: null`.
4. **Confirm creation.**

### Supersession Handling

After creating a new ADR, prompt the user:

> *"Does this ADR supersede an existing ADR? (enter number or skip)"*

If the user provides a number:
1. Locate the existing ADR.
2. Update its `superseded_by` frontmatter field to the new ADR's number. (This is the one permitted mutation on an accepted ADR.)
3. Set the new ADR's references to mention the superseded record.

## ADR Immutability Reminder

Once an ADR is accepted, it is **immutable**. The only permitted change is setting `superseded_by` when a new ADR supersedes it. To change a decision, create a new ADR.

## Templates

- `templates/decision.md` — ADR template (copy of `scaffold/templates/core/decision.md`)

## Scripts

- `scripts/next-number.sh` — Determines the next NNN sequence number
