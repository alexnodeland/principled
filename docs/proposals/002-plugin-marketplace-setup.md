---
title: "Plugin Marketplace Setup"
number: 002
status: draft
author: Alex
created: 2026-02-04
updated: 2026-02-04
supersedes: null
superseded_by: null
---

# RFC-002: Plugin Marketplace Setup

## Audience

- Plugin maintainers and contributors
- Teams evaluating principled-docs for adoption
- Future plugin authors (first-party and community)
- Engineers responsible for Claude Code plugin distribution within organizations

## Context

principled-docs is currently structured as a single Claude Code plugin. The repo root _is_ the plugin: `.claude-plugin/plugin.json` at the root, `skills/` and `hooks/` at the root, and the repo installs itself as its own plugin for dogfooding. This works well for a single plugin.

However, there are reasons to evolve this structure:

1. **Distribution friction.** Teams that want to adopt principled-docs must add the plugin directly by path or repo URL. There is no marketplace catalog that makes the plugin discoverable alongside other plugins, and no mechanism for a team to curate a set of plugins for their organization.

2. **No path for additional plugins.** The Principled methodology could benefit from complementary plugins (e.g., code review checklists, release management, onboarding guides). The current single-plugin structure has no place for these — they would each need a separate repository, separate distribution, and separate installation.

3. **No community contribution path for plugins.** External contributors who want to build plugins that complement principled-docs have no standard way to make them discoverable to existing users. There is no directory or registry they can submit to.

4. **Organizational adoption.** Teams adopting Claude Code plugins often want a single marketplace URL they can add to their `.claude/settings.json` via `extraKnownMarketplaces`, rather than individually managing plugin paths. A marketplace provides a single point of trust and distribution.

Claude Code supports custom plugin marketplaces — git repositories that contain a `.claude-plugin/marketplace.json` catalog listing available plugins. This proposal defines how to transform the principled-docs repository into a curated marketplace with tiered plugin organization, while preserving principled-docs as the flagship first-party plugin.

## Proposal

Transform this repository from a single-plugin repo into a curated plugin marketplace with two tiers: first-party plugins (maintained by the project) and external plugins (community-contributed). The principled-docs plugin itself moves into the first-party tier.

### 1. Repository Structure

The target directory layout after transformation:

```
principled-docs/                          # Repo root = marketplace
├── .claude-plugin/
│   ├── marketplace.json                  # NEW — marketplace catalog
│   └── plugin.json                       # REMOVED — moves into plugin dir
├── plugins/                              # NEW — first-party plugins
│   └── principled-docs/                  # Existing plugin, relocated
│       ├── .claude-plugin/
│       │   └── plugin.json               # Existing manifest (relocated)
│       ├── skills/                        # Existing skills (relocated)
│       ├── hooks/                         # Existing hooks (relocated)
│       └── README.md                     # Plugin-specific README
├── external_plugins/                     # NEW — community plugins
│   └── .gitkeep                          # Placeholder until first submission
├── docs/                                 # Marketplace-level documentation
│   ├── proposals/                        # Marketplace RFCs (including this one)
│   ├── plans/
│   ├── decisions/
│   └── architecture/
├── .claude/                              # Marketplace dev configuration
│   ├── settings.json
│   ├── CLAUDE.md
│   └── skills/                           # Dev skills
├── .github/
│   └── workflows/
│       └── ci.yml                        # Updated CI for marketplace layout
├── CLAUDE.md                             # Marketplace-level context
├── CONTRIBUTING.md                       # Updated for marketplace + plugin contribution
├── README.md                             # Marketplace README (updated)
└── LICENSE
```

Key structural decisions:

- **The repo root becomes the marketplace.** `.claude-plugin/marketplace.json` replaces the root-level `plugin.json`.
- **`plugins/` holds first-party plugins.** These are maintained by the project. `principled-docs` is the first (and currently only) entry.
- **`external_plugins/` holds community plugins.** These are contributed by third parties, reviewed by maintainers, and listed in the marketplace catalog. This directory starts empty.
- **`docs/` remains at the root.** The documentation pipeline (proposals, plans, decisions, architecture) governs the _marketplace_ — not any individual plugin. Individual plugins maintain their own docs if needed.
- **Dev infrastructure stays at the root.** `.claude/`, `.github/`, config files (`.prettierrc`, `.shellcheckrc`, etc.), and `package.json` remain at the repo root and apply to the entire marketplace.

### 2. Marketplace Manifest

Create `.claude-plugin/marketplace.json`:

```json
{
  "name": "principled-marketplace",
  "version": "1.0.0",
  "description": "Curated marketplace for Principled methodology Claude Code plugins. First-party and community plugins for specification-first development.",
  "owner": {
    "name": "Alex"
  },
  "metadata": {
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "principled-docs",
      "source": "./plugins/principled-docs",
      "description": "Scaffold, author, and enforce module documentation structure following the Principled specification-first methodology.",
      "version": "0.3.1",
      "category": "documentation",
      "keywords": [
        "documentation",
        "rfc",
        "adr",
        "specification-first",
        "monorepo",
        "ddd"
      ]
    }
  ]
}
```

The `metadata.pluginRoot` field provides a default base path for relative plugin sources. Each plugin entry explicitly declares its `source` path regardless, for clarity.

### 3. Plugin Relocation

Move the existing principled-docs plugin from the repo root into `plugins/principled-docs/`:

| Current Location             | New Location                                         |
| ---------------------------- | ---------------------------------------------------- |
| `.claude-plugin/plugin.json` | `plugins/principled-docs/.claude-plugin/plugin.json` |
| `skills/`                    | `plugins/principled-docs/skills/`                    |
| `hooks/`                     | `plugins/principled-docs/hooks/`                     |

The `plugin.json` content does not change. The plugin remains self-contained — all skills, hooks, scripts, templates, and reference docs move together.

#### What Stays at the Root

These are marketplace-level concerns, not plugin concerns:

- `docs/` — Marketplace proposals, plans, decisions, architecture
- `.claude/` — Marketplace dev configuration and dev skills
- `.github/` — CI pipeline for the marketplace
- `CLAUDE.md` — Marketplace context (updated to reflect new structure)
- `CONTRIBUTING.md` — Updated for both marketplace and plugin contribution
- `README.md` — Marketplace overview with plugin catalog
- `LICENSE` — Applies to entire marketplace
- Config files (`.prettierrc`, `.shellcheckrc`, `.markdownlint.jsonc`, etc.) — Apply to all code in the marketplace
- `package.json` — Dev tooling dependencies
- `.pre-commit-config.yaml` — Pre-commit hooks for entire repo

### 4. First-Party Plugin Structure

Each first-party plugin in `plugins/` is a self-contained Claude Code plugin:

```
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest (required)
├── skills/                        # Plugin skills
│   ├── <skill-name>/
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   ├── scripts/
│   │   └── reference/
│   └── ...
├── hooks/                         # Plugin hooks (optional)
│   ├── hooks.json
│   └── scripts/
├── README.md                      # Plugin-specific documentation
└── CLAUDE.md                      # Plugin-specific Claude Code context (optional)
```

Requirements for first-party plugins:

- Must have a valid `.claude-plugin/plugin.json` manifest
- Must pass `claude plugin validate .` from the plugin directory
- Must follow the marketplace's shell and Markdown lint standards
- Must include a `README.md` with installation, usage, and skill/hook documentation
- Skills must be self-contained (no cross-plugin imports)

### 5. External Plugin Structure

External (community) plugins in `external_plugins/` follow the same structural requirements as first-party plugins:

```
external_plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json
├── skills/
├── hooks/                         # Optional
└── README.md
```

Additional requirements for external plugins:

- Must include an `author` field in `plugin.json`
- Must include a `homepage` or `repository` field pointing to the upstream source
- Must pass CI validation (lint, structure, plugin validate)
- Must be submitted via pull request and reviewed by a marketplace maintainer

External plugins are listed in `marketplace.json` with their `external_plugins/` source path:

```json
{
  "name": "community-plugin-name",
  "source": "./external_plugins/community-plugin-name",
  "description": "What it does.",
  "author": "Community Author",
  "category": "category-name"
}
```

### 6. Marketplace Categories

Plugins are organized by category in the marketplace catalog. Initial categories:

| Category        | Description                                             |
| --------------- | ------------------------------------------------------- |
| `documentation` | Documentation structure, authoring, and enforcement     |
| `workflow`      | Development workflow automation and process enforcement |
| `quality`       | Code quality, review, and standards enforcement         |
| `architecture`  | Architectural governance and decision tracking          |

Categories are informational — they appear in `marketplace.json` plugin entries and are used for display and filtering. They do not affect directory structure. New categories can be added without a proposal.

### 7. Dogfooding Update

The dogfooding configuration in `.claude/settings.json` must update to reference the plugin at its new location:

```json
{
  "plugins": [
    {
      "path": "./plugins/principled-docs"
    }
  ]
}
```

The `CLAUDE_PLUGIN_ROOT` environment variable must also update:

```json
{
  "env": {
    "CLAUDE_PLUGIN_ROOT": "./plugins/principled-docs"
  }
}
```

All hook scripts in the principled-docs plugin use `${CLAUDE_PLUGIN_ROOT}` for path resolution, so they will work correctly at the new location without modification.

### 8. CI Pipeline Updates

The CI pipeline (`.github/workflows/ci.yml`) must adapt to the new directory structure:

#### Shell and Markdown Lint

No change — glob patterns (`**/*.sh`, `**/*.md`) already match files recursively regardless of where they live.

#### Template Drift Check

The `check-template-drift.sh` script uses paths relative to `CLAUDE_PLUGIN_ROOT`. It must be invoked with the correct root:

```yaml
- name: Check template drift
  run: |
    CLAUDE_PLUGIN_ROOT=./plugins/principled-docs \
      bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh
```

#### Structure Validation

Root structure validation must point to the marketplace's `docs/` directory:

```yaml
- name: Validate marketplace docs structure
  run: |
    CLAUDE_PLUGIN_ROOT=./plugins/principled-docs \
      bash plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --root
```

#### Plugin Validation

Add a new CI step that validates every plugin in the marketplace:

```yaml
- name: Validate all plugins
  run: |
    for plugin_dir in plugins/*/; do
      echo "Validating $plugin_dir..."
      (cd "$plugin_dir" && claude plugin validate .)
    done
    for plugin_dir in external_plugins/*/; do
      [ -d "$plugin_dir" ] || continue
      echo "Validating $plugin_dir..."
      (cd "$plugin_dir" && claude plugin validate .)
    done
```

#### Marketplace Manifest Validation

Add a CI step that validates the marketplace manifest:

```yaml
- name: Validate marketplace manifest
  run: |
    # Verify marketplace.json exists and is valid JSON
    jq . .claude-plugin/marketplace.json > /dev/null
    # Verify every listed plugin source directory exists
    jq -r '.plugins[].source' .claude-plugin/marketplace.json | while read -r src; do
      if [ ! -d "$src" ]; then
        echo "ERROR: Plugin source directory not found: $src"
        exit 1
      fi
    done
```

### 9. Pre-commit Hook Updates

The `.pre-commit-config.yaml` template drift check hook must update its entry point:

```yaml
- repo: local
  hooks:
    - id: template-drift
      name: Check template drift
      entry: bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh
      language: system
      pass_filenames: false
      types: [markdown]
```

### 10. Dev Skill Updates

The dev skills in `.claude/skills/` must update any paths that reference plugin scripts. For example, the `/propagate-templates` skill must know templates are now at `plugins/principled-docs/skills/scaffold/templates/`.

The `/check-ci` and `/lint` skills should continue to operate from the repo root, as lint config files remain there.

### 11. Documentation Updates

#### `CLAUDE.md` (Root)

Update to describe the marketplace structure:

- Replace "this repo **is** the principled-docs plugin" with "this repo is the Principled methodology plugin marketplace"
- Update the architecture table to reflect marketplace vs. plugin layers
- Update all path references from `skills/` to `plugins/principled-docs/skills/`
- Document the `plugins/` and `external_plugins/` directories
- Add marketplace contribution guidelines

#### `README.md` (Root)

Transform from plugin README to marketplace README:

- Marketplace overview and purpose
- Available plugins catalog (with links to individual plugin READMEs)
- Installation instructions (marketplace add, then plugin install)
- How to contribute a plugin (first-party and external)

#### `CONTRIBUTING.md`

Add sections for:

- Contributing a new first-party plugin
- Submitting an external plugin
- Marketplace manifest maintenance
- Plugin review criteria

#### Plugin-Level `README.md`

The existing `README.md` content (plugin installation, skills, hooks, configuration) moves to `plugins/principled-docs/README.md`. This is the plugin's own documentation, independent of the marketplace.

### 12. User-Facing Workflow

After this transformation, the end-user workflow for adopting plugins changes:

**Adding the marketplace:**

```
/plugin marketplace add owner/principled-docs
```

**Listing available plugins:**

```
/plugin marketplace list
```

**Installing principled-docs:**

```
/plugin install principled-docs@principled-marketplace
```

**Team-wide adoption via settings:**

```json
{
  "extraKnownMarketplaces": {
    "principled-marketplace": {
      "source": {
        "source": "github",
        "repo": "owner/principled-docs"
      }
    }
  },
  "enabledPlugins": {
    "principled-docs@principled-marketplace": true
  }
}
```

### 13. Migration Strategy

The transformation should be executed as a single coordinated change to avoid an intermediate broken state:

1. Create `plugins/principled-docs/` directory
2. Move `.claude-plugin/plugin.json` to `plugins/principled-docs/.claude-plugin/plugin.json`
3. Move `skills/` to `plugins/principled-docs/skills/`
4. Move `hooks/` to `plugins/principled-docs/hooks/`
5. Create `.claude-plugin/marketplace.json` at the repo root
6. Create `external_plugins/.gitkeep`
7. Move root `README.md` to `plugins/principled-docs/README.md`; write new marketplace `README.md` at root
8. Update `.claude/settings.json` (plugin path, `CLAUDE_PLUGIN_ROOT`)
9. Update `.github/workflows/ci.yml` (template drift path, validation paths)
10. Update `.pre-commit-config.yaml` (template drift hook entry point)
11. Update root `CLAUDE.md` and `.claude/CLAUDE.md` (path references, architecture description)
12. Update `CONTRIBUTING.md` (marketplace contribution sections)
13. Update dev skills in `.claude/skills/` (path references)
14. Run full CI locally (`/check-ci`) to verify nothing is broken

This is a restructuring with no functional changes to the plugin itself. All skills, hooks, templates, and scripts remain identical — only their paths within the repo change.

## Alternatives Considered

### Alternative 1: Keep principled-docs at the repo root alongside marketplace.json

In this model, the repo root serves as both the plugin and the marketplace. `.claude-plugin/` contains both `plugin.json` and `marketplace.json`. `skills/` and `hooks/` remain at the root. Additional plugins are added to `plugins/` and `external_plugins/`.

**Rejected because:** This creates an ambiguous structure where the root is simultaneously a plugin and a marketplace. It conflates marketplace governance (proposals, CI, contribution guidelines) with plugin content (skills, hooks, templates). New contributors would need to understand that some root-level directories belong to the marketplace and others belong to the principled-docs plugin. Moving the plugin into `plugins/` provides a clean separation of concerns.

### Alternative 2: Separate marketplace repository

Create a new repository (`principled-marketplace`) that serves as the marketplace, referencing principled-docs and other plugins by their GitHub repo URLs rather than bundling them.

**Rejected because:** This adds repository management overhead, splits the documentation pipeline across repos, and breaks the dogfooding workflow. A monorepo marketplace is simpler — plugins can share CI, linting, and contribution infrastructure. Community plugins benefit from the same quality gates as first-party plugins. The existing docs pipeline (proposals, plans, decisions) naturally governs the marketplace as a whole.

### Alternative 3: Pattern B — Dual-purpose repo (plugin + marketplace at root)

Similar to Alternative 1, but with a clearer convention: the root is formally declared as a plugin via `plugin.json`, and separately as a marketplace via `marketplace.json`, with both coexisting in `.claude-plugin/`.

**Rejected because:** While Claude Code supports this pattern, it creates tension when the repo grows. Skills at the root are ambiguous — do they belong to the marketplace or to the principled-docs plugin? The Pattern C approach (curated directory with tiers) removes this ambiguity entirely. Each plugin is a self-contained directory, and the root is purely the marketplace.

### Alternative 4: Reference external plugins by repo URL instead of bundling

Instead of an `external_plugins/` directory, list community plugins in `marketplace.json` with `"source": { "source": "github", "repo": "author/plugin-repo" }`, pointing to their upstream repositories.

**Rejected as the sole approach because:** External source references bypass the marketplace's quality gates (CI lint, structure validation). Bundling ensures every plugin passes the same checks. However, this approach could be _additionally_ supported in the future for plugins that prefer to maintain their own repos while still being discoverable through this marketplace.

## Consequences

### Positive

- **Clean separation of concerns.** Marketplace governance (proposals, CI, contribution) is distinct from plugin content (skills, hooks, templates). Each layer has its own directory.
- **Scalable to multiple plugins.** New first-party plugins are added to `plugins/`, community plugins to `external_plugins/`, and both are listed in `marketplace.json`. No structural refactoring needed.
- **Single distribution point.** Teams add one marketplace URL and get access to all plugins. No per-plugin URL management.
- **Unified quality gates.** All plugins — first-party and community — pass the same CI pipeline (lint, structure validation, plugin validation).
- **Community contribution path.** External contributors have a clear process for submitting plugins via `external_plugins/` and pull request.
- **Marketplace discoverability.** Users can browse available plugins via `/plugin marketplace list` without knowing individual plugin repos.
- **Dogfooding preserved.** The principled-docs plugin continues to be installed on the repo via `.claude/settings.json`, now pointing to its new path.

### Negative

- **Path disruption.** Every reference to `skills/`, `hooks/`, or `.claude-plugin/plugin.json` in the repo must be updated. This affects `CLAUDE.md`, `.claude/CLAUDE.md`, `CONTRIBUTING.md`, CI workflows, pre-commit config, and dev skills.
- **External documentation breakage.** Any external documentation, blog posts, or tutorials that reference the old repo structure will need updating.
- **Deeper nesting.** Plugin files move one directory deeper (`plugins/principled-docs/skills/scaffold/templates/core/proposal.md` vs. `skills/scaffold/templates/core/proposal.md`). This increases path length in git diffs, CI logs, and developer navigation.
- **Marketplace maintenance overhead.** `marketplace.json` must be kept in sync with actual plugin directories. A new plugin added to `plugins/` but not listed in `marketplace.json` is invisible to users.

### Risks

- **Claude Code marketplace feature stability.** The marketplace feature is relatively new in Claude Code. Schema changes or behavioral changes could require updates to `marketplace.json`. Mitigated by pinning to the documented schema and validating in CI.
- **Git history disruption.** Moving files from root to `plugins/principled-docs/` creates a large rename commit. `git log --follow` tracks renames, but some tools may lose file history context. Mitigated by executing the move in a single commit with `git mv`.
- **Dogfooding regression.** If the `.claude/settings.json` plugin path is not updated correctly, enforcement hooks and skills will silently stop working. Mitigated by running the full CI pipeline and hook smoke tests after migration.
- **Community adoption unknown.** The `external_plugins/` tier assumes community interest in contributing plugins. If no community plugins materialize, the tier adds structural complexity with no benefit. Mitigated by keeping it minimal (just `.gitkeep`) until there is demand.

## Architecture Impact

This proposal requires updates to the following existing architecture documents:

- **[Plugin System Architecture](../architecture/plugin-system.md)** — Add marketplace layer above the plugin layer. Document the relationship between `marketplace.json` and individual `plugin.json` manifests.
- **[Documentation Pipeline](../architecture/documentation-pipeline.md)** — Clarify that the documentation pipeline (proposals, plans, decisions) governs the marketplace, not individual plugins.
- **[Enforcement System](../architecture/enforcement-system.md)** — Update path references for hook scripts.

This proposal may also produce new architectural decisions:

- Marketplace naming conventions (reserved names, naming rules for submitted plugins)
- External plugin review and acceptance criteria
- Marketplace versioning strategy (how `marketplace.json` version relates to individual plugin versions)

## Decisions

The following questions were raised during drafting and have been resolved:

1. **Marketplace name:** `principled-marketplace`. This avoids collision with reserved names (`claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `life-sciences`).
2. **Root `docs/` scope:** The root documentation pipeline governs the marketplace as a whole (including this proposal). Individual plugins may maintain their own `docs/` directories if they grow large enough to warrant it, but this is not required.
3. **`metadata.pluginRoot`:** Set to `"./plugins"` to provide a default base path. Individual plugin `source` entries still use explicit relative paths for clarity.
4. **External plugin bundling vs. references:** External plugins are bundled (copied into the repo) rather than referenced by URL. This ensures they pass the same CI quality gates. URL-based references may be supported in the future as an additional mechanism.
5. **Migration approach:** Single coordinated commit using `git mv` to preserve history, followed by path updates in a second commit.

## Open Questions

1. **Plugin-level documentation pipelines.** Should individual plugins in `plugins/` maintain their own `docs/proposals/`, `docs/plans/`, `docs/decisions/` directories? Or should all governance documents live in the marketplace-level `docs/`? The answer likely depends on plugin size and team structure, but a default convention would be useful.

2. **Marketplace versioning.** When a new plugin is added or an existing plugin is updated, should the marketplace `version` in `marketplace.json` be bumped? If so, what versioning scheme (semver, date-based, independent of plugin versions)?

3. **External plugin update mechanism.** When a community plugin's upstream repository publishes a new version, how should the bundled copy in `external_plugins/` be updated? Options include manual PR, automated sync via CI, or a script that pulls latest from the declared `repository` URL.

4. **Plugin interdependencies.** Should the marketplace support declaring that one plugin depends on another (e.g., a future plugin that extends principled-docs)? Claude Code does not currently support plugin dependency resolution, so this may be premature.
