---
title: "gh CLI as the GitHub Integration Interface"
number: "010"
status: accepted
author: Alex
created: 2026-02-22
updated: 2026-02-22
from_proposal: "007"
supersedes: null
superseded_by: null
---

# ADR-010: gh CLI as the GitHub Integration Interface

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

The principled-github plugin needs to interact with GitHub's API for issues, pull requests, labels, and repository configuration. Three integration approaches were considered:

1. **gh CLI** — Use GitHub's official CLI tool (`gh`) for all API interactions.
2. **Direct REST API** — Use `curl` to call the GitHub REST API directly.
3. **GraphQL API** — Use `curl` with GitHub's GraphQL API for more efficient queries.

## Decision

Use the `gh` CLI as the sole interface for all GitHub API interactions. Every skill that needs GitHub access runs `check-gh-cli.sh` first to verify the CLI is installed and authenticated. All GitHub operations use `gh` subcommands: `gh issue list`, `gh issue create`, `gh pr create`, `gh label create`, `gh api`, etc.

## Options Considered

### Option 1: gh CLI (chosen)

Use `gh issue`, `gh pr`, `gh label`, and `gh api` commands.

**Pros:**

- Handles authentication automatically (OAuth token, SSH, credential store)
- Structured output via `--json` flags — reliable field extraction
- Cross-platform (Linux, macOS, Windows)
- Familiar to developers who use GitHub
- Abstracts API versioning — gh CLI tracks API changes
- `gh api` subcommand provides escape hatch for any REST/GraphQL endpoint

**Cons:**

- External dependency: gh CLI must be installed and authenticated
- Version-specific behavior: different gh versions may have different flags
- Not available in all CI environments by default (mitigated: most GitHub Actions runners include it)

### Option 2: Direct REST API via curl

Use `curl -H "Authorization: token $GITHUB_TOKEN"` for all API calls.

**Pros:**

- No external dependency beyond curl (universally available)
- Full control over API version and request format

**Cons:**

- Manual authentication management (token storage, header injection)
- Verbose: every API call requires URL construction, header management, pagination handling
- JSON response parsing requires jq (which is optional in the marketplace convention)
- API versioning must be tracked manually

### Option 3: GraphQL API via curl

Use GitHub's GraphQL endpoint for efficient batched queries.

**Pros:**

- More efficient for complex queries (fewer API calls)
- Can fetch exactly the fields needed

**Cons:**

- All cons of Option 2 (manual auth, verbose curl)
- GraphQL syntax is complex for simple operations
- More difficult to debug than REST
- Overkill for the plugin's needs (simple CRUD on issues, PRs, labels)

## Consequences

### Positive

- All skills share a consistent, well-documented interface for GitHub operations
- Authentication is handled by the gh CLI's own credential management — no token management in scripts
- `check-gh-cli.sh` provides a single gating check: if gh is available and authenticated, all skills work
- The `gh api` subcommand provides access to any GitHub API endpoint not covered by dedicated subcommands

### Negative

- The gh CLI is a hard dependency for the entire plugin — no fallback if it's not installed
- Teams must ensure gh CLI is authenticated in their environment (development and CI)
- The `check-gh-cli.sh` script must be duplicated across 7 skills (following the self-containment convention)

## References

- [RFC-007: Principled GitHub Plugin](../proposals/007-principled-github-plugin.md)
- Implementation: `plugins/principled-github/skills/sync-issues/scripts/check-gh-cli.sh` (canonical)
- gh CLI documentation: https://cli.github.com/
