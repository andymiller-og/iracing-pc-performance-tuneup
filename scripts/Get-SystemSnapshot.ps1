<#
.SYNOPSIS
  Collects the hardware and Windows facts that matter for iRacing performance, without screenshots or HWiNFO.
.DESCRIPTION
  CPU, RAM speed and channel count, GPU and driver, VRAM and power limit (NVIDIA), monitors from EDID,
  Windows power mode, Memory Integrity (HVCI), hardware-accelerated GPU scheduling, multi-plane overlay state,
  power supply (if the firmware reports it), and a short sample of background CPU and GPU-memory consumers.
.PARAMETER SampleSeconds
  How long to sample background CPU usage. Default 5. Use 0 to skip.
.NOTES
  Read-only. Some items need the sim or other apps to be running to be meaningful (background load, GPU memory).
#>
[CmdletBinding()]
param([int]$SampleSeconds = 5)
$ErrorActionPreference = 'SilentlyContinue'

function Section($t) { ""; "== $t" }

Section 'System'
$cs = Get-CimInstance Win32_ComputerSystem; $os = Get-CimInstance Win32_OperatingSystem; $bios = Get-CimInstance Win32_BIOS
"Model: $($cs.Manufacturer) $($cs.Model)   BIOS: $($bios.SMBIOSBIOSVersion) ($(if ($bios.ReleaseDate) { ([datetime]$bios.ReleaseDate).ToString('yyyy-MM-dd') }))"
"OS: $($os.Caption) build $($os.BuildNumber)   Last boot: $([datetime]$os.LastBootUpTime)"

Section 'CPU'
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
"$($cpu.Name.Trim())   cores=$($cpu.NumberOfCores) threads=$($cpu.NumberOfLogicalProcessors) maxClock=$($cpu.MaxClockSpeed) MHz"
# Hybrid Intel: P-cores have 2 threads, E-cores 1, so threads is neither cores nor 2x cores (Core Ultra 200 has no HT at all).
# A plain i5-12400/13400F-style name is not enough: the 12400/12500/12600 non-K have no E-cores.
$hybrid = $cpu.Manufacturer -match 'Intel' -and (($cpu.NumberOfLogicalProcessors -ne $cpu.NumberOfCores -and $cpu.NumberOfLogicalProcessors -ne 2*$cpu.NumberOfCores) -or $cpu.Name -match 'Core\(TM\) Ultra|Core Ultra')
if ($hybrid) { "Hybrid Intel CPU (P-cores + E-cores): the sim's render thread should sit on a P-core; check per-core load if stutter is reported." }

Section 'Memory'
$dimms = Get-CimInstance Win32_PhysicalMemory
$total = [math]::Round(($dimms | Measure-Object Capacity -Sum).Sum / 1GB, 0)
$speeds = ($dimms | ForEach-Object { "$($_.ConfiguredClockSpeed)/$($_.Speed)" } | Select-Object -Unique) -join ', '
$slots = ($dimms | ForEach-Object { (@($_.BankLabel, $_.DeviceLocator) | Where-Object { $_ }) -join ' ' }) -join '; '
"$total GB total in $(@($dimms).Count) module(s); configured/rated MT/s: $speeds   (equal numbers = running at rated speed)"
"Slots in use: $slots"
"Channel count: not reported by Windows. 1 module = single channel (unless the memory is soldered); 2 or 4 modules in the slots the board manual marks for dual channel (often A2+B2, or labels naming channels A and B) = dual channel."
"Free now: $([math]::Round($os.FreePhysicalMemory/1MB,1)) GB"

Section 'GPU'
$gpus = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Virtual|Basic Display|Meta' }
foreach ($g in $gpus) { "$($g.Name)   driver $($g.DriverVersion)$(if ($g.DriverDate) { ' (' + ([datetime]$g.DriverDate).ToString('yyyy-MM-dd') + ')' })" }
$smi = (Get-Command nvidia-smi).Source; if (-not $smi -and (Test-Path "$env:windir\System32\nvidia-smi.exe")) { $smi = "$env:windir\System32\nvidia-smi.exe" }
if ($smi) {
  "nvidia-smi: " + (& $smi --query-gpu=name,driver_version,memory.total,memory.used,power.limit,power.max_limit,clocks.max.graphics,pcie.link.gen.current,pcie.link.width.current --format=csv,noheader)
  "throttle reasons now: " + (& $smi --query-gpu=clocks_event_reasons.sw_power_cap,clocks_event_reasons.hw_slowdown,clocks_event_reasons.sw_thermal_slowdown --format=csv,noheader) + "  (power cap / hw slowdown / thermal)"
}
$hags = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name HwSchMode).HwSchMode
"Hardware-accelerated GPU scheduling: " + $(switch ($hags) { 2 {'On'} 1 {'Off'} default {'default/unknown'} })
$mpo = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Name OverlayTestMode -ErrorAction SilentlyContinue).OverlayTestMode
$mpoStray = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\Dxgkrnl' -Name OverlayTestMode -ErrorAction SilentlyContinue).OverlayTestMode
"Multi-plane overlay: " + $(if ($mpo -eq 5) {'Dwm OverlayTestMode=5 is set (requested off; confirm with the capture present mode, newer Windows builds may ignore it)'} else {'enabled (Windows default)'})
if ($null -ne $mpoStray) { "  Note: OverlayTestMode is also set under ...\Windows\Dxgkrnl, which has no effect and can be deleted." }

Section 'Monitors (from EDID)'
$ids = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID
$params = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams
foreach ($m in $ids) {
  $name = -join ($m.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
  $mfg  = -join ($m.ManufacturerName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })
  $p = $params | Where-Object { $_.InstanceName -eq $m.InstanceName }
  $diag = if ($p) { [math]::Round([math]::Sqrt([math]::Pow($p.MaxHorizontalImageSize,2) + [math]::Pow($p.MaxVerticalImageSize,2)) / 2.54, 1) } else { '?' }
  "$mfg $name   ~$diag in diagonal (EDID size $($p.MaxHorizontalImageSize)x$($p.MaxVerticalImageSize) cm; some monitors report a bogus 16x9)"
}
$vc = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution } | Select-Object -First 1
if ($vc) { "Primary desktop mode: $($vc.CurrentHorizontalResolution)x$($vc.CurrentVerticalResolution) @ $($vc.CurrentRefreshRate) Hz (confirm each panel's refresh in Settings > Display > Advanced; EDID mode lists are unreliable)" }
"Note: EDID names can differ from retail names (model codes rather than marketing names). EDID gives the active picture size, not the outer monitor width. Look up the model's spec sheet; see references/monitor-geometry.md."

Section 'Windows power and security'
$scheme = (powercfg /getactivescheme) -replace '.*\((.*)\).*','$1'
$pk = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'
$onBattery = [bool](Get-CimInstance Win32_Battery | Where-Object { $_.BatteryStatus -eq 1 })   # 1 = discharging
$ov = if ($onBattery) { $pk.ActiveOverlayDcPowerScheme } else { $pk.ActiveOverlayAcPowerScheme }
$mode = if ($null -eq $ov) { 'not set (Windows treats that as Balanced)' } elseif ($ov -eq 'ded574b5-45a0-4f42-8737-46345c09c238') { 'Best performance' } elseif ($ov -eq '961cc777-2547-4f9d-8174-7d86181b8a7a') { 'Best power efficiency' } elseif ($ov -eq '00000000-0000-0000-0000-000000000000') { 'Balanced' } else { "unknown overlay $ov" }
$mode += if ($onBattery) { ' (on battery: plug in before measuring)' } else { '' }
"Power plan: $scheme   Power mode overlay: $mode   (Windows 11 reports 'Balanced' as the plan even when the mode is Best performance; the overlay is what matters)"
$dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard
$hvci = if ($dg.SecurityServicesRunning -contains 2) {'ON (running)'} else {'off'}
"Memory Integrity (HVCI): $hvci   VBS status: $($dg.VirtualizationBasedSecurityStatus) (2 = running)"
"Game Mode: " + $(if ((Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -Name AutoGameModeEnabled).AutoGameModeEnabled -eq 0) {'off'} else {'on (default)'})

Section 'Power supply (firmware record, often absent on OEM PCs)'
try {
  $raw = (Get-CimInstance -Namespace root\wmi -ClassName MSSmBios_RawSMBiosTables).SMBiosData
  $i = 0; $found = $false
  while ($i -lt $raw.Length - 4) {
    $type = $raw[$i]; $len = $raw[$i+1]; if ($len -lt 4) { break }
    $j = $i + $len; while ($j -lt $raw.Length - 1 -and -not ($raw[$j] -eq 0 -and $raw[$j+1] -eq 0)) { $j++ }; $j += 2
    if ($type -eq 39) { $found = $true; $cap = [BitConverter]::ToUInt16($raw, $i + 0x0C); "Max power capacity: " + $(if ($cap -eq 0x8000) {'unknown'} else {"$cap W"}) }
    if ($type -eq 127) { break }; $i = $j
  }
  if (-not $found) { "Not reported by firmware. Ask the user to read the PSU label or the BIOS System Information page, or check the original order sheet. Do not infer it from the GPU model." }
} catch { "Could not read SMBIOS." }

Section 'Storage (sim drive)'
$installDir = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\iRacing.com Motorsport Simulations\iRacing').InstallDir
if (-not $installDir) { $installDir = "${env:ProgramFiles(x86)}\iRacing" }
if (Test-Path $installDir) {
  $drive = (Get-Item $installDir).PSDrive.Name
  $ld = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($drive):'"
  "Sim on $($drive): $([math]::Round($ld.FreeSpace/1GB,0)) GB free of $([math]::Round($ld.Size/1GB,0)) GB"
} else { "Sim install folder not found ($installDir); storage not checked." }
$docs = [Environment]::GetFolderPath('MyDocuments'); $tel = Get-ChildItem (Join-Path $docs 'iRacing\telemetry') -File
if ($tel) { "Telemetry folder: $($tel.Count) files, $([math]::Round(($tel | Measure-Object Length -Sum).Sum/1GB,1)) GB (auto-logging grows this; housekeeping item, not performance)" }

if ($SampleSeconds -gt 0) {
  Section "Background load ($SampleSeconds s sample; 1000 ms/s = one full core)"
  $p0 = @{}; foreach ($p in Get-Process) { try { $p0[$p.Id] = $p.TotalProcessorTime.TotalMilliseconds } catch {} }
  Start-Sleep -Seconds $SampleSeconds
  $prow = foreach ($p in Get-Process) { try { if ($p0.ContainsKey($p.Id)) { [pscustomobject]@{ name=$p.ProcessName; pid=$p.Id; cpu_ms_per_s=[math]::Round(($p.TotalProcessorTime.TotalMilliseconds - $p0[$p.Id])/$SampleSeconds,0) } } } catch {} }
  $prow | Where-Object { $_.cpu_ms_per_s -ge 30 } | Sort-Object cpu_ms_per_s -Descending | Select-Object -First 15 | Format-Table -AutoSize | Out-String
  "Total CPU: $((Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average)%"
}

Section 'GPU dedicated memory by process (MB), busiest adapter'
# CIM class names are not localised (Get-Counter paths are); instances are per adapter LUID, so iGPU and dGPU stay apart
$pm = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory)
$am = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory)
$rows = foreach ($c in $pm) { if ($c.Name -match '^pid_(\d+)_luid_(0x[0-9A-Fa-f]+_0x[0-9A-Fa-f]+)') { $pp = Get-Process -Id $matches[1]; [pscustomobject]@{ adapter = $matches[2]; process = $(if ($pp) { $pp.ProcessName } else { 'pid ' + $matches[1] }); MB = [math]::Round($c.DedicatedUsage/1MB,0) } } }
$ads = @($am | Where-Object { $_.Name -match 'luid_(0x[0-9A-Fa-f]+_0x[0-9A-Fa-f]+)' } | ForEach-Object { [pscustomobject]@{ adapter = $matches[1]; MB = [math]::Round($_.DedicatedUsage/1MB,0) } } | Sort-Object MB -Descending)
if (-not $ads -and $rows) { $ads = @($rows | Group-Object adapter | ForEach-Object { [pscustomobject]@{ adapter = $_.Name; MB = ($_.Group | Measure-Object MB -Sum).Sum } } | Sort-Object MB -Descending) }
if ($ads) {
  $top = $ads[0].adapter
  $rows | Where-Object { $_.adapter -eq $top -and $_.MB -gt 50 } | Sort-Object MB -Descending | Select-Object process, MB | Format-Table -AutoSize | Out-String
  "Dedicated in use: " + (($ads | ForEach-Object { "adapter $($_.adapter) $($_.MB) MB" }) -join '; ') + $(if ($ads.Count -gt 1) { ' (separate adapters; do not add them)' })
  "Per-process figures overlap (dwm also counts surfaces it shares with other windows), so use the adapter figure as the total. 'dwm' is the Windows compositor: it grows with monitor count and open windows and is not reclaimable by the sim."
} else { "GPU memory counters not available on this PC (need Windows 10 1709+ and a WDDM 2 driver)." }
