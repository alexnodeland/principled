---
name: new-proposal
description: >
  Create a new proposal (RFC) document.
  Use when proposing a change, new feature, or architectural decision
  that needs team review. Handles numbering, naming, and template population.
  Use --root for cross-cutting proposals that affect multiple modules.
allowed-tools: Read, Write, Bash(ls *), Bash(wc *)
user-invocable: true
---

# New Proposal — RFC Creation

Create a new proposal (RFC) document with correct numbering, naming, and template content.

## Command

```
/new-proposal <short-title> [--module <path>] [--root]
```

## Arguments

| Argument | Required | Description |
|---|---|---|
| `<short-title>` | Yes | Short, hyphenated title for the proposal (e.g., `switch-to-event-sourcing`) |
| `--module <path>` | No | Target module path (e.g., `packages/auth-service`). Defaults to current module context. |
| `--root` | No | Create a cross-cutting proposal at the repo root level (`docs/proposals/`) |

## Workflow

1. **Parse arguments.** Extract the short title from `$ARGUMENTS`. Determine the target:
   - If `--root`: target is `docs/proposals/` at the repo root
   - If `--module <path>`: target is `<path>/docs/proposals/`
   - Otherwise: determine target from current working context

2. **Get next sequence number.** Run:
   ```bash
   bash scripts/next-number.sh --dir <target-proposals-dir>
   ```
   This returns the next available `NNN` (zero-padded to 3 digits).

3. **Create the proposal file.** Read the template from `templates/proposal.md` and create `<target>/NNN-<short-title>.md`.

4. **Populate frontmatter:**

   | Field | Value |
   |---|---|
   | `title` | Derived from the short title (humanized) |
   | `number` | The NNN from step 2 |
   | `status` | `draft` |
   | `author` | Git user name (`git config user.name`) or prompt user |
   | `created` | Today's date (`YYYY-MM-DD`) |
   | `updated` | Today's date (`YYYY-MM-DD`) |
   | `supersedes` | `null` |
   | `superseded_by` | `null` |

5. **Pre-populate context.** If the target is a module, read available module information (README, CLAUDE.md) to seed the Context section with relevant background.

6. **Identify architecture impact.** List any existing architecture docs in the module's `docs/architecture/` directory that may need updating if this proposal is accepted.

7. **Confirm creation.** Report the created file path and remind the user of next steps:
   - Fill in the proposal content
   - When ready for review: `/proposal-status NNN in-review`
   - When accepted: `/proposal-status NNN accepted` (will prompt for plan creation)

## Slug Rules

The short title must follow these rules:
- Lowercase only
- Words separated by hyphens
- No special characters, underscores, or spaces

**Good:** `switch-to-event-sourcing`, `add-payment-gateway`
**Bad:** `Switch_To_Event_Sourcing`, `add payment gateway`

## Templates

- `templates/proposal.md` — RFC template (copy of `scaffold/templates/core/proposal.md`)

## Scripts

- `scripts/next-number.sh` — Determines the next NNN sequence number for a directory
