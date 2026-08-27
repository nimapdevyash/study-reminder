#!/usr/bin/env bash
# study-reminder — a background gremlin that blasts a meme sound at a random
# interval (default: every 20–90 minutes) at max volume.
#
#   ./study-reminder.sh start        # launch in the background
#   ./study-reminder.sh status       # is it alive? + recent log
#   ./study-reminder.sh once         # fire the sound right now (test)
#   ./study-reminder.sh fetch <url>  # grab the meme audio via yt-dlp
#
# There is no `stop`. The only way to stop it is the `daddy_please_stop` command.
#
# Config via env (all optional):
#   STUDY_MIN_SECS   min gap between hits   (default 1200 = 20 min)
#   STUDY_MAX_SECS   max gap between hits   (default 5400 = 90 min)
#   STUDY_VOLUME     sink volume to set     (default 1.0 = 100%; 1.5 = overdrive)
#   STUDY_WARMUP     seconds before 1st hit (default 30)
#   STUDY_RESTORE    1 = restore prior volume after each hit (default 0)
#   STUDY_SINK       wpctl sink id          (default @DEFAULT_AUDIO_SINK@)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$HERE/media"
VAR_DIR="$HERE/var"
PID_FILE="$VAR_DIR/study-reminder.pid"
LOG_FILE="$VAR_DIR/study-reminder.log"

MIN_SECS="${STUDY_MIN_SECS:-1200}"
MAX_SECS="${STUDY_MAX_SECS:-5400}"
VOLUME="${STUDY_VOLUME:-1.0}"
WARMUP="${STUDY_WARMUP:-30}"
SINK="${STUDY_SINK:-@DEFAULT_AUDIO_SINK@}"
OS="$(uname -s 2>/dev/null || echo Linux)"

mkdir -p "$VAR_DIR" "$MEDIA_DIR"

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# crank the default output device to $VOLUME (0.0-1.0). echoes the prior level.
crank_volume() {
  case "$OS" in
    Darwin)
      local pct prev
      prev="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null || true)"
      pct="$(awk -v v="$VOLUME" 'BEGIN{p=v*100; if(p>100)p=100; printf "%d", p}')"
      osascript -e "set volume output volume $pct without output muted" >/dev/null 2>&1 || true
      printf '%s\n' "${prev:-}"
      ;;
    *)
      local prev
      prev="$(wpctl get-volume "$SINK" 2>/dev/null | awk '{print $2}' || true)"
      wpctl set-mute   "$SINK" 0         >/dev/null 2>&1 || true
      wpctl set-volume "$SINK" "$VOLUME" >/dev/null 2>&1 || true
      printf '%s\n' "${prev:-}"
      ;;
  esac
}

restore_volume() {
  local prev="$1"
  [ -n "$prev" ] || return 0
  case "$OS" in
    Darwin) osascript -e "set volume output volume $prev" >/dev/null 2>&1 || true ;;
    *)      wpctl set-volume "$SINK" "$prev" >/dev/null 2>&1 || true ;;
  esac
}

find_sound() {
  local f
  for f in "$MEDIA_DIR"/sound.*; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

rand_between() {
  local min="$1" max="$2" span
  span=$(( max - min + 1 ))
  (( span < 1 )) && span=1
  echo $(( min + RANDOM % span ))
}

play_once() {
  local sound prev
  if ! sound="$(find_sound)"; then
    log "no sound file — add $MEDIA_DIR/sound.mp3 (or .wav/.ogg/.m4a/.webm), or run: $0 fetch <url>"
    return 1
  fi

  prev="$(crank_volume)"
  log "playing $(basename "$sound") @ vol $VOLUME"

  if command -v mpv >/dev/null 2>&1; then
    mpv --no-video --really-quiet --no-config --volume=100 "$sound" >/dev/null 2>&1 || true
  elif command -v ffplay >/dev/null 2>&1; then
    ffplay -nodisp -autoexit -loglevel quiet "$sound" >/dev/null 2>&1 || true
  elif command -v afplay >/dev/null 2>&1; then          # macOS
    afplay "$sound" >/dev/null 2>&1 || true
  elif command -v pw-play >/dev/null 2>&1; then
    pw-play "$sound" >/dev/null 2>&1 || true
  elif command -v aplay >/dev/null 2>&1; then
    aplay -q "$sound" >/dev/null 2>&1 || true
  elif command -v powershell.exe >/dev/null 2>&1; then   # Git Bash / WSL on Windows
    powershell.exe -NoProfile -c "(New-Object Media.SoundPlayer '$sound').PlaySync()" >/dev/null 2>&1 \
      || powershell.exe -NoProfile -c "\$p=New-Object -ComObject WMPlayer.OCX; \$p.URL='$sound'; \$p.controls.play(); Start-Sleep 10" >/dev/null 2>&1 || true
  else
    log "no audio player found (need mpv, ffplay, afplay, pw-play, or aplay)"
    return 1
  fi

  if [ "${STUDY_RESTORE:-0}" = "1" ]; then
    restore_volume "${prev:-}"
  fi
}

run_loop() {
  echo $$ > "$PID_FILE"
  trap 'log "study-reminder stopping"; rm -f "$PID_FILE"; exit 0' TERM INT EXIT
  log "study-reminder started (pid $$) — interval ${MIN_SECS}-${MAX_SECS}s, warmup ${WARMUP}s"
  local wait="$WARMUP"
  while true; do
    log "next hit in ${wait}s"
    sleep "$wait" & wait $! || true
    play_once || true
    wait="$(rand_between "$MIN_SECS" "$MAX_SECS")"
  done
}

is_running() {
  [ -f "$PID_FILE" ] || return 1
  local pid; pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

cmd_start() {
  if is_running; then echo "already running (pid $(cat "$PID_FILE"))"; return 0; fi
  find_sound >/dev/null 2>&1 || echo "!! no sound file yet — add $MEDIA_DIR/sound.mp3 or run: $0 fetch <url>"
  nohup setsid bash "$HERE/study-reminder.sh" run >>"$LOG_FILE" 2>&1 &
  disown || true
  sleep 0.6
  if is_running; then
    echo "started (pid $(cat "$PID_FILE"))  log: $LOG_FILE"
  else
    echo "failed to start — see $LOG_FILE"; return 1
  fi
}

# internal: used only by the daddy_please_stop command
cmd_teardown() {
  if ! is_running; then echo "not running"; rm -f "$PID_FILE"; return 0; fi
  local pid; pid="$(cat "$PID_FILE")"
  kill "$pid" 2>/dev/null || true
  for _ in $(seq 1 25); do is_running || break; sleep 0.2; done
  if is_running; then kill -9 "$pid" 2>/dev/null || true; fi
  rm -f "$PID_FILE"
  echo "stopped"
}

cmd_status() {
  if is_running; then echo "running (pid $(cat "$PID_FILE"))"; else echo "stopped"; fi
  local s; s="$(find_sound 2>/dev/null || true)"
  echo "sound:    ${s:-<none — add media/sound.mp3>}"
  echo "interval: ${MIN_SECS}-${MAX_SECS}s   volume: ${VOLUME}   warmup: ${WARMUP}s"
  if [ -f "$LOG_FILE" ]; then echo "--- last log ---"; tail -n 8 "$LOG_FILE"; fi
}

case "${1:-}" in
  start)         cmd_start ;;
  status)        cmd_status ;;
  once|test)     play_once ;;
  fetch)         shift; exec bash "$HERE/fetch-sound.sh" "$@" ;;
  run)           run_loop ;;                       # internal: foreground loop
  __teardown)    cmd_teardown ;;                   # internal: for daddy_please_stop only
  *) echo "usage: $0 {start|status|once|fetch <url>}   (stop only via: daddy_please_stop)"; exit 1 ;;
esac
