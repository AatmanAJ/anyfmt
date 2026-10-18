#!/usr/bin/env bash
# Measures BUILD.md §10 budgets on this machine and prints Markdown rows for
# docs/PERF.md. Usage: scripts/perf.sh <products dir (Release)>
#   - app launch → ready (app reports it with --perf-report)
#   - idle CPU and memory over 60 s (phys_footprint via `footprint`)
#   - 12 MP HEIC → JPG (CLI, minus CLI start-up overhead)
#   - 1 minute 1080p MOV → MP4: hardware vs software encode
set -euo pipefail
cd "$(dirname "$0")/.."
PRODUCTS="${1:?products dir}"
NAME="$(sed -n 's/^BRAND_NAME = //p' Config/Brand.xcconfig)"
APP="$PRODUCTS/$NAME.app"
CLI="$APP/Contents/Helpers/$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"
FF="$APP/Contents/Helpers/ffmpeg"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; [[ -n "${PID:-}" ]] && kill "$PID" 2>/dev/null || true' EXIT

row() { printf '| %s | %s | %s |\n' "$1" "$2" "$3"; }
echo "| Measure | Result | Budget |"
echo "|---|---|---|"

# Launch → ready (median of 5 cold-ish launches)
launches=()
for i in 1 2 3 4 5; do
  rm -f "$WORK/perf.json"
  "$APP/Contents/MacOS/$NAME" --perf-report "$WORK/perf.json" --no-onboarding --quit-after-ready >/dev/null 2>&1 || true
  [[ -f "$WORK/perf.json" ]] && launches+=("$(python3 -c "import json;print(json.load(open('$WORK/perf.json'))['launchToReadyMs'])")")
done
if (( ${#launches[@]} )); then
  median="$(printf '%s\n' "${launches[@]}" | sort -n | sed -n "$(( (${#launches[@]} + 1) / 2 ))p")"
  row "App launch → ready (median of ${#launches[@]})" "${median} ms" "< 300 ms"
fi

# Idle CPU + memory
"$APP/Contents/MacOS/$NAME" --no-onboarding >/dev/null 2>&1 &
PID=$!
sleep 8
cpu0="$(ps -o cputime= -p "$PID" | awk -F'[:.]' '{print ($1*60+$2)+$3/100}')"
sleep 60
cpu1="$(ps -o cputime= -p "$PID" | awk -F'[:.]' '{print ($1*60+$2)+$3/100}')"
idle="$(python3 -c "print(f'{($cpu1-$cpu0)/60*100:.2f}')")"
fp="$(footprint -p "$PID" 2>/dev/null | awk '/phys_footprint:/{print $2, $3; exit}')"
[[ -z "$fp" ]] && fp="$(footprint "$PID" 2>/dev/null | awk '/Footprint:/{print $2, $3; exit}')"
rss="$(ps -o rss= -p "$PID" | awk '{printf "%.1f MB", $1/1024}')"
row "Idle CPU (60 s, after launch)" "${idle} % of one core" "~0 %"
row "Idle memory (phys_footprint / RSS)" "${fp:-n/a} / ${rss}" "< 40 MB"
kill "$PID" 2>/dev/null || true; PID=""

# 12 MP HEIC → JPG
"$FF" -v error -f lavfi -i "testsrc2=size=4032x3024:rate=1" -frames:v 1 "$WORK/12mp.png"
sips -s format heic "$WORK/12mp.png" --out "$WORK/12mp.heic" >/dev/null
t0=$(python3 -c 'import time;print(time.time())')
"$CLI" version >/dev/null
t1=$(python3 -c 'import time;print(time.time())')
"$CLI" convert "$WORK/12mp.heic" --to jpg --out "$WORK/out" >/dev/null
t2=$(python3 -c 'import time;print(time.time())')
heic="$(python3 -c "print(int((($t2-$t1)-($t1-$t0))*1000))")"
row "12 MP HEIC → JPG (engine time, CLI start-up subtracted)" "${heic} ms" "< 400 ms"

# 1 minute 1080p MOV → MP4
"$FF" -v error -f lavfi -i "testsrc2=size=1920x1080:rate=30" -f lavfi -i "sine=frequency=440:sample_rate=48000" \
  -t 60 -c:v libx264 -preset veryfast -crf 20 -c:a aac -b:a 160k "$WORK/1min.mov"
for hw in true false; do
  rm -rf "$WORK/out"
  s=$(python3 -c 'import time;print(time.time())')
  "$CLI" convert "$WORK/1min.mov" --to mp4 --opt hardware=$hw --opt videoQuality=high --opt resolution=1080 --out "$WORK/out" >/dev/null
  e=$(python3 -c 'import time;print(time.time())')
  row "1 min 1080p MOV → MP4, re-encode, hardware=$hw" "$(python3 -c "print(f'{$e-$s:.2f} s')")" "report; HW where faster"
done
rm -rf "$WORK/out"
s=$(python3 -c 'import time;print(time.time())')
"$CLI" convert "$WORK/1min.mov" --to mp4 --out "$WORK/out" >/dev/null
e=$(python3 -c 'import time;print(time.time())')
row "1 min 1080p MOV → MP4, default (stream copy when legal)" "$(python3 -c "print(f'{$e-$s:.2f} s')")" "report"
