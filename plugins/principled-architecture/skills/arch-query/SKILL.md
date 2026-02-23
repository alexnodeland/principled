---
name: arch-query
description: >
  Answer natural-language questions about the architecture by
  cross-referencing ADRs, architecture docs, proposals, and the
  codebase. Designed for onboarding and architecture exploration.
allowed-tools: Read, Bash(git *), Bash(ls *), Bash(bash plugins/*)
user-invocable: true
---

# Architecture Query --- Interactive Architecture Q&A

Answer natural-language questions about the architecture by searching across ADRs, architecture documents, proposals, and the codebase. Designed for onboarding and architecture exploration.

## Command

```
/arch-query "<question>"
```

## Arguments

| Argument       | Required | Description                                         |
| -------------- | -------- | --------------------------------------------------- |
| `"<question>"` | Yes      | A natural-language architecture question in quotes. |

## Example Questions

- "Which ADRs govern the plugin system?"
- "What decisions affect the documentation pipeline?"
- "Why did we choose heuristic analysis over AST-level parsing?"
- "Which modules have no architectural governance?"
- "What is the dependency direction rule for lib modules?"
- "How does the enforcement system work?"

## Workflow

1. **Parse the question.** Identify the query type:
   - **Module query**: "Which ADRs govern module X?" --- search for module-specific governance
   - **Decision query**: "Why did we decide X?" --- search ADRs for the decision context
   - **Pattern query**: "How does X work?" --- search architecture docs and code
   - **Coverage query**: "Which modules lack governance?" --- run audit logic
   - **General query**: broad architecture questions --- search across all sources

2. **Search relevant sources.** Based on the query type:
   - **ADRs** (`docs/decisions/`): Read titles, status, and body content. Focus on the "Decision" and "Context" sections.
   - **Architecture docs** (`docs/architecture/`): Read content for pattern descriptions, module relationships, and design explanations.
   - **Proposals** (`docs/proposals/`): Read for historical context on why features were built and what alternatives were considered.
   - **Module CLAUDE.md files**: Read for module type, dependencies, and structural context.
   - **Codebase**: When the question requires code-level context, examine relevant source files.

3. **Synthesize the answer.** Combine information from multiple sources into a coherent response:
   - Lead with the direct answer
   - Support with references to specific documents
   - Include relevant context from the decision history
   - Note any caveats or limitations

4. **Cite sources.** Every claim should reference a specific document:

   ```
   The plugin system uses a three-layer architecture (skills, hooks, foundation)
   as described in docs/architecture/plugin-system.md. Module types are declared
   in CLAUDE.md per ADR-003, and dependency direction rules are enforced
   heuristically per ADR-014.
   ```

5. **Suggest follow-ups.** When relevant, suggest related queries or skills:

   ```
   For a visual map of module governance, try: /arch-map
   For a full coverage audit, try: /arch-audit
   ```

## Design Notes

This skill is deliberately open-ended. It leverages Claude's ability to search, read, and synthesize rather than running deterministic scripts. The value is in connecting questions to the right documents, not in producing structured reports (that is what `/arch-map` and `/arch-audit` are for).
