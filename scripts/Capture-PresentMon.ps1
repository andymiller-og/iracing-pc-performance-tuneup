<#
.SYNOPSIS
  Records a per-frame PresentMon capture of the iRacing sim and saves the CSV where the tune-up can analyse it.
.DESCRIPTION
  Uses Intel PresentMon's console tool. PresentMon needs Administrator rights for ETW tracing, so this script relaunches
  itself elevated if needed (Windows will ask for consent). Two modes:
    -Delay/-Seconds : start after a countdown and stop after N seconds. Good for "grid up, start script, drive".
    -Hotkey         : press the hotkey in the sim to start and again to stop (default ALT+SHIFT+F11), then Ctrl+C.
  The output path is fixed before elevating and printed first, with the expected run time. When the capture ends, the
  script that did the work writes <csv>.status.json (status, exitCode, frames, message); the calling window reads it,
  prints a CAPTURE RESULT line and exits with the same code, so a calling agent learns the result even though the
  elevated window was separate. Exit codes: 0 ok, 1 PresentMon not found, 2 no CSV written, 3 fewer than 100 frames,
  4 elevation declined, 5 no status reported (elevated window closed early).
  Analyse the CSV with Analyze-PresentMon.ps1.
.PARAMETER OutDir
  Folder for the CSV. Default: Documents\iRacing-tuneup\captures.
.PARAMETER OutFile
  Exact CSV path instead of OutDir + generated name.
.PARAMETER Seconds
  Recording length in timed mode. Default 240 (a race start plus about one lap at most tracks).
.PARAMETER Delay
  Seconds to wait before recording starts in timed mode. Default 15, enough to alt-tab back to the sim.
.PARAMETER Hotkey
  Use hotkey mode instead of timed mode.
.PARAMETER Label
  Short label added to the filename, e.g. "baseline-dry" or "batch2".
.PARAMETER ProcessName
  Executable to record. Default iRacingSim64DX11.exe.
.EXAMPLE
  .\Capture-PresentMon.ps1 -Label baseline-dry
  .\Capture-PresentMon.ps1 -Hotkey -Label batch3
#>
[CmdletBinding()]
param(
  [string]$OutDir = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'iRacing-tuneup\captures'),
  [string]$OutFile,
  [int]$Seconds = 240,
  [int]$Delay = 15,
  [switch]$Hotkey,
  [string]$Label = 'capture',
  [string]$ProcessName = 'iRacingSim64DX11.exe',
  [switch]$Elevated   # internal: set on the elevated relaunch
)

$out = if ($OutFile) { $OutFile } else { Join-Path $OutDir "pmcap-$Label-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv" }
$out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($out); $statusFile = "$out.status.json"
function Write-Status($status, $code, $frames, $msg) {
  [ordered]@{ status=$status; exitCode=$code; frames=$frames; outFile=$out; message=$msg; finished=(Get-Date).ToString('s') } | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding ASCII
}

if (-not $Elevated) {
  # say up front how long this takes, so a calling agent can set its tool timeout
  if ($Hotkey) { Write-Host "Expected duration: open-ended (hotkey mode ends when the user stops PresentMon with Ctrl+C), plus the UAC prompt." }
  else { Write-Host "Expected duration: about $($Delay + $Seconds + 10) s ($Delay s delay + $Seconds s recording + ~10 s start/stop), plus the time to accept the UAC prompt. Set any tool timeout above $($Delay + $Seconds + 70) s." }
  Write-Host "Output: $out"
  Write-Host "Status: $statusFile"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "PresentMon needs Administrator rights for frame tracing. Relaunching elevated (Windows will ask)."
  New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
  Remove-Item -LiteralPath $statusFile -ErrorAction SilentlyContinue
  # Start-Process joins these with spaces, so paths carry their own quotes (and no trailing backslash before a quote)
  $relaunch = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-OutFile',"`"$out`"",'-Seconds',$Seconds,'-Delay',$Delay,'-Label',"`"$Label`"",'-ProcessName',"`"$ProcessName`"",'-Elevated')
  if ($Hotkey) { $relaunch += '-Hotkey' }
  try { Start-Process -FilePath 'powershell.exe' -ArgumentList $relaunch -Verb RunAs -Wait -ErrorAction Stop }
  catch { Write-Host "CAPTURE RESULT: status=elevation-declined exitCode=4 ($($_.Exception.Message))"; exit 4 }
  if (-not (Test-Path -LiteralPath $statusFile)) { Write-Host "CAPTURE RESULT: status=no-status exitCode=5 (the elevated window closed before reporting; check $out)"; exit 5 }
  $st = Get-Content -LiteralPath $statusFile -Raw | ConvertFrom-Json
  Write-Host "CAPTURE RESULT: status=$($st.status) exitCode=$($st.exitCode) frames=$($st.frames) file=$($st.outFile)"
  if ($st.message) { Write-Host $st.message }
  exit [int]$st.exitCode
}

$exe = Get-ChildItem "$env:ProgramFiles\Intel\PresentMon\PresentMonConsoleApplication" -Filter 'PresentMon*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $exe) { $exe = (Get-Command presentmon -ErrorAction SilentlyContinue).Source }
if (-not $exe) {
  $msg = "PresentMon console tool not found. Install with: winget install --id Intel.PresentMon -e"
  Write-Error $msg; Write-Status 'presentmon-missing' 1 0 $msg
  if ($Elevated) { Start-Sleep -Seconds 8 }; exit 1
}

New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
$svc = Get-Service PresentMonService -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Running') { try { Start-Service PresentMonService } catch {} }

# Pass the path as its own argument: PowerShell adds quotes when it has spaces (embedded quotes break on PS 7.3+)
$pmArgs = @('--process_name', $ProcessName, '--output_file', $out, '--stop_existing_session')
if ($Hotkey) {
  $pmArgs += @('--hotkey', 'ALT+SHIFT+F11')
  Write-Host "Hotkey mode. In the sim, press ALT+SHIFT+F11 to START recording and again to STOP. Then press Ctrl+C in this window to finish."
} else {
  # without --terminate_after_timed (PresentMon 2.x), PresentMon keeps running after the timed capture and this script never returns
  $pmArgs += @('--delay', $Delay, '--timed', $Seconds, '--terminate_after_timed')
  Write-Host "Timed mode. Recording starts in $Delay s and runs for $Seconds s. Alt-tab back to the sim now."
}
Write-Host "Target: $ProcessName   Output: $out"
$code = 2; $n = 0; $msg = ''
try {
  & $exe @pmArgs
} finally {
  # runs on Ctrl+C too, so hotkey captures also report back
  if (Test-Path -LiteralPath $out) {
    $n = (Get-Content -LiteralPath $out | Measure-Object -Line).Lines - 1
    Write-Host "`nSaved $n frames to $out"
    if ($n -lt 100) { $code = 3; $msg = "Very few frames ($n). Was the sim running and on track? The process name must match exactly: $ProcessName"; Write-Host $msg } else { $code = 0 }
  } else {
    $msg = "No CSV was written. Check that the sim was running and that PresentMon had Administrator rights."; Write-Host "`n$msg"
  }
  $stName = switch ($code) { 0 {'ok'} 3 {'few-frames'} default {'no-csv'} }
  Write-Status $stName $code $n $msg
  if ($Elevated) { Start-Sleep -Seconds 3 } else { Write-Host "CAPTURE RESULT: status=$stName exitCode=$code frames=$n file=$out" }
}
exit $code
