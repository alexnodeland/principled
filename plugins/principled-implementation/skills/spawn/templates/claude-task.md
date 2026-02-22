# Task {{TASK_ID}}: {{TASK_DESCRIPTION}}

## Context

You are executing task **{{TASK_ID}}** from **Plan-{{PLAN_NUMBER}}** ({{PLAN_TITLE}}).
You are working in an isolated git worktree.

### Plan Objective

{{PLAN_OBJECTIVE}}

### Bounded Context(s)

{{BOUNDED_CONTEXT_DETAILS}}

### Related Tasks in This Phase

{{RELATED_TASKS}}

## Instructions

1. Create a named branch: `git checkout -b impl/{{PLAN_NUMBER}}/{{TASK_ID_SANITIZED}}`
2. Implement the task described above completely
3. Run any available tests or checks in this worktree
4. Commit changes with: `impl({{PLAN_NUMBER}}): {{TASK_ID}} — <brief description>`
5. Do NOT push, merge, or modify the main branch
6. If blocked by out-of-scope issues, document in `.task-blockers.md`

## Acceptance Criteria

{{ACCEPTANCE_CRITERIA}}

## Project Conventions

{{PROJECT_CONVENTIONS}}
