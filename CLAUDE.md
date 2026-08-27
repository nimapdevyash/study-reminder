# CLAUDE.md

Project guidance for Claude Code working in this repo.

## What this is

`study-reminder` — a cross-platform background tool that plays a bundled meme
clip at max volume every 20–90 minutes (and once per login). Installed and
driven by one-line bootstrappers; stopped only by the `daddy_please_stop`
command.

- GitHub: `nimapdevyash/study-reminder` (public), default branch `main`.
- The bundled sound lives in `media/` and ships with the repo — never fetched at
  play time.

## Key files

| file | role |
| --- | --- |
| `get.sh` | universal Unix/WSL/Git-Bash bootstrap (OS detection, background install) |
| `install.ps1` | Windows bootstrap — must stay `iex`-safe: no `<# #>` block comments, no `#Requires`, no top-level `param()` |
| `study-reminder.sh` / `windows/study-reminder.ps1` | the loop + `start` / `status` / `once` / `run` / internal `__teardown` |
| `daddy_please_stop.sh` / `daddy_please_stop.ps1` | the only off switch |
| `README.md` | the user-facing source of truth for install / stop / usage commands |

## Invariants — do not break

- **There is no user-facing `stop` or `restart`.** Teardown is only reachable via
  `daddy_please_stop`, which calls the internal `__teardown` token.
- Windows one-liners must contain **no `$` variables** — they get pasted into
  both `cmd.exe` and PowerShell, and an outer PowerShell will expand `$foo`
  before the inner shell runs.
- `install.ps1` / `daddy_please_stop.ps1` stay `iex`-safe (see table above).
- Env vars are prefixed `STUDY_`.

## REQUIRED after changing any install / stop / usage command

If a change touches the **Linux** or **Windows** command a user runs — the
`get.sh` curl line, the `install.ps1` PowerShell line, the `daddy_please_stop`
invocation, subcommand names, env var names, or the raw URLs — then in the same
change you MUST:

1. Update `README.md` so every command shown there is the current, working one.
2. Verify each raw URL in `README.md` still resolves (HTTP 200).
3. Commit and push to `origin main`.

Do not consider the task done until the README matches the code and the push has
landed. If pushing is blocked in the environment, say so explicitly and give the
user the exact `git push` / `gh` command to run.
