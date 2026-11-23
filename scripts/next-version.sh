#!/bin/bash
# Prints the next semver (without "v") from conventional commits since the last
# v* tag, or nothing when no commit warrants a release.
#   feat!: / BREAKING CHANGE -> major, feat: -> minor, fix|perf|refactor|revert: -> patch
set -euo pipefail

LAST_TAG="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)"
RANGE="${LAST_TAG:+$LAST_TAG..}HEAD"
IFS=. read -r MAJOR MINOR PATCH <<<"${LAST_TAG#v}"
MAJOR="${MAJOR:-0}" MINOR="${MINOR:-0}" PATCH="${PATCH:-0}"

SUBJECTS="$(git log --format=%s "$RANGE")"
BODIES="$(git log --format=%b "$RANGE")"

if grep -qE '^[a-z]+(\([^)]*\))?!:' <<<"$SUBJECTS" || grep -qE '^BREAKING[ -]CHANGE:' <<<"$BODIES"; then
  echo "$((MAJOR + 1)).0.0"
elif grep -qE '^feat(\([^)]*\))?:' <<<"$SUBJECTS"; then
  echo "$MAJOR.$((MINOR + 1)).0"
elif grep -qE '^(fix|perf|refactor|revert)(\([^)]*\))?:' <<<"$SUBJECTS"; then
  echo "$MAJOR.$MINOR.$((PATCH + 1))"
fi
