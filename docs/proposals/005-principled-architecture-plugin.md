---
title: "Principled Architecture Plugin"
number: 005
status: draft
author: Alex
created: 2026-02-22
updated: 2026-02-22
supersedes: null
superseded_by: null
---

# RFC-005: Principled Architecture Plugin

## Audience

- Teams using the principled methodology who want to enforce architectural decisions at the code level
- Architects and tech leads responsible for maintaining system integrity across modules
- Plugin maintainers evaluating the marketplace's expansion into governance tooling
- Contributors to the principled marketplace

## Context

The principled methodology records architectural decisions in ADRs (Architecture Decision Records) and maintains living architecture documents in `docs/architecture/`. These documents describe the system's intended design: which patterns to use, how modules should communicate, what boundaries to respect, and which trade-offs were made.

However, there is no mechanism to verify that the codebase actually conforms to these documented decisions. ADRs are write-once records (immutable after acceptance, enforced by principled-docs hooks), but the code they govern evolves continuously. Over time, architectural drift accumulates:

1. **Decisions without enforcement.** An ADR might declare "all inter-module communication uses events" but nothing prevents a developer from adding a direct function call between modules. The ADR is accepted, the code diverges, and nobody notices until the architecture review months later.

2. **Architecture documents go stale.** Living architecture docs in `docs/architecture/` describe the intended system design, but they are updated manually. As the codebase evolves, these documents fall behind. New modules are added without updating the architecture diagrams. Integration patterns change without updating the architecture doc.

3. **Module boundary violations.** ADR-003 established module type declarations via `CLAUDE.md`. But declaring a module's type doesn't enforce its boundaries. A `lib` module might start importing from an `app` module, violating the dependency direction. Nothing in the pipeline catches this.

4. **No architectural visibility.** Teams lack tooling to answer basic questions: "Which ADRs govern module X?" "Has any module violated the event-driven pattern from ADR-007?" "Which architecture docs need updating after this quarter's changes?" These queries require manual document archaeology.

5. **Decision coverage gaps.** Some modules may not be covered by any ADR — their architecture is implicit rather than explicit. There is no way to identify which parts of the codebase lack explicit architectural governance.

The principled pipeline produces high-quality architectural documentation. What's missing is the feedback loop: tooling that maps code to decisions, detects drift, and keeps the architecture documents honest.

## Proposal

Add a new first-party plugin, `principled-architecture`, to the marketplace. This plugin provides skills for mapping code to architectural decisions, detecting architectural drift, auditing decision coverage, and keeping architecture documents synchronized with the codebase.

### 1. Plugin Structure

```
plugins/principled-architecture/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── arch-strategy/             # Background knowledge skill
│   │   └── SKILL.md
│   ├── arch-map/                  # Map code to ADRs and architecture docs
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   │   └── arch-map.md
│   │   └── scripts/
│   │       └── scan-modules.sh
│   ├── arch-drift/                # Detect drift between decisions and code
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── check-boundaries.sh
│   ├── arch-audit/                # Audit ADR and architecture doc coverage
│   │   ├── SKILL.md
│   │   └── templates/
│   │       └── audit-report.md
│   ├── arch-sync/                 # Update architecture docs from codebase
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── detect-changes.sh
│   └── arch-query/                # Query the architecture knowledge base
│       └── SKILL.md
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── check-boundary-violation.sh
└── README.md
```

### 2. Skills

| Skill           | Command                                         | Category   | Description                                                                     |
| --------------- | ----------------------------------------------- | ---------- | ------------------------------------------------------------------------------- |
| `arch-strategy` | _(background — not user-invocable)_             | Knowledge  | Provides context about architecture governance conventions                      |
| `arch-map`      | `/arch-map [--module <path>] [--output <path>]` | Analytical | Generate a map linking modules to their governing ADRs and architecture docs    |
| `arch-drift`    | `/arch-drift [--module <path>] [--strict]`      | Analytical | Detect violations of architectural decisions in the codebase                    |
| `arch-audit`    | `/arch-audit [--module <path>]`                 | Analytical | Audit ADR coverage — identify modules without explicit architectural governance |
| `arch-sync`     | `/arch-sync [--doc <path>] [--all]`             | Generative | Update architecture documents to reflect current codebase state                 |
| `arch-query`    | `/arch-query "<question>"`                      | Analytical | Answer questions about the architecture by cross-referencing code and decisions |

#### `/arch-map`

The foundational skill. It builds a map between code modules and architectural artifacts:

1. Scans all modules by finding `CLAUDE.md` files (per ADR-003)
2. For each module, reads its `CLAUDE.md` to determine type (`core`, `lib`, `app`)
3. Scans all ADRs in `docs/decisions/` and identifies which modules each ADR governs (by parsing ADR content for module references, path mentions, or explicit scope declarations)
4. Scans architecture docs in `docs/architecture/` for module references
5. Generates a Markdown map using the `arch-map.md` template:

```markdown
# Architecture Map

## Module: packages/event-store (core)

### Governing ADRs

- **ADR-001**: Pure bash frontmatter parsing — Affects: frontmatter handling
- **ADR-005**: Pre-commit framework — Affects: hook configuration

### Architecture Docs

- [Plugin System](docs/architecture/plugin-system.md) — Referenced in: §3 Event Flow

### Coverage: Full (2 ADRs, 1 architecture doc)

## Module: packages/api-gateway (app)

### Governing ADRs

- _(none)_

### Architecture Docs

- _(none)_

### Coverage: None — ⚠ No architectural governance
```

The `--module` flag scopes to a single module. Without it, all modules are mapped.

#### `/arch-drift`

The core enforcement skill. It checks whether the codebase conforms to documented architectural decisions:

1. Reads all accepted ADRs
2. For each ADR, extracts the architectural constraints it declares (patterns to follow, boundaries to respect, technologies to use or avoid)
3. Analyzes the relevant modules for violations:
   - **Dependency direction**: `lib` modules importing from `app` modules
   - **Module boundary**: Direct imports across module boundaries where the ADR prescribes events or interfaces
   - **Pattern conformance**: Code patterns that contradict ADR decisions (e.g., synchronous calls where the ADR mandates async)
   - **Technology constraints**: Use of libraries or approaches that an ADR explicitly rejected
4. Reports violations with severity (error vs. warning) and references to the governing ADR
5. In `--strict` mode, any violation is a failure. In default mode, violations are reported as warnings.

The analysis is necessarily heuristic — it uses file scanning, import analysis, and pattern matching rather than full semantic analysis. It aims for high-value, low-false-positive checks.

#### `/arch-audit`

Identifies gaps in architectural governance:

1. Lists all modules (via `CLAUDE.md` discovery)
2. Cross-references against the architecture map to find modules with:
   - No governing ADRs
   - No mention in architecture documents
   - ADRs in `deprecated` or `superseded` status with no replacement
3. Identifies orphaned ADRs (accepted ADRs that reference modules or patterns no longer present in the codebase)
4. Identifies stale architecture docs (docs that reference modules, patterns, or components that have been removed or renamed)
5. Generates an audit report using the `audit-report.md` template, categorized by severity:
   - **Critical**: Module with no governance that handles sensitive operations
   - **Warning**: Module with no governance (default for uncovered modules)
   - **Info**: ADR or architecture doc that may be stale

#### `/arch-sync`

Updates architecture documents to reflect the current codebase:

1. Reads the specified architecture doc (or all docs with `--all`)
2. Compares the documented state against the actual codebase:
   - Module list (are all current modules mentioned?)
   - Module types (do declared types match `CLAUDE.md`?)
   - Integration patterns (do described patterns match actual imports/dependencies?)
   - Component inventory (are all significant components listed?)
3. Generates suggested updates as a diff or inline edit
4. Presents the changes for human review before applying

This skill is generative — it proposes changes but requires human approval. Architecture documents are too important to update fully automatically.

#### `/arch-query`

An interactive query skill for architecture questions:

1. Takes a natural-language question (e.g., "Which modules use event sourcing?", "What decisions govern the auth module?", "Why did we choose pattern X?")
2. Searches across ADRs, architecture docs, proposals, and the codebase to find relevant information
3. Synthesizes an answer with references to source documents
4. Particularly useful for onboarding (new team members asking "why is this designed this way?")

This skill is deliberately open-ended — it leverages Claude's ability to search and synthesize rather than running a deterministic script.

### 3. Hooks

| Hook                        | Event               | Script                        | Timeout | Behavior |
| --------------------------- | ------------------- | ----------------------------- | ------- | -------- |
| Boundary Violation Advisory | PostToolUse (Write) | `check-boundary-violation.sh` | 10s     | Advisory |

The hook triggers when a file is written in a module directory. It performs a lightweight check: does the file contain imports from modules it shouldn't depend on (based on module type conventions: `app` can depend on `lib` and `core`, `lib` can depend on `core`, `core` should have no internal module dependencies). Advisory only — always exits 0. It warns rather than blocks because import analysis from file content alone has limited accuracy.

### 4. Module Type Dependency Rules

Based on ADR-003's module type declarations, the plugin enforces these dependency direction rules:

| Module Type | Can Depend On     | Cannot Depend On                     |
| ----------- | ----------------- | ------------------------------------ |
| `app`       | `lib`, `core`     | other `app`                          |
| `lib`       | `core`            | `app`, other `lib` (unless declared) |
| `core`      | _(none internal)_ | `app`, `lib`                         |

These are default rules. Teams can override them by declaring explicit dependency allowances in their module's `CLAUDE.md`.

### 5. Marketplace Integration

Add to `.claude-plugin/marketplace.json`:

```json
{
  "name": "principled-architecture",
  "source": "./plugins/principled-architecture",
  "description": "Map code to architectural decisions, detect drift, audit decision coverage, and keep architecture documents synchronized.",
  "version": "0.1.0",
  "category": "architecture",
  "keywords": [
    "architecture",
    "adr",
    "governance",
    "drift-detection",
    "module-boundaries",
    "dependency-rules"
  ]
}
```

### 6. Dependencies

- **Git** — For file history and change detection in `/arch-sync`
- **principled-docs** — Conceptual dependency (reads ADRs, proposals, architecture docs, and module `CLAUDE.md` files). No runtime coupling.

### 7. Script Conventions

All scripts follow marketplace conventions:

- Pure bash, no external dependencies beyond git
- Frontmatter parsing uses the same approach as principled-docs
- `scan-modules.sh` discovers modules by finding `CLAUDE.md` files recursively and parsing the `## Module Type` section
- jq with grep fallback for JSON parsing
- Exit codes: 0 = success/allow, 2 = block (hooks only — not used in v0.1.0 since hooks are advisory), 1 = script error

## Alternatives Considered

### Alternative 1: Extend principled-docs with architecture skills

Add `/arch-map`, `/arch-drift`, and related skills to the principled-docs plugin, since ADRs and architecture docs are already managed by principled-docs.

**Rejected because:** principled-docs is about document _authoring and structure_ — creating, scaffolding, and enforcing document formats. Architecture governance is about the _relationship between documents and code_ — mapping, drift detection, compliance checking. These are fundamentally different concerns. principled-docs ensures ADRs are well-formed; principled-architecture ensures the codebase conforms to what the ADRs say. Combining them would overload principled-docs' already broad scope (9 skills, 3 hooks) and blur the boundary between document authoring and code governance.

### Alternative 2: Static analysis tooling instead of a Claude Code plugin

Use established static analysis tools (ArchUnit for Java, dependency-cruiser for JavaScript, etc.) to enforce architectural rules, configured via standalone config files rather than a Claude Code plugin.

**Rejected as the sole approach because:** Static analysis tools are excellent for specific language ecosystems but:

- They are language-specific (ArchUnit = Java, dependency-cruiser = JS). The principled methodology is language-agnostic.
- They define rules in code or config, disconnected from the ADRs that explain _why_ those rules exist. The principled approach links enforcement to documentation.
- They don't understand the documentation pipeline (proposals, plans, ADRs). They can't answer "which ADR governs this module?" or "which modules lack governance?"

However, static analysis tools are _complementary_. `/arch-drift` could optionally invoke ecosystem-specific tools when available, combining principled pipeline awareness with deep language-level analysis.

### Alternative 3: Architecture fitness functions in tests

Encode architectural rules as test cases (e.g., "no module in `packages/libs/` imports from `packages/apps/`") run via the test suite.

**Rejected as the sole approach because:** Fitness function tests enforce specific rules but:

- They don't provide the mapping and discovery capabilities (`/arch-map`, `/arch-query`, `/arch-audit`)
- They require manual rule authoring for each ADR — there's no automation to derive rules from ADR content
- They don't detect _stale governance_ (ADRs that no longer match the codebase)
- They provide binary pass/fail, not the nuanced reports that guide architectural improvement

Like static analysis, fitness function tests are complementary. `/arch-drift --strict` could run as part of a test suite for CI enforcement.

## Consequences

### Positive

- **Closes the governance feedback loop.** ADRs are no longer just records — they become enforceable constraints with automated drift detection.
- **Architecture visibility.** `/arch-map` provides a single view of which decisions govern which code, replacing manual document archaeology.
- **Coverage accountability.** `/arch-audit` identifies modules with no architectural governance, prompting teams to document implicit decisions.
- **Living architecture docs.** `/arch-sync` keeps architecture documents aligned with the evolving codebase, reducing the staleness that plagues manually maintained architecture docs.
- **Onboarding enablement.** `/arch-query` lets new team members understand architectural context through natural questions rather than document searches.
- **Language-agnostic.** By operating at the module/file level rather than the AST level, the plugin works across any language ecosystem.

### Negative

- **Heuristic analysis limitations.** `/arch-drift` uses file-level pattern matching, not semantic analysis. It will miss some violations and may flag false positives. Mitigated by keeping the analysis advisory-focused and making strict mode opt-in.
- **ADR scope ambiguity.** Not all ADRs clearly declare which modules they govern. `/arch-map` must infer scope from ADR content, which may be imprecise. Mitigated by encouraging explicit scope declarations in ADRs (e.g., a `scope` frontmatter field or explicit module references).
- **Architecture document format assumptions.** `/arch-sync` must understand the structure of architecture documents to propose updates. If teams use non-standard formats, the skill's suggestions may be poor. Mitigated by focusing on the principled-docs scaffold format and making format detection configurable.

### Risks

- **Scope creep into static analysis.** The temptation to add deeper code analysis (import parsing, dependency graph construction, pattern detection) could pull the plugin toward becoming a static analysis tool. This should be resisted — the plugin's value is in connecting code to _documentation_, not in duplicating what language-specific tools do better.
- **ADR scope field adoption.** The plugin works best when ADRs declare their scope explicitly. If existing ADRs lack scope information, `/arch-map` must rely on content inference, which is less reliable. This may motivate a principled-docs template update to include a `scope` field in the ADR template — a cross-plugin change requiring coordination.
- **Performance at scale.** Scanning all modules and cross-referencing all ADRs could be slow in large monorepos. `/arch-map` should cache its results and support incremental updates.

## Architecture Impact

- **[Plugin System Architecture](../architecture/plugin-system.md)** — Add principled-architecture as a first-party plugin. Document the `architecture` category and the governance feedback loop pattern.
- **[Documentation Pipeline](../architecture/documentation-pipeline.md)** — Add an architecture governance stage to the pipeline diagram. Document how `/arch-drift` creates a feedback loop from code back to ADRs.
- **[Enforcement System](../architecture/enforcement-system.md)** — Document the boundary violation advisory hook and its relationship to the existing principled-docs enforcement hooks.

A new ADR may be needed to formalize:

- The module dependency direction rules (app → lib → core)
- The ADR scope declaration convention (how ADRs declare which modules they govern)
- The architecture map format and caching strategy

## Open Questions

1. **ADR scope declaration.** Should ADRs include a `scope` or `modules` frontmatter field that explicitly lists the modules they govern? This would make `/arch-map` more precise but requires a template change in principled-docs. Alternatively, scope could be a convention within the ADR body (e.g., a `## Scope` section).

2. **Import analysis depth.** How deep should `/arch-drift` analyze imports? Options range from file-level (checking `import`/`require` statements via regex) to AST-level (using language-specific parsers). File-level is language-agnostic but shallow; AST-level is precise but language-specific. The plugin should probably start with file-level and support optional language-specific analyzers as extensions.

3. **Architecture map caching.** Should `/arch-map` persist its output (e.g., in a `.architecture/map.json` file) for use by other skills, or regenerate on every invocation? Caching improves performance but introduces staleness risk. If cached, what invalidation strategy?

4. **Relationship to principled-quality.** `/arch-drift` findings could feed into review checklists generated by principled-quality's `/review-checklist`. Should there be a defined integration point between these plugins, or should they remain fully independent?
