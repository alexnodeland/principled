---
name: test-hooks
description: >
  Smoke-test all enforcement hooks by feeding known good and bad inputs
  and verifying exit codes. Tests the ADR immutability guard, the
  proposal lifecycle guard, the manifest integrity advisory, the PR
  reference advisory, the review checklist advisory, and the release
  readiness advisory.
allowed-tools: Bash(echo *), Bash(bash plugins/*), Read
user-invocable: true
---

# Test Hooks — Enforcement Hook Smoke Tests

Smoke-test all enforcement hooks by feeding known good and bad inputs and verifying exit codes.

## Command

```
/test-hooks
```

## Workflow

### ADR Immutability Guard (`plugins/principled-docs/hooks/scripts/check-adr-immutability.sh`)

Run these test cases:

1. **Accepted ADR — should block (exit 2):**
   For each file in `docs/decisions/` with `status: accepted`, feed its path:

   ```bash
   echo '{"tool_input":{"file_path":"<path>"}}' | bash plugins/principled-docs/hooks/scripts/check-adr-immutability.sh
   ```

   Expected: exit code 2.

2. **Non-decision file — should allow (exit 0):**

   ```bash
   echo '{"tool_input":{"file_path":"CLAUDE.md"}}' | bash plugins/principled-docs/hooks/scripts/check-adr-immutability.sh
   ```

   Expected: exit code 0.

3. **Non-existent file — should allow (exit 0):**

   ```bash
   echo '{"tool_input":{"file_path":"docs/decisions/999-nonexistent.md"}}' | bash plugins/principled-docs/hooks/scripts/check-adr-immutability.sh
   ```

   Expected: exit code 0.

### Proposal Lifecycle Guard (`plugins/principled-docs/hooks/scripts/check-proposal-lifecycle.sh`)

Run these test cases:

1. **Accepted proposal — should block (exit 2):**
   For each file in `docs/proposals/` with status `accepted`, `rejected`, or `superseded`, feed its path. Expected: exit code 2.

2. **Draft proposal — should allow (exit 0):**
   For each file in `docs/proposals/` with status `draft`, feed its path. Expected: exit code 0.

3. **Non-proposal file — should allow (exit 0):**

   ```bash
   echo '{"tool_input":{"file_path":"CLAUDE.md"}}' | bash plugins/principled-docs/hooks/scripts/check-proposal-lifecycle.sh
   ```

   Expected: exit code 0.

### Manifest Integrity Advisory (`plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh`)

Run these test cases:

1. **Manifest file edit — should warn but allow (exit 0):**

   ```bash
   echo '{"tool_input":{"file_path":".impl/manifest.json"}}' | bash plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh
   ```

   Expected: exit code 0, with advisory message on stderr.

2. **Unrelated file — should pass silently (exit 0):**

   ```bash
   echo '{"tool_input":{"file_path":"src/index.ts"}}' | bash plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh
   ```

   Expected: exit code 0, no output.

3. **Missing JSON input — should allow (exit 0):**

   ```bash
   echo '{}' | bash plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh
   ```

   Expected: exit code 0 (guard scripts default to allow).

### PR Reference Advisory (`plugins/principled-github/hooks/scripts/check-pr-references.sh`)

Run these test cases:

1. **`gh pr create` command — should warn but allow (exit 0):**

   ```bash
   echo '{"tool_input":{"command":"gh pr create --title \"test\" --body \"test\""}}' | bash plugins/principled-github/hooks/scripts/check-pr-references.sh
   ```

   Expected: exit code 0, with advisory message on stderr.

2. **Unrelated command — should pass silently (exit 0):**

   ```bash
   echo '{"tool_input":{"command":"git status"}}' | bash plugins/principled-github/hooks/scripts/check-pr-references.sh
   ```

   Expected: exit code 0, no output.

3. **Missing JSON input — should allow (exit 0):**

   ```bash
   echo '{}' | bash plugins/principled-github/hooks/scripts/check-pr-references.sh
   ```

   Expected: exit code 0 (guard scripts default to allow).

### Review Checklist Advisory (`plugins/principled-quality/hooks/scripts/check-review-checklist.sh`)

Run these test cases:

1. **`gh pr review` command — should warn but allow (exit 0):**

   ```bash
   echo '{"tool_input":{"command":"gh pr review 42"}}' | bash plugins/principled-quality/hooks/scripts/check-review-checklist.sh
   ```

   Expected: exit code 0, with advisory message on stderr.

2. **`gh pr merge` command — should warn but allow (exit 0):**

   ```bash
   echo '{"tool_input":{"command":"gh pr merge 42"}}' | bash plugins/principled-quality/hooks/scripts/check-review-checklist.sh
   ```

   Expected: exit code 0, with advisory message on stderr.

3. **Unrelated command — should pass silently (exit 0):**

   ```bash
   echo '{"tool_input":{"command":"git status"}}' | bash plugins/principled-quality/hooks/scripts/check-review-checklist.sh
   ```

   Expected: exit code 0, no output.

### Release Readiness Advisory (`plugins/principled-release/hooks/scripts/check-release-readiness.sh`)

Run these test cases:

1. **`git tag` command — should warn but allow (exit 0):**

   ```bash
   echo '{"tool_input":{"command":"git tag v1.0.0"}}' | bash plugins/principled-release/hooks/scripts/check-release-readiness.sh
   ```

   Expected: exit code 0, with advisory message on stderr.

2. **`git tag -l` command — should pass silently (exit 0):**

   ```bash
   echo '{"tool_input":{"command":"git tag -l"}}' | bash plugins/principled-release/hooks/scripts/check-release-readiness.sh
   ```

   Expected: exit code 0, no advisory (listing tags is not a release action).

3. **Unrelated command — should pass silently (exit 0):**

   ```bash
   echo '{"tool_input":{"command":"git status"}}' | bash plugins/principled-release/hooks/scripts/check-release-readiness.sh
   ```

   Expected: exit code 0, no output.

### Reporting

For each test case, report PASS or FAIL with the actual vs expected exit code. Provide a summary at the end with total pass/fail counts.
