# Issue Classification Guide

## Purpose

When ingesting a GitHub issue, determine what principled documents to create. The classification is based on the issue's scope, complexity, and nature.

## Classification Matrix

| Signal                                                     | RFC + Plan | Plan Only |
| ---------------------------------------------------------- | ---------- | --------- |
| Labels: `feature`, `enhancement`, `rfc`                    | Yes        | ---       |
| Labels: `bug`, `fix`, `patch`                              | ---        | Yes       |
| Body mentions API changes, architecture, new modules       | Yes        | ---       |
| Body describes a specific fix with known root cause        | ---        | Yes       |
| Body is longer than ~500 words with design discussion      | Yes        | ---       |
| Body is short and task-oriented                            | ---        | Yes       |
| Multiple components or modules affected                    | Yes        | ---       |
| Single component, localized change                         | ---        | Yes       |
| Issue has "alternatives considered" or tradeoff discussion | Yes        | ---       |
| Issue is a straightforward TODO                            | ---        | Yes       |

## Decision Logic

1. **Start by checking labels.** Labels are the strongest signal because humans applied them intentionally.
   - `feature`, `enhancement`, `rfc`, `proposal`, `design` → RFC + Plan
   - `bug`, `fix`, `patch`, `hotfix`, `chore`, `task` → No documents; implement directly
   - No labels or ambiguous labels → continue to body analysis

2. **Analyze body content.** Look for signals of design scope:
   - Mentions of architecture, API design, data model changes, new abstractions → RFC + Plan
   - Mentions of specific files, error messages, stack traces, concrete steps → No documents

3. **Consider body length.** Longer issues with discussion of tradeoffs and alternatives suggest RFC-level scope. Short, action-oriented issues suggest no documents at all.

4. **Ask what will consume the plan.** Plans exist to be executed by `/orchestrate`,
   `/decompose`, or `/spawn`. If nothing will orchestrate this work, a plan is ceremony —
   take **No documents** instead.

5. **Default to RFC + Plan for design work; default to No documents for fixes.** An RFC
   that turns out unnecessary is cheap. Inventing an RFC purely to unlock a plan is not:
   it puts a fake design on the permanent record to satisfy a guard.

**There is no "Plan only" outcome.** `check-plan-proposal-link.sh` blocks any plan whose
`originating_proposal` is missing (exit 2), and that guard is correct — a plan is a DDD
decomposition of an accepted design, so a plan with no design is a decomposition of
nothing. Every plan in this repository has an RFC behind it; most fixes have neither.

## Mapping Issue Content to Documents

### Issue → Proposal (RFC)

| Issue Section                    | Proposal Section                        |
| -------------------------------- | --------------------------------------- |
| Title                            | Title (humanized)                       |
| Body opening paragraph           | Context                                 |
| Body feature description         | Proposal                                |
| Body "alternatives" or "options" | Alternatives Considered                 |
| Body questions or unknowns       | Open Questions                          |
| Labels                           | Audience hints                          |
| Comments with discussion         | Additional context for Proposal section |

### Issue → Plan

| Issue Section                           | Plan Section           |
| --------------------------------------- | ---------------------- |
| Title                                   | Title                  |
| Body problem statement                  | Objective              |
| Body checklist or steps                 | Implementation Tasks   |
| Body dependencies or prerequisites      | Dependencies           |
| Body acceptance criteria or "done when" | Acceptance Criteria    |
| Labels with component names             | Bounded Contexts hints |

## Label-to-Lifecycle Mapping

When applying labels after ingestion:

- RFC created → add `type:rfc`, `proposal:draft`
- Plan created → add `type:plan`, `plan:active`
- Both created → add all four labels
