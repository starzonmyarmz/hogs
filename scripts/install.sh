#!/bin/bash
# Builds the app as <last release>-dev+<sha>, replaces /Applications/Hogs.app and opens it.
# Set SIGN_IDENTITY to your long-lived local certificate so permissions survive reinstalls.
set -euo pipefail
cd "$(dirname "$0")/.."

source scripts/version.sh
build=$(git rev-parse --short HEAD)
if [[ -n $(git status --porcelain) ]]; then
  build="$build.dirty"
fi
version="$(read_version)-dev+$build"

scripts/build-app.sh "$version" >/dev/null
osascript -e 'tell application id "com.iamdanielmarino.hogs" to quit' 2>/dev/null || true
rm -rf "/Applications/Hogs.app"
ditto "dist/Hogs.app" "/Applications/Hogs.app"
open "/Applications/Hogs.app"
echo "Installed Hogs $version"
