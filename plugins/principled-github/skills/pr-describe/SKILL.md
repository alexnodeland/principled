---
name: pr-describe
description: >
  Generate a structured pull request description from a DDD plan task.
  Reads the plan, task manifest, and implementation branch to produce
  a PR body with references to the originating proposal, plan, ADRs,
  and related tasks. Use when opening a PR for plan-driven work.
allowed-tools: Read, Bash(gh *), Bash(git *), Bash(ls *), Bash(bash plugins/*)
user-invocable: true
---

# PR Describe --- Structured Pull Request Description

Generate a structured PR description from a DDD plan task, with full cross-references to proposals, plans, and ADRs.

## Command

```
/pr-describe [<task-id>] [--plan <plan-path>] [--branch <branch>] [--create]
```

## Arguments

| Argument          | Required | Description                                                      |
| ----------------- | -------- | ---------------------------------------------------------------- |
| `<task-id>`       | No       | Task ID from the plan (e.g., `1.1`). Auto-detected from branch.  |
| `--plan <path>`   | No       | Path to the plan file. Auto-detected from manifest if available. |
| `--branch <name>` | No       | Branch name. Defaults to current branch.                         |
| `--create`        | No       | Create the PR immediately after generating the description.      |

## Prerequisites

- `gh` CLI must be installed and authenticated
- Current branch (or specified branch) must have commits ahead of the base branch

## Workflow

1. **Detect context.** Determine the task and plan:
   - If `<task-id>` provided: use it directly
   - If branch name matches `impl/<plan-number>/<task-id>`: extract task ID and plan number
   - If `.impl/manifest.json` exists: look up task details
   - If no context found: prompt user for the plan path

2. **Extract plan metadata.** Read the plan file for:
   - Plan title and number
   - Originating proposal reference
   - Related ADRs
   - Bounded contexts

3. **Extract task details.** If manifest exists:

   ```bash
   bash scripts/task-manifest.sh --get-task --task-id <task-id>
   ```

4. **Analyze the branch.** Determine changes:

   ```bash
   bash scripts/analyze-branch.sh --branch <branch>
   ```

   Returns: files changed, commit messages, diff summary.

5. **Generate the PR description.** Read `templates/pr-body.md` and populate:
   - Summary from commit messages and task description
   - Plan and task references
   - Proposal and ADR references
   - Files changed summary
   - Checklist items

6. **Output or create.**
   - Without `--create`: output the PR body for review
   - With `--create`: create the PR via `gh pr create`

## Branch Name Convention

The skill recognizes the `impl/<plan-number>/<task-id>` branch naming convention from `principled-implementation` and auto-detects plan and task context from it.

## Scripts

- `scripts/task-manifest.sh` --- Read task details from manifest (copy from principled-implementation)
- `scripts/analyze-branch.sh` --- Analyze branch changes for PR description

## Templates

- `templates/pr-body.md` --- Pull request body template
