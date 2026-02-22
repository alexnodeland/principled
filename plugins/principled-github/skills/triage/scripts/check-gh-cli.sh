#!/usr/bin/env bash
# check-gh-cli.sh — Verify that the GitHub CLI (gh) is installed and authenticated.
#
# Usage: check-gh-cli.sh
#
# Checks:
#   1. gh is on PATH
#   2. gh auth status succeeds (user is logged in)
#
# Exit codes:
#   0 — gh is available and authenticated
#   1 — gh is missing or not authenticated

set -euo pipefail

# Check if gh is installed
if ! command -v gh &> /dev/null; then
  echo "Error: gh CLI is not installed." >&2
  echo "Install it from https://cli.github.com/" >&2
  exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
  echo "Error: gh CLI is not authenticated." >&2
  echo "Run 'gh auth login' to authenticate." >&2
  exit 1
fi

echo "OK: gh CLI is available and authenticated."
exit 0
