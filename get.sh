#!/bin/sh
# aag-meme -- universal one-command bootstrap.
#
#   curl -fsSL https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/get.sh | sh
#
# Detects the OS, downloads the tool (the "ghop ghop" clip is bundled), installs
# the right kind of background service, and starts it. The only off switch,
# on every OS, is:   daddy-please-stop
set -eu

REPO_SLUG="nimapdevyash/aag-meme"
BRANCH="main"
RAW="https://raw.githubusercontent.com/$REPO_SLUG/$BRANCH"
DEST="${AAG_HOME:-$HOME/.local/share/aag-meme}"

say() { printf '[aag-meme] %s\n' "$*"; }

uname_s="$(uname -s 2>/dev/null || echo unknown)"

# ---------------------------------------------------------------------------
# Windows shell environment (Git Bash / MSYS / Cygwin) -> hand off to PowerShell
# ---------------------------------------------------------------------------
case "$uname_s" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    say "Windows detected -> PowerShell installer"
    ps="$(command -v powershell.exe || command -v pwsh.exe || command -v powershell || true)"
    [ -n "$ps" ] || { say "powershell not found on PATH"; exit 1; }
    "$ps" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden \
      -Command "iex ((New-Object Net.WebClient).DownloadString('$RAW/install.ps1'))"
    say "launched. off switch:  daddy-please-stop"
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Unix: figure out flavour
# ---------------------------------------------------------------------------
is_wsl=0
if [ -r /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then is_wsl=1; fi
case "$uname_s" in
  Linux)  flavor=linux ;;
  Darwin) flavor=macos ;;
  *) say "unsupported OS: $uname_s"; exit 1 ;;
esac
say "$flavor -> $DEST"

# ---------------------------------------------------------------------------
# Fetch the repo (git if present, else tarball)
# ---------------------------------------------------------------------------
mkdir -p "$DEST"
if command -v git >/dev/null 2>&1; then
  if [ -d "$DEST/.git" ]; then
    git -C "$DEST" fetch -q --depth 1 origin "$BRANCH"
    git -C "$DEST" reset -q --hard "origin/$BRANCH"
  else
    rm -rf "$DEST"
    git clone -q --depth 1 -b "$BRANCH" "https://github.com/$REPO_SLUG.git" "$DEST"
  fi
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL "https://codeload.github.com/$REPO_SLUG/tar.gz/refs/heads/$BRANCH" \
    | tar -xz -C "$DEST" --strip-components=1
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "https://codeload.github.com/$REPO_SLUG/tar.gz/refs/heads/$BRANCH" \
    | tar -xz -C "$DEST" --strip-components=1
else
  say "need git, curl, or wget"; exit 1
fi
chmod +x "$DEST"/*.sh 2>/dev/null || true

# ---------------------------------------------------------------------------
# Put `aag-meme` and `daddy-please-stop` on PATH
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.local/bin"
ln -sf "$DEST/aag-meme.sh"          "$HOME/.local/bin/aag-meme"
ln -sf "$DEST/daddy-please-stop.sh" "$HOME/.local/bin/daddy-please-stop"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) say "note: add ~/.local/bin to PATH -> export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# ---------------------------------------------------------------------------
# Start it in the background, picking the mechanism that fits the box
# ---------------------------------------------------------------------------
started=""

if [ "$flavor" = macos ]; then
  plist="$HOME/Library/LaunchAgents/com.aag-meme.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.aag-meme</string>
  <key>ProgramArguments</key>
  <array><string>/bin/sh</string><string>$DEST/aag-meme.sh</string><string>run</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST
  launchctl unload "$plist" 2>/dev/null || true
  if launchctl load "$plist" 2>/dev/null; then started="launchd agent com.aag-meme"; fi
fi

if [ -z "$started" ] && [ "$flavor" = linux ] && [ "$is_wsl" = 0 ] \
   && command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/systemd/user"
  sed "s|^ExecStart=.*|ExecStart=$DEST/aag-meme.sh run|" \
    "$DEST/aag-meme.service" > "$HOME/.config/systemd/user/aag-meme.service"
  systemctl --user daemon-reload
  if systemctl --user enable --now aag-meme 2>/dev/null; then started="systemd user service aag-meme"; fi
fi

if [ -z "$started" ]; then
  # WSL / systemd-less linux / launchd refused -> detached nohup loop
  nohup "$DEST/aag-meme.sh" start >/dev/null 2>&1 &
  started="detached background loop"
fi

say "started via $started"
say "done. it fires every 20-90 min. off switch (any OS):  daddy-please-stop"
