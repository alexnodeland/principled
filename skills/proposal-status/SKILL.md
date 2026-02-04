---
name: proposal-status
description: >
  Transition a proposal through its lifecycle states.
  Valid transitions: draft → in-review → accepted|rejected|superseded.
  On acceptance, prompts to create a corresponding implementation plan.
allowed-tools: Read, Write, Bash(ls *), Bash(grep *), Bash(sed *)
user-invocable: true
---

# Proposal Status — Lifecycle Transitions

Transition a proposal through its lifecycle states with validation and side-effects.

## Command

```
/proposal-status <number-or-path> <new-status> [--module <path>] [--root]
```

## Arguments

| Argument           | Required | Description                                                      |
| ------------------ | -------- | ---------------------------------------------------------------- |
| `<number-or-path>` | Yes      | Proposal number (e.g., `001`) or full file path                  |
| `<new-status>`     | Yes      | Target status: `in-review`, `accepted`, `rejected`, `superseded` |
| `--module <path>`  | No       | Module containing the proposal                                   |
| `--root`           | No       | Proposal is at repo root level                                   |

## Workflow

1. **Parse arguments.** Extract the proposal identifier and target status from `$ARGUMENTS`.

2. **Locate the proposal.** If a number is given, search for `NNN-*.md` in the appropriate `docs/proposals/` directory. If a path is given, use it directly.

3. **Read current status.** Parse the proposal's frontmatter to get the current `status` field.

4. **Validate the transition.** Check against the state machine defined in `reference/valid-transitions.md`:

   ```
   draft ──→ in-review ──→ accepted
                       ──→ rejected
                       ──→ superseded
   ```

   - If the transition is **invalid**, report an error with the legal transitions from the current state. Example: _"Cannot transition proposal 001 from 'draft' to 'accepted'. Valid transitions from 'draft': in-review."_
   - If the current status is **terminal** (`accepted`, `rejected`, `superseded`), report: _"Proposal 001 has reached terminal status '\<status\>' and cannot be transitioned."_

5. **Update the proposal.** If valid:
   - Update the `status` field in frontmatter
   - Update the `updated` field to today's date

6. **Handle side-effects:**

   **On `accepted`:**
   - Prompt the user: _"Proposal NNN has been accepted. Create an implementation plan? Use `/new-plan <title> --from-proposal NNN`."_

   **On `superseded`:**
   - Prompt for the superseding proposal number
   - Update the `superseded_by` field in frontmatter with the superseding proposal's number

7. **Confirm the transition.** Report the updated status and any next steps.

## State Machine

Read `reference/valid-transitions.md` for the complete state machine definition, including conditions and side-effects for each transition.

## Reference

- `reference/valid-transitions.md` — State machine definition with legal transitions, conditions, and side-effects
