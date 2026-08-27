#Requires -Version 5.1
<#
  aag-meme -- one-command Windows installer.

  Run this in PowerShell (no admin needed):

    powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/install.ps1 | iex"

  It downloads the repo (sound bundled), drops it in %LOCALAPPDATA%\aag-meme,
  registers a hidden scheduled task that fires the clip every 20-90 minutes and
  again on every logon, and puts `aag-meme` + `daddy-please-stop` on your PATH.

  Off switch (the only one):  daddy-please-stop
#>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo   = 'nimapdevyash/aag-meme'
$Branch = 'main'
$Dest   = Join-Path $env:LOCALAPPDATA 'aag-meme'

Write-Host '==> aag-meme installer' -ForegroundColor Cyan
Write-Host "    target: $Dest"

$zip     = Join-Path $env:TEMP ('aag-meme-{0}.zip'   -f [guid]::NewGuid().ToString('N'))
$stage   = Join-Path $env:TEMP ('aag-meme-{0}'       -f [guid]::NewGuid().ToString('N'))
$url     = "https://codeload.github.com/$Repo/zip/refs/heads/$Branch"

try {
  Write-Host "==> downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

  Write-Host '==> extracting'
  Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
  $srcRoot = Join-Path $stage "aag-meme-$Branch"
  if (-not (Test-Path $srcRoot)) {
    $srcRoot = (Get-ChildItem -LiteralPath $stage -Directory | Select-Object -First 1).FullName
  }

  $existing = Join-Path $Dest 'windows\aag-meme.ps1'
  if (Test-Path $existing) {
    Write-Host '==> stopping previous install'
    try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $existing stop | Out-Null } catch { }
  }

  Write-Host '==> installing'
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Copy-Item -Path (Join-Path $srcRoot '*') -Destination $Dest -Recurse -Force

  $ps1 = Join-Path $Dest 'windows\aag-meme.ps1'
  Write-Host '==> registering scheduled task'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ps1 start

  Write-Host ''
  Write-Host 'done. it will fire every 20-90 min, and on every logon.' -ForegroundColor Green
  Write-Host '  open a NEW terminal, then:'
  Write-Host '    aag-meme once       # test it'
  Write-Host '    aag-meme status'
  Write-Host '    daddy-please-stop   # the only off switch'
}
finally {
  Remove-Item -LiteralPath $zip   -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
