# aag-meme

A background gremlin. Every 20–90 minutes (random) it cranks the default audio
output to max and plays the **"ladle meoww ghop ghop ghop"** clip — and it fires
once on every login too. The sound ships with the tool. No setup, no download,
no config.

**One off switch, every OS:** the `daddy-please-stop` command.

---

## Install — one command

**Linux / macOS / WSL / Git-Bash-on-Windows:**

```sh
curl -fsSL https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/get.sh | sh
```

**Windows PowerShell:**

```powershell
powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/install.ps1 | iex"
```

`get.sh` sniffs the OS and does the right thing:

| environment | what it sets up |
| --- | --- |
| Linux + systemd | a `--user` systemd service (auto-starts at login, auto-restarts) |
| Linux without systemd / WSL | a detached `nohup` background loop |
| macOS | a `LaunchAgent` (`com.aag-meme`, RunAtLoad + KeepAlive) |
| Git Bash / MSYS / Cygwin | hands off to the PowerShell installer |
| Windows PowerShell | a hidden Scheduled Task (at logon) |

Either way you end up with two commands on your PATH:

```
aag-meme once | status | restart
daddy-please-stop      # the only way to make it stop
```

## Stopping it

```
daddy-please-stop
```

That disables the service / task / agent, kills the loop, and removes the PATH
shims — on any OS. Until you run it, the gremlin survives reboots.

Windows, without a working shell:

```powershell
powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/stop.ps1 | iex"
```

---

## Swapping the sound

Drop any `media/sound.*` file (`.mp3 .wav .ogg .m4a .webm`) into the install
directory, or on Unix pull one from a URL:

```
aag-meme fetch "https://www.youtube.com/watch?v=XXXXXXXXXXX"
```

## Knobs (env vars, set before install / `aag-meme start`)

| var            | default | meaning                                  |
| -------------- | ------- | ---------------------------------------- |
| `AAG_MIN_SECS` | 1200    | shortest gap between hits (20 min)       |
| `AAG_MAX_SECS` | 5400    | longest gap between hits (90 min)        |
| `AAG_VOLUME`   | 1.0     | master volume, `0.0`–`1.0`               |
| `AAG_WARMUP`   | 30      | seconds before the first hit after start |
| `AAG_RESTORE`  | 0       | `1` = put volume back after each hit     |
| `AAG_HOME`     | `~/.local/share/aag-meme` | install dir (Unix)         |

Example: `AAG_MIN_SECS=300 AAG_MAX_SECS=1200 curl -fsSL …/get.sh | sh`

---

## Layout

```
get.sh                  universal bootstrap (OS detection + background install)
install.ps1             Windows PowerShell bootstrap
install.sh              alias -> get.sh
stop.ps1               Windows off switch (raw-URL runnable)
daddy-please-stop.sh   Unix off switch (systemd / launchd / nohup teardown)
media/sound.mp3, .wav   the "ghop ghop" clip (bundled)
aag-meme.sh            Unix: the gremlin loop + start/stop/status/once/fetch
fetch-sound.sh         Unix: grab a different clip via yt-dlp/curl
aag-meme.service       Linux: systemd user unit template
windows/aag-meme.ps1   Windows: loop, Scheduled Task, PATH shims, Core Audio
```

## Manual use (no installer)

Unix:

```
./aag-meme.sh start | status | stop | once
```

Windows:

```
powershell -File windows\aag-meme.ps1 start | status | stop | once
```

Needs, per OS: `wpctl` + `mpv`/`ffplay`/`pw-play` (Linux) · `afplay` (macOS,
built in) · Windows Media Player (Windows, built in).
