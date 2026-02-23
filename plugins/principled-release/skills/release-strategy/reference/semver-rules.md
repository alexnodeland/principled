# Semver Rules

## Version Bump Heuristics

The principled release plugin determines version bump type from pipeline signals. These heuristics can be overridden with `--type major|minor|patch`.

### Automatic Detection

| Signal                                         | Bump Type | Rationale                                          |
| ---------------------------------------------- | --------- | -------------------------------------------------- |
| Proposal with `supersedes` field set           | **Major** | Superseding a prior RFC indicates breaking changes |
| ADR with `supersedes` field set                | **Major** | Superseding an architectural decision is breaking  |
| Accepted proposal (new RFC)                    | **Minor** | New specifications introduce new capabilities      |
| Plan tasks without an originating proposal     | **Patch** | Implementation work without new specifications     |
| Commits referencing only fixes or improvements | **Patch** | Maintenance and bug fixes                          |

### Priority Rules

When multiple signals are present, the highest bump type wins:

1. Any **major** signal makes the release major
2. Otherwise, any **minor** signal makes the release minor
3. Otherwise, the release is **patch**

### Override Behavior

The `--type` flag on `/version-bump` overrides automatic detection entirely. This is intentional --- teams may choose to release a minor version even when a technically-breaking change was made, if the break only affects internal APIs.

## Version Manifest Files

The plugin detects version manifests by scanning module directories for known files:

| File               | Ecosystem  | Version Field                           |
| ------------------ | ---------- | --------------------------------------- |
| `package.json`     | Node.js    | `"version": "X.Y.Z"`                    |
| `Cargo.toml`       | Rust       | `version = "X.Y.Z"`                     |
| `pyproject.toml`   | Python     | `version = "X.Y.Z"`                     |
| `VERSION`          | Generic    | Single line `X.Y.Z`                     |
| `CLAUDE.md`        | Principled | Version in frontmatter                  |
| `plugin.json`      | Claude     | `"version": "X.Y.Z"`                    |
| `.claude-plugin/*` | Claude     | `"version": "X.Y.Z"` in plugin manifest |

The first matching file found (in the order above) is used. If no manifest is found, the skill reports the module and skips it.

## Module Detection

Modules are detected via `CLAUDE.md` files following ADR-003 (module type declaration). Each directory containing a `CLAUDE.md` is considered a module boundary.

The root `CLAUDE.md` defines the top-level module. Nested `CLAUDE.md` files define sub-modules, each potentially with its own versioning.

## Pre-release Versions

Pre-release support is deferred to a future version. For v0.1.0, all versions follow strict `MAJOR.MINOR.PATCH` format.
