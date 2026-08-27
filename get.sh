#!/bin/sh
# study-reminder -- universal one-command bootstrap.
#
#   curl -fsSL https://raw.githubusercontent.com/nimapdevyash/study-reminder/main/get.sh | sh
#
# Detects the OS, downloads the tool (the "ghop ghop" clip is bundled), installs
# the right kind of background service, and starts it. The only off switch,
# on every OS, is:   daddy_please_stop
set -eu

REPO_SLUG="nimapdevyash/study-reminder"
BRANCH="main"
RAW="https://raw.githubusercontent.com/$REPO_SLUG/$BRANCH"
DEST="${STUDY_HOME:-$HOME/.local/share/study-reminder}"

say() { printf '[study-reminder] %s\n' "$*"; }

uname_s="$(uname -s 2>/dev/null || echo unknown)"

# ---------------------------------------------------------------------------
# Windows shell environment (Git Bash / MSYS / Cygwin) -> hand off to PowerShell
# ---------------------------------------------------------------------------
case "$uname_s" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    say "Windows detected -> PowerShell installer"
    ps="$(command -v powershell.exe || command -v pwsh.exe || command -v powershell || true)"
    [ -n "$ps" ] || { say "powershell not found on PATH"; exit 1; }
    "$ps" -NoProfile -ExecutionPolicy Bypass -Command \
      "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iex ((New-Object Net.WebClient).DownloadString('$RAW/install.ps1'))"
    say "done. off switch:  daddy_please_stop"
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
# Clear any previous install so a rerun is a genuine fresh setup
# (disables the old service/agent, kills the old loop; harmless if none)
# ---------------------------------------------------------------------------
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now study-reminder >/dev/null 2>&1 || true
  rm -f "$HOME/.config/systemd/user/study-reminder.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi
launchctl unload "$HOME/Library/LaunchAgents/com.study-reminder.plist" 2>/dev/null || true
pkill -f 'study-reminder.sh run'   2>/dev/null || true
pkill -f 'study-reminder.sh start' 2>/dev/null || true
rm -f "$DEST/var/study-reminder.pid"

# ---------------------------------------------------------------------------
# Put `study-reminder` and `daddy_please_stop` on PATH
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.local/bin"
ln -sf "$DEST/study-reminder.sh"          "$HOME/.local/bin/study-reminder"
ln -sf "$DEST/daddy_please_stop.sh" "$HOME/.local/bin/daddy_please_stop"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) say "note: add ~/.local/bin to PATH -> export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# ---------------------------------------------------------------------------
# Start it in the background, picking the mechanism that fits the box
# ---------------------------------------------------------------------------
started=""

if [ "$flavor" = macos ]; then
  plist="$HOME/Library/LaunchAgents/com.study-reminder.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.study-reminder</string>
  <key>ProgramArguments</key>
  <array><string>/bin/sh</string><string>$DEST/study-reminder.sh</string><string>run</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST
  launchctl unload "$plist" 2>/dev/null || true
  if launchctl load "$plist" 2>/dev/null; then started="launchd agent com.study-reminder"; fi
fi

if [ -z "$started" ] && [ "$flavor" = linux ] && [ "$is_wsl" = 0 ] \
   && command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/systemd/user"
  sed "s|^ExecStart=.*|ExecStart=$DEST/study-reminder.sh run|" \
    "$DEST/study-reminder.service" > "$HOME/.config/systemd/user/study-reminder.service"
  systemctl --user daemon-reload
  if systemctl --user enable --now study-reminder 2>/dev/null; then started="systemd user service study-reminder"; fi
fi

if [ -z "$started" ]; then
  # WSL / systemd-less linux / launchd refused -> detached nohup loop
  nohup "$DEST/study-reminder.sh" start >/dev/null 2>&1 &
  started="detached background loop"
fi

say "started via $started"
say "done. it fires every 20-90 min. off switch (any OS):  daddy_please_stop"
