#!/usr/bin/env bash
# Grab the meme audio and park it at media/sound.<ext> so study-reminder.sh can find it.
# Usage: ./fetch-sound.sh <youtube-or-direct-media-url>
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$HERE/media"
mkdir -p "$MEDIA_DIR"

url="${1:-}"
[ -n "$url" ] || { echo "usage: $0 <youtube-or-direct-media-url>"; exit 1; }

if command -v yt-dlp >/dev/null 2>&1; then
  rm -f "$MEDIA_DIR"/sound.*
  # -x = extract audio; keep whatever container yt-dlp lands on (mpv/ffplay play them all).
  yt-dlp -x --audio-quality 0 -o "$MEDIA_DIR/sound.%(ext)s" "$url"
elif command -v curl >/dev/null 2>&1; then
  # assume the URL points straight at an audio file
  ext="${url##*.}"; [ "${#ext}" -le 4 ] || ext="mp3"
  rm -f "$MEDIA_DIR"/sound.*
  curl -fL --progress-bar -o "$MEDIA_DIR/sound.$ext" "$url"
else
  echo "need yt-dlp or curl installed"; exit 1
fi

echo "saved: $(ls "$MEDIA_DIR"/sound.* 2>/dev/null)"
