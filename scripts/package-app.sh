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

# Bind Info.plist into the ad-hoc signature so TCC/Accessibility can track the app.
codesign --force --deep --sign - "$APP" >/dev/null

echo "Built $APP"

# Zip for GitHub Releases / in-app update (Check for Updates expects a .zip asset).
DIST_ZIP="$ROOT/dist/iRecorder.app.zip"
rm -f "$DIST_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST_ZIP"
echo "Zipped $DIST_ZIP"

INSTALL_APP="/Applications/iRecorder.app"
if [[ "${IRECORDER_SKIP_INSTALL:-}" == "1" ]]; then
  echo "Skipped install (IRECORDER_SKIP_INSTALL=1)."
else
  # Replace running /Applications copy so you don't keep testing a stale binary.
  pkill -x iRecorder 2>/dev/null || true
  sleep 0.3
  rm -rf "$INSTALL_APP"
  cp -R "$APP" "$INSTALL_APP"
  codesign --force --deep --sign - "$INSTALL_APP" >/dev/null
  echo "Installed $INSTALL_APP"
  echo "Open it, then confirm Accessibility is checked for iRecorder (rebuild invalidates prior grant)."
  open "$INSTALL_APP"
fi
