# study-reminder -- Windows installer.
#
# One-liner (safe pasted in cmd.exe OR a PowerShell prompt -- no $ variables):
#
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/nimapdevyash/study-reminder/main/install.ps1'))"
#
# It downloads the repo (the ghop ghop clip is bundled), drops it in
# %LOCALAPPDATA%\study-reminder, registers a hidden scheduled task that fires the clip
# every 20-90 minutes and again on every logon, and puts `study-reminder` +
# `daddy_please_stop` on your PATH.
#
# Off switch (the only one):  daddy_please_stop

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$Repo   = 'nimapdevyash/study-reminder'
$Branch = 'main'
$Dest   = Join-Path $env:LOCALAPPDATA 'study-reminder'

Write-Host '==> study-reminder installer' -ForegroundColor Cyan
Write-Host "    target: $Dest"

$tmpZip = Join-Path $env:TEMP ('study-reminder-{0}.zip' -f ([guid]::NewGuid().ToString('N')))
$tmpDir = Join-Path $env:TEMP ('study-reminder-{0}'     -f ([guid]::NewGuid().ToString('N')))
$url    = "https://codeload.github.com/$Repo/zip/refs/heads/$Branch"

function Expand-Zip([string]$zip, [string]$out) {
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $inner = Join-Path $out ('x-{0}' -f ([guid]::NewGuid().ToString('N')))
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $inner)
    return $inner
  } catch { }
  try {
    Expand-Archive -LiteralPath $zip -DestinationPath $out -Force -ErrorAction Stop
    return $out
  } catch { }
  $sh = New-Object -ComObject Shell.Application
  $sh.Namespace($out).CopyHere($sh.Namespace($zip).Items(), 16)
  return $out
}

try {
  Write-Host "==> downloading $url"
  (New-Object Net.WebClient).DownloadFile($url, $tmpZip)

  Write-Host '==> extracting'
  $extracted = Expand-Zip $tmpZip $tmpDir
  $srcRoot = Get-ChildItem -LiteralPath $extracted -Directory |
    Where-Object { $_.Name -like 'study-reminder*' } | Select-Object -First 1
  if (-not $srcRoot) { throw "could not find extracted repo under $extracted" }

  $prev = Join-Path $Dest 'windows\study-reminder.ps1'
  if (Test-Path $prev) {
    Write-Host '==> stopping previous install'
    try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $prev __teardown | Out-Null } catch { }
  }

  Write-Host '==> installing'
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Copy-Item -Path (Join-Path $srcRoot.FullName '*') -Destination $Dest -Recurse -Force

  $ps1 = Join-Path $Dest 'windows\study-reminder.ps1'
  if (-not (Test-Path $ps1)) { throw "install looks incomplete: $ps1 missing" }

  Write-Host '==> registering scheduled task'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ps1 start

  Write-Host ''
  Write-Host 'done. it fires every 20-90 min, and on every logon.' -ForegroundColor Green
  Write-Host '  open a NEW terminal, then:'
  Write-Host '    study-reminder once       # test it now'
  Write-Host '    study-reminder status'
  Write-Host '    daddy_please_stop   # the only off switch'
}
finally {
  Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
