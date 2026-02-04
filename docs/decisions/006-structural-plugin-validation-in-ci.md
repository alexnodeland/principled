---
title: "Structural Plugin Validation in CI"
number: "006"
status: accepted
author: Alex
created: 2026-02-04
updated: 2026-02-04
from_proposal: "002"
supersedes: null
superseded_by: null
---

# ADR-006: Structural Plugin Validation in CI

## Context

RFC-002 specifies that the CI pipeline must validate each plugin in the marketplace. The original proposal suggested running `claude plugin validate .` in each plugin directory. However, the `claude` CLI is a desktop/developer tool — it may not be available in all CI environments (GitHub Actions runners, container-based CI, etc.) and installing it adds a heavyweight dependency to the pipeline.

The marketplace needs CI validation that:

- Confirms every listed plugin has a valid manifest
- Works without installing the Claude Code CLI
- Follows the plugin's existing convention of minimal external dependencies (see ADR-004)
- Handles both first-party (`plugins/`) and community (`external_plugins/`) tiers

## Decision

**Use structural validation in CI rather than requiring the `claude` CLI.**

Plugin validation in CI performs the following checks:

1. Verify `.claude-plugin/plugin.json` exists in each plugin directory
2. Verify the JSON is well-formed (parseable by `jq` or `python3 -m json.tool` as fallback)
3. Verify every `source` path listed in `marketplace.json` points to an existing directory

Marketplace manifest validation is a separate CI step that:

1. Verifies `.claude-plugin/marketplace.json` is well-formed JSON
2. Iterates over the `plugins` array and confirms each `source` directory exists

Both steps use `jq` as the primary JSON parser with `python3 -m json.tool` as a fallback, consistent with the plugin's convention of optional `jq` (see ADR-001).

## Consequences

### Positive

- CI runs without installing the Claude Code CLI — no additional heavyweight dependency
- Validation is fast (JSON parsing + directory existence checks)
- Follows ADR-004's principle: external tool dependencies are minimized
- `jq`/`python3` fallback pattern is already established in the plugin's hook scripts
- Catches the most common contributor errors (malformed JSON, missing directories)

### Negative

- Does not validate plugin semantics (e.g., whether `skills/` directories contain valid `SKILL.md` files, whether hook matchers are correctly formed)
- A plugin could pass CI validation but fail `claude plugin validate .` at runtime
- If Claude Code introduces new manifest requirements, structural checks may not catch violations until a user tries to install the plugin

### Alternatives Considered

1. **Require `claude` CLI in CI.** Would provide authoritative validation but adds a large binary dependency to the CI environment, requires authentication setup, and couples the pipeline to a desktop tool's release cycle.

2. **Write a comprehensive bash validator.** A custom script could check skill structure (`SKILL.md` existence, frontmatter fields) and hook configuration (`hooks.json` schema). Rejected as over-engineering for the current marketplace size — structural checks are sufficient until the marketplace has enough plugins and contributors to justify the maintenance cost.

3. **Skip plugin validation in CI entirely.** Rely on maintainer review for plugin correctness. Rejected — even basic structural checks catch common errors and reduce review burden.
