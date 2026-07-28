---
title: "Bats for Shell Testing"
number: "019"
status: accepted
author: Alex
created: 2026-07-28
updated: 2026-07-28
from_proposal: "001"
supersedes: null
superseded_by: null
---

# ADR-019: Bats for Shell Testing

## Status

Accepted

<!-- Valid values: proposed, accepted, deprecated, superseded -->
<!-- Once accepted, this document is IMMUTABLE. -->
<!-- Exception: superseded_by may be updated when a new ADR supersedes this one. -->

## Context

RFC-001 considered [Bats](https://github.com/bats-core/bats-core) and deferred it:

> Bats is a full testing framework for Bash. While valuable, it's a heavier addition.
> The existing validation scripts already serve as integration tests. Bats can be
> introduced in a future RFC if more comprehensive test coverage is needed.

That was a reasonable call for a repository with a handful of scripts. It stopped being
reasonable at 53 shell scripts and 8,700 lines, and the deferral's own condition —
"if more comprehensive test coverage is needed" — has now been met concretely rather
than speculatively.

### What the smoke tests could not catch

The prior approach was per-hook smoke tests, duplicated in the justfile and inline in
`ci.yml`. Both fed one known-good and one known-bad input and asserted the exit code.
They passed continuously while the following were true:

- **`grep -oP` in 13 places across 5 plugins.** PCRE-only; stock macOS grep has no
  `-P`. Each sat in a `jq`-optional fallback written `grep -oP ... || echo ""`, so on
  macOS without jq the extraction yielded nothing, the guard found no file path, and
  allowed everything. The smoke tests ran on a machine with jq, so they never touched
  the fallback.
- **`declare -A` in two architecture scripts.** bash 4.0+; macOS ships 3.2. Both
  scripts aborted before doing any work. CI ran ubuntu's bash 5.
- **`spawn/SKILL.md` referencing a script that did not exist**, with the failure
  swallowed by `2>/dev/null || echo "Error: ..."`.

None of these are exotic. They are the ordinary failure modes of shell in a codebase
whose guards **fail open by design** — a broken guard allows everything and produces no
symptom until something slips through. That property makes untested guards worse than
untested ordinary code, and it is the argument that changes the balance RFC-001 struck.

### The specific trap

The most instructive failure is one the tests themselves initially fell into.

An obvious way to test a `jq`-optional fallback is to restrict `PATH`:

```bash
env PATH=/usr/bin:/bin bash the-hook.sh
```

This does not work. `jq` is installed at `/usr/bin/jq` on macOS, so `command -v jq`
still succeeds, the hook takes the jq branch, and the fallback is never executed. The
test passes and asserts nothing. That is precisely how PCRE fallbacks survived in five
plugins.

A framework does not prevent this — but it makes the fix expressible once, in `setup()`,
and reused by every test.

## Decision

**Adopt Bats as the shell test framework, installed as an npm devDependency, with tests
in `tests/`. It replaces the per-hook smoke tests in both the justfile and `ci.yml`.**

- `bats` is added to `devDependencies` alongside markdownlint and prettier, consistent
  with ADR-004's Node-as-dev-tooling boundary. No plugin script depends on Node.
- Tests live in `tests/*.bats`, run via `just test` or `npx bats tests/`.
- The `test-hook-*` justfile recipes and the ~211 lines of inline smoke tests in
  `ci.yml` are removed. Maintaining three descriptions of the same behaviour meant
  three places to update per hook change — the same duplication problem ADR-018
  addressed for shared code.
- Two CI jobs run the suite: `test` on ubuntu, and `compat-bash32` on `macos-latest`
  under `/bin/bash`, which is 3.2.

**Every hook test must exercise the no-jq path with jq genuinely absent** — via a
symlink directory containing the tools hooks need and excluding jq, not via a `PATH`
prefix. This is a hard requirement, not a style preference.

Current coverage: 62 tests. 34 over the 11 hooks (allow, block, malformed input, no-jq,
plus corpus-wide checks that every accepted ADR and terminal proposal is blocked), and
28 over the task graph library.

## Options Considered

### Option 1: Bats via npm devDependency (chosen)

**Pros:**

- Standard framework; contributors do not learn a bespoke harness
- `setup()` / `teardown()` and `BATS_TEST_TMPDIR` make isolated fixtures trivial —
  each test gets a scratch git repository, which is what makes the parallel-merge and
  cache-rebuild tests possible at all
- Installs with `npm ci`, which contributors already run
- TAP output; per-test failures rather than a script that dies on the first one
- Retires ~211 lines of inline CI YAML and eight justfile recipes

**Cons:**

- A new dev dependency, which is exactly what RFC-001 was avoiding
- Contributors must run `npm ci` before tests, and `npx bats` is slower to start than
  a bare script
- Adds ~40s to CI across the two jobs

### Option 2: Keep smoke tests, extend them (rejected)

Add the missing cases to the existing justfile and `ci.yml` smoke tests.

**Pros:** no new dependency; no migration.

**Cons:** the duplication is the defect. The same assertions already lived in two
places and disagreed in coverage. Adding no-jq and hostile-input cases to both would
have tripled that. And the smoke tests have no per-test isolation, so the task graph
tests — which need a scratch git repository per case — are not expressible in them.

### Option 3: A hand-rolled pure-bash harness (rejected)

Write a small runner: no dependency, matches the "pure bash" ethos.

**Pros:** zero dependencies; runs anywhere.

**Cons:** reimplements setup/teardown, temp directories, assertions, and TAP output —
roughly what Bats already is, minus the documentation and the contributors who know it.
The "pure bash" principle applies to the **plugin runtime**, which users install. Dev
tooling is explicitly exempt under ADR-004, and markdownlint and prettier already
establish the precedent.

### Option 4: shUnit2 (rejected)

Comparable capability. Bats is more widely used in this domain, has better fixture
ergonomics via `BATS_TEST_TMPDIR`, and distributes on npm, which this repository already
depends on.

## Consequences

### Positive

- Guards that fail open are now verified to fail open only when they should
- The no-jq fallback is tested with jq genuinely absent — the single highest-value
  assertion in the suite, and the one the previous approach could not make
- `compat-bash32` catches bash 4-only syntax that ubuntu's bash 5 accepts silently
- One place describes hook behaviour instead of three
- New shared code arrives with tests rather than a checker registration step

### Negative

- Contributors must run `npm ci` before `just test`
- CI is ~40s slower
- Reverses a documented deferral in RFC-001, which is a cost to the record even though
  the deferral anticipated it

### Neutral

- Plugin runtime stays pure bash. Nothing a user installs depends on Node.
- `/test-hooks` becomes a wrapper that runs the suite and helps interpret failures,
  rather than a document describing checks to perform by hand.

## Open Questions

- **Coverage targets.** 62 tests cover hooks and the task graph. The remaining ~40
  scripts — `validate-structure.sh`, `parse-plan.sh`, `task-manifest.sh`,
  `collect-changes.sh` — have none. Which are worth testing, and is there a threshold
  below which a script should not ship?
- **Fixture strategy for the larger scripts.** Hook tests need only stdin and a
  repository. `validate-structure.sh` needs a synthetic module tree. Should fixtures
  live in `tests/fixtures/`, or be generated per test as the task graph tests do?
- **Should `just test` gate `pre-commit`?** It currently runs in CI and on demand. At
  62 tests the runtime is a few seconds; at ten times that it would be intrusive.
