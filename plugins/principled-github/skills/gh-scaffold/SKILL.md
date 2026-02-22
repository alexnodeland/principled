---
name: gh-scaffold
description: >
  Scaffold GitHub-specific configuration files aligned with the principled
  workflow. Creates issue templates, PR templates, actions workflows,
  and config files in the .github/ directory. Use when setting up a new
  repo or adding principled GitHub integration to an existing one.
allowed-tools: Read, Write, Bash(mkdir *), Bash(ls *), Bash(gh *)
user-invocable: true
---

# GH Scaffold --- GitHub Configuration Scaffolding

Generate the `.github/` directory structure with issue templates, PR templates, actions workflows, and configuration files aligned with the principled workflow.

## Command

```
/gh-scaffold [--templates] [--workflows] [--codeowners] [--all]
```

## Arguments

| Argument       | Required | Description                                         |
| -------------- | -------- | --------------------------------------------------- |
| `--templates`  | No       | Scaffold issue templates and PR template only       |
| `--workflows`  | No       | Scaffold GitHub Actions workflows only              |
| `--codeowners` | No       | Scaffold CODEOWNERS file only                       |
| `--all`        | No       | Scaffold everything (default if no flags specified) |

## Workflow

### Template Scaffolding (`--templates` or `--all`)

1. **Create directories:**

   ```
   .github/ISSUE_TEMPLATE/
   ```

2. **Write issue templates:**
   - Read `templates/proposal-issue-template.yml` and write to `.github/ISSUE_TEMPLATE/proposal.yml`
   - Read `templates/plan-issue-template.yml` and write to `.github/ISSUE_TEMPLATE/plan.yml`
   - Read `templates/bug-report-template.yml` and write to `.github/ISSUE_TEMPLATE/bug-report.yml`
   - Read `templates/config.yml` and write to `.github/ISSUE_TEMPLATE/config.yml`

3. **Write PR template:**
   - Read `templates/pull-request-template.md` and write to `.github/pull_request_template.md`

### Workflow Scaffolding (`--workflows` or `--all`)

1. **Create directory:**

   ```
   .github/workflows/
   ```

2. **Write workflow files:**
   - Read `templates/pr-check-workflow.yml` and write to `.github/workflows/principled-pr-check.yml`
   - Read `templates/label-sync-workflow.yml` and write to `.github/workflows/principled-labels.yml`

### CODEOWNERS Scaffolding (`--codeowners` or `--all`)

1. **Generate CODEOWNERS.** If no CODEOWNERS file exists:
   - Scan for modules (directories with `CLAUDE.md` or `docs/`)
   - Generate initial CODEOWNERS from git log ownership data
   - Write to `.github/CODEOWNERS`
   - If CODEOWNERS already exists, skip with a message

2. **Report results.** List all created files and directories.

## Templates

- `templates/proposal-issue-template.yml` --- GitHub issue template for proposals
- `templates/plan-issue-template.yml` --- GitHub issue template for plans
- `templates/bug-report-template.yml` --- GitHub issue template for bug reports
- `templates/config.yml` --- Issue template chooser configuration
- `templates/pull-request-template.md` --- PR description template
- `templates/pr-check-workflow.yml` --- GitHub Actions workflow for PR validation
- `templates/label-sync-workflow.yml` --- GitHub Actions workflow for label sync
