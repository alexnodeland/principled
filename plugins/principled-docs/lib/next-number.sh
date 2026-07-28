#!/usr/bin/env bash
# next-number.sh — Determine the next NNN sequence number for a directory.
#
# Usage: next-number.sh --dir <path>
#
# Scans the target directory for files matching the NNN-*.md pattern,
# finds the highest number, and returns the next number zero-padded to
# 3 digits. Returns "001" for empty directories.

set -euo pipefail

DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dir)
    DIR="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -z "$DIR" ]]; then
  echo "Error: --dir is required" >&2
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  echo "001"
  exit 0
fi

MAX=0

for file in "$DIR"/[0-9][0-9][0-9]-*.md; do
  # If glob doesn't match, the literal pattern is returned
  [[ -e "$file" ]] || continue

  basename_file="$(basename "$file")"
  # Extract the leading 3-digit number
  num="${basename_file%%-*}"
  # Strip leading zeros for arithmetic
  num_int=$((10#$num))

  if ((num_int > MAX)); then
    MAX=$num_int
  fi
done

NEXT=$((MAX + 1))
printf "%03d\n" "$NEXT"
