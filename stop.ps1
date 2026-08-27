# aag-meme off switch for Windows. Runnable straight from a raw URL:
#
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;$t=Join-Path $env:TEMP 'aag-stop.ps1';(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/nimapdevyash/aag-meme/main/stop.ps1',$t);& $t"
#
# (You normally just run the `daddy-please-stop` command instead.)

$ErrorActionPreference = 'SilentlyContinue'

$Dest = Join-Path $env:LOCALAPPDATA 'aag-meme'
$ps1  = Join-Path $Dest 'windows\aag-meme.ps1'

if (Test-Path $ps1) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ps1 stop
}
else {
  # inline teardown if the install folder is already gone
  try { Stop-ScheduledTask       -TaskName 'aag-meme' } catch { }
  try { Unregister-ScheduledTask -TaskName 'aag-meme' -Confirm:$false } catch { }
  Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -match 'aag-meme\.ps1.*\brun\b' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  $bin = Join-Path $Dest 'bin'
  $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($cur) {
    $new = ($cur -split ';' | Where-Object { $_ -and $_ -ne $bin }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
  }
  Write-Host 'aag-meme stopped. quiet now.'
}
