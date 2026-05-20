#!/usr/bin/env bash
# Build GrammarCat, assemble the .app bundle, and ad-hoc codesign it.
# Usage: bash scripts/build-app.sh [--install]
#   --install  also copy the bundle to /Applications
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="GrammarCat"
BUILD_CONFIG="release"
APP_DIR="$ROOT/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

echo "==> swift build ($BUILD_CONFIG)"
swift build -c "$BUILD_CONFIG"

BIN="$ROOT/.build/$BUILD_CONFIG/$APP_NAME"
if [[ ! -f "$BIN" ]]; then
    echo "error: built binary not found at $BIN" >&2
    exit 1
fi

echo "==> assembling $APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Info.plist"

echo "==> codesign (ad-hoc)"
codesign --force --sign - "$APP_DIR"
codesign --verify --verbose "$APP_DIR"

if [[ "${1:-}" == "--install" ]]; then
    echo "==> installing to /Applications"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_DIR" "/Applications/$APP_NAME.app"
    echo "installed: /Applications/$APP_NAME.app"
fi

echo "==> done: $APP_DIR"
