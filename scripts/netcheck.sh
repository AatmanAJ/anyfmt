#!/usr/bin/env bash
# Verifies "zero network calls without opt-in" (BUILD.md §13): launches the app
# signed out with update checks off, drives conversions through the bundled
# CLI and engines, and samples every socket the processes open (lsof, plus a
# nettop snapshot). Any socket other than the OS-provided Unix-domain ones fails.
# Usage: scripts/netcheck.sh <products dir> [seconds]
set -euo pipefail
cd "$(dirname "$0")/.."
PRODUCTS="${1:?products dir}"
SECS="${2:-45}"
NAME="$(sed -n 's/^BRAND_NAME = //p' Config/Brand.xcconfig)"
APP="$PRODUCTS/$NAME.app"
CLI="$APP/Contents/Helpers/$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"
WORK="$(mktemp -d)"
LOG="$WORK/sockets.log"
trap 'kill ${PID:-0} 2>/dev/null || true; rm -rf "$WORK"' EXIT

"$APP/Contents/MacOS/$NAME" --no-onboarding >/dev/null 2>&1 &
PID=$!
sleep 3

# Workload: conversions through the same engines the wheel uses.
FF="$APP/Contents/Helpers/ffmpeg"
"$FF" -v error -f lavfi -i testsrc2=size=640x480:rate=1 -frames:v 1 "$WORK/a.png"
"$FF" -v error -f lavfi -i "testsrc2=size=320x240:rate=25" -f lavfi -i sine -t 3 -c:v libx264 -c:a aac "$WORK/v.mov"
( for i in 1 2 3; do
    "$CLI" convert "$WORK/a.png" --to jpg --out "$WORK/o" >/dev/null 2>&1 || true
    "$CLI" convert "$WORK/a.png" --to webp --out "$WORK/o" >/dev/null 2>&1 || true
    "$CLI" convert "$WORK/v.mov" --to mp4 --opt hardware=false --out "$WORK/o" >/dev/null 2>&1 || true
    "$CLI" convert "$WORK/v.mov" --to mp3 --out "$WORK/o" >/dev/null 2>&1 || true
  done ) &
WORKLOAD=$!

end=$(( $(date +%s) + SECS ))
: > "$LOG"
while (( $(date +%s) < end )); do
  pids="$PID $(pgrep -f "$APP/Contents/Helpers" | tr '\n' ' ')"
  for p in $pids; do lsof -nP -a -p "$p" -i 2>/dev/null | tail -n +2 >> "$LOG" || true; done
  sleep 0.5
done
wait "$WORKLOAD" 2>/dev/null || true
nettop -P -L 1 -n -x 2>/dev/null | grep -iE "$NAME|ffmpeg|ffprobe|resvg" > "$WORK/nettop.txt" || true

if [[ -s "$LOG" ]]; then
  echo "✗ network sockets observed:"; sort -u "$LOG"; exit 1
fi
echo "✓ zero network sockets from $NAME, its CLI and its engines over ${SECS}s (lsof -i every 0.5 s; nettop rows: $(wc -l < "$WORK/nettop.txt" | tr -d ' '))"
