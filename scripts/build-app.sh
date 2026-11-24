#!/bin/bash
# Usage: scripts/build-app.sh [version]
# Builds "dist/Hogs.app" and dist/hogs-<version>.zip. Signs with $SIGN_IDENTITY
# (a certificate name or SHA-1 hash), or ad hoc when it's unset.
set -euo pipefail

VERSION="${1:-0.0.0-dev}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Hogs.app"

cd "$ROOT"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Hogs"

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Hogs"
sed "s/@VERSION@/$VERSION/g" packaging/Info.plist > "$APP/Contents/Info.plist"

ICONSET="$DIST/AppIcon.iconset"
swift scripts/make-icon.swift packaging/icon.svg "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

codesign --force --options runtime --timestamp=none \
  ${SIGN_KEYCHAIN:+--keychain "$SIGN_KEYCHAIN"} \
  --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"

ditto -c -k --keepParent "$APP" "$DIST/hogs-$VERSION.zip"
echo "$DIST/hogs-$VERSION.zip"
