# Check Discovery

The `run-checks.sh` script discovers available test, lint, and build commands by examining project configuration files.

## Discovery Sources

Checks are discovered in the following order. If multiple sources define the same check type (e.g., both `package.json` and `Makefile` define a `test` command), all are included.

### Node.js (`package.json`)

| Script              | Check Name | Command             |
| ------------------- | ---------- | ------------------- |
| `scripts.test`      | test       | `npm test`          |
| `scripts.lint`      | lint       | `npm run lint`      |
| `scripts.typecheck` | typecheck  | `npm run typecheck` |
| `scripts.build`     | build      | `npm run build`     |

### Makefile (`Makefile` or `makefile`)

| Target   | Check Name | Command      |
| -------- | ---------- | ------------ |
| `test:`  | test       | `make test`  |
| `lint:`  | lint       | `make lint`  |
| `check:` | check      | `make check` |

### Python (`pytest.ini`, `pyproject.toml`, `setup.cfg`)

| Config                              | Check Name | Command  |
| ----------------------------------- | ---------- | -------- |
| `[tool.pytest]` in `pyproject.toml` | test       | `pytest` |
| `pytest.ini` exists                 | test       | `pytest` |

### Rust (`Cargo.toml`)

| Config              | Check Name | Command                       |
| ------------------- | ---------- | ----------------------------- |
| `Cargo.toml` exists | test       | `cargo test`                  |
| `Cargo.toml` exists | clippy     | `cargo clippy -- -D warnings` |

### Go (`go.mod`)

| Config          | Check Name | Command         |
| --------------- | ---------- | --------------- |
| `go.mod` exists | test       | `go test ./...` |
| `go.mod` exists | vet        | `go vet ./...`  |

### Pre-commit (`.pre-commit-config.yaml`)

| Config        | Check Name | Command                      |
| ------------- | ---------- | ---------------------------- |
| Config exists | pre-commit | `pre-commit run --all-files` |

## Execution

Each discovered check runs with:

- **Working directory**: the target directory (worktree or repo root)
- **Timeout**: 300 seconds (5 minutes) per check
- **Output capture**: both stdout and stderr
- **Exit code**: 0 = pass, non-zero = fail

## Extending Discovery

To add support for additional project types, add new detection blocks to `run-checks.sh` following the existing pattern:

1. Check for the presence of a config file
2. Extract relevant commands or targets
3. Append to the `CHECK_NAMES`, `CHECK_COMMANDS`, and `CHECK_SOURCES` arrays
