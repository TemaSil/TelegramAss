#!/usr/bin/env bash
# Builds the web preview and captures the README screenshots.
#
# Android supplies Roboto itself, so it is not bundled in the shipped app.
# CanvasKit has no such fallback and fetches it from a CDN, which fails
# offline — so this script injects it into pubspec.yaml for the duration of the
# preview build and takes it out again afterwards. An emoji font is
# deliberately NOT injected: CanvasKit promotes it over Roboto and then renders
# no Latin text at all, so a few emoji show as boxes in the screenshots.
set -euo pipefail

cd "$(dirname "$0")/.."
PORT=8791

cleanup() {
  [ -f pubspec.yaml.preview-bak ] && mv pubspec.yaml.preview-bak pubspec.yaml
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

cp pubspec.yaml pubspec.yaml.preview-bak
python3 tool/preview_fonts.py

flutter pub get
flutter build web --release --dart-define=DEMO_AUTOLOGIN=true

# Point CanvasKit at the copy Flutter already bundled instead of the CDN.
python3 tool/preview_canvaskit.py

(cd build/web && python3 -m http.server "$PORT" >/dev/null 2>&1) &
SERVER_PID=$!
sleep 2

node shots.js
echo "Screenshots written to docs/screenshots/"
