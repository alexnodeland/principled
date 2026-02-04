---
name: new-architecture-doc
description: >
  Create a new architecture document describing current design.
  Use when documenting a component, data flow, or system design
  that onboarding engineers need to understand.
allowed-tools: Read, Write, Bash(ls *), Bash(find *)
user-invocable: true
---

# New Architecture Doc — Architecture Document Creation

Create a new architecture document describing current system design.

## Command

```
/new-architecture-doc <title> [--module <path>] [--root]
```

## Arguments

| Argument          | Required | Description                                                                                  |
| ----------------- | -------- | -------------------------------------------------------------------------------------------- |
| `<title>`         | Yes      | Descriptive title for the architecture document (e.g., `data-flow`, `authentication-system`) |
| `--module <path>` | No       | Target module path                                                                           |
| `--root`          | No       | Create at repo root level (`docs/architecture/`)                                             |

## Workflow

1. **Parse arguments.** Extract the title and determine the target:
   - If `--root`: target is `docs/architecture/` at repo root
   - If `--module <path>`: target is `<path>/docs/architecture/`
   - Otherwise: determine from current working context

2. **Scan for related ADRs.** Look in the corresponding `docs/decisions/` directory for ADRs that may be related to this architecture document. List them for cross-referencing.

3. **Create the document.** Read `templates/architecture.md` and create `<target>/<title>.md`.

4. **Populate frontmatter:**

   | Field          | Value                                        |
   | -------------- | -------------------------------------------- |
   | `title`        | The document title (humanized from the slug) |
   | `last_updated` | Today's date                                 |
   | `related_adrs` | List of related ADR numbers found in step 2  |

5. **Pre-populate ADR references.** In the "Key Decisions" section, insert links to the related ADRs discovered in step 2.

6. **Confirm creation.** Report the file path and remind the user that architecture docs are living documents — they should be updated as the design evolves and should always reference the ADRs that produced the current design.

## Architecture Doc Conventions

- Architecture docs use **freeform descriptive names** (no number prefix).
- They are **living documents** — updated as design evolves.
- They **reference ADRs** that produced the current design.
- Their primary audience is **onboarding engineers**.

## Templates

- `templates/architecture.md` — Architecture document template (copy of `scaffold/templates/core/architecture.md`)
