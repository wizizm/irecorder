#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --product iRecorder
BIN="$ROOT/.build/release/iRecorder"
APP="$ROOT/dist/iRecorder.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/iRecorder"
cp "$ROOT/Sources/iRecorder/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/iRecorder"
echo "Built $APP"
echo "Drag to /Applications, then open once and grant Accessibility."
