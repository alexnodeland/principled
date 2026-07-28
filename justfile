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

# Check cross-plugin script drift (check-gh-cli.sh)
drift-cross:
    bash scripts/check-cross-plugin-drift.sh

# Check template drift for principled-docs
drift-docs:
    bash plugins/principled-docs/skills/scaffold/scripts/check-template-drift.sh

# Check all template drift
drift: drift-docs drift-cross

# ─── Validate ────────────────────────────────────────────────────────────────

# Validate root documentation structure
validate-root:
    bash plugins/principled-docs/lib/validate-structure.sh --root

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

# ─── Aggregate ───────────────────────────────────────────────────────────────

# Verify every script referenced by a skill or hook actually exists
refs:
    bash scripts/check-skill-references.sh

# Reconcile declared pipeline state (statuses, numbering, links) against reality
audit:
    bash scripts/pipeline-audit.sh

# Run the bats test suite
test:
    npx bats tests/

# Run the full CI pipeline locally
ci: lint drift refs audit validate test
    @echo ""
    @echo "All CI checks passed."
