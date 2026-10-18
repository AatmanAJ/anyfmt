#!/usr/bin/env bash
# Lane E fixtures: audio, video and subtitles. Contract: Tests/Fixtures/make-fixtures.sh.
# Every file is generated from scratch with the bundled ffmpeg (no lavfi device needed:
# source filters run inside -filter_complex). Runs in a few seconds.
set -euo pipefail
: "${OUT:?OUT must be set}" "${FFMPEG:?FFMPEG must be set}"
mkdir -p "$OUT"

TONE="aevalsrc=0.4*sin(2*PI*440*t)|0.4*sin(2*PI*660*t):s=44100:d=2"
PICT="testsrc2=size=320x240:rate=30:duration=2"
ff() { "$FFMPEG" -hide_banner -nostdin -loglevel error -y "$@"; }
tone() { ff -filter_complex "$TONE[a]" -map "[a]" "$@"; }
movie() { ff -filter_complex "$PICT[v];$TONE[a]" -map "[v]" -map "[a]" "$@"; }

# ---------------------------------------------------------------- audio (2 s stereo tone)
tone -c:a libmp3lame -b:a 128k -id3v2_version 3 -metadata title="Halo Tone" -metadata artist="Halo" "$OUT/sample.mp3"
tone -c:a aac_at -b:a 128k -metadata title="Halo Tone" "$OUT/sample.m4a"
tone -c:a pcm_s16le "$OUT/sample.wav"
tone -c:a flac "$OUT/sample.flac"
tone -c:a libvorbis -q:a 4 "$OUT/sample.ogg"
tone -c:a libopus -b:a 96k -ar 48000 "$OUT/sample.opus"
tone -c:a pcm_s16be "$OUT/sample.aiff"
tone -c:a pcm_s16le -f caf "$OUT/sample.caf"
tone -c:a wmav2 -b:a 128k -f asf "$OUT/sample.wma"

# Audio edge cases
ff -filter_complex "testsrc2=size=96x96:rate=1:duration=1[v]" -map "[v]" -frames:v 1 -c:v png "$OUT/edge-cover.png"
ff -i "$OUT/edge-cover.png" -filter_complex "$TONE[a]" -map "[a]" -map 0:v -c:a libmp3lame -b:a 128k -c:v copy -disposition:v:0 attached_pic \
     -id3v2_version 3 -metadata title="Covered" -metadata artist="Halo" "$OUT/edge-cover.mp3"
ff -filter_complex "aevalsrc=0.3*sin(2*PI*1000*t)|0.3*sin(2*PI*1500*t):s=96000:d=2[a]" -map "[a]" \
   -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 "$OUT/edge-24bit.flac"
ff -filter_complex "aevalsrc=0.2*sin(2*PI*220*t)|0.2*sin(2*PI*330*t)|0.2*sin(2*PI*440*t)|0.1*sin(2*PI*60*t)|0.2*sin(2*PI*550*t)|0.2*sin(2*PI*660*t):s=48000:d=1:c=5.1[a]" \
   -map "[a]" -c:a pcm_s16le "$OUT/edge-surround.wav"
# ffmpeg's CAF muxer can't write AAC; the system afconvert can.
if command -v afconvert >/dev/null; then afconvert -f caff -d aac "$OUT/sample.caf" "$OUT/edge-aac.caf"; fi
ff -filter_complex "aevalsrc=0.4*sin(2*PI*440*t):s=44100:d=2[a]" -map "[a]" -c:a pcm_s16le "$OUT/edge-mono.wav"

# ---------------------------------------------------------------- video (2 s 320×240 + tone)
movie -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac_at -b:a 128k -movflags +faststart "$OUT/sample.mp4"
movie -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac_at -b:a 128k "$OUT/sample.mov"
movie -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac_at -b:a 128k -f mp4 "$OUT/sample.m4v"
movie -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a libopus -b:a 96k -ar 48000 "$OUT/sample.mkv"
movie -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -b:v 400k -pix_fmt yuv420p -c:a libopus -b:a 96k -ar 48000 "$OUT/sample.webm"
movie -c:v mpeg4 -q:v 5 -tag:v XVID -c:a libmp3lame -b:a 128k "$OUT/sample.avi"
movie -c:v wmv2 -q:v 5 -c:a wmav2 -b:a 128k "$OUT/sample.wmv"

# Video edge cases
ff -display_rotation 90 -i "$OUT/sample.mp4" -c copy "$OUT/edge-rotated.mp4"
ff -filter_complex "testsrc2=size=321x241:rate=30:duration=2[v]" -map "[v]" -c:v ffv1 "$OUT/edge-odd.mkv"
ff -filter_complex "$PICT[v]" -map "[v]" -c:v libx264 -preset veryfast -pix_fmt yuv420p "$OUT/edge-noaudio.mp4"
ff -filter_complex "$PICT,select='not(between(mod(n\,30)\,10\,19))'[v];$TONE[a]" -map "[v]" -map "[a]" \
   -fps_mode vfr -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac_at "$OUT/edge-vfr.mp4"
# Camera-style QuickTime user data (©xyz ©mak ©mod ©nam). iPhone-style `mdta` keys need
# AVFoundation to write correctly; the unit tests build that file themselves.
ff -i "$OUT/sample.mov" -c copy -metadata location="+37.3349-122.0090/" \
   -metadata make="Apple" -metadata model="iPhone 15 Pro" -metadata title="Private trip" \
   -metadata creation_time="2024-05-01T10:00:00Z" "$OUT/edge-location.mov"
ff -i "$OUT/sample.mp4" -c copy -metadata location="+37.3349-122.0090/" -metadata title="Private trip" \
   -metadata creation_time="2024-05-01T10:00:00Z" "$OUT/edge-location.mp4"
movie -c:v libx265 -preset ultrafast -x265-params log-level=error -tag:v hvc1 -pix_fmt yuv420p -c:a aac_at -b:a 128k "$OUT/edge-hevc.mov"

# ---------------------------------------------------------------- subtitles
cat > "$OUT/sample.srt" <<'EOF'
1
00:00:00,500 --> 00:00:01,500
Hello, <i>world</i>!

2
00:00:01,600 --> 00:00:02,000
Second cue
on two lines
EOF

cat > "$OUT/sample.vtt" <<'EOF'
WEBVTT

00:00:00.500 --> 00:00:01.500
Hello, <i>world</i>!

intro
00:00:01.600 --> 00:00:02.000 line:0 align:start
Second &amp; last
EOF

# Muxed subtitle track for subtitle-mapping tests.
ff -i "$OUT/sample.mkv" -i "$OUT/sample.srt" -map 0 -map 1 -c copy -c:s srt "$OUT/edge-subs.mkv"

printf '\xEF\xBB\xBF1\r\n00:00:01,000 --> 00:00:02,000\r\nBOM and CRLF\r\n\r\n2\r\n00:00:02,500 --> 00:00:03,000\r\nSecond\r\n' > "$OUT/edge-bom-crlf.srt"
printf '1\r00:00:01,000 --> 00:00:02,000\rClassic Mac CR\r\r2\r00:00:02,000 --> 00:00:03,000\rLine two\r' > "$OUT/edge-cr.srt"
printf '1\n00:00:01,000 --> 00:00:02,000\nNo trailing newline' > "$OUT/edge-no-trailing-newline.srt"
printf '1\n00:00:01,000 --> 00:00:02,000\ncaf\xe9 cr\xe8me\n' > "$OUT/edge-cp1252.srt"
{ printf '\xFF\xFE'; printf '1\r\n00:00:01,000 --> 00:00:02,000\r\nUTF-16 \xc3\xa9t\xc3\xa9\r\n' | iconv -f UTF-8 -t UTF-16LE; } > "$OUT/edge-utf16.srt"

cat > "$OUT/edge-overlap.srt" <<'EOF'
1
00:00:05,000 --> 00:00:08,000
Starts later but listed first

2
00:00:01,000 --> 00:00:04,000
Speaker A

3
00:00:02,000 --> 00:00:03,500
Speaker B (overlaps A)

4
00:00:02,000 --> 00:00:03,000
Speaker C (same start as B)
EOF

cat > "$OUT/edge-styling.srt" <<'EOF'
1
00:00:01,000 --> 00:00:02,000
<i>Italic</i>, <b>bold</b>, <u>under</u>

2
00:00:02,000 --> 00:00:03,000
<font color="red">Red</font> and <font color="#FF8800">orange</font>

3
00:00:03,000 --> 00:00:04,000
{\an8}Top of the screen

4
00:00:04,000 --> 00:00:05,000
{\i1}ASS italic{\i0} and a < b & c > d <3

5
00:00:05,000 --> 00:00:06,000
{\an7}<font face="Arial" size="12">Top left, face only</font>
EOF

cat > "$OUT/edge-hours.srt" <<'EOF'
1
99:59:59,999 --> 100:00:00,000
Almost a hundred hours

2
123:45:06,789 --> 123:45:07,000
Past a hundred hours
EOF

cat > "$OUT/edge-missing-index.srt" <<'EOF'
00:00:01,000 --> 00:00:02,000
No index at all

seven
00:00:02,000 --> 00:00:03,000
Non-numeric index

42
00:00:03,000 --> 00:00:04,000
Out-of-sequence index
EOF

printf '\n\n  \n1\n00:00:01,000 --> 00:00:02,000\nAfter leading blanks\n\n\n\n \t \n2\n00:00:02,000 --> 00:00:03,000\nAfter many blanks\n\n\n\n' > "$OUT/edge-extra-blank.srt"

cat > "$OUT/edge-malformed.srt" <<'EOF'
1
00:00:01,000 --> 00:00:0x,000
Broken end time

2
Text without any timing line

3
00:00:05,000 --> 00:00:04,000
Ends before it starts

4
00:00:06,000 --> 00:00:07,000
Valid survivor
EOF

cat > "$OUT/edge-dot-separator.srt" <<'EOF'
1
00:00:01.000 --> 00:00:02.500
Dots instead of commas

2
00:00:03,25 --> 00:00:04,5
Short fractions
EOF

cat > "$OUT/edge-glued.srt" <<'EOF'
1
00:00:01,000 --> 00:00:02,000
First
2
00:00:02,000 --> 00:00:03,000
Second, no blank line before
EOF

cat > "$OUT/edge-header-blocks.vtt" <<'EOF'
WEBVTT - Halo edge cases
Kind: captions
Language: en

STYLE
::cue(.loud) { color: #ff0000; background-color: black; }

REGION
id:fred
width:40%

NOTE This is a comment
spanning two lines

1
00:00:01.000 --> 00:00:02.000 region:fred align:left
<c.loud>Loud</c> and <v Bob>Bob speaks</v>

NOTE trailing note
EOF

cat > "$OUT/edge-settings.vtt" <<'EOF'
WEBVTT

00:00:01.000 --> 00:00:02.000 line:0
Top centre

00:00:02.000 --> 00:00:03.000 line:50% align:end
Middle right

00:00:03.000 --> 00:00:04.000 align:start position:10% size:50%
No line setting

00:00:04.000 --> 00:00:05.000 line:-1 align:start
Bottom left
EOF

cat > "$OUT/edge-entities.vtt" <<'EOF'
WEBVTT

00:00:01.000 --> 00:00:02.000
Tom &amp; Jerry &lt;3 &gt; x&nbsp;y &#x2014; &#169;

00:00:02.000 --> 00:00:03.000
<ruby>漢<rt>kan</rt></ruby> and <00:00:02.500>karaoke <c.yellow.big>yellow</c>

00:00:03.000 --> 00:00:04.000
<lang en>Lang</lang> <b.loud>bold class</b>
EOF

cat > "$OUT/edge-short-time.vtt" <<'EOF'
WEBVTT

01:02.003 --> 01:04.500
Minutes only

100:00:00.000 --> 100:00:01.000
Hundred hours
EOF

cat > "$OUT/edge-no-blank-between.vtt" <<'EOF'
WEBVTT

00:00:01.000 --> 00:00:02.000
First
00:00:02.000 --> 00:00:03.000
Second, no blank line before
EOF

cat > "$OUT/edge-rolling.vtt" <<'EOF'
WEBVTT
Kind: captions
Language: en

00:00:00.000 --> 00:00:02.000 align:start position:0%
so today we are going

00:00:02.000 --> 00:00:04.000 align:start position:0%
so today we are going
to talk about subtitles

00:00:04.000 --> 00:00:06.000 align:start position:0%
to talk about subtitles
and why they matter
EOF

cat > "$OUT/edge-malformed.vtt" <<'EOF'
WEBVTT

00:00:01.000 --> 00:00:xx.000
Broken

just some orphan text

00:00:03.000 --> 00:00:04.000
Valid survivor
EOF

printf '00:00:01.000 --> 00:00:02.000\nNo signature\n' > "$OUT/edge-nosig.vtt"
