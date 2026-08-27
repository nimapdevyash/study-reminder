# aag-meme

A background gremlin. Every 20–90 minutes (random) it cranks the default audio
output to max and plays the **"ladle meoww ghop ghop ghop"** clip. It also fires
once on every logon. The sound ships with the tool — no setup, no download.

There is exactly one off switch: the **`daddy-please-stop`** command.

---

## Windows — one command

Open PowerShell and paste:

```powershell
powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/install.ps1 | iex"
```

That downloads the tool to `%LOCALAPPDATA%\aag-meme`, registers a hidden
scheduled task (fires every 20–90 min and at every logon), and puts two commands
on your PATH. Open a **new** terminal, then:

```
aag-meme once        # test it right now
aag-meme status      # is it armed?
aag-meme restart
daddy-please-stop    # the only way to make it stop
```

`daddy-please-stop` unregisters the task, kills the loop, and removes the PATH
shims. Until you run it, the gremlin survives reboots.

## Linux — one command

```bash
curl -fsSL https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/install.sh | bash
```

Installs to `~/.local/share/aag-meme`, enables a systemd **user** service, and
links `aag-meme` + `daddy-please-stop` into `~/.local/bin`.

```
aag-meme once
aag-meme status
daddy-please-stop
```

Needs `wpctl` (PipeWire) and one of `mpv` / `ffplay` / `pw-play`.

---

## Swapping the sound

Drop any `media/sound.*` file (`.mp3 .wav .ogg .m4a .webm`) into the install
directory, or on Linux pull one from a URL:

```
aag-meme fetch "https://www.youtube.com/watch?v=XXXXXXXXXXX"
```

## Knobs (env vars)

| var            | default | meaning                                  |
| -------------- | ------- | ---------------------------------------- |
| `AAG_MIN_SECS` | 1200    | shortest gap between hits (20 min)       |
| `AAG_MAX_SECS` | 5400    | longest gap between hits (90 min)        |
| `AAG_VOLUME`   | 1.0     | master volume, `0.0`–`1.0`               |
| `AAG_WARMUP`   | 30      | seconds before the first hit after start |
| `AAG_RESTORE`  | 0       | Linux only: `1` = restore volume after   |

Set them before `start` (Linux: `AAG_MIN_SECS=300 aag-meme start`; Windows: set
the env var in the scheduled task or via `setx` before running `aag-meme start`).

---

## Layout

```
install.ps1 / install.sh     one-command bootstrappers
media/sound.mp3, sound.wav    the ghop ghop clip (bundled)
aag-meme.sh                   Linux: the gremlin loop + start/stop/status/once
fetch-sound.sh               Linux: grab a different clip via yt-dlp/curl
aag-meme.service             Linux: systemd user unit template
daddy-please-stop.sh         Linux: the off switch
windows/aag-meme.ps1         Windows: everything (loop, task, PATH shims)
```

## Manual Linux use (no installer)

```
./aag-meme.sh start      # detached background process
./aag-meme.sh status
./aag-meme.sh stop
```

Or wire up the systemd unit yourself:

```
sed "s|^ExecStart=.*|ExecStart=$PWD/aag-meme.sh run|" aag-meme.service \
  > ~/.config/systemd/user/aag-meme.service
systemctl --user daemon-reload
systemctl --user enable --now aag-meme
```
