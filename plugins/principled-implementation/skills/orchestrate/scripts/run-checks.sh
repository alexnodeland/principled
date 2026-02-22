#!/usr/bin/env bash
# run-checks.sh — Discover and execute project checks (tests, lints, builds).
#
# Usage:
#   run-checks.sh --discover [--cwd <path>]    # Find available check commands
#   run-checks.sh --execute [--cwd <path>]     # Run discovered checks
#
# Output (--discover):
#   <check-name>|<command>|<source>
#
# Output (--execute):
#   [PASS]/[FAIL] per check with summary
#
# Exit codes:
#   0 — all checks passed (or discovery mode)
#   1 — one or more checks failed

set -euo pipefail

MODE=""
CWD="."
CHECK_TIMEOUT=300

while [[ $# -gt 0 ]]; do
  case "$1" in
  --discover)
    MODE="discover"
    shift
    ;;
  --execute)
    MODE="execute"
    shift
    ;;
  --cwd)
    CWD="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Error: --discover or --execute is required" >&2
  exit 1
fi

if [[ ! -d "$CWD" ]]; then
  echo "Error: directory not found: $CWD" >&2
  exit 1
fi

# --- Discover checks ---
declare -a CHECK_NAMES=()
declare -a CHECK_COMMANDS=()
declare -a CHECK_SOURCES=()

discover_checks() {
  local dir="$1"

  # Node.js: package.json scripts
  if [[ -f "$dir/package.json" ]]; then
    if command -v jq &> /dev/null; then
      local scripts
      scripts="$(jq -r '.scripts // {} | keys[]' "$dir/package.json" 2> /dev/null || echo "")"
      for script in $scripts; do
        case "$script" in
        test)
          CHECK_NAMES+=("test")
          CHECK_COMMANDS+=("npm test")
          CHECK_SOURCES+=("package.json")
          ;;
        lint)
          CHECK_NAMES+=("lint")
          CHECK_COMMANDS+=("npm run lint")
          CHECK_SOURCES+=("package.json")
          ;;
        typecheck | type-check)
          CHECK_NAMES+=("typecheck")
          CHECK_COMMANDS+=("npm run $script")
          CHECK_SOURCES+=("package.json")
          ;;
        build)
          CHECK_NAMES+=("build")
          CHECK_COMMANDS+=("npm run build")
          CHECK_SOURCES+=("package.json")
          ;;
        esac
      done
    else
      # Fallback: grep for common scripts
      if grep -q '"test"' "$dir/package.json" 2> /dev/null; then
        CHECK_NAMES+=("test")
        CHECK_COMMANDS+=("npm test")
        CHECK_SOURCES+=("package.json")
      fi
      if grep -q '"lint"' "$dir/package.json" 2> /dev/null; then
        CHECK_NAMES+=("lint")
        CHECK_COMMANDS+=("npm run lint")
        CHECK_SOURCES+=("package.json")
      fi
      if grep -q '"build"' "$dir/package.json" 2> /dev/null; then
        CHECK_NAMES+=("build")
        CHECK_COMMANDS+=("npm run build")
        CHECK_SOURCES+=("package.json")
      fi
    fi
  fi

  # Makefile targets
  if [[ -f "$dir/Makefile" || -f "$dir/makefile" ]]; then
    local makefile="${dir}/Makefile"
    if [[ ! -f "$makefile" ]]; then
      makefile="${dir}/makefile"
    fi
    if grep -qE '^test:' "$makefile" 2> /dev/null; then
      CHECK_NAMES+=("test")
      CHECK_COMMANDS+=("make test")
      CHECK_SOURCES+=("Makefile")
    fi
    if grep -qE '^lint:' "$makefile" 2> /dev/null; then
      CHECK_NAMES+=("lint")
      CHECK_COMMANDS+=("make lint")
      CHECK_SOURCES+=("Makefile")
    fi
    if grep -qE '^check:' "$makefile" 2> /dev/null; then
      CHECK_NAMES+=("check")
      CHECK_COMMANDS+=("make check")
      CHECK_SOURCES+=("Makefile")
    fi
  fi

  # Python: pytest
  if [[ -f "$dir/pytest.ini" || -f "$dir/pyproject.toml" || -f "$dir/setup.cfg" ]]; then
    if [[ -f "$dir/pyproject.toml" ]] && grep -q '\[tool.pytest' "$dir/pyproject.toml" 2> /dev/null; then
      CHECK_NAMES+=("test")
      CHECK_COMMANDS+=("pytest")
      CHECK_SOURCES+=("pyproject.toml")
    elif [[ -f "$dir/pytest.ini" ]]; then
      CHECK_NAMES+=("test")
      CHECK_COMMANDS+=("pytest")
      CHECK_SOURCES+=("pytest.ini")
    fi
  fi

  # Rust: Cargo
  if [[ -f "$dir/Cargo.toml" ]]; then
    CHECK_NAMES+=("test")
    CHECK_COMMANDS+=("cargo test")
    CHECK_SOURCES+=("Cargo.toml")
    CHECK_NAMES+=("clippy")
    CHECK_COMMANDS+=("cargo clippy -- -D warnings")
    CHECK_SOURCES+=("Cargo.toml")
  fi

  # Go
  if [[ -f "$dir/go.mod" ]]; then
    CHECK_NAMES+=("test")
    CHECK_COMMANDS+=("go test ./...")
    CHECK_SOURCES+=("go.mod")
    CHECK_NAMES+=("vet")
    CHECK_COMMANDS+=("go vet ./...")
    CHECK_SOURCES+=("go.mod")
  fi

  # Pre-commit
  if [[ -f "$dir/.pre-commit-config.yaml" ]]; then
    CHECK_NAMES+=("pre-commit")
    CHECK_COMMANDS+=("pre-commit run --all-files")
    CHECK_SOURCES+=(".pre-commit-config.yaml")
  fi
}

discover_checks "$CWD"

# --- Mode: discover ---
if [[ "$MODE" == "discover" ]]; then
  if [[ ${#CHECK_NAMES[@]} -eq 0 ]]; then
    echo "No checks discovered in $CWD"
    exit 0
  fi
  for i in "${!CHECK_NAMES[@]}"; do
    echo "${CHECK_NAMES[$i]}|${CHECK_COMMANDS[$i]}|${CHECK_SOURCES[$i]}"
  done
  exit 0
fi

# --- Mode: execute ---
if [[ ${#CHECK_NAMES[@]} -eq 0 ]]; then
  echo "No checks discovered in $CWD. Nothing to run."
  exit 0
fi

TOTAL=${#CHECK_NAMES[@]}
PASSED=0
FAILED=0

for i in "${!CHECK_NAMES[@]}"; do
  name="${CHECK_NAMES[$i]}"
  cmd="${CHECK_COMMANDS[$i]}"
  _source="${CHECK_SOURCES[$i]}" # Used for diagnostics if needed

  START_TIME="$(date +%s)"

  # Run the check in the target directory with timeout
  set +e
  OUTPUT="$(cd "$CWD" && timeout "$CHECK_TIMEOUT" bash -c "$cmd" 2>&1)"
  EXIT_CODE=$?
  set -e

  END_TIME="$(date +%s)"
  DURATION=$((END_TIME - START_TIME))

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "[PASS] $name ($cmd) — ${DURATION}s"
    PASSED=$((PASSED + 1))
  else
    echo "[FAIL] $name ($cmd) — exit $EXIT_CODE"
    # Show first 20 lines of output for failed checks
    echo "$OUTPUT" | head -20 | sed 's/^/  /'
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "Summary: ${PASSED}/${TOTAL} checks passed."

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi

exit 0
