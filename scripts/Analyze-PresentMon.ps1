<#
.SYNOPSIS
  Summarises a PresentMon per-frame CSV: fps, lows, which side (CPU or GPU) limited each frame, GPU power/clock/VRAM, and a time series.
.DESCRIPTION
  Works with PresentMon 2.x CSVs from either the console tool or the app. Columns that are absent (for example GPU
  power when the PresentMon service is not running) are skipped rather than failing.
  The verdict logic is in references/diagnosis.md; this script only computes the numbers.
.PARAMETER Path
  The capture CSV.
.PARAMETER BucketSeconds
  Width of the time-series buckets. Default 15.
.PARAMETER StartWindowSeconds
  Length of the start window summarised on its own (default 120: grid, start and most of a first lap). Use it to
  compare captures of different lengths; later laps run faster as the field spreads out.
.PARAMETER PowerLimitW
  GPU board power limit (e.g. from nvidia-smi). When given, the script reports how close mean/p99 power sat to it.
.PARAMETER Json
  Emit a JSON object instead of text (for logging into the tune-up record).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [int]$BucketSeconds = 15,
  [int]$StartWindowSeconds = 120,
  [double]$PowerLimitW = 0,
  [switch]$Json
)

if (-not (Test-Path $Path)) { Write-Error "Not found: $Path"; exit 1 }
$sr = New-Object System.IO.StreamReader($Path)
$hdr = $sr.ReadLine().Split(',')
$ix = @{}; for ($i=0; $i -lt $hdr.Length; $i++) { $ix[$hdr[$i]] = $i }
$want = 'TimeInSeconds','MsBetweenPresents','MsCPUBusy','MsCPUWait','MsGPUBusy','MsGPUWait','GPUPower','GPUFrequency','GPUTemperature','GPUUtilization','GPUMemorySizeUsed','GPUMemorySize','CPUUtilization','PresentMode','Application'
$want = $want | Where-Object { $ix.ContainsKey($_) }
$cols = @{}; foreach ($w in $want) { $cols[$w] = New-Object System.Collections.Generic.List[string] }
$n=0
while (($line = $sr.ReadLine()) -ne $null) { $f = $line.Split(','); if ($f.Length -lt $hdr.Length) { continue }; foreach ($w in $want) { $cols[$w].Add($f[$ix[$w]]) }; $n++ }
$sr.Close()
if ($n -lt 50) { Write-Error "Only $n frames in the file; not enough to analyse."; exit 1 }

function ToD($list) { $a = New-Object double[] $list.Count; for($i=0;$i -lt $list.Count;$i++){ $v=$list[$i]; if($v -eq 'NA' -or $v -eq ''){ $a[$i]=[double]::NaN } else { $a[$i]=[double]$v } }; return $a }
function Pct($sorted, $q) { if ($sorted.Count -eq 0) { return [double]::NaN }; return $sorted[[math]::Min($sorted.Count-1,[math]::Floor($sorted.Count*$q))] }
function Stat($a) { $b = @($a | Where-Object { -not [double]::IsNaN($_) } | Sort-Object); if ($b.Count -eq 0) { return $null }; $sum=0; foreach($x in $b){$sum+=$x}; [pscustomobject]@{ n=$b.Count; mean=[math]::Round($sum/$b.Count,2); min=[math]::Round($b[0],2); p1=[math]::Round((Pct $b 0.01),2); p50=[math]::Round((Pct $b 0.5),2); p99=[math]::Round((Pct $b 0.99),2); max=[math]::Round($b[-1],2) } }
function Has($k) { $cols.ContainsKey($k) }

$t = ToD $cols['TimeInSeconds']; $ft = ToD $cols['MsBetweenPresents']
$cpuB = if (Has 'MsCPUBusy') { ToD $cols['MsCPUBusy'] } else { $null }
$cpuW = if (Has 'MsCPUWait') { ToD $cols['MsCPUWait'] } else { $null }
$gpuB = if (Has 'MsGPUBusy') { ToD $cols['MsGPUBusy'] } else { $null }
$gpuW = if (Has 'MsGPUWait') { ToD $cols['MsGPUWait'] } else { $null }
$gpuP = if (Has 'GPUPower') { ToD $cols['GPUPower'] } else { $null }
$gpuF = if (Has 'GPUFrequency') { ToD $cols['GPUFrequency'] } else { $null }
$gpuT = if (Has 'GPUTemperature') { ToD $cols['GPUTemperature'] } else { $null }
$gpuU = if (Has 'GPUUtilization') { ToD $cols['GPUUtilization'] } else { $null }
$vram = if (Has 'GPUMemorySizeUsed') { ToD $cols['GPUMemorySizeUsed'] } else { $null }
$vramTot = if (Has 'GPUMemorySize') { (ToD $cols['GPUMemorySize'] | Where-Object { -not [double]::IsNaN($_) } | Select-Object -First 1) } else { $null }
$cpuU = if (Has 'CPUUtilization') { ToD $cols['CPUUtilization'] } else { $null }

$ftSorted = @($ft | Where-Object { -not [double]::IsNaN($_) } | Sort-Object -Descending)
$avgFps = 1000 / (($ft | Where-Object { -not [double]::IsNaN($_) } | Measure-Object -Average).Average)
$low1 = 1000 / (Pct $ftSorted 0.01); $low01 = 1000 / (Pct $ftSorted 0.001)

# per-frame limiter classification
$gpuBound=0; $cpuBound=0; $neither=0
if ($gpuB -and $cpuB) {
  for($i=0;$i -lt $n;$i++){ if([double]::IsNaN($ft[$i])){continue}; if($gpuB[$i] -ge 0.9*$ft[$i]){ $gpuBound++ } elseif ($cpuB[$i] -ge 0.9*$ft[$i]) { $cpuBound++ } else { $neither++ } }
}
$gpuWaitMean = if ($gpuW) { (Stat $gpuW).mean } else { $null }
$cpuWaitMean = if ($cpuW) { (Stat $cpuW).mean } else { $null }
$verdict = if (-not $gpuB) { 'No GPU timing columns; cannot classify. Re-capture with GPU tracking on.' }
  elseif ($gpuBound -ge 0.75*$n) { 'GPU-bound: the GPU is busy for nearly the whole frame and rarely waits.' }
  elseif ($cpuBound -ge 0.75*$n -and $gpuWaitMean -gt 1.0) { 'CPU-bound: the CPU side fills the frame while the GPU idles part of every frame.' }
  else { 'Balanced / mixed: limiter alternates between CPU and GPU.' }
$reflexNote = 'If NVIDIA Reflex is enabled in-game, MsCPUBusy is inflated to match the GPU (Reflex delays the CPU start), so a GPU-bound capture also shows CPU busy ~= frame time. Trust GPUWait and the GPU-bound count over CPUBusy.'

$powerNote = $null
if ($gpuP -and $PowerLimitW -gt 0) {
  $ps = Stat $gpuP; $pct = [math]::Round(100*$ps.p99/$PowerLimitW,0)
  $clockNote = if ($gpuF) { $fs = Stat $gpuF; " Clock p50 $($fs.p50) MHz, max $($fs.max) MHz." } else { '' }
  $capVerdict = if ($pct -ge 92) { "Likely power-capped (p99 within 8% of the limit); confirm with nvidia-smi clocks_event_reasons.sw_power_cap during a session." } else { "Not power-capped in this capture (p99 at $pct% of the limit)." }
  $powerNote = "GPU power mean $($ps.mean) W, p99 $($ps.p99) W vs limit $PowerLimitW W ($pct% of limit at p99).$clockNote $capVerdict"
}
$modes = ($cols['PresentMode'] | Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join '; '

# start window: same-length comparison between captures of different durations
$maxT = ($t | Measure-Object -Maximum).Maximum
$sw = $null
if ($maxT -gt $StartWindowSeconds) {
  $swFt = @(); for($i=0;$i -lt $n;$i++){ if($t[$i] -lt $StartWindowSeconds -and -not [double]::IsNaN($ft[$i])){ $swFt += $ft[$i] } }
  if ($swFt.Count -ge 50) {
    $swSorted = @($swFt | Sort-Object -Descending)
    $sw = [pscustomobject]@{ seconds=$StartWindowSeconds; frames=$swFt.Count; avgFps=[math]::Round(1000/(($swFt | Measure-Object -Average).Average),1); low1pctFps=[math]::Round(1000/(Pct $swSorted 0.01),1) }
  }
}
$durationWarning = if ($maxT -lt 30) { "Capture is only $([math]::Round($maxT,1)) s long. That is a mis-triggered capture, not a measurement; re-capture from before the lights through at least one lap." } else { $null }

# buckets
$buckets = @()
for($b=0; $b -lt $maxT; $b+=$BucketSeconds){
  $idx = @(); for($i=0;$i -lt $n;$i++){ if($t[$i] -ge $b -and $t[$i] -lt ($b+$BucketSeconds)){ $idx += $i } }
  if($idx.Count -lt 5){continue}
  $fts = @($idx | ForEach-Object { $ft[$_] }) | Sort-Object -Descending
  $m = { param($arr) if (-not $arr) { return $null }; $v = $idx | ForEach-Object { $arr[$_] } | Where-Object { -not [double]::IsNaN($_) }; if ($v) { [math]::Round(($v | Measure-Object -Average).Average,2) } else { $null } }
  $buckets += [pscustomobject]@{ start=$b; frames=$idx.Count; avgFps=[math]::Round(1000/(($fts | Measure-Object -Average).Average),1); p1Fps=[math]::Round(1000/$fts[[math]::Floor($fts.Count*0.01)],1); cpuBusy=(& $m $cpuB); gpuBusy=(& $m $gpuB); gpuWait=(& $m $gpuW); gpuPowerW=(& $m $gpuP); gpuUtil=(& $m $gpuU); gpuMHz=(& $m $gpuF); vramGB=$(if ($vram) { [math]::Round((& $m $vram)/1e9,2) } else { $null }); cpuUtil=(& $m $cpuU); maxFrameMs=[math]::Round($fts[0],1) }
}

$result = [ordered]@{
  file = (Split-Path $Path -Leaf); frames = $n; durationS = [math]::Round($maxT,0); application = ($cols['Application'] | Select-Object -First 1)
  durationWarning = $durationWarning; startWindow = $sw
  avgFps = [math]::Round($avgFps,1); low1pctFps = [math]::Round($low1,1); low01pctFps = [math]::Round($low01,1)
  framesOver16_7ms = ($ftSorted | Where-Object { $_ -gt 16.7 }).Count; framesOver33ms = ($ftSorted | Where-Object { $_ -gt 33.3 }).Count
  frameTimeMs = (Stat $ft); cpuBusyMs = (Stat $cpuB); cpuWaitMs = (Stat $cpuW); gpuBusyMs = (Stat $gpuB); gpuWaitMs = (Stat $gpuW)
  gpuBoundFrames = $gpuBound; cpuBoundFrames = $cpuBound; neitherFrames = $neither
  gpuPowerW = (Stat $gpuP); gpuMHz = (Stat $gpuF); gpuTempC = (Stat $gpuT); gpuUtilPct = (Stat $gpuU)
  vramUsedGB = $(if ($vram) { $s = Stat $vram; [pscustomobject]@{ mean=[math]::Round($s.mean/1e9,2); max=[math]::Round($s.max/1e9,2); totalGB=$(if ($vramTot) { [math]::Round($vramTot/1e9,2) } else { $null }) } } else { $null })
  cpuUtilPct = (Stat $cpuU); presentModes = $modes; verdict = $verdict; reflexNote = $reflexNote; powerNote = $powerNote; buckets = $buckets
}

if ($Json) { $result | ConvertTo-Json -Depth 5; exit }

"File: $($result.file)   frames=$n   duration=$($result.durationS)s   app=$($result.application)"
"Average FPS = $($result.avgFps)   1% low = $($result.low1pctFps)   0.1% low = $($result.low01pctFps)   frames >16.7ms: $($result.framesOver16_7ms)   >33ms: $($result.framesOver33ms)"
if ($durationWarning) { "WARNING: $durationWarning" }
if ($sw) { "Start window (first $($sw.seconds) s, $($sw.frames) frames): average FPS = $($sw.avgFps)   1% low = $($sw.low1pctFps)   (compare this line between captures of different lengths)" }
""
"{0,-16} {1,8} {2,8} {3,8} {4,8} {5,8} {6,8}" -f 'metric','mean','min','p1','p50','p99','max'
foreach ($k in 'frameTimeMs','cpuBusyMs','cpuWaitMs','gpuBusyMs','gpuWaitMs','gpuPowerW','gpuMHz','gpuTempC','gpuUtilPct','cpuUtilPct') { $s = $result[$k]; if ($s) { "{0,-16} {1,8} {2,8} {3,8} {4,8} {5,8} {6,8}" -f $k,$s.mean,$s.min,$s.p1,$s.p50,$s.p99,$s.max } }
if ($result.vramUsedGB) { "VRAM used: mean $($result.vramUsedGB.mean) GB, max $($result.vramUsedGB.max) GB" + $(if ($result.vramUsedGB.totalGB) { " of $($result.vramUsedGB.totalGB) GB" }) }
""
"Limiter per frame (busy >= 90% of frame time): GPU-bound=$gpuBound  CPU-bound=$cpuBound  neither=$neither"
"VERDICT: $verdict"
"Note: $reflexNote"
if ($powerNote) { $powerNote }
"Present modes: $modes   ('Hardware: Independent Flip' or 'Hardware Composed: Independent Flip' = direct to screen, good; 'Composed: Flip' = compositor in the path)"
""
"{0,6} {1,6} {2,7} {3,6} {4,8} {5,8} {6,8} {7,7} {8,7} {9,7} {10,7} {11,7} {12,7}" -f 'start','frames','avgFPS','p1FPS','CPUbusy','GPUbusy','GPUwait','GPU W','GPU%','GPUMHz','VRAM','CPU%','maxFT'
foreach ($bk in $buckets) { "{0,6} {1,6} {2,7} {3,6} {4,8} {5,8} {6,8} {7,7} {8,7} {9,7} {10,7} {11,7} {12,7}" -f $bk.start,$bk.frames,$bk.avgFps,$bk.p1Fps,$bk.cpuBusy,$bk.gpuBusy,$bk.gpuWait,$bk.gpuPowerW,$bk.gpuUtil,$bk.gpuMHz,$bk.vramGB,$bk.cpuUtil,$bk.maxFrameMs }
