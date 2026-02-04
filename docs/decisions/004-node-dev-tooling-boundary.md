---
title: "Node.js Dev Tooling Boundary"
number: "004"
status: accepted
author: Alex
created: 2026-02-04
updated: 2026-02-04
from_proposal: "001"
supersedes: null
superseded_by: null
---

# ADR-004: Node.js Dev Tooling Boundary

## Context

principled-docs is a pure-bash Claude Code plugin. All plugin runtime scripts (`parse-frontmatter.sh`, `validate-structure.sh`, `check-template-drift.sh`, `next-number.sh`, hook scripts) are bash with no external runtime dependencies beyond standard Unix utilities and optional jq.

RFC-001 introduces Markdown linting and formatting via `markdownlint-cli2` and `prettier`, both of which require Node.js. This creates a question: does adding Node.js compromise the plugin's pure-bash identity?

## Decision

**Node.js is introduced strictly as a dev tooling dependency, not a plugin runtime dependency.**

The boundary is enforced by:

- `package.json` exists at the repo root with `"private": true` and only `devDependencies`
- No plugin skill, hook, or script imports or executes Node.js code
- Node.js is only invoked by the pre-commit framework, CI pipeline, and developer commands
- `node_modules/` is gitignored

## Consequences

### Positive

- Markdown quality is enforced by best-in-class tooling (markdownlint-cli2, Prettier)
- Plugin runtime remains pure bash — no Node.js needed to _use_ the plugin
- Dev dependency boundary is clear and auditable via `package.json`

### Negative

- Contributors need Node.js 18+ installed for dev tooling
- `node_modules/` adds disk usage locally (not committed)

### Alternatives Considered

1. **Skip Markdown linting entirely.** Rejected — Markdown is the plugin's primary output artifact; leaving it unlinted while enforcing shell quality would be inconsistent.

2. **Use a non-Node Markdown linter (e.g., mdl in Ruby).** `markdownlint-cli2` has the best rule set and ecosystem integration (pre-commit hooks, CI actions). The Node.js dependency is justified by tooling quality.
