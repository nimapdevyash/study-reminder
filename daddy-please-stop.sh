#!/usr/bin/env bash
# The one and only off switch for aag-meme on Linux.
# Disables the systemd user service, kills the background loop, and removes
# the PATH shims. After this the gremlin is fully gone until you re-install.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now aag-meme 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/aag-meme.service"
  systemctl --user daemon-reload 2>/dev/null || true
fi

bash "$HERE/aag-meme.sh" stop 2>/dev/null || true

rm -f "$HOME/.local/bin/aag-meme" "$HOME/.local/bin/daddy-please-stop"

echo "aag-meme stopped and removed. quiet now."
