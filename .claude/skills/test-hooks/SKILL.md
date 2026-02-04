---
name: test-hooks
description: >
  Smoke-test the enforcement hooks by feeding known good and bad inputs
  and verifying exit codes. Tests both the ADR immutability guard and
  the proposal lifecycle guard.
allowed-tools: Bash(echo *), Bash(bash hooks/*), Read
user-invocable: true
---

# Test Hooks — Enforcement Hook Smoke Tests

Smoke-test the enforcement hooks by feeding known good and bad inputs and verifying exit codes.

## Command

```
/test-hooks
```

## Workflow

### ADR Immutability Guard (`hooks/scripts/check-adr-immutability.sh`)

Run these test cases:

1. **Accepted ADR — should block (exit 2):**
   For each file in `docs/decisions/` with `status: accepted`, feed its path:

   ```bash
   echo '{"tool_input":{"file_path":"<path>"}}' | bash hooks/scripts/check-adr-immutability.sh
   ```

   Expected: exit code 2.

2. **Non-decision file — should allow (exit 0):**

   ```bash
   echo '{"tool_input":{"file_path":"CLAUDE.md"}}' | bash hooks/scripts/check-adr-immutability.sh
   ```

   Expected: exit code 0.

3. **Non-existent file — should allow (exit 0):**

   ```bash
   echo '{"tool_input":{"file_path":"docs/decisions/999-nonexistent.md"}}' | bash hooks/scripts/check-adr-immutability.sh
   ```

   Expected: exit code 0.

### Proposal Lifecycle Guard (`hooks/scripts/check-proposal-lifecycle.sh`)

Run these test cases:

1. **Accepted proposal — should block (exit 2):**
   For each file in `docs/proposals/` with status `accepted`, `rejected`, or `superseded`, feed its path. Expected: exit code 2.

2. **Draft proposal — should allow (exit 0):**
   For each file in `docs/proposals/` with status `draft`, feed its path. Expected: exit code 0.

3. **Non-proposal file — should allow (exit 0):**

   ```bash
   echo '{"tool_input":{"file_path":"CLAUDE.md"}}' | bash hooks/scripts/check-proposal-lifecycle.sh
   ```

   Expected: exit code 0.

### Reporting

For each test case, report PASS or FAIL with the actual vs expected exit code. Provide a summary at the end with total pass/fail counts.
