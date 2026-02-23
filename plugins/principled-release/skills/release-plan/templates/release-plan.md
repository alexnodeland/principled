---
title: "Release Plan: {{VERSION}}"
date: { { DATE } }
since: { { SINCE_TAG } }
---

# Release Plan: {{VERSION}}

**Prepared:** {{DATE}}
**Since:** {{SINCE_TAG}}
**Commits:** {{COMMIT_COUNT}}

---

## Modules Affected

{{MODULES_SECTION}}

## Features

{{FEATURES_SECTION}}

## Improvements

{{IMPROVEMENTS_SECTION}}

## Decisions

{{DECISIONS_SECTION}}

## Outstanding Items

{{OUTSTANDING_SECTION}}

## Release Steps

1. Review this release plan with the team
2. Run `/release-ready --strict` to verify all pipeline documents are in terminal status
3. Run `/version-bump` to apply version changes to module manifests
4. Run `/changelog --since {{SINCE_TAG}}` to generate the changelog
5. Commit version bumps and changelog
6. Run `/tag-release {{VERSION}}` to create the tag and release notes
