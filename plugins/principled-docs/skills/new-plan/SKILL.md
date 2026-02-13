---
name: new-plan
description: >
  Create a DDD implementation plan from an accepted decision (ADR).
  Plans implement decisions by decomposing work into
  bounded contexts, aggregates, and concrete tasks using
  domain-driven development. Use when an accepted ADR needs
  a tactical implementation breakdown before work begins.
allowed-tools: Read, Write, Bash(ls *), Bash(grep *), Bash(find *)
user-invocable: true
---

# New Plan — DDD Implementation Plan Creation

Create a domain-driven implementation plan that implements an accepted decision (ADR).

## Command

```
/new-plan <short-title> --from-adr NNN [--module <path>] [--root]
```

## Arguments

| Argument          | Required | Description                                                                  |
| ----------------- | -------- | ---------------------------------------------------------------------------- |
| `<short-title>`   | Yes      | Short, hyphenated title for the plan                                         |
| `--from-adr NNN`  | **Yes**  | The number of the originating decision. The ADR must have status `accepted`. |
| `--module <path>` | No       | Target module path                                                           |
| `--root`          | No       | Create at repo root level                                                    |

## Workflow

1. **Parse arguments.** Extract title and `--from-adr NNN` from `$ARGUMENTS`. The `--from-adr` flag is required — plans always originate from an accepted decision.

2. **Locate and verify the decision.** Find the ADR matching NNN in the appropriate `docs/decisions/` directory. Read its frontmatter and verify:
   - The ADR exists
   - Its `status` is `accepted`
   - If not accepted, report an error: _"Cannot create plan: ADR NNN has status '\<status\>'. Only accepted decisions can have implementation plans."_

3. **Get next sequence number.** Run:

   ```bash
   bash scripts/next-number.sh --dir <target-plans-dir>
   ```

4. **Read DDD guidance.** Before creating the plan, read `reference/ddd-guide.md` to inform the decomposition approach. Use this guidance to help the user structure their bounded contexts, aggregates, and domain events.

5. **Create the plan file.** Read the template from `templates/plan.md` and create `<target>/NNN-<short-title>.md`.

6. **Populate frontmatter:**

   | Field             | Value                            |
   | ----------------- | -------------------------------- |
   | `title`           | Derived from the short title     |
   | `number`          | The NNN from step 3              |
   | `status`          | `active`                         |
   | `author`          | Git user name or prompt          |
   | `created`         | Today's date                     |
   | `updated`         | Today's date                     |
   | `originating_adr` | The ADR number from `--from-adr` |

7. **Pre-populate from decision.** Read the originating ADR's content and use it to seed:
   - The Objective section (link to ADR)
   - Initial bounded contexts (derived from the decision's scope)
   - Known dependencies
   - Implementation constraints from the decision

8. **Confirm creation.** Report the created file and guide the user to:
   - Complete the domain analysis (bounded contexts, aggregates, domain events)
   - Define implementation tasks per the DDD guide

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
