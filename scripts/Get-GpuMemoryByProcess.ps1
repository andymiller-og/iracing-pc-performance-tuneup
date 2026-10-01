<#
.SYNOPSIS
  Shows who is holding dedicated GPU memory right now, plus the card's total. Run while the sim is in a session.
.DESCRIPTION
  iRacing sizes its own texture budget (VidMemToUseMB) at roughly 78% of the card and then grows into whatever is free.
  The Windows compositor (dwm) holds memory for every monitor and open window, and overlays (NVIDIA app, Racelab,
  SimHub, Discord) hold more. When the total reaches the card's capacity, the sim stalls on memory: GPU utilisation
  reads ~99% while GPU power drops below what the same card draws when compute-bound. That pattern was decisive in the
  worked example's rain test.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'SilentlyContinue'
$s = Get-Counter '\GPU Process Memory(*)\Dedicated Usage'
$rows = foreach ($c in $s.CounterSamples) { if ($c.InstanceName -match 'pid_(\d+)') { $p = Get-Process -Id $matches[1]; [pscustomobject]@{ process = $(if ($p) { $p.ProcessName } else { 'pid ' + $matches[1] }); MB = [math]::Round($c.CookedValue/1MB,0) } } }
$rows | Where-Object { $_.MB -gt 30 } | Sort-Object MB -Descending | Format-Table -AutoSize
"Total dedicated in use: $([math]::Round(($rows | Measure-Object MB -Sum).Sum,0)) MB"
$smi = Get-Command nvidia-smi; if (-not $smi -and (Test-Path "$env:windir\System32\nvidia-smi.exe")) { $smi = "$env:windir\System32\nvidia-smi.exe" } else { $smi = $smi.Source }
if ($smi) { "nvidia-smi memory used/total: " + (& $smi --query-gpu=memory.used,memory.total --format=csv,noheader) }
else { $vc = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'AMD|Radeon|NVIDIA' } | Select-Object -First 1; "Adapter: $($vc.Name) (for total VRAM on AMD, check Adrenalin > Performance > Metrics; Win32 AdapterRAM is unreliable above 4 GB)" }
