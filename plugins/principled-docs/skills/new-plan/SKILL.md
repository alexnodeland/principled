---
name: new-plan
description: >
  Create a DDD implementation plan from an accepted proposal.
  Plans bridge proposals and decisions by decomposing work into
  bounded contexts, aggregates, and concrete tasks using
  domain-driven development. Use when an accepted proposal needs
  a tactical implementation breakdown before work begins.
allowed-tools: Read, Write, Bash(ls *), Bash(grep *), Bash(find *)
user-invocable: true
---

# New Plan — DDD Implementation Plan Creation

Create a domain-driven implementation plan that bridges an accepted proposal and its resulting decisions.

## Command

```
/new-plan <short-title> --from-proposal NNN [--module <path>] [--root]
```

## Arguments

| Argument              | Required | Description                                                                       |
| --------------------- | -------- | --------------------------------------------------------------------------------- |
| `<short-title>`       | Yes      | Short, hyphenated title for the plan                                              |
| `--from-proposal NNN` | **Yes**  | The number of the originating proposal. The proposal must have status `accepted`. |
| `--module <path>`     | No       | Target module path                                                                |
| `--root`              | No       | Create at repo root level                                                         |

## Workflow

1. **Parse arguments.** Extract title and `--from-proposal NNN` from `$ARGUMENTS`. The `--from-proposal` flag is required — plans always originate from a proposal.

2. **Locate and verify the proposal.** Find the proposal matching NNN in the appropriate `docs/proposals/` directory. Read its frontmatter and verify:
   - The proposal exists
   - Its `status` is `accepted`
   - If not accepted, report an error: _"Cannot create plan: proposal NNN has status '\<status\>'. Only accepted proposals can have implementation plans."_

3. **Get next sequence number.** Run:

   ```bash
   bash scripts/next-number.sh --dir <target-plans-dir>
   ```

4. **Read DDD guidance.** Before creating the plan, read `reference/ddd-guide.md` to inform the decomposition approach. Use this guidance to help the user structure their bounded contexts, aggregates, and domain events.

5. **Create the plan file.** Read the template from `templates/plan.md` and create `<target>/NNN-<short-title>.md`.

6. **Populate frontmatter:**

   | Field                  | Value                                      |
   | ---------------------- | ------------------------------------------ |
   | `title`                | Derived from the short title               |
   | `number`               | The NNN from step 3                        |
   | `status`               | `active`                                   |
   | `author`               | Git user name or prompt                    |
   | `created`              | Today's date                               |
   | `updated`              | Today's date                               |
   | `originating_proposal` | The proposal number from `--from-proposal` |

7. **Pre-populate from proposal.** Read the originating proposal's content and use it to seed:
   - The Objective section (link to proposal)
   - Initial bounded contexts (derived from the proposal's scope)
   - Known dependencies
   - Anticipated decisions

8. **Confirm creation.** Report the created file and guide the user to:
   - Complete the domain analysis (bounded contexts, aggregates, domain events)
   - Define implementation tasks per the DDD guide
   - Create ADRs for decisions made during implementation

## Plan Lifecycle

| State       | Description                                               |
| ----------- | --------------------------------------------------------- |
| `active`    | Work is in progress. Plan is mutable.                     |
| `complete`  | All tasks are done. Related ADRs have been created.       |
| `abandoned` | Plan was abandoned. Originating proposal may still stand. |

## Reference

- `reference/ddd-guide.md` — Practical guide to DDD decomposition for implementation plans

## Templates

- `templates/plan.md` — DDD implementation plan template (copy of `scaffold/templates/core/plan.md`)

## Scripts

- `scripts/next-number.sh` — Determines the next NNN sequence number
