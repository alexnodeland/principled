# Mapping Conventions

Reference documentation for how the principled-architecture plugin maps code to architectural decisions.

## ADR Scope Detection

ADRs can declare their scope (which modules they govern) through several mechanisms, checked in priority order:

### 1. Explicit Module References in Body

The most reliable signal. The ADR body mentions specific module paths:

```markdown
This decision affects `packages/event-store/` and `packages/api-gateway/`.
```

The mapper scans ADR content for paths that match discovered module directories.

### 2. Component or Pattern References

ADRs may reference components, patterns, or technologies that map to specific modules:

```markdown
## Decision

All event handlers must use the EventBus interface from core.
```

The mapper cross-references these against module contents and CLAUDE.md descriptions.

### 3. Universal Scope

Some ADRs apply to all modules (e.g., "all modules must declare their type in CLAUDE.md"). These are identified by the absence of specific module references and the presence of universal language ("all modules", "every module", "any module").

## Architecture Map Format

The architecture map is a Markdown document with one section per discovered module:

```markdown
# Architecture Map

Generated: YYYY-MM-DD

## Module: <path> (<type>)

### Governing ADRs

- **ADR-NNN**: <title> --- Affects: <brief scope description>
- ...

### Architecture Docs

- [<title>](path) --- Referenced in: <section>
- ...

### Coverage: <Full|Partial|None>
```

## Coverage Classification

| Level       | Criteria                                                               |
| ----------- | ---------------------------------------------------------------------- |
| **Full**    | At least one governing ADR AND at least one architecture doc reference |
| **Partial** | Has governing ADRs OR architecture doc references, but not both        |
| **None**    | No governing ADRs and no architecture doc references                   |

## Map Interpretation

- **Full coverage** does not mean complete governance --- it means the module has documented architectural context in both ADRs and architecture docs.
- **None coverage** is a signal, not necessarily a problem. Some modules (utilities, simple scripts) may not need explicit governance.
- The map is a snapshot. It reflects the current state of documents and code at generation time. It does not track historical changes.

## Architecture Document References

Architecture documents in `docs/architecture/` are scanned for module path references. A module is considered referenced by an architecture doc if the doc's body contains the module's directory path or name.
