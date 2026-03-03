# principled — development task runner
# Usage: just <recipe>    or    just --list

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List available recipes
default:
    @just --list

# ─── Lint ────────────────────────────────────────────────────────────────────

# Run shell formatting check (shfmt)
lint-shfmt:
    find . -name '*.sh' -not -path './node_modules/*' | xargs shfmt -i 2 -bn -sr -d

# Run shell lint (ShellCheck)
lint-shellcheck:
    find . -name '*.sh' -not -path './node_modules/*' | xargs shellcheck --shell=bash

# Run Markdown lint (markdownlint-cli2)
lint-markdown:
    npx markdownlint-cli2 '**/*.md'

# Run Markdown formatting check (Prettier)
lint-prettier:
    npx prettier --check '**/*.md'

# Fix Markdown formatting (Prettier --write)
fmt:
    npx prettier --write '**/*.md'

# Run all lint checks
lint: lint-shfmt lint-shellcheck lint-markdown lint-prettier

# ─── Template Drift ─────────────────────────────────────────────────────────

# Check template drift for principled-docs
drift-docs:
    bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh

# Check template drift for principled-implementation
drift-impl:
    bash plugins/principled-implementation/scripts/check-template-drift.sh

# Check template drift for principled-github
drift-github:
    bash plugins/principled-github/scripts/check-template-drift.sh

# Check template drift for principled-quality
drift-quality:
    bash plugins/principled-quality/scripts/check-template-drift.sh

# Check template drift for principled-release
drift-release:
    bash plugins/principled-release/scripts/check-template-drift.sh

# Check template drift for principled-architecture
drift-arch:
    bash plugins/principled-architecture/scripts/check-template-drift.sh

# Check all template drift
drift: drift-docs drift-impl drift-github drift-quality drift-release drift-arch

# ─── Validate ────────────────────────────────────────────────────────────────

# Validate root documentation structure
validate-root:
    bash plugins/principled-docs/skills/scaffold/scripts/validate-structure.sh --root

# Validate marketplace manifest
validate-marketplace:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v jq &> /dev/null; then
        jq . .claude-plugin/marketplace.json > /dev/null
    else
        python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))"
    fi
    for src in $(python3 -c "
    import json
    with open('.claude-plugin/marketplace.json') as f:
        data = json.load(f)
    for p in data.get('plugins', []):
        print(p['source'])
    "); do
        if [ ! -d "$src" ]; then
            echo "ERROR: Plugin source directory not found: $src"
            exit 1
        fi
        echo "OK: $src"
    done

# Validate all plugin manifests
validate-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    for plugin_dir in plugins/*/; do
        [ -d "$plugin_dir" ] || continue
        manifest="${plugin_dir}.claude-plugin/plugin.json"
        if [ ! -f "$manifest" ]; then
            echo "ERROR: Missing $manifest"
            exit 1
        fi
        if command -v jq &> /dev/null; then
            jq . "$manifest" > /dev/null
        else
            python3 -c "import json; json.load(open('$manifest'))"
        fi
        echo "OK: $manifest"
    done

# Run all validation checks
validate: validate-root validate-marketplace validate-plugins

# ─── Hook Smoke Tests ────────────────────────────────────────────────────────

# Smoke-test ADR immutability hook
test-hook-adr:
    #!/usr/bin/env bash
    set -euo pipefail
    for adr in docs/decisions/*.md; do
        status=$(bash plugins/principled-docs/hooks/scripts/parse-frontmatter.sh --file "$adr" --field status)
        if [ "$status" = "accepted" ]; then
            result=0
            echo "{\"tool_input\":{\"file_path\":\"$adr\"}}" \
                | bash plugins/principled-docs/hooks/scripts/check-adr-immutability.sh > /dev/null 2>&1 || result=$?
            if [ "$result" -ne 2 ]; then
                echo "FAIL: expected exit 2 for accepted ADR $adr, got $result"; exit 1
            fi
            echo "PASS: $adr (accepted → blocked)"
        fi
    done
    result=0
    echo '{"tool_input":{"file_path":"CLAUDE.md"}}' \
        | bash plugins/principled-docs/hooks/scripts/check-adr-immutability.sh > /dev/null 2>&1 || result=$?
    if [ "$result" -ne 0 ]; then
        echo "FAIL: expected exit 0 for non-decision file, got $result"; exit 1
    fi
    echo "PASS: non-decision file (allowed)"

# Smoke-test proposal lifecycle hook
test-hook-proposal:
    #!/usr/bin/env bash
    set -euo pipefail
    for proposal in docs/proposals/*.md; do
        status=$(bash plugins/principled-docs/hooks/scripts/parse-frontmatter.sh --file "$proposal" --field status)
        if [ "$status" = "accepted" ] || [ "$status" = "rejected" ] || [ "$status" = "superseded" ]; then
            result=0
            echo "{\"tool_input\":{\"file_path\":\"$proposal\"}}" \
                | bash plugins/principled-docs/hooks/scripts/check-proposal-lifecycle.sh > /dev/null 2>&1 || result=$?
            if [ "$result" -ne 2 ]; then
                echo "FAIL: expected exit 2 for $status proposal $proposal, got $result"; exit 1
            fi
            echo "PASS: $proposal ($status → blocked)"
        fi
        if [ "$status" = "draft" ]; then
            result=0
            echo "{\"tool_input\":{\"file_path\":\"$proposal\"}}" \
                | bash plugins/principled-docs/hooks/scripts/check-proposal-lifecycle.sh > /dev/null 2>&1 || result=$?
            if [ "$result" -ne 0 ]; then
                echo "FAIL: expected exit 0 for draft proposal $proposal, got $result"; exit 1
            fi
            echo "PASS: $proposal (draft → allowed)"
        fi
    done

# Smoke-test manifest integrity hook
test-hook-manifest:
    #!/usr/bin/env bash
    set -euo pipefail
    result=0
    echo '{"tool_input":{"file_path":".impl/manifest.json"}}' \
        | bash plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] && echo "PASS: manifest.json (advisory)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }
    result=0
    echo '{"tool_input":{"file_path":"src/index.ts"}}' \
        | bash plugins/principled-implementation/hooks/scripts/check-manifest-integrity.sh > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] && echo "PASS: unrelated file (passthrough)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }

# Smoke-test PR reference hook
test-hook-pr:
    #!/usr/bin/env bash
    set -euo pipefail
    result=0
    echo '{"tool_input":{"command":"gh pr create --title test --body test"}}' \
        | bash plugins/principled-github/hooks/scripts/check-pr-references.sh > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] && echo "PASS: gh pr create (advisory)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }
    result=0
    echo '{"tool_input":{"command":"git status"}}' \
        | bash plugins/principled-github/hooks/scripts/check-pr-references.sh > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] && echo "PASS: unrelated command (passthrough)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }

# Smoke-test review checklist hook
test-hook-review:
    #!/usr/bin/env bash
    set -euo pipefail
    for cmd in "gh pr review 42" "gh pr merge 42"; do
        result=0
        echo "{\"tool_input\":{\"command\":\"$cmd\"}}" \
            | bash plugins/principled-quality/hooks/scripts/check-review-checklist.sh > /dev/null 2>&1 || result=$?
        [ "$result" -eq 0 ] && echo "PASS: $cmd (advisory)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }
    done
    result=0
    echo '{"tool_input":{"command":"git status"}}' \
        | bash plugins/principled-quality/hooks/scripts/check-review-checklist.sh > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] && echo "PASS: unrelated command (passthrough)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }

# Smoke-test release readiness hook
test-hook-release:
    #!/usr/bin/env bash
    set -euo pipefail
    result=0
    echo '{"tool_input":{"command":"git tag v1.0.0"}}' \
        | bash plugins/principled-release/hooks/scripts/check-release-readiness.sh > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] && echo "PASS: git tag (advisory)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }
    for cmd in "git tag -l" "git status"; do
        result=0
        echo "{\"tool_input\":{\"command\":\"$cmd\"}}" \
            | bash plugins/principled-release/hooks/scripts/check-release-readiness.sh > /dev/null 2>&1 || result=$?
        [ "$result" -eq 0 ] && echo "PASS: $cmd (passthrough)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }
    done

# Smoke-test boundary violation hook
test-hook-boundary:
    #!/usr/bin/env bash
    set -euo pipefail
    result=0
    echo '{"tool_input":{"file_path":"src/index.ts"}}' \
        | bash plugins/principled-architecture/hooks/scripts/check-boundary-violation.sh > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] && echo "PASS: source file (advisory)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }
    result=0
    echo '{"tool_input":{"file_path":"README.md"}}' \
        | bash plugins/principled-architecture/hooks/scripts/check-boundary-violation.sh > /dev/null 2>&1 || result=$?
    [ "$result" -eq 0 ] && echo "PASS: non-source file (passthrough)" || { echo "FAIL: expected exit 0, got $result"; exit 1; }

# Run all hook smoke tests
test-hooks: test-hook-adr test-hook-proposal test-hook-manifest test-hook-pr test-hook-review test-hook-release test-hook-boundary

# ─── Aggregate ───────────────────────────────────────────────────────────────

# Run the full CI pipeline locally
ci: lint drift validate test-hooks
    @echo ""
    @echo "All CI checks passed."
