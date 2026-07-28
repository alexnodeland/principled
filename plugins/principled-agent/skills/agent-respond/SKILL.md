---
name: agent-respond
description: >
  Address review feedback on an agent-authored PR, and promote the durable
  lessons into agent memory so the same correction is not needed again. Use
  when a human has reviewed an agent PR and requested changes.
allowed-tools: Read, Write, Edit, Bash(bash plugins/*), Bash(bash scripts/*), Bash(gh *), Bash(git *), Bash(ls *), Bash(cat *)
user-invocable: true
---

# Agent Respond — Address PR Review Feedback

Act on review comments, and close the loop by writing what was learned into memory.

## Command

```
/agent-respond <pr-number> [--agent <id>] [--no-promote]
```

## Arguments

| Argument       | Required | Description                                                   |
| -------------- | -------- | ------------------------------------------------------------- |
| `<pr-number>`  | Yes      | PR carrying the review feedback                               |
| `--agent <id>` | No       | Agent whose memory to update. Inferred from the PR if omitted |
| `--no-promote` | No       | Address the feedback but write nothing to memory              |

## Why this exists

Without it, a reviewer corrects the same thing on every PR forever. The correction lands
in a comment thread, the session ends, and the next agent starts with no knowledge of it.

This skill is the mechanism by which review feedback stops repeating: durable corrections
become memory (ADR-020), which is injected at the next spawn.

## Workflow

1. **Verify `gh` and read the review.**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/check-gh-cli.sh"
   gh pr view <pr-number> --json number,title,author,isDraft,reviews,comments,files
   gh api "repos/{owner}/{repo}/pulls/<pr-number>/comments"
   ```

   The second call matters: `gh pr view` returns review summaries, not inline
   line-level comments, and inline comments are usually where the substance is.

2. **Separate the feedback.** Sort every comment into three buckets, because they get
   different treatment:

   | Kind           | Example                                 | Action                        |
   | -------------- | --------------------------------------- | ----------------------------- |
   | **Defect**     | "this crashes on empty input"           | Fix, then reply               |
   | **Convention** | "we use `lib/` for shared scripts here" | Fix **and** promote to memory |
   | **Preference** | "I'd have named this differently"       | Judgement; reply either way   |

   Only conventions are memory candidates. A defect is a fact about one PR; a convention
   is a fact about the codebase that will apply to every future one.

3. **Address each item.** Make the changes, then commit with attribution:

   ```bash
   git commit -m "review: <what changed>

   Addresses review feedback on #<pr-number>.

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

4. **Reply to each thread**, saying what was done or why it was not. A comment left
   unanswered reads as ignored, which costs the reviewer's trust more than a disagreement
   does.

   ```bash
   gh pr comment <pr-number> --body "<response>"
   ```

   Disagreeing is legitimate — say so with reasoning and leave the thread open for the
   human. Do not silently decline.

5. **Promote conventions to memory** (unless `--no-promote`). For each convention, apply
   the `agent-strategy` standard — durable, certain, not already present — then append to
   the agent's `## Known Patterns` via `/agent-memory --learn`.

   Write the **rule**, not the incident. "PR #34 used the wrong path" teaches nothing;
   "shared scripts live in the plugin's `lib/`, referenced via `${CLAUDE_PLUGIN_ROOT}`"
   prevents the next occurrence.

   Then record the round:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh" --update-metrics --agent <id> --session
   ```

6. **Leave the PR a draft.** Addressing feedback does not make a PR ready — promotion and
   merge are human acts (ADR-022). Do not run `gh pr ready`, `gh pr review --approve`, or
   `gh pr merge`.

## Reporting

List each comment with what was done, flag anything deliberately not done and why, and
state exactly which lines were added to memory so the reviewer can object to a bad
learning before it compounds.

## Scripts

- `${CLAUDE_PLUGIN_ROOT}/lib/agent-memory.sh` — memory interface (ADR-018, ADR-020)
- `${CLAUDE_PLUGIN_ROOT}/lib/check-gh-cli.sh` — gh availability
