#!/usr/bin/env bash
# The one and only off switch for aag-meme -- works on any OS.
# Tears down whatever the installer set up (systemd user service, launchd agent,
# background loop, scheduled task) and removes the PATH shims.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
OS="$(uname -s 2>/dev/null || echo unknown)"

case "$OS" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    # Windows shell env -> let the PowerShell side do the teardown
    ps="$(command -v powershell.exe || command -v pwsh.exe || command -v powershell || true)"
    if [ -n "$ps" ] && [ -f "$HERE/windows/aag-meme.ps1" ]; then
      "$ps" -NoProfile -ExecutionPolicy Bypass -File "$HERE/windows/aag-meme.ps1" stop
    elif [ -n "$ps" ]; then
      "$ps" -NoProfile -ExecutionPolicy Bypass -Command \
        '[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $t=Join-Path $env:TEMP "aag-stop.ps1"; (New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/stop.ps1",$t); & $t'
    fi
    ;;
  Darwin)
    launchctl unload "$HOME/Library/LaunchAgents/com.aag-meme.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.aag-meme.plist"
    bash "$HERE/aag-meme.sh" stop 2>/dev/null || true
    ;;
  *)
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user disable --now aag-meme 2>/dev/null || true
      rm -f "$HOME/.config/systemd/user/aag-meme.service"
      systemctl --user daemon-reload 2>/dev/null || true
    fi
    bash "$HERE/aag-meme.sh" stop 2>/dev/null || true
    ;;
esac

# kill any stray background loop, regardless of how it was launched
pkill -f 'aag-meme.sh run'   2>/dev/null || true
pkill -f 'aag-meme.sh start' 2>/dev/null || true

rm -f "$HOME/.local/bin/aag-meme" "$HOME/.local/bin/daddy-please-stop"

echo "aag-meme stopped and removed. quiet now."
