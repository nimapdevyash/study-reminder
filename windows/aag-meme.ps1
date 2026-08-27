# aag-meme (Windows) -- a background gremlin that blasts a meme sound at a
# random interval (default: every 20-90 minutes) at max system volume.
#
#   powershell -File aag-meme.ps1 start      # register task + put shims on PATH (runs at logon)
#   powershell -File aag-meme.ps1 stop       # the ONLY off switch (also: the daddy-please-stop command)
#   powershell -File aag-meme.ps1 status     # scheduled? running? + recent log
#   powershell -File aag-meme.ps1 once       # fire the sound right now (test)
#   powershell -File aag-meme.ps1 run        # internal: the foreground loop
#
# After `start`, these are on your PATH (new terminal):
#   aag-meme status | once | restart
#   daddy-please-stop                        # stop everything, remove shims
#
# Config via env vars (all optional):
#   AAG_MIN_SECS   min gap between hits   (default 1200 = 20 min)
#   AAG_MAX_SECS   max gap between hits   (default 5400 = 90 min)
#   AAG_VOLUME     master volume 0.0-1.0  (default 1.0 = 100%)
#   AAG_WARMUP     seconds before 1st hit (default 30)

[CmdletBinding()]
param([Parameter(Position = 0)][string]$Command = 'status')

$ErrorActionPreference = 'Stop'

$Here     = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root     = Split-Path -Parent $Here                 # install root (holds media/)
$MediaDir = Join-Path $Root 'media'
$BinDir   = Join-Path $Root 'bin'                    # shim commands go on PATH
$VarDir   = Join-Path $Here 'var'
$LogFile  = Join-Path $VarDir 'aag-meme.log'
$TaskName = 'aag-meme'

$MinSecs = if ($env:AAG_MIN_SECS) { [int]$env:AAG_MIN_SECS }    else { 1200 }
$MaxSecs = if ($env:AAG_MAX_SECS) { [int]$env:AAG_MAX_SECS }    else { 5400 }
$Volume  = if ($env:AAG_VOLUME)   { [double]$env:AAG_VOLUME }   else { 1.0 }
$Warmup  = if ($env:AAG_WARMUP)   { [int]$env:AAG_WARMUP }      else { 30 }

New-Item -ItemType Directory -Force -Path $VarDir | Out-Null

function Log([string]$msg) {
  $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
  Write-Host $line
  try { Add-Content -LiteralPath $LogFile -Value $line } catch { }
}

function Get-SoundFile {
  Get-ChildItem -LiteralPath $MediaDir -Filter 'sound.*' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '^\.(mp3|wav|wma|m4a)$' } |
    Select-Object -First 1
}

# --- crank the default output device to max via the Core Audio API -------------
function Set-MaxVolume([double]$level) {
  $level = [math]::Min([math]::Max($level, 0.0), 1.0)
  try {
    if (-not ('AagAudio' -as [type])) {
      Add-Type -Language CSharp @'
using System;
using System.Runtime.InteropServices;

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
  int RegisterControlChangeNotify(IntPtr p);
  int UnregisterControlChangeNotify(IntPtr p);
  int GetChannelCount(out uint c);
  int SetMasterVolumeLevel(float level, Guid ctx);
  int SetMasterVolumeLevelScalar(float level, Guid ctx);
  int GetMasterVolumeLevel(out float level);
  int GetMasterVolumeLevelScalar(out float level);
  int SetChannelVolumeLevel(uint ch, float level, Guid ctx);
  int SetChannelVolumeLevelScalar(uint ch, float level, Guid ctx);
  int GetChannelVolumeLevel(uint ch, out float level);
  int GetChannelVolumeLevelScalar(uint ch, out float level);
  int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, Guid ctx);
  int GetMute(out bool mute);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
  int Activate(ref Guid iid, int clsCtx, IntPtr act, [MarshalAs(UnmanagedType.IUnknown)] out object o);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
  int EnumAudioEndpoints(int dataFlow, int mask, IntPtr devices);
  int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ep);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject { }

public static class AagAudio {
  public static void Max(float level) {
    var e = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
    IMMDevice dev;
    e.GetDefaultAudioEndpoint(0 /*eRender*/, 0 /*eConsole*/, out dev);
    Guid iid = typeof(IAudioEndpointVolume).GUID;
    object o;
    dev.Activate(ref iid, 23 /*CLSCTX_ALL*/, IntPtr.Zero, out o);
    var v = (IAudioEndpointVolume)o;
    v.SetMute(false, Guid.Empty);
    v.SetMasterVolumeLevelScalar(level, Guid.Empty);
  }
}
'@
    }
    [AagAudio]::Max([float]$level)
    return $true
  }
  catch {
    Log "Core Audio path failed ($($_.Exception.Message)); falling back to volume-up keys"
    try {
      $wsh = New-Object -ComObject WScript.Shell
      1..50 | ForEach-Object { $wsh.SendKeys([char]175) }   # VK_VOLUME_UP
      return $true
    }
    catch { return $false }
  }
}

# --- play the clip once, waiting for it to finish ----------------------------
function Invoke-Blast {
  $sound = Get-SoundFile
  if (-not $sound) { Log "no sound file in $MediaDir (want sound.mp3 / .wav)"; return }

  [void](Set-MaxVolume $Volume)
  Log ("playing {0} @ vol {1}" -f $sound.Name, $Volume)

  $played = $false

  # 1. Windows Media Player COM -- works headless, no dispatcher needed
  try {
    $wmp = New-Object -ComObject WMPlayer.OCX
    $wmp.settings.volume = 100
    $wmp.settings.autoStart = $true
    $wmp.URL = $sound.FullName
    $wmp.controls.play()
    $startBy = (Get-Date).AddSeconds(20)
    while ($wmp.playState -ne 3 -and $wmp.playState -ne 8 -and (Get-Date) -lt $startBy) { Start-Sleep -Milliseconds 100 }
    $endBy = (Get-Date).AddSeconds(180)
    while ($wmp.playState -eq 3 -and (Get-Date) -lt $endBy) { Start-Sleep -Milliseconds 200 }
    $wmp.controls.stop(); $wmp.close()
    [Runtime.InteropServices.Marshal]::ReleaseComObject($wmp) | Out-Null
    $played = $true
  }
  catch { Log "WMP path failed: $($_.Exception.Message)" }

  # 2. WPF MediaPlayer
  if (-not $played) {
    try {
      Add-Type -AssemblyName presentationCore -ErrorAction Stop
      $mp = New-Object System.Windows.Media.MediaPlayer
      $mp.Open([Uri]$sound.FullName)
      $deadline = (Get-Date).AddSeconds(5)
      while (-not $mp.NaturalDuration.HasTimeSpan -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 50 }
      $mp.Volume = 1.0
      $mp.Play()
      $secs = if ($mp.NaturalDuration.HasTimeSpan) { $mp.NaturalDuration.TimeSpan.TotalSeconds + 1 } else { 12 }
      Start-Sleep -Seconds $secs
      $mp.Stop(); $mp.Close()
      $played = $true
    }
    catch { Log "MediaPlayer failed: $($_.Exception.Message)" }
  }

  # 3. SoundPlayer (wav only) / 4. hand off to the shell
  if (-not $played -and $sound.Extension -eq '.wav') {
    try { (New-Object System.Media.SoundPlayer $sound.FullName).PlaySync(); $played = $true } catch { }
  }
  if (-not $played) {
    try { Start-Process -FilePath $sound.FullName; $played = $true } catch { }
  }
  if (-not $played) { Log "could not play the sound with any method" }
}

# --- the gremlin loop -------------------------------------------------------
function Invoke-Loop {
  Log ("aag-meme started (pid {0}) -- interval {1}-{2}s, warmup {3}s" -f $PID, $MinSecs, $MaxSecs, $Warmup)
  $wait = $Warmup
  while ($true) {
    Log "next hit in ${wait}s"
    Start-Sleep -Seconds $wait
    try { Invoke-Blast } catch { Log "blast error: $($_.Exception.Message)" }
    $wait = Get-Random -Minimum $MinSecs -Maximum ($MaxSecs + 1)
  }
}

# --- scheduled-task lifecycle --------------------------------------------------
function New-TaskAction {
  $ps  = (Get-Command powershell.exe).Source
  $ps1 = Join-Path $Here 'aag-meme.ps1'
  New-ScheduledTaskAction -Execute $ps `
    -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" run' -f $ps1)
}

function Add-UserPath([string]$dir) {
  $cur   = [Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = @()
  if ($cur) { $parts = $cur -split ';' | Where-Object { $_ -ne '' } }
  if ($parts -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', (($parts + $dir) -join ';'), 'User')
    Log "added '$dir' to your user PATH (open a NEW terminal to use the commands)"
  }
  if (($env:Path -split ';') -notcontains $dir) { $env:Path = "$env:Path;$dir" }
}

function Remove-UserPath([string]$dir) {
  $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $cur) { return }
  $parts = $cur -split ';' | Where-Object { $_ -ne '' -and $_ -ne $dir }
  [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

function Install-Shims {
  New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
  $ps1 = Join-Path $Here 'aag-meme.ps1'
  $runner = '@echo off' + "`r`n" +
  ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}" %*' -f $ps1) + "`r`n"
  $stopper = '@echo off' + "`r`n" +
  ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}" stop' -f $ps1) + "`r`n"
  Set-Content -LiteralPath (Join-Path $BinDir 'aag-meme.cmd')         -Value $runner  -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $BinDir 'daddy-please-stop.cmd') -Value $stopper -Encoding ASCII
  Add-UserPath $BinDir
}

function Remove-Shims {
  Remove-Item -LiteralPath (Join-Path $BinDir 'aag-meme.cmd')          -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath (Join-Path $BinDir 'daddy-please-stop.cmd') -Force -ErrorAction SilentlyContinue
  Remove-UserPath $BinDir
}

function Stop-LoopProcesses {
  Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'aag-meme\.ps1.*\brun\b' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Get-StartupCmd {
  $dir = [Environment]::GetFolderPath('Startup')
  Join-Path $dir 'aag-meme.cmd'
}

function Register-Autostart {
  # Preferred: a hidden Scheduled Task that runs at every logon.
  try {
    $action    = New-TaskAction
    $trigger   = New-ScheduledTaskTrigger -AtLogOn
    $me        = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
      -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
      -Settings $settings -Description 'aag-meme -- random meme-sound gremlin' -Force -ErrorAction Stop | Out-Null
    Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    return 'scheduled task'
  }
  catch {
    Log "scheduled task unavailable ($($_.Exception.Message)); using Startup folder instead"
  }
  # Fallback: Startup-folder .cmd (runs at logon) + launch the loop right now.
  $ps1 = Join-Path $Here 'aag-meme.ps1'
  $body = '@echo off' + "`r`n" +
  ('start "" /min powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" run' -f $ps1) + "`r`n"
  Set-Content -LiteralPath (Get-StartupCmd) -Value $body -Encoding ASCII
  Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden `
    -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $ps1, 'run')
  return 'Startup folder + background process'
}

function Unregister-Autostart {
  try { Stop-ScheduledTask       -TaskName $TaskName -ErrorAction SilentlyContinue | Out-Null } catch { }
  try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue } catch { }
  Remove-Item -LiteralPath (Get-StartupCmd) -Force -ErrorAction SilentlyContinue
}

function Invoke-Start {
  $how = Register-Autostart
  Install-Shims
  Log "started via $how (fires every logon + every ${MinSecs}-${MaxSecs}s)"
  Log "off switch: run  daddy-please-stop"
  Invoke-Status
}

function Invoke-Stop {
  Unregister-Autostart
  Stop-LoopProcesses
  Remove-Shims
  Log "stopped -- autostart removed, loop killed, PATH shims removed. quiet now."
}

function Invoke-Status {
  $task = $null
  if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  }
  if ($task) {
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    Write-Host ("autostart: scheduled task (state {0}, last run {1})" -f $task.State, $info.LastRunTime)
  }
  elseif (Test-Path (Get-StartupCmd)) {
    Write-Host "autostart: Startup folder ($(Get-StartupCmd))"
  }
  else {
    Write-Host "autostart: not installed"
  }
  $running = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'aag-meme\.ps1.*\brun\b' }
  if ($running) {
    Write-Host ("loop:     running (pid {0})" -f (($running.ProcessId) -join ', '))
  }
  else {
    Write-Host "loop:     not running"
  }
  $s = Get-SoundFile
  Write-Host ("sound:    {0}" -f $(if ($s) { $s.FullName } else { '<none>' }))
  Write-Host ("interval: {0}-{1}s   volume: {2}   warmup: {3}s" -f $MinSecs, $MaxSecs, $Volume, $Warmup)
  if (Test-Path $LogFile) { Write-Host '--- last log ---'; Get-Content -LiteralPath $LogFile -Tail 8 }
}

switch ($Command.ToLower()) {
  'start'   { Invoke-Start }
  'stop'    { Invoke-Stop }
  'restart' { Invoke-Stop; Start-Sleep -Seconds 1; Invoke-Start }
  'status'  { Invoke-Status }
  'once'    { Invoke-Blast }
  'test'    { Invoke-Blast }
  'run'     { Invoke-Loop }
  default   { Write-Host 'usage: aag-meme.ps1 {start|stop|restart|status|once|run}  (or the `daddy-please-stop` command)' }
}
