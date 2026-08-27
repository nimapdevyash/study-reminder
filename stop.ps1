#Requires -Version 5.1
# aag-meme off switch for Windows -- runnable straight from a raw URL:
#   powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/stop.ps1 | iex"
# (You normally just run the `daddy-please-stop` command instead.)

$ErrorActionPreference = 'SilentlyContinue'
$dir = Join-Path $env:LOCALAPPDATA 'aag-meme'
$ps1 = Join-Path $dir 'windows\aag-meme.ps1'

if (Test-Path $ps1) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ps1 stop
}
else {
  # inline teardown if the install folder is gone
  try { Stop-ScheduledTask       -TaskName 'aag-meme' } catch { }
  try { Unregister-ScheduledTask -TaskName 'aag-meme' -Confirm:$false } catch { }
  Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -match 'aag-meme\.ps1.*\brun\b' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  $bin = Join-Path $dir 'bin'
  $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($cur) {
    $new = ($cur -split ';' | Where-Object { $_ -and $_ -ne $bin }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
  }
  Write-Host 'aag-meme stopped. quiet now.'
}
