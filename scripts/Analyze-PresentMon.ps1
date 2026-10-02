<#
.SYNOPSIS
  Summarises a PresentMon per-frame CSV: fps, lows, pacing, which side (CPU or GPU) limited each frame, GPU power/clock/VRAM, and a time series.
.DESCRIPTION
  Works with PresentMon 2.x CSVs from either the app (TimeInSeconds + Ms* columns) or the console tool (CPUStartTime
  + Ms* columns), and with short-name variants (FrameTime, CPUBusy, GPUBusy, ...). The detected column set is printed.
  Columns that are absent (for example GPU power when the PresentMon service is not running) are skipped rather than
  failing; if the frame-time column is missing the script says so and stops. Time is re-based to start at 0. Rows from
  other processes (dwm, overlays) are dropped and counted. NA / nan / inf / empty cells count as missing. A
  semicolon-separated file with comma decimals (re-saved by Excel in a comma-decimal locale) is detected and parsed.
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
.PARAMETER TargetHz
  Frame-rate target (e.g. 90 for a VR headset, 144 for a capped panel). When given, the script reports how many frames
  (count and %) took more than 2% longer than the 1000/TargetHz ms budget.
.PARAMETER Process
  Application to analyse (e.g. iRacingSim64DX11.exe; '.exe' optional). Default: iRacingSim64DX11.exe if present, else
  the most common Application in the file.
.PARAMETER Json
  Emit a JSON object instead of text (for logging into the tune-up record).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [int]$BucketSeconds = 15,
  [int]$StartWindowSeconds = 120,
  [double]$PowerLimitW = 0,
  [double]$TargetHz = 0,
  [string]$Process = '',
  [switch]$Json
)

if (-not (Test-Path -LiteralPath $Path)) { Write-Error "Not found: $Path"; exit 1 }
$inv = [Globalization.CultureInfo]::InvariantCulture
$sr = New-Object System.IO.StreamReader((Resolve-Path -LiteralPath $Path).ProviderPath)
$first = $sr.ReadLine(); $peek = $sr.ReadLine()
if ($null -eq $first -or $null -eq $peek) { $sr.Close(); Write-Error "$Path is empty or has no data rows."; exit 1 }

# separator and decimal mark: PresentMon writes ',' and '.'; Excel in a comma-decimal locale re-saves as ';' and ','
$sep = ','; $commaDec = $false; $unquote = $first.Contains('"'); $formatNote = $null
if ($first -notmatch ',' -and $first -match ';') {
  $sep = ';'; $commaDec = $peek -match '\d,\d'
  $formatNote = if ($commaDec) { "Semicolon-separated file with comma decimals (re-saved by Excel in a comma-decimal locale); parsed as such. Prefer the original PresentMon CSV: Excel can round or reformat values." } else { "Semicolon-separated file; parsed with '.' decimals." }
} elseif ($first -notmatch ',' -and $first -match "`t") { $sep = "`t" }
$hdr = @($first.Replace('"','').Split($sep) | ForEach-Object { $_.Trim() })
$ix = @{}; for ($i=0; $i -lt $hdr.Length; $i++) { if (-not $ix.ContainsKey($hdr[$i])) { $ix[$hdr[$i]] = $i } }

# column aliases, first match wins: app = TimeInSeconds + Ms*, console 2.x = CPUStartTime + Ms*, short names = FrameTime/CPUBusy/...
function Pick([string[]]$names) { foreach ($nm in $names) { if ($ix.ContainsKey($nm)) { return $nm } }; return $null }
$map = [ordered]@{
  t = (Pick 'TimeInSeconds','CPUStartTime','CPUStartQPCTime','CPUStartQPC','CPUStartDateTime')
  ft = (Pick 'MsBetweenPresents','FrameTime','MsBetweenAppStart')
  cpuB = (Pick 'MsCPUBusy','CPUBusy'); cpuW = (Pick 'MsCPUWait','CPUWait')
  gpuB = (Pick 'MsGPUBusy','GPUBusy'); gpuW = (Pick 'MsGPUWait','GPUWait')
  disp = (Pick 'MsBetweenDisplayChange','DisplayedTime')
  gpuP = (Pick 'GPUPower'); gpuF = (Pick 'GPUFrequency'); gpuT = (Pick 'GPUTemperature'); gpuU = (Pick 'GPUUtilization')
  vram = (Pick 'GPUMemorySizeUsed'); vramTot = (Pick 'GPUMemorySize'); cpuU = (Pick 'CPUUtilization')
}
$columnSet = if ($ix.ContainsKey('FrameTime') -or $ix.ContainsKey('CPUBusy') -or $ix.ContainsKey('GPUBusy')) { 'short-name variant (FrameTime / CPUBusy / GPUBusy)' }
  elseif ($ix.ContainsKey('MsCPUBusy') -or $ix.ContainsKey('MsGPUBusy')) { if ($ix.ContainsKey('TimeInSeconds')) { 'PresentMon 2.x app format (TimeInSeconds + Ms* metrics)' } else { 'PresentMon 2.x console format (CPUStart* time + Ms* metrics)' } }
  elseif ($ix.ContainsKey('MsBetweenPresents')) { 'PresentMon 1.x / --v1_metrics format (no CPU/GPU busy columns)' }
  else { 'unrecognised' }
if (-not $map.ft) { $sr.Close(); Write-Error ("Verdict unavailable: no frame-time column (looked for MsBetweenPresents, FrameTime, MsBetweenAppStart), so fps, lows and the limiter cannot be computed. Column set: $columnSet. Header: " + ($hdr -join ',')); exit 2 }

# read: keep the wanted cells as strings (cheap), convert each column in one go afterwards
$keys = @($map.Keys | Where-Object { $map[$_] }); $nc = $keys.Count
$ci = New-Object int[] $nc; $S = New-Object 'System.Collections.Generic.List[string][]' $nc
for ($j=0; $j -lt $nc; $j++) { $ci[$j] = $ix[$map[$keys[$j]]]; $S[$j] = New-Object System.Collections.Generic.List[string] }
$ai = if ($ix.ContainsKey('Application')) { $ix['Application'] } else { -1 }
$pi = if ($ix.ContainsKey('PresentMode')) { $ix['PresentMode'] } else { -1 }
$appS = New-Object System.Collections.Generic.List[string]; $pmS = New-Object System.Collections.Generic.List[string]
$nh = $hdr.Length; $short = 0; $line = $peek
while ($null -ne $line) {
  if ($unquote) { $line = $line.Replace('"','') }; if ($commaDec) { $line = $line.Replace(',','.') }
  $f = $line.Split($sep)
  if ($f.Length -lt $nh) { if ($line.Trim()) { $short++ }; $line = $sr.ReadLine(); continue }
  for ($j=0; $j -lt $nc; $j++) { $S[$j].Add($f[$ci[$j]]) }
  if ($ai -ge 0) { $appS.Add($f[$ai]) }; if ($pi -ge 0) { $pmS.Add($f[$pi]) }
  $line = $sr.ReadLine()
}
$sr.Close()
$nRaw = $S[0].Count
if ($nRaw -eq 0) { Write-Error "No complete data rows in $Path."; exit 1 }
# invariant-culture numbers; NA, '', nan, -nan(ind), inf -> NaN (a whole-column cast is fast; fall back per cell on any bad token)
$sty = [Globalization.NumberStyles]::Float; $nan = [double]::NaN; $big = [double]::MaxValue
function ToD($list) {
  $s = $list.ToArray()
  if ([Array]::IndexOf($s, '') -lt 0) { try { $a = [double[]]$s; if (-not [double]::IsInfinity([Linq.Enumerable]::Sum($a))) { return ,$a } } catch { } }
  $a = New-Object double[] $s.Length; $d = 0.0
  for ($i=0; $i -lt $s.Length; $i++) { if ([double]::TryParse($s[$i], $sty, $inv, [ref]$d) -and $d -le $big -and $d -ge -$big) { $a[$i] = $d } else { $a[$i] = $nan } }
  return ,$a
}
$D = @{}; for ($j=0; $j -lt $nc; $j++) { $D[$keys[$j]] = ToD $S[$j]; $S[$j] = $null }

# process filter: -Process, else the sim, else the most common Application
$sel = -1; $appName = $null; $appNames = @(); $appCnt = @(); $rowApp = $null
if ($ai -ge 0) {
  $appArr = $appS.ToArray(); $appNames = @([Linq.Enumerable]::Distinct([string[]]$appArr))
  if ($appNames.Count -eq 1) { $appCnt = @($nRaw) }
  else {
    $aid = New-Object 'System.Collections.Generic.Dictionary[string,int]'; for ($k=0; $k -lt $appNames.Count; $k++) { $aid[$appNames[$k]] = $k }
    $appCnt = New-Object int[] $appNames.Count; $rowApp = New-Object int[] $nRaw
    for ($i=0; $i -lt $nRaw; $i++) { $v = $aid[$appArr[$i]]; $rowApp[$i] = $v; $appCnt[$v]++ }
  }
  if ($Process) {
    for ($k=0; $k -lt $appNames.Count; $k++) { if ($appNames[$k] -eq $Process -or $appNames[$k] -eq "$Process.exe") { $sel = $k; break } }
    if ($sel -lt 0) { Write-Error ("Process '$Process' is not in the file. Applications present: " + ((0..($appNames.Count-1) | ForEach-Object { "$($appNames[$_])=$($appCnt[$_])" }) -join '; ')); exit 2 }
  } else {
    for ($k=0; $k -lt $appNames.Count; $k++) { if ($appNames[$k] -eq 'iRacingSim64DX11.exe') { $sel = $k; break } }
    if ($sel -lt 0) { for ($k=0; $k -lt $appNames.Count; $k++) { if ($appNames[$k] -match '^iRacingSim') { $sel = $k; break } } }
    if ($sel -lt 0) { $sel = 0; for ($k=1; $k -lt $appNames.Count; $k++) { if ($appCnt[$k] -gt $appCnt[$sel]) { $sel = $k } } }
  }
  $appName = $appNames[$sel]
}
$ftRaw = $D['ft']; $kidx = $null; $nanFt = 0
if ($null -ne $rowApp -or [double]::IsNaN([Linq.Enumerable]::Sum($ftRaw)) -or [Linq.Enumerable]::Min($ftRaw) -le 0) {
  $kidx = New-Object System.Collections.Generic.List[int]
  for ($i=0; $i -lt $nRaw; $i++) { if ($null -ne $rowApp -and $rowApp[$i] -ne $sel) { continue }; if ($ftRaw[$i] -gt 0) { $kidx.Add($i) } else { $nanFt++ } }
}
$n = if ($null -ne $kidx) { $kidx.Count } else { $nRaw }
$otherApps = @(0..([math]::Max(0,$appNames.Count-1)) | Where-Object { $appNames.Count -gt 1 -and $_ -ne $sel } | Sort-Object { -$appCnt[$_] } | ForEach-Object { "$($appNames[$_])=$($appCnt[$_])" })
$droppedOther = if ($sel -ge 0) { $nRaw - $appCnt[$sel] } else { 0 }
$rowsNote = $null
if ($droppedOther -gt 0 -or $nanFt -gt 0 -or $short -gt 0) {
  $parts = @(); if ($droppedOther -gt 0) { $parts += "$droppedOther from other processes ($($otherApps -join ', '))" }; if ($nanFt -gt 0) { $parts += "$nanFt with no frame time" }; if ($short -gt 0) { $parts += "$short short/malformed lines" }
  $rowsNote = "Kept $n of $nRaw rows for $(if ($appName) { $appName } else { 'the file' }); dropped " + ($parts -join '; ') + '.'
}
if ($n -lt 50) { Write-Error "Only $n usable frames$(if ($appName) { " for $appName" }) in the file; not enough to analyse.$(if ($rowsNote) { " $rowsNote" })"; exit 1 }
if ($null -ne $kidx) { foreach ($k in @($D.Keys)) { $src = $D[$k]; $a = New-Object double[] $n; for ($i=0; $i -lt $n; $i++) { $a[$i] = $src[$kidx[$i]] }; $D[$k] = $a } }
function Col($k) { if ($D.ContainsKey($k)) { return ,$D[$k] } else { return $null } }
$t = Col 't'; $ft = Col 'ft'; $cpuB = Col 'cpuB'; $cpuW = Col 'cpuW'; $gpuB = Col 'gpuB'; $gpuW = Col 'gpuW'; $disp = Col 'disp'
$gpuP = Col 'gpuP'; $gpuF = Col 'gpuF'; $gpuT = Col 'gpuT'; $gpuU = Col 'gpuU'; $vram = Col 'vram'; $cpuU = Col 'cpuU'
$vramTot = $null; $vt = Col 'vramTot'; if ($vt) { foreach ($x in $vt) { if ($x -eq $x) { $vramTot = $x; break } } }
# a column that is present but all NA counts as absent
foreach ($k in 't','cpuB','cpuW','gpuB','gpuW','disp','gpuP','gpuF','gpuT','gpuU','vram','cpuU') { $a = Col $k; if ($a) { $ok = $false; foreach ($x in $a) { if ($x -eq $x) { $ok = $true; break } }; if (-not $ok) { Set-Variable -Name $k -Value $null } } }

function Pct($sorted, $q) { if ($sorted.Count -eq 0) { return [double]::NaN }; return $sorted[[math]::Min($sorted.Count-1,[math]::Floor($sorted.Count*$q))] }
function Stat($a) {
  if ($null -eq $a) { return $null }; $b = [double[]]$a.Clone(); [Array]::Sort($b)   # NaN sorts first
  $k = 0; while ($k -lt $b.Length -and [double]::IsNaN($b[$k])) { $k++ }; if ($k -ge $b.Length) { return $null }
  if ($k -gt 0) { $c = New-Object double[] ($b.Length-$k); [Array]::Copy($b, $k, $c, 0, $c.Length); $b = $c }
  $sum = [Linq.Enumerable]::Sum($b)
  [pscustomobject]@{ n=$b.Count; mean=[math]::Round($sum/$b.Count,2); min=[math]::Round($b[0],2); p1=[math]::Round((Pct $b 0.01),2); p50=[math]::Round((Pct $b 0.5),2); p99=[math]::Round((Pct $b 0.99),2); max=[math]::Round($b[-1],2) }
}
function LB($a, $v, $lo, $hi) { while ($lo -lt $hi) { $m = ($lo + $hi) -shr 1; if ($a[$m] -lt $v) { $lo = $m + 1 } else { $hi = $m } }; $lo }   # first index with a[i] >= v
function UB($a, $v, $lo, $hi) { while ($lo -lt $hi) { $m = ($lo + $hi) -shr 1; if ($a[$m] -le $v) { $lo = $m + 1 } else { $hi = $m } }; $lo }   # first index with a[i] > v

# time base: re-base to 0; detect s vs ms from the frame-time sum; rebuild from frame times if unusable
$sumFt = [Linq.Enumerable]::Sum($ft); $timeNote = $null; $timeCol = $map.t; $timeUnit = 's'
$t0 = [double]::PositiveInfinity; $t1 = [double]::NegativeInfinity; $tValid = 0
if ($t) {
  if (-not [double]::IsNaN([Linq.Enumerable]::Sum($t))) { $tValid = $n; $t0 = [Linq.Enumerable]::Min($t); $t1 = [Linq.Enumerable]::Max($t) }
  else { foreach ($x in $t) { if ($x -eq $x) { $tValid++; if ($x -lt $t0) { $t0 = $x }; if ($x -gt $t1) { $t1 = $x } } } }
}
$scale = 1.0; $rebuild = $false
if (-not $t -or $tValid -lt 0.9*$n -or $t1 -le $t0) { $rebuild = $true; $timeNote = "No usable time column (looked for TimeInSeconds, CPUStartTime, CPUStartQPCTime); time rebuilt from cumulative frame times." }
else {
  $ratio = ($t1 - $t0) / ($sumFt / 1000)
  if ($ratio -ge 500 -and $ratio -le 2000) { $scale = 0.001; $timeUnit = 'ms' }
  elseif ($ratio -lt 0.5 -or $ratio -gt 2) { $rebuild = $true; $timeNote = "Time column $timeCol does not match the frame times (span / frame-time sum = $([math]::Round($ratio,2))); time rebuilt from cumulative frame times." }
}
if ($rebuild) { $t = New-Object double[] $n; $acc = 0.0; for ($i=0; $i -lt $n; $i++) { $t[$i] = $acc / 1000; $acc += $ft[$i] }; $timeCol = '(cumulative frame time)'; $t1 = $t[$n-1] }
elseif ($t0 -ne 0 -or $scale -ne 1) { for ($i=0; $i -lt $n; $i++) { $t[$i] = ($t[$i] - $t0) * $scale }; $t1 = ($t1 - $t0) * $scale }
$maxT = [math]::Max(0.0, $t1)
# time-sorted view: ranges of it give the start window and the buckets (an identity view for normal, time-ordered files)
$ts = [double[]]$t.Clone(); [Array]::Sort($ts); $order = $null
if (-not [Linq.Enumerable]::SequenceEqual($t, $ts)) { $ts = [double[]]$t.Clone(); $order = [int[]](0..($n-1)); [Array]::Sort($ts, $order) }
$tStart = 0; while ($tStart -lt $n -and [double]::IsNaN($ts[$tStart])) { $tStart++ }
function Slice($arr, $a, $b) { $r = New-Object double[] ($b - $a); if ($null -eq $order) { [Array]::Copy($arr, $a, $r, 0, $b - $a) } else { for ($i=$a; $i -lt $b; $i++) { $r[$i-$a] = $arr[$order[$i]] } }; return ,$r }
function MeanR($arr, $a, $b) {
  if ($null -eq $arr) { return $null }; $s = Slice $arr $a $b; $sum = [Linq.Enumerable]::Sum($s)
  if (-not [double]::IsNaN($sum)) { return [math]::Round($sum / $s.Length, 2) }
  $sum = 0.0; $c = 0; foreach ($v in $s) { if ($v -eq $v) { $sum += $v; $c++ } }; if ($c) { return [math]::Round($sum / $c, 2) }; return $null
}

# fps, lows, threshold counts, pacing
$budget = if ($TargetHz -gt 0) { 1000 / $TargetHz } else { 0 }; $budgetTol = 1.02 * $budget   # 2% slack so timer jitter at a cap is not counted
$ftAsc = [double[]]$ft.Clone(); [Array]::Sort($ftAsc); $ftSorted = [double[]]$ftAsc.Clone(); [Array]::Reverse($ftSorted)
$over16 = $n - (UB $ftAsc 16.7 0 $n); $over33 = $n - (UB $ftAsc 33.3 0 $n); $overB = if ($budget -gt 0) { $n - (UB $ftAsc $budgetTol 0 $n) } else { 0 }
$ftMean = $sumFt / $n; $avgFps = 1000 / $ftMean
$low1 = 1000 / (Pct $ftSorted 0.01); $low01 = 1000 / (Pct $ftSorted 0.001)
$sumSq = 0.0; $absD = 0.0; $prev = $ft[0]; $gpuBound=0; $cpuBound=0; $neither=0; $hasG = $null -ne $gpuB; $hasC = $null -ne $cpuB
for ($i=0; $i -lt $n; $i++) {
  $x = $ft[$i]; $sumSq += $x*$x; $dd = $x - $prev; if ($dd -lt 0) { $absD -= $dd } else { $absD += $dd }; $prev = $x
  if ($hasG) { if ($gpuB[$i] -ge 0.9*$x) { $gpuBound++ } elseif ($hasC -and $cpuB[$i] -ge 0.9*$x) { $cpuBound++ } else { $neither++ } }
}
$ftSd = [math]::Round([math]::Sqrt([math]::Max(0.0, $sumSq/$n - $ftMean*$ftMean)), 2)
$ftDelta = [math]::Round($absD / [math]::Max(1, $n-1), 2)
$budgetInfo = if ($budget -gt 0) { [pscustomobject]@{ targetHz=$TargetHz; budgetMs=[math]::Round($budget,2); framesOver=$overB; pctOver=[math]::Round(100*$overB/$n,2) } } else { $null }

# verdict
$sFt = Stat $ft; $sCpuB = Stat $cpuB; $sGpuB = Stat $gpuB; $sGpuW = Stat $gpuW
$gpuIdleMean = if ($sGpuW) { $sGpuW.mean } elseif ($sGpuB) { $sFt.mean - $sGpuB.mean } else { $null }
$med = $sFt.p50; $near = (UB $ftAsc (1.02*$med) 0 $n) - (LB $ftAsc (0.98*$med) 0 $n); $clustered = $near -ge 0.8*$n
$capDesc = "frame time sits within 2% of $med ms ($([math]::Round(1000/$med,0)) fps) for $([math]::Round(100*$near/$n,0))% of frames"
$capNote = $null
$verdict = if (-not $hasG) { 'No GPU timing columns (MsGPUBusy / GPUBusy); cannot classify. Re-capture with GPU tracking on (do not pass --no_track_gpu or --v1_metrics).' }
  elseif ($gpuBound -ge 0.75*$n) { 'GPU-bound: the GPU is busy for nearly the whole frame and rarely waits.' }
  elseif ($clustered -and $sGpuB.mean -lt 0.85*$sFt.mean -and (-not $hasC -or $sCpuB.mean -lt 0.85*$sFt.mean)) { "Frame-rate capped: $capDesc while CPU and GPU busy both sit well below the frame time. Limited by the frame cap/vsync, neither CPU nor GPU. Raise or remove the cap (or test with VSync off) to find the real limiter." }
  elseif (-not $hasC) { 'Not GPU-bound, but there are no CPU timing columns (MsCPUBusy / CPUBusy), so CPU-bound cannot be confirmed.' }
  elseif ($cpuBound -ge 0.75*$n -and $gpuIdleMean -gt 0.1*$sFt.mean) { 'CPU-bound: the CPU side fills the frame while the GPU idles part of every frame.' }
  else { 'Balanced / mixed: limiter alternates between CPU and GPU.' }
if ($clustered -and $verdict -like 'CPU-bound*') { $capNote = "Frame time is flat: $capDesc. If that matches the in-game FPS limit or the refresh rate, the limiter's wait is counted as CPU busy and the real limit is the cap; raise the cap and re-capture to confirm." }
$reflexNote = 'If NVIDIA Reflex is enabled in-game, MsCPUBusy is inflated to match the GPU (Reflex delays the CPU start), so a GPU-bound capture also shows CPU busy ~= frame time. Trust GPUWait and the GPU-bound count over CPUBusy.'

$powerNote = $null
if ($gpuP -and $PowerLimitW -gt 0) {
  $ps = Stat $gpuP; $pct = [math]::Round(100*$ps.p99/$PowerLimitW,0)
  $clockNote = if ($gpuF) { $fs = Stat $gpuF; " Clock p50 $($fs.p50) MHz, max $($fs.max) MHz." } else { '' }
  $capVerdict = if ($pct -ge 92) { "Likely power-capped (p99 within 8% of the limit); confirm with nvidia-smi clocks_event_reasons.sw_power_cap during a session." } else { "Not power-capped in this capture (p99 at $pct% of the limit)." }
  $powerNote = "GPU power mean $($ps.mean) W, p99 $($ps.p99) W vs limit $PowerLimitW W ($pct% of limit at p99).$clockNote $capVerdict"
}
$modes = ''
if ($pi -ge 0) {
  $pmArr = $pmS.ToArray(); if ($null -ne $kidx) { $tmp = New-Object string[] $n; for ($i=0; $i -lt $n; $i++) { $tmp[$i] = $pmArr[$kidx[$i]] }; $pmArr = $tmp }
  $pmNames = @([Linq.Enumerable]::Distinct([string[]]$pmArr))
  if ($pmNames.Count -eq 1) { $modes = "$($pmNames[0])=$n" }
  else {
    $pid2 = New-Object 'System.Collections.Generic.Dictionary[string,int]'; for ($k=0; $k -lt $pmNames.Count; $k++) { $pid2[$pmNames[$k]] = $k }
    $pc = New-Object int[] $pmNames.Count; foreach ($s in $pmArr) { $pc[$pid2[$s]]++ }
    $modes = (0..($pmNames.Count-1) | Sort-Object { -$pc[$_] } | ForEach-Object { "$($pmNames[$_])=$($pc[$_])" }) -join '; '
  }
}

# start window: same-length comparison between captures of different durations
$sw = $null
if ($maxT -gt $StartWindowSeconds) {
  $e = LB $ts $StartWindowSeconds $tStart $n
  if ($e - $tStart -ge 50) {
    $swFt = Slice $ft $tStart $e; $swAvg = [Linq.Enumerable]::Sum($swFt) / $swFt.Length; [Array]::Sort($swFt); [Array]::Reverse($swFt)
    $sw = [pscustomobject]@{ seconds=$StartWindowSeconds; frames=$swFt.Length; avgFps=[math]::Round(1000/$swAvg,1); low1pctFps=[math]::Round(1000/(Pct $swFt 0.01),1) }
  }
}
$durationWarning = if ($maxT -lt 30) { "Capture is only $([math]::Round($maxT,1)) s long. That is a mis-triggered capture, not a measurement; re-capture from before the lights through at least one lap." } else { $null }

# buckets: each one is a range of the time-sorted view
$buckets = New-Object System.Collections.Generic.List[object]
$nb = [int][math]::Floor($maxT / $BucketSeconds) + 1; $a = $tStart
for ($k=0; $k -lt $nb; $k++) {
  $b = LB $ts (($k+1)*$BucketSeconds) $a $n; $lo = $a; $a = $b
  if ($b - $lo -lt 5) { continue }
  $fts = Slice $ft $lo $b; [Array]::Sort($fts); [Array]::Reverse($fts); $avg = [Linq.Enumerable]::Sum($fts) / $fts.Length
  $vg = MeanR $vram $lo $b
  $buckets.Add([pscustomobject]@{ start=$k*$BucketSeconds; frames=$fts.Length; avgFps=[math]::Round(1000/$avg,1); p1Fps=[math]::Round(1000/$fts[[math]::Floor($fts.Length*0.01)],1); cpuBusy=(MeanR $cpuB $lo $b); gpuBusy=(MeanR $gpuB $lo $b); gpuWait=(MeanR $gpuW $lo $b); gpuPowerW=(MeanR $gpuP $lo $b); gpuUtil=(MeanR $gpuU $lo $b); gpuMHz=(MeanR $gpuF $lo $b); vramGB=$(if ($null -ne $vg) { [math]::Round($vg/1e9,2) } else { $null }); cpuUtil=(MeanR $cpuU $lo $b); maxFrameMs=[math]::Round($fts[0],1) })
}

$missing = @(); foreach ($p in @(@('t','time'),@('cpuB','CPU busy'),@('cpuW','CPU wait'),@('gpuB','GPU busy'),@('gpuW','GPU wait'))) { if (-not $map[$p[0]]) { $missing += $p[1] } }
$colDesc = "time=$timeCol ($timeUnit) frame=$($map.ft) cpu=$($map.cpuB)/$($map.cpuW) gpu=$($map.gpuB)/$($map.gpuW)" + $(if ($missing) { "; missing: $($missing -join ', ')" } else { '' })
$result = [ordered]@{
  file = (Split-Path $Path -Leaf); frames = $n; durationS = [math]::Round($maxT,0); application = $appName
  durationWarning = $durationWarning; startWindow = $sw
  avgFps = [math]::Round($avgFps,1); low1pctFps = [math]::Round($low1,1); low01pctFps = [math]::Round($low01,1)
  framesOver16_7ms = $over16; framesOver33ms = $over33
  frameTimeMs = $sFt; cpuBusyMs = $sCpuB; cpuWaitMs = (Stat $cpuW); gpuBusyMs = $sGpuB; gpuWaitMs = $sGpuW
  gpuBoundFrames = $gpuBound; cpuBoundFrames = $cpuBound; neitherFrames = $neither
  gpuPowerW = (Stat $gpuP); gpuMHz = (Stat $gpuF); gpuTempC = (Stat $gpuT); gpuUtilPct = (Stat $gpuU)
  vramUsedGB = $(if ($vram) { $s = Stat $vram; [pscustomobject]@{ mean=[math]::Round($s.mean/1e9,2); max=[math]::Round($s.max/1e9,2); totalGB=$(if ($vramTot) { [math]::Round($vramTot/1e9,2) } else { $null }) } } else { $null })
  cpuUtilPct = (Stat $cpuU); presentModes = $modes; verdict = $verdict; reflexNote = $reflexNote; powerNote = $powerNote; buckets = $buckets
  columnSet = $columnSet; columns = $colDesc; formatNote = $formatNote; timeNote = $timeNote; rowsNote = $rowsNote; rowsInFile = $nRaw
  frameTimeSdMs = $ftSd; frameTimeMeanAbsDeltaMs = $ftDelta; targetBudget = $budgetInfo; displayChangeMs = (Stat $disp); capNote = $capNote
}

if ($Json) { $result | ConvertTo-Json -Depth 5; exit }

function F($fmt) { [string]::Format($inv, $fmt, [object[]]$args) }   # invariant decimals in every locale
"File: $($result.file)   frames=$n   duration=$($result.durationS)s   app=$($result.application)"
"Columns: $columnSet; $colDesc"
foreach ($note in $formatNote, $timeNote, $rowsNote) { if ($note) { "NOTE: $note" } }
"Average FPS = $($result.avgFps)   1% low = $($result.low1pctFps)   0.1% low = $($result.low01pctFps)   frames >16.7ms: $($result.framesOver16_7ms)   >33ms: $($result.framesOver33ms)"
"Pacing: frame-time SD = $ftSd ms   mean frame-to-frame change = $ftDelta ms   (lower is smoother)"
if ($budgetInfo) { "Target $TargetHz Hz ($($budgetInfo.budgetMs) ms budget): $overB frames more than 2% over budget ($($budgetInfo.pctOver)%)" }
if ($durationWarning) { "WARNING: $durationWarning" }
if ($sw) { "Start window (first $($sw.seconds) s, $($sw.frames) frames): average FPS = $($sw.avgFps)   1% low = $($sw.low1pctFps)   (compare this line between captures of different lengths)" }
""
F "{0,-16} {1,8} {2,8} {3,8} {4,8} {5,8} {6,8}" 'metric' 'mean' 'min' 'p1' 'p50' 'p99' 'max'
foreach ($k in 'frameTimeMs','displayChangeMs','cpuBusyMs','cpuWaitMs','gpuBusyMs','gpuWaitMs','gpuPowerW','gpuMHz','gpuTempC','gpuUtilPct','cpuUtilPct') { $s = $result[$k]; if ($s) { F "{0,-16} {1,8} {2,8} {3,8} {4,8} {5,8} {6,8}" $k $s.mean $s.min $s.p1 $s.p50 $s.p99 $s.max } }
if ($result.vramUsedGB) { "VRAM used: mean $($result.vramUsedGB.mean) GB, max $($result.vramUsedGB.max) GB" + $(if ($result.vramUsedGB.totalGB) { " of $($result.vramUsedGB.totalGB) GB" }) }
""
"Limiter per frame (busy >= 90% of frame time): GPU-bound=$gpuBound  CPU-bound=$cpuBound  neither=$neither"
"VERDICT: $verdict"
if ($capNote) { "Note: $capNote" }
"Note: $reflexNote"
if ($powerNote) { $powerNote }
"Present modes: $modes   ('Hardware: Independent Flip' or 'Hardware Composed: Independent Flip' = direct to screen, good; 'Composed: Flip' = compositor in the path)"
""
F "{0,6} {1,6} {2,7} {3,6} {4,8} {5,8} {6,8} {7,7} {8,7} {9,7} {10,7} {11,7} {12,7}" 'start' 'frames' 'avgFPS' 'p1FPS' 'CPUbusy' 'GPUbusy' 'GPUwait' 'GPU W' 'GPU%' 'GPUMHz' 'VRAM' 'CPU%' 'maxFT'
foreach ($bk in $buckets) { F "{0,6} {1,6} {2,7} {3,6} {4,8} {5,8} {6,8} {7,7} {8,7} {9,7} {10,7} {11,7} {12,7}" $bk.start $bk.frames $bk.avgFps $bk.p1Fps $bk.cpuBusy $bk.gpuBusy $bk.gpuWait $bk.gpuPowerW $bk.gpuUtil $bk.gpuMHz $bk.vramGB $bk.cpuUtil $bk.maxFrameMs }
