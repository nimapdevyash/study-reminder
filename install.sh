#!/usr/bin/env bash
# aag-meme -- one-command Linux installer.
#
#   curl -fsSL https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/install.sh | bash
#
# Clones (or downloads) the repo to ~/.local/share/aag-meme, installs a systemd
# user service, and starts it. Sound is bundled.
set -euo pipefail

REPO_SLUG="nimapdevyash/aag-meme"
BRANCH="main"
DEST="${AAG_HOME:-$HOME/.local/share/aag-meme}"

echo "==> aag-meme installer -> $DEST"

if command -v git >/dev/null 2>&1; then
  if [ -d "$DEST/.git" ]; then
    git -C "$DEST" fetch --depth 1 origin "$BRANCH"
    git -C "$DEST" reset --hard "origin/$BRANCH"
  else
    rm -rf "$DEST"
    git clone --depth 1 -b "$BRANCH" "https://github.com/$REPO_SLUG.git" "$DEST"
  fi
else
  echo "==> git not found, downloading tarball"
  mkdir -p "$DEST"
  curl -fsSL "https://codeload.github.com/$REPO_SLUG/tar.gz/refs/heads/$BRANCH" \
    | tar -xz -C "$DEST" --strip-components=1
fi

chmod +x "$DEST"/*.sh || true

# put `aag-meme` and `daddy-please-stop` on PATH
mkdir -p "$HOME/.local/bin"
ln -sf "$DEST/aag-meme.sh"          "$HOME/.local/bin/aag-meme"
ln -sf "$DEST/daddy-please-stop.sh" "$HOME/.local/bin/daddy-please-stop"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "==> add ~/.local/bin to PATH (e.g. in ~/.bashrc / ~/.zshrc):"
     echo "     export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

if command -v systemctl >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/systemd/user"
  sed "s|^ExecStart=.*|ExecStart=$DEST/aag-meme.sh run|" \
    "$DEST/aag-meme.service" > "$HOME/.config/systemd/user/aag-meme.service"
  systemctl --user daemon-reload
  systemctl --user enable --now aag-meme
  echo "==> systemd user service 'aag-meme' enabled + started"
  echo "    logs:       journalctl --user -u aag-meme -f"
else
  "$DEST/aag-meme.sh" start
fi

echo ""
echo "done. off switch (the only one):  daddy-please-stop"
