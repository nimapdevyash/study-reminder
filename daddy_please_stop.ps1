# study-reminder off switch for Windows. Runnable straight from a raw URL:
#
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;$t=Join-Path $env:TEMP 'study-stop.ps1';(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/nimapdevyash/study-reminder/main/daddy_please_stop.ps1',$t);& $t"
#
# (You normally just run the `daddy_please_stop` command instead.)

$ErrorActionPreference = 'SilentlyContinue'

$Dest = Join-Path $env:LOCALAPPDATA 'study-reminder'
$ps1  = Join-Path $Dest 'windows\study-reminder.ps1'

if (Test-Path $ps1) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ps1 __teardown
}
else {
  # inline teardown if the install folder is already gone
  try { Stop-ScheduledTask       -TaskName 'study-reminder' } catch { }
  try { Unregister-ScheduledTask -TaskName 'study-reminder' -Confirm:$false } catch { }
  Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -match 'study-reminder\.ps1.*\brun\b' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  $bin = Join-Path $Dest 'bin'
  $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($cur) {
    $new = ($cur -split ';' | Where-Object { $_ -and $_ -ne $bin }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
  }
  Write-Host 'study-reminder stopped. quiet now.'
}
