---
name: github-strategy
description: >
  GitHub integration strategy for the Principled framework.
  Consult when working with GitHub issues, pull requests, labels,
  CODEOWNERS, or .github/ templates in the context of the principled
  documentation pipeline. Covers issue-proposal mapping, PR-plan alignment,
  label taxonomy, and the GitHub-principled sync model.
user-invocable: false
---

# GitHub Strategy --- Background Knowledge

This skill provides Claude Code with comprehensive knowledge of how the Principled methodology maps to GitHub native features. It is not directly invocable --- it informs Claude's behavior when GitHub-related context is encountered.

## When to Consult This Skill

Activate this knowledge when:

- Creating or updating GitHub issues related to proposals or plans
- Writing pull request descriptions that reference plans, tasks, or ADRs
- Working with `.github/` directory (issue templates, PR templates, workflows, CODEOWNERS)
- Managing GitHub labels for principled lifecycle stages
- Discussing how the principled pipeline maps to GitHub features

## Reference Documentation

Read these files for detailed guidance on specific topics:

### Mapping Model

- **`reference/mapping-model.md`** --- How principled documents map to GitHub entities: proposals to issues, plans to tracking issues, tasks to PRs, decisions to linked references. Covers bidirectional sync, status mapping, and conflict resolution.

### Label Taxonomy

- **`reference/label-taxonomy.md`** --- The complete label set for principled workflows: lifecycle labels (`proposal:draft`, `proposal:accepted`), type labels (`rfc`, `adr`, `plan`), priority labels, and module scope labels. Covers naming conventions, color codes, and grouping rules.

### Template Guide

- **`reference/template-guide.md`** --- How `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE/` files align with principled document types. Covers template fields, frontmatter mapping, and conditional sections.

## Key Principles

1. **GitHub is the collaboration layer.** Proposals drive discussion as issues. Plans track execution as tracking issues. PRs implement tasks from plans.
2. **Documents are the source of truth.** GitHub issues and PRs reference principled documents --- never the reverse. The markdown files in `docs/` are canonical.
3. **Labels encode lifecycle state.** Every principled lifecycle stage has a corresponding GitHub label. Label changes reflect document status transitions.
4. **Templates enforce structure.** GitHub issue and PR templates mirror principled document templates, ensuring consistent information capture.
5. **CODEOWNERS follows module boundaries.** Code ownership aligns with module structure and documentation responsibility.
6. **Bidirectional references.** Issues link to proposal files. PRs link to plan tasks. Commit messages reference plan numbers.
