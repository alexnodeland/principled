#!/usr/bin/env bash
# validate-tag.sh — Validate a git tag format and check for duplicates.
#
# Usage: validate-tag.sh <version>
#
# Checks:
#   1. Version matches semver format (vX.Y.Z or X.Y.Z)
#   2. Tag does not already exist
#
# Exit codes:
#   0 — tag is valid and does not exist
#   1 — error (invalid format or tag already exists)

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Error: version argument is required" >&2
  echo "Usage: validate-tag.sh <version>" >&2
  exit 1
fi

VERSION="$1"

# Normalize: add 'v' prefix if not present
TAG_NAME="$VERSION"
if [[ "$VERSION" =~ ^[0-9] ]]; then
  TAG_NAME="v${VERSION}"
fi

# Validate semver format (vX.Y.Z)
if ! [[ "$TAG_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid version format: $VERSION" >&2
  echo "Expected semver format: X.Y.Z or vX.Y.Z" >&2
  exit 1
fi

# Check if tag already exists
if git rev-parse "$TAG_NAME" > /dev/null 2>&1; then
  echo "Error: tag '$TAG_NAME' already exists" >&2
  echo "Use a different version or delete the existing tag first." >&2
  exit 1
fi

echo "OK: $TAG_NAME is a valid tag and does not exist yet."
exit 0
