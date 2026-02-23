# Governance Rules

Reference documentation for the principled-architecture plugin's dependency direction model and enforcement levels.

## Module Dependency Direction

Based on ADR-003's module type declarations, the plugin enforces these default dependency direction rules:

| Module Type | Can Depend On     | Cannot Depend On                     |
| ----------- | ----------------- | ------------------------------------ |
| `app`       | `lib`, `core`     | other `app`                          |
| `lib`       | `core`            | `app`, other `lib` (unless declared) |
| `core`      | _(none internal)_ | `app`, `lib`                         |

### Rule Definitions

- **app modules** are top-level applications. They may import from `lib` and `core` modules. They must not import from other `app` modules --- applications are independent entry points.
- **lib modules** are shared libraries. They may import from `core` modules. By default, they must not import from `app` modules (dependency inversion) or other `lib` modules (to prevent circular library dependencies). Cross-lib dependencies can be declared explicitly.
- **core modules** are foundational. They must not import from `app` or `lib` modules. They provide base types, utilities, and contracts that other modules depend on.

### Override Mechanism

Teams can override default rules by declaring explicit dependency allowances in their module's `CLAUDE.md`:

```markdown
## Dependencies

- packages/shared-types (lib) --- explicit cross-lib dependency for shared type definitions
```

When the `## Dependencies` section lists a module, that dependency is treated as allowed even if the default rules would prohibit it.

## Enforcement Levels

| Level        | Behavior                                   | Use Case                      |
| ------------ | ------------------------------------------ | ----------------------------- |
| **Advisory** | Report violations as warnings; never block | Default for all analysis      |
| **Strict**   | Exit non-zero on error-severity violations | CI integration via `--strict` |

## Violation Severity

| Severity    | Criteria                                  | Example                            |
| ----------- | ----------------------------------------- | ---------------------------------- |
| **Error**   | Clear dependency direction violation      | `core` module importing from `app` |
| **Warning** | Probable violation, heuristic uncertainty | Import path matches another module |
| **Info**    | Governance observation, not a violation   | Module has no ADR coverage         |

## Import Pattern Recognition

The plugin recognizes these import patterns via regex (language-agnostic, file-level):

- JavaScript/TypeScript: `import ... from '...'`, `require('...')`
- Python: `import ...`, `from ... import ...`
- Go: `import "..."`
- Rust: `use ...::...`
- General: Relative paths (`../`) and absolute paths matching module directories

The pattern set is intentionally broad rather than precise. False positives are preferred over missed violations --- the advisory model means false positives are informational, not disruptive.
