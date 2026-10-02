<#
.SYNOPSIS
  Shows who is holding dedicated GPU memory right now, per graphics adapter, plus the card's total. Run while the sim is in a session.
.DESCRIPTION
  iRacing sizes its own texture budget (VidMemToUseMB) at roughly 78% of the card and then grows into whatever is free.
  The Windows compositor (dwm) holds memory for every monitor and open window, and overlays (NVIDIA app, Racelab,
  SimHub, Discord) hold more. When the total reaches the card's capacity, the sim stalls on memory: GPU utilisation
  reads ~99% while GPU power drops below what the same card draws when compute-bound. That pattern was decisive in the
  rain test with a full field.
  Reads the GPU performance counters through CIM (class names are not localised, unlike Get-Counter paths) and keeps
  each adapter (LUID) separate, so an iGPU's numbers are never added to the discrete card's.
.PARAMETER MinMB
  Hide processes holding less than this. Default 30.
#>
[CmdletBinding()]
param([int]$MinMB = 30)

$pm = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -ErrorAction SilentlyContinue)
$am = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction SilentlyContinue)
if (-not $pm) { "GPU memory counters are not available on this PC (they need Windows 10 1709+ and a WDDM 2 driver). Use the vendor tool (nvidia-smi, Adrenalin metrics) instead." }
$rows = foreach ($c in $pm) {
  if ($c.Name -match '^pid_(\d+)_luid_(0x[0-9A-Fa-f]+_0x[0-9A-Fa-f]+)') {
    $p = Get-Process -Id $matches[1] -ErrorAction SilentlyContinue
    [pscustomobject]@{ adapter = $matches[2]; process = $(if ($p) { $p.ProcessName } else { 'pid ' + $matches[1] }); pid = [int]$matches[1]; MB = [math]::Round($c.DedicatedUsage/1MB,0) }
  }
}
$adapters = foreach ($grp in ($rows | Group-Object adapter)) {
  $tot = ($am | Where-Object { $_.Name -match [regex]::Escape($grp.Name) } | Measure-Object DedicatedUsage -Sum).Sum
  [pscustomobject]@{ adapter = $grp.Name; inUseMB = $(if ($tot) { [math]::Round($tot/1MB,0) } else { ($grp.Group | Measure-Object MB -Sum).Sum }); processMB = ($grp.Group | Measure-Object MB -Sum).Sum; rows = $grp.Group }
}
$adapters = @($adapters | Sort-Object inUseMB -Descending)
foreach ($ad in $adapters) {
  if ($ad.inUseMB -lt 100 -and $ad -ne $adapters[0]) { "Adapter luid $($ad.adapter): $($ad.inUseMB) MB dedicated in use (integrated or idle adapter; processes not listed)"; continue }
  ""; "Adapter luid $($ad.adapter)$(if ($adapters.Count -gt 1 -and $ad -eq $adapters[0]) { ' (busiest; the discrete GPU while the sim runs)' }): $($ad.inUseMB) MB dedicated in use$(if ($ad.processMB -gt $ad.inUseMB) { " (per-process figures add up to $($ad.processMB) MB because shared surfaces, mostly dwm's, are counted in more than one process; the adapter figure is the real total)" })"
  ($ad.rows | Where-Object { $_.MB -ge $MinMB } | Sort-Object MB -Descending | Select-Object process, pid, MB | Format-Table -AutoSize | Out-String).TrimEnd()
}
if ($adapters.Count -gt 1) { ""; "Totals are per adapter; do not add them together. Compare the busiest adapter with the card's capacity below." }
$smi = (Get-Command nvidia-smi -ErrorAction SilentlyContinue).Source; if (-not $smi -and (Test-Path "$env:windir\System32\nvidia-smi.exe")) { $smi = "$env:windir\System32\nvidia-smi.exe" }
if ($smi) { "nvidia-smi memory used/total: " + (& $smi --query-gpu=memory.used,memory.total --format=csv,noheader) }
else { $vc = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'AMD|Radeon|NVIDIA|Arc' } | Select-Object -First 1; "Adapter: $($vc.Name) (for total VRAM on AMD/Intel, check Adrenalin > Performance > Metrics or Task Manager > GPU; Win32 AdapterRAM is unreliable above 4 GB)" }
