#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --product iRecorder
BIN="$ROOT/.build/release/iRecorder"
APP="$ROOT/dist/iRecorder.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/iRecorder"
cp "$ROOT/Sources/iRecorder/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/MenuBarIcon.png" "$APP/Contents/Resources/MenuBarIcon.png"
chmod +x "$APP/Contents/MacOS/iRecorder"
echo "Built $APP"
echo "Drag to /Applications, then open once and grant Accessibility."
