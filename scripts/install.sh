#!/bin/bash
# Builds the app as <last release>-dev, or as the release itself from a clean checkout of its tag,
# replaces /Applications/Hogs.app and opens it.
# Set SIGN_IDENTITY to your long-lived local certificate so permissions survive reinstalls.
set -euo pipefail
cd "$(dirname "$0")/.."

source scripts/version.sh
version="$(read_version)"
if [[ -n $(git status --porcelain) ]] || ! git tag --points-at HEAD | grep -qx "v$version"; then
  version="$version-dev"
fi

scripts/build-app.sh "$version" >/dev/null
osascript -e 'tell application id "com.iamdanielmarino.hogs" to quit' 2>/dev/null || true
rm -rf "/Applications/Hogs.app"
ditto "dist/Hogs.app" "/Applications/Hogs.app"
open "/Applications/Hogs.app"
echo "Installed Hogs $version ($(git rev-list --count HEAD))"
