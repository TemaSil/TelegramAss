#!/usr/bin/env bash
# Builds the web preview and captures the README screenshots.
#
# The app bundles Inter, so CanvasKit has a font without reaching for the CDN
# it would otherwise fetch one from — which is what used to fail offline. No
# emoji font is bundled: CanvasKit promotes it over the text face and then
# renders no Latin at all, so a few emoji show as boxes in the screenshots.
set -euo pipefail

cd "$(dirname "$0")/.."
PORT=8791

cleanup() {
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

flutter pub get
flutter build web --release --dart-define=DEMO_AUTOLOGIN=true

# Point CanvasKit at the copy Flutter already bundled instead of the CDN.
python3 tool/preview_canvaskit.py

(cd build/web && python3 -m http.server "$PORT" >/dev/null 2>&1) &
SERVER_PID=$!
sleep 2

node shots.js
echo "Screenshots written to docs/screenshots/"
