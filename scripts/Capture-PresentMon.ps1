<#
.SYNOPSIS
  Records a per-frame PresentMon capture of the iRacing sim and saves the CSV where the tune-up can analyse it.
.DESCRIPTION
  Uses Intel PresentMon's console tool. PresentMon needs Administrator rights for ETW tracing, so this script relaunches
  itself elevated if needed (Windows will ask for consent). Two modes:
    -Delay/-Seconds : start after a countdown and stop after N seconds. Good for "grid up, start script, drive".
    -Hotkey         : press the hotkey in the sim to start and again to stop (default ALT+SHIFT+F11).
  The output filename encodes the time; the analysis script reads it with Analyze-PresentMon.ps1.
.PARAMETER OutDir
  Folder for the CSV. Default: Documents\iRacing-tuneup\captures.
.PARAMETER Seconds
  Recording length in timed mode. Default 240 (a race start plus about one lap at most tracks).
.PARAMETER Delay
  Seconds to wait before recording starts in timed mode. Default 15, enough to alt-tab back to the sim.
.PARAMETER Hotkey
  Use hotkey mode instead of timed mode.
.PARAMETER Label
  Short label added to the filename, e.g. "baseline-dry" or "batch2".
.EXAMPLE
  .\Capture-PresentMon.ps1 -Label baseline-dry
  .\Capture-PresentMon.ps1 -Hotkey -Label batch3
#>
[CmdletBinding()]
param(
  [string]$OutDir = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'iRacing-tuneup\captures'),
  [int]$Seconds = 240,
  [int]$Delay = 15,
  [switch]$Hotkey,
  [string]$Label = 'capture',
  [string]$ProcessName = 'iRacingSim64DX11.exe'
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "PresentMon needs Administrator rights for frame tracing. Relaunching elevated (Windows will ask)."
  $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-OutDir',"`"$OutDir`"",'-Seconds',$Seconds,'-Delay',$Delay,'-Label',"`"$Label`"",'-ProcessName',$ProcessName)
  if ($Hotkey) { $args += '-Hotkey' }
  Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait
  exit
}

$exe = Get-ChildItem "$env:ProgramFiles\Intel\PresentMon\PresentMonConsoleApplication" -Filter 'PresentMon*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $exe) { $exe = (Get-Command presentmon -ErrorAction SilentlyContinue).Source }
if (-not $exe) { Write-Error "PresentMon console tool not found. Install with: winget install --id Intel.PresentMon -e"; Read-Host 'Press Enter to close'; exit 1 }

New-Item -ItemType Directory -Force $OutDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $OutDir "pmcap-$Label-$stamp.csv"

$svc = Get-Service PresentMonService -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Running') { try { Start-Service PresentMonService } catch {} }

$pmArgs = @('--process_name', $ProcessName, '--output_file', "`"$out`"", '--stop_existing_session')
if ($Hotkey) {
  $pmArgs += @('--hotkey', 'ALT+SHIFT+F11')
  Write-Host "Hotkey mode. In the sim, press ALT+SHIFT+F11 to START recording and again to STOP. Then close this window."
} else {
  $pmArgs += @('--delay', $Delay, '--timed', $Seconds)
  Write-Host "Timed mode. Recording starts in $Delay s and runs for $Seconds s. Alt-tab back to the sim now."
}
Write-Host "Target: $ProcessName   Output: $out"
& $exe @pmArgs
if (Test-Path $out) {
  $n = (Get-Content $out | Measure-Object -Line).Lines - 1
  Write-Host "`nSaved $n frames to $out"
  if ($n -lt 100) { Write-Host "Very few frames. Was the sim running and on track? The process name must match exactly: $ProcessName" }
} else {
  Write-Host "`nNo CSV was written. Check that the sim was running and that PresentMon had Administrator rights."
}
if (-not $Hotkey) { Start-Sleep -Seconds 3 }
