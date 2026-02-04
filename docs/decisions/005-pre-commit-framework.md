---
title: "pre-commit Framework for Git Hooks"
number: "005"
status: accepted
author: Alex
created: 2026-02-04
updated: 2026-02-04
from_proposal: "001"
supersedes: null
superseded_by: null
---

# ADR-005: pre-commit Framework for Git Hooks

## Context

RFC-001 proposed two options for managing Git pre-commit hooks:

- **Option A:** The [pre-commit](https://pre-commit.com/) framework — a Python-based hook manager with `.pre-commit-config.yaml` configuration
- **Option B:** A raw Git hook script (`scripts/pre-commit.sh`) installed via a setup script, with no framework dependency

The hooks need to run: shfmt, ShellCheck, markdownlint-cli2, Prettier, and the template drift check.

## Decision

**Option A: Use the pre-commit framework.**

The `.pre-commit-config.yaml` declares all hooks with explicit repo sources and version tags. Contributors install with `pre-commit install` (one-time setup).

## Rationale

- **Declarative configuration** — `.pre-commit-config.yaml` is both config and documentation of what checks run
- **Version management** — each hook repo is pinned to a specific rev, ensuring reproducible behavior
- **Caching** — pre-commit caches hook environments, making subsequent runs fast
- **Ecosystem** — first-party pre-commit hooks exist for ShellCheck, shfmt, markdownlint-cli2, and Prettier
- **Local hooks** — the template drift check is declared as a `local` hook alongside the external ones
- **Language-agnostic** — despite being Python-based, pre-commit manages hooks in any language

## Consequences

### Positive

- Single `pre-commit install` sets up all hooks
- Adding new checks is a config change, not a script change
- Hook versions are pinned and auditable

### Negative

- Adds a Python dependency (pre-commit itself) — contributors need Python 3 installed
- One more tool to install during onboarding

### Alternatives Considered

1. **Raw Git hook script.** Zero dependencies beyond the linters themselves, but requires manual installation logic, doesn't handle caching, and the script itself becomes maintenance burden as checks are added or changed.
