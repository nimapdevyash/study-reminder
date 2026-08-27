# study-reminder

A background "study reminder". Every 20–90 minutes (random) it cranks the
default audio output to max and plays the **"ladle meoww ghop ghop ghop"** clip
— and it fires once on every login too. The sound ships with the tool. No setup,
no download, no config.

**There is no `stop` command.** The one and only off switch, on every OS, is the
`daddy_please_stop` command.

---

## Install

**Linux / macOS / WSL / Git-Bash-on-Windows** — one command:

```sh
curl -fsSL https://raw.githubusercontent.com/nimapdevyash/study-reminder/main/get.sh | sh
```

**Windows** — one command. Works pasted into either a PowerShell prompt **or**
`cmd.exe` (no `$` variables, so nothing gets mangled by shell double-expansion):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/nimapdevyash/study-reminder/main/install.ps1'))"
```

Already at a `PS>` prompt? The bare form is enough:

```powershell
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/nimapdevyash/study-reminder/main/install.ps1'))
```

`get.sh` sniffs the OS and does the right thing:

| environment | what it sets up |
| --- | --- |
| Linux + systemd | a `--user` systemd service (auto-starts at login, auto-restarts) |
| Linux without systemd / WSL | a detached `nohup` background loop |
| macOS | a `LaunchAgent` (`com.study-reminder`, RunAtLoad + KeepAlive) |
| Git Bash / MSYS / Cygwin | hands off to the PowerShell installer |
| Windows PowerShell | a hidden Scheduled Task at logon (falls back to a Startup-folder entry if task registration is blocked) |

Either way you end up with two commands on your PATH:

```
study-reminder once | status        # test / inspect — no `stop` here
daddy_please_stop                    # the only way to make it stop
```

## Stopping it

```
daddy_please_stop
```

That disables the service / task / agent, kills the loop, and removes the PATH
shims — on any OS. Until you run it, the gremlin survives reboots.

Windows, from a raw URL (if the PATH command isn't available) — cmd.exe or PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/nimapdevyash/study-reminder/main/daddy_please_stop.ps1'))"
```

---

## Swapping the sound

Drop any `media/sound.*` file (`.mp3 .wav .ogg .m4a .webm`) into the install
directory, or on Unix pull one from a URL:

```
study-reminder fetch "https://www.youtube.com/watch?v=XXXXXXXXXXX"
```

## Knobs (env vars, set before install / `study-reminder start`)

| var            | default | meaning                                  |
| -------------- | ------- | ---------------------------------------- |
| `STUDY_MIN_SECS` | 1200    | shortest gap between hits (20 min)       |
| `STUDY_MAX_SECS` | 5400    | longest gap between hits (90 min)        |
| `STUDY_VOLUME`   | 1.0     | master volume, `0.0`–`1.0`               |
| `STUDY_WARMUP`   | 30      | seconds before the first hit after start |
| `STUDY_RESTORE`  | 0       | `1` = put volume back after each hit     |
| `STUDY_HOME`     | `~/.local/share/study-reminder` | install dir (Unix)         |

Example: `STUDY_MIN_SECS=300 STUDY_MAX_SECS=1200 curl -fsSL …/get.sh | sh`

---

## Layout

```
get.sh                    universal bootstrap (OS detection + background install)
install.ps1               Windows PowerShell bootstrap
install.sh                alias -> get.sh
daddy_please_stop.sh      Unix off switch (systemd / launchd / nohup teardown)
daddy_please_stop.ps1     Windows off switch (raw-URL runnable)
media/sound.mp3, .wav     the "ghop ghop" clip (bundled)
study-reminder.sh         Unix: the loop + start / status / once / fetch
fetch-sound.sh            Unix: grab a different clip via yt-dlp/curl
study-reminder.service    Linux: systemd user unit template
windows/study-reminder.ps1  Windows: loop, Scheduled Task, PATH shims, Core Audio
```

## Manual use (no installer)

Unix:

```
./study-reminder.sh start | status | once     # stop only via ./daddy_please_stop.sh
```

Windows:

```
powershell -File windows\study-reminder.ps1 start | status | once
```
(stop only via `daddy_please_stop`)

Needs, per OS: `wpctl` + `mpv`/`ffplay`/`pw-play` (Linux) · `afplay` (macOS,
built in) · Windows Media Player (Windows, built in).
