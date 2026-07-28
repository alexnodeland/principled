<p align="center">
  <strong>📐 Principled Marketplace</strong>
</p>

<p align="center">
  <em>A curated Claude Code plugin marketplace for specification-first development.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/claude_code-v2.1.3+-7c3aed?style=flat-square" alt="Claude Code v2.1.3+" />
  <img src="https://img.shields.io/badge/marketplace-v0.5.0-blue?style=flat-square" alt="Marketplace v0.5.0" />
  <img src="https://img.shields.io/badge/license-MIT-gray?style=flat-square" alt="License: MIT" />
</p>

---

A Claude Code plugin marketplace hosting first-party and community plugins for the Principled specification-first methodology. Add the marketplace once, install any plugin.

## 📦 Available Plugins

### First-Party

| Plugin                                                                       | Category       | Description                                                                                                                           |
| ---------------------------------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| [**principled-docs**](plugins/principled-docs/README.md)                     | documentation  | Scaffold, author, and enforce module documentation structure following the Principled specification-first methodology (v0.3.1)        |
| [**principled-implementation**](plugins/principled-implementation/README.md) | implementation | Orchestrate DDD plan execution via worktree-isolated Claude Code agents (v0.1.0)                                                      |
| [**principled-github**](plugins/principled-github/README.md)                 | workflow       | Integrate the principled workflow with GitHub native features: issues, PRs, templates, actions, CODEOWNERS, and labels (v0.1.0)       |
| [**principled-quality**](plugins/principled-quality/README.md)               | quality        | Connect code reviews to the principled documentation pipeline with spec-driven checklists and review tracking (v0.1.0)                |
| [**principled-release**](plugins/principled-release/README.md)               | workflow       | Generate changelogs from the documentation pipeline, verify release readiness, and coordinate versioned releases (v0.1.0)             |
| [**principled-architecture**](plugins/principled-architecture/README.md)     | architecture   | Map modules to governing ADRs, detect architectural drift, audit governance coverage, and sync architecture docs (v0.1.0)             |
| [**principled-tasks**](plugins/principled-tasks/README.md)                   | workflow       | Git-native, graph-linked task tracking backed by an append-only event log — merges cleanly across parallel agent branches (v0.1.0)    |
| [**principled-agent**](plugins/principled-agent/README.md)                   | orchestration  | Agent identity, memory, and the contributor protocol — governed dispatch, draft-PR constraints, and a file-based halt switch (v0.1.0) |

### Community

_No community plugins yet. See [Contributing](#-contributing-a-plugin) to submit one._

## ⚡ Quick Start

### Add the Marketplace

```
/plugin marketplace add alexnodeland/principled
```

### Install a Plugin

```
/plugin install principled-docs@principled-marketplace
/plugin install principled-implementation@principled-marketplace
/plugin install principled-github@principled-marketplace
/plugin install principled-quality@principled-marketplace
/plugin install principled-release@principled-marketplace
/plugin install principled-architecture@principled-marketplace
/plugin install principled-tasks@principled-marketplace
/plugin install principled-agent@principled-marketplace
```

### Team-Wide Adoption

Add to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "principled-marketplace": {
      "source": {
        "source": "github",
        "repo": "alexnodeland/principled"
      }
    }
  },
  "enabledPlugins": {
    "principled-docs@principled-marketplace": true,
    "principled-implementation@principled-marketplace": true,
    "principled-github@principled-marketplace": true,
    "principled-quality@principled-marketplace": true,
    "principled-release@principled-marketplace": true,
    "principled-architecture@principled-marketplace": true,
    "principled-tasks@principled-marketplace": true,
    "principled-agent@principled-marketplace": true
  }
}
```

## 📂 Structure

```
principled/
├── .claude-plugin/
│   └── marketplace.json         # Plugin catalog
├── plugins/                     # First-party plugins
│   ├── principled-docs/         # Documentation structure plugin
│   ├── principled-implementation/ # Plan execution plugin
│   ├── principled-github/       # GitHub integration plugin
│   ├── principled-quality/      # Code review quality plugin
│   ├── principled-release/     # Release lifecycle plugin
│   ├── principled-architecture/ # Architecture governance plugin
│   └── principled-agent/       # Agent identity and memory plugin
├── external_plugins/            # Community plugins
├── docs/                        # Marketplace governance
│   ├── proposals/               # RFCs
│   ├── plans/                   # Implementation plans
│   ├── decisions/               # ADRs
│   └── architecture/            # Design docs
└── .claude/                     # Dev configuration
```

## 🤝 Contributing a Plugin

### First-Party Plugins

First-party plugins live in `plugins/`. They are maintained by the project and must:

- Have a valid `.claude-plugin/plugin.json` manifest
- Follow marketplace lint standards (ShellCheck, shfmt, markdownlint, Prettier)
- Include a `README.md` with installation, usage, and skill/hook documentation
- Be self-contained (no cross-plugin imports)

### Community Plugins

Community plugins live in `external_plugins/`. Submit via pull request:

1. Create `external_plugins/<your-plugin>/` with the standard plugin structure
2. Include `.claude-plugin/plugin.json` with `author` and `homepage`/`repository` fields
3. Include a `README.md`
4. Ensure all CI checks pass
5. A maintainer will review and add the entry to `marketplace.json`

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

## 📋 Categories

| Category         | Description                                             |
| ---------------- | ------------------------------------------------------- |
| `documentation`  | Documentation structure, authoring, and enforcement     |
| `implementation` | Plan execution, orchestration, and agent automation     |
| `workflow`       | Development workflow automation and process enforcement |
| `quality`        | Code quality, review, and standards enforcement         |
| `architecture`   | Architectural governance and decision tracking          |

---

<p align="center">
  <sub>Built with the <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> plugin system · Principled specification-first methodology</sub>
</p>
