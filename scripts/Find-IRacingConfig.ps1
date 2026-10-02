<#
.SYNOPSIS
  Locates the iRacing settings files and prints the performance-relevant settings in the same words the sim's UI uses.
.DESCRIPTION
  Reads rendererDX11Monitor.ini (flat screens) or the VR renderer file, plus app.ini, from the user's Documents\iRacing
  folder (OneDrive-redirected Documents handled). Prints Driving and Replays values side by side, the monitor geometry,
  and a list of anomalies worth asking about. Read-only: this script never edits the files.
.PARAMETER Raw
  Also dump every key in [Graphics Options], [MonitorSetup] and [Display] as key=value.
.PARAMETER Path
  Override the Documents\iRacing folder.
#>
[CmdletBinding()]
param([switch]$Raw, [string]$Path)

if (-not $Path) {
  $Path = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'iRacing'
  # OneDrive Known Folder Move switched on after the sim was installed can leave the folder in the local Documents
  $local = Join-Path $env:USERPROFILE 'Documents\iRacing'
  if (-not (Test-Path $Path) -and (Test-Path $local)) { $Path = $local }
}
if (-not (Test-Path $Path)) { Write-Error "iRacing settings folder not found at $Path. Launch the sim once, or pass -Path."; exit 1 }

$sim = Get-Process iRacingSim64DX11 -ErrorAction SilentlyContinue
if ($sim) { "NOTE: the sim is running (PID $($sim.Id)). Values below are what is on disk; the sim writes this file when it exits, and some changes only apply after a restart. Quit and relaunch the sim, then re-run this to verify." }

$candidates = @('rendererDX11Monitor.ini','rendererDX11OpenXR.ini','rendererDX11OpenVR.ini','rendererDX11Oculus.ini','rendererDX11.ini')
$files = foreach ($c in $candidates) { $f = Join-Path $Path $c; if (Test-Path $f) { Get-Item $f } }
"Renderer files present (newest first):"
$files | Sort-Object LastWriteTime -Descending | ForEach-Object { "  $($_.Name)  written $($_.LastWriteTime)" }
$renderer = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $renderer) { Write-Error "No renderer file ($($candidates -join ', ')) in $Path. Launch the sim once (flat or VR) and exit it, then re-run, or pass -Path to the folder that holds the files."; exit 1 }
"Using: $($renderer.Name)  (the most recently written one is the mode the user last ran; confirm with the user if VR and flat files are both recent)"

function Parse-Ini($file) {
  $ini = @{}; $section = ''
  foreach ($line in Get-Content $file) {
    if ($line -match '^\s*\[(.+)\]') { $section = $matches[1]; if (-not $ini.ContainsKey($section)) { $ini[$section] = [ordered]@{} }; continue }
    if ($line -match '^\s*([^=;\s]+)\s*=\s*([^;]*)') { $ini[$section][$matches[1]] = $matches[2].Trim() }
  }
  return $ini
}
$r = Parse-Ini $renderer.FullName
# missing sections become empty tables so every row still prints ('-'); VR files have no [Replay Graphics] or [MonitorSetup]
$missingSec = @('Graphics Options','Replay Graphics','MonitorSetup','Display' | Where-Object { -not $r.ContainsKey($_) })
foreach ($sec in 'Graphics Options','Replay Graphics','MonitorSetup','Display','User Options') { if (-not $r.ContainsKey($sec)) { $r[$sec] = @{} } }
$g = $r['Graphics Options']; $rg = $r['Replay Graphics']; $ms = $r['MonitorSetup']; $d = $r['Display']; $uo = $r['User Options']
$appFile = Join-Path $Path 'app.ini'; $a = if (Test-Path $appFile) { Parse-Ini $appFile } else { @{} }
foreach ($sec in 'View','Graphics','User Options') { if (-not $a.ContainsKey($sec)) { $a[$sec] = @{} } }
if ($missingSec) { "NOTE: sections not in $($renderer.Name): $($missingSec -join ', '). Their rows show '-'$(if ($missingSec -contains 'Replay Graphics') { '; VR renderer files have no separate Replays settings' })." }
if (-not (Test-Path $appFile)) { "NOTE: app.ini not found in $Path; FOV, mirror FOV and Max Cars (transmitted) show '-'." }
# The focus-loss setting has lived in both files across builds; prefer the renderer file, fall back to app.ini.
$focusSrc = $renderer.Name; $focusLost = $uo['reduceFramerate_WhenFocusLost']
if ($null -eq $focusLost) { $focusLost = $a['User Options']['reduceFramerate_WhenFocusLost']; $focusSrc = if ($null -eq $focusLost) { 'not in either file' } else { 'app.ini' } }

function Lvl($v, $map) { if ($null -eq $v) { return '-' }; if ($map.ContainsKey([string]$v)) { return $map[[string]$v] } ; return $v }
function V($v) { if ($null -eq $v -or "$v" -eq '') { return '-' }; return $v }   # raw value, or '-' when the key is absent
function Num($v) { $x = 0.0; if ($null -ne $v -and [double]::TryParse("$v", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$x)) { return $x }; return $null }
$offLowMedHigh = @{'0'='Off';'1'='Low';'2'='Medium';'3'='High'}
$lowMedHigh = @{'0'='Low';'1'='Medium';'2'='High'}
# Event, Grandstands and Objects show Off/Low/High in the 2026 UI although the ini comments say low/med/high (verified against screenshots: 0=Off, 1=Low, 2=High).
$offLowHigh = @{'0'='Off';'1'='Low';'2'='High'}
$lowMedHighMax = @{'0'='Low';'1'='Medium';'2'='High';'3'='Max'}
$onoff = @{'0'='Off';'1'='On'}
$aa = @{'0'='None';'1'='MSAA';'2'='FXAA';'3'='SMAA'}

function Row($ui, $page, $drv, $rep) { [pscustomobject]@{ 'Setting (UI name)'=$ui; Page=$page; Driving=$drv; Replays=$rep } }
$rows = @(
  Row 'Resolution' 'Display' "$(V $d['windowedWidth'])x$(V $d['windowedHeight']) windowed=$(if ($null -eq $d['fullScreen']) {'-'} else {[int]($d['fullScreen'] -ne '1')})" ''
  Row 'Full Screen / Border' 'Display' "FullScreen=$(Lvl $d['fullScreen'] $onoff) Border=$(Lvl $d['border'] $onoff)" ''
  Row 'Resolution Scaling' 'Display' $(if ($g['ResolutionScaling'] -eq '0') {'None'} else {V $g['ResolutionScaling']}) ''
  Row 'HDR' 'Graphics > Image Quality' (Lvl $g['EnableHDR'] $onoff) (Lvl $rg['EnableHDR'] $onoff)
  Row 'Shader Quality' 'Graphics > Image Quality' (Lvl $g['ShaderQuality'] $lowMedHighMax) ''
  Row 'Anti-Aliasing Method' 'Graphics > Anti-Aliasing' "$(Lvl $g['AntiAliasMethod'] $aa)$(if ($g['AntiAliasMethod'] -eq '1') {" $($g['MSAASamples'])x"})" ''
  Row 'MSAA filter' 'Graphics > Anti-Aliasing' $(if ($g['AntiAliasMethod'] -eq '1') { Lvl $g['MSAAUseFilter'] @{'0'='Soft';'1'='Neutral';'2'='Sharp';'3'='Simple (legacy)'} } else { '(MSAA not in use)' }) ''
  Row 'Sharpening' 'Graphics > Post-Processing' "$(Lvl $g['Sharpening'] $onoff) (amount $(V $g['SharpeningAmount']))" (Lvl $rg['Sharpening'] $onoff)
  Row 'SSAO / Heat Haze / DoF / Distortion' 'Graphics > Post-Processing' "$(Lvl $g['SSAO'] $onoff) / $(Lvl $g['HeatHaze'] $onoff) / $(Lvl $g['DepthOfField'] $onoff) / $(Lvl $g['Distortion'] $onoff)" ''
  Row 'Screen Space Reflections' 'Graphics > Other Effects' (Lvl $g['SSRLevel'] @{'0'='Off';'1'='Low res';'2'='Full res'}) (Lvl $rg['SSRLevel'] @{'0'='Off';'1'='Low res';'2'='Full res'})
  Row 'Shadow Maps' 'Graphics > Shadows and Lighting' (Lvl $g['ShadowMapType'] $onoff) (Lvl $rg['ShadowMapType'] $onoff)
  Row 'Dynamic Objects (shadows)' 'Graphics > Shadows and Lighting' $(if ($g['DynamicShadowMaps'] -eq '1') {"On, detail $(Lvl $g['ShadowDetail'] @{'0'='Low';'1'='High'})"} else {Lvl $g['DynamicShadowMaps'] $onoff}) (Lvl $rg['DynamicShadowMaps'] $onoff)
  Row 'Night Shadow Maps' 'Graphics > Shadows and Lighting' (Lvl $g['DNSMEnable'] $onoff) (Lvl $rg['DNSMEnable'] $onoff)
  Row 'Sky and Clouds' 'Graphics > World Detail' (Lvl $g['SkyRefreshRate'] $lowMedHigh) (Lvl $rg['SkyRefreshRate'] $lowMedHigh)
  Row 'Cars' 'Graphics > World Detail' (Lvl $g['CarDetail'] $lowMedHigh) (Lvl $rg['CarDetail'] $lowMedHigh)
  Row 'Pit Objects' 'Graphics > World Detail' (Lvl $g['PitObjectDetail'] $offLowMedHigh) (Lvl $rg['PitObjectDetail'] $offLowMedHigh)
  Row 'Event' 'Graphics > World Detail' (Lvl $g['WeekendDetail'] $offLowHigh) (Lvl $rg['WeekendDetail'] $offLowHigh)
  Row 'Grandstands' 'Graphics > World Detail' (Lvl $g['GrandstandDetail'] $offLowHigh) (Lvl $rg['GrandstandDetail'] $offLowHigh)
  Row 'Crowds' 'Graphics > World Detail' (Lvl $g['CrowdDetail'] $offLowMedHigh) (Lvl $rg['CrowdDetail'] $offLowMedHigh)
  Row 'Objects' 'Graphics > World Detail' (Lvl $g['ObjectDetail'] $offLowHigh) (Lvl $rg['ObjectDetail'] $offLowHigh)
  Row 'Foliage' 'Graphics > World Detail' (Lvl $g['FoliageDetail'] $offLowMedHigh) (Lvl $rg['FoliageDetail'] $offLowMedHigh)
  Row 'Two Pass Trees / High Quality Trees' 'Graphics > World Detail' "$(Lvl $g['TwoPassTrees'] $onoff) / $(Lvl $g['LowQualityTrees'] @{'1'='Off (low quality)';'0'='On'})" (Lvl $rg['TwoPassTrees'] $onoff)
  Row 'Particles details / Full Resolution' 'Graphics > Particles' "$(Lvl $g['ParticleDetail'] $lowMedHigh) / $(Lvl $g['ParticlesFullRes'] $onoff)" "$(Lvl $rg['ParticleDetail'] $lowMedHigh) / $(Lvl $rg['ParticlesFullRes'] $onoff)"
  Row 'Headlight Details' 'Graphics > Your Car Detail' (Lvl $g['HeadlightLevel'] @{'-1'='Disabled';'0'='Disabled/Low (UI showed Disabled for 0)';'1'='Medium';'2'='High'}) ''
  Row 'Steering Wheel / Hands' 'Graphics > Your Car Detail' "$(Lvl $g['SteeringWheel'] @{'0'='Off';'1'='On';'2'='Fixed';'3'='Only if display'}) / $(Lvl $g['DriverHands'] $onoff)" ''
  Row 'Cockpit Mirrors Max / Higher Detail in Mirrors' 'Graphics > Mirrors' "$(V $g['MaxCockpitMirrors']) / $(Lvl $g['MirrorDetail'] $onoff)" "$(V $rg['MaxCockpitMirrors']) / $(Lvl $rg['MirrorDetail'] $onoff)"
  Row 'Virtual Mirror / FOV' 'Graphics > Mirrors' "$(Lvl $g['VirtualMirrors'] $onoff) / $(V $a['View']['virtualMirrorFOV'])" ''
  Row 'Headlights On Track in Mirrors' 'Graphics > Mirrors' (Lvl $g['HeadlightsInMirrors'] $onoff) ''
  Row 'Draw Cars (view/mirrors)' 'Graphics > Other Cars Detail' "$(V $g['MaxCarsToDraw'])/$(V $g['MaxCarsToDrawInMirrors'])" "$(V $rg['MaxCarsToDraw'])/$(V $rg['MaxCarsToDrawInMirrors'])"
  Row 'Draw Pits (view/mirrors)' 'Graphics > Other Cars Detail' "$(V $g['MaxPitObjsToDraw'])/$(V $g['MaxPitObjsToDrawInMirrors'])" "$(V $rg['MaxPitObjsToDraw'])/$(V $rg['MaxPitObjsToDrawInMirrors'])"
  Row 'Max Cars (transmitted)' 'Graphics > Other Cars Detail' (V $a['Graphics']['serverTransmitMaxCars']) ''
  Row 'Dynamic LOD Frame Rate Threshold' 'Graphics > Dynamic LOD' (V $g['LODMinFPSTarget']) (V $rg['LODMinFPSTarget'])
  Row 'Car / World LOD Behavior' 'Graphics > Dynamic LOD' "$(if ($null -eq $g['LODPctMin']) {'-'} elseif ($g['LODPctMin'] -eq '100') {'Only Decrease'} else {'Increase+Decrease'})" ''
  Row 'Limit Frame Rate / Max FPS' 'Graphics > Frame Rate' "$(Lvl $g['LimitFrameRate'] @{'0'='No limit';'1'='Limit'}) / $(V $g['DesiredFPSLimit'])" ''
  Row 'NVIDIA Reflex / Max Pre-Rendered Frames' 'Graphics > Frame Rate' "$(Lvl $g['NvReflexMode'] @{'0'='Off';'1'='Enabled';'2'='Enabled + Boost'}) / $(V $g['MaxPreRenderedFrames'])" ''
  Row 'Vertical Sync (in-game)' 'Graphics > Frame Rate' (Lvl $g['VerticalSync'] $onoff) ''
  Row 'Video Memory Swap High-Res Cars / 2048 Car Textures' 'Graphics > Video Memory' "$(Lvl $g['CacheSwap3HighResCars'] $onoff) / $(Lvl $g['CarPaint2048x2048'] $onoff)" ''
  Row 'Video memory budget (auto, MB)' '(not in UI)' (V $g['VidMemToUseMB']) ''
  Row 'Reduce frame rate when focus lost' "(not in UI; $focusSrc)" (Lvl $focusLost @{'0'='No (full rate)';'1'='Yes'}) ''
)
""; "== Graphics settings ($($renderer.Name))"
($rows | Format-Table -AutoSize -Wrap | Out-String -Width 220).TrimEnd()   # explicit width: redirected output (agents) is otherwise cut at 120 columns and drops Replays

if ($ms.Count) {
  ""; "== Monitor geometry (Display > Monitor)"
  $type = if ($ms['NumMonitors'] -eq '3') { if ($ms['MonitorType'] -eq '1') {'3 Curved Screens'} else {'3 Flat Screens'} } else { if ($ms['MonitorType'] -eq '1') {'1 Curved Screen'} else {'1 Flat Screen'} }
  "Monitor Type: $type"
  $mw = Num $ms['MonitorWidth']; $sw = Num $ms['ScreenWidth']; $vdm = Num $ms['ViewingDist']
  "Monitor Width: $(V $ms['MonitorWidth']) mm$(if ($null -ne $mw) { " ($([math]::Round($mw/25.4,2)) in)" })   Screen (active) width: $(V $ms['ScreenWidth']) mm$(if ($null -ne $mw -and $null -ne $sw) { "   Bezel each side: $([math]::Round(($mw-$sw)/2,1)) mm" })"
  "Viewing Distance: $(V $ms['ViewingDist']) mm$(if ($null -ne $vdm) { " ($([math]::Round($vdm/25.4,1)) in)" })"
  "Radius of Curvature: $(V $ms['RadiusOfCurvature']) mm   Render Scene Using 3 Projections: $(Lvl $ms['RenderViewPerMonitor'] $onoff)   Nvidia Simultaneous Multi-Projection: $(Lvl $ms['EnableSMPSurround'] $onoff)"
  "Computed FOV (app.ini drivingCamFOV): $(V $a['View']['drivingCamFOV'])"
}

""; "== Anomalies to raise with the user (heuristics, verify before acting)"
$flags = @()
if ($ms.Count) {
  $vd = Num $ms['ViewingDist']; if ($null -ne $vd -and ($vd -lt 300 -or $vd -gt 1500)) { $flags += "Viewing distance $vd mm is implausible (typical 500-900 mm). Likely a typo or unit mix-up; FOV will be clamped." }
  if ((Num $a['View']['drivingCamFOV']) -ge 178) { $flags += "FOV is $($a['View']['drivingCamFOV']) degrees, which is the sim's clamp, not a computed value. Geometry inputs are wrong." }
  if ($ms['NumMonitors'] -eq '3' -and $ms['RenderViewPerMonitor'] -eq '1' -and $ms['EnableSMPSurround'] -eq '0') { $flags += "Triples with 3 projections but SMP off. On NVIDIA this is the single largest CPU-side win (see references/nvidia.md); not available on AMD." }
  if ($null -ne $mw -and $null -ne $sw -and $mw -lt $sw) { $flags += "Monitor width ($($ms['MonitorWidth']) mm) is smaller than the screen (active) width ($($ms['ScreenWidth']) mm). Monitor width is the outer width including bezels; one of the two is wrong. Check the spec sheet." }
  if ($ms['MonitorType'] -eq '1' -and $ms['RadiusOfCurvature'] -eq '1000') { $flags += "Radius of curvature is the 1000 mm default; verify against the panel spec (1000R/1500R/1800R)." }
}
if ($g['AntiAliasMethod'] -eq '0') { $flags += "No anti-aliasing. Distant cars and fences will shimmer; any method is a GPU-only cost. SMAA and MSAA 2x are the usual candidates; which is cheaper differs by rig, so measure." }
if ($null -ne (Num $g['MaxCarsToDraw']) -and (Num $g['MaxCarsToDraw']) -lt 30) { $flags += "Draw Cars $($g['MaxCarsToDraw']): in fields larger than this, the farther cars are not drawn at all. Compare with the grid sizes the user races." }
if ((Num $g['LODMinFPSTarget']) -gt 65) { $flags += "Dynamic LOD threshold $($g['LODMinFPSTarget']) is above typical frame rates for many rigs; if fps sits below it, the sim is actively stripping car detail (seen as 'looks worse')." }
if ($g['LimitFrameRate'] -eq '1' -and (Num $g['DesiredFPSLimit']) -gt 170) { $flags += "Frame cap $($g['DesiredFPSLimit']) is above the refresh of most 144-165 Hz panels; compare it with the refresh rate in Get-SystemSnapshot. With VRR, a cap 3-5 below the panel refresh keeps frames inside the VRR range." }
if ($g['ParticlesFullRes'] -eq '1') { $flags += "Full-resolution particles on: the largest GPU cost in rain spray. Fine if the user rarely races in rain and has GPU headroom." }
if ($g['Sharpening'] -eq '1' -and $g['AntiAliasMethod'] -eq '0') { $flags += "Sharpening with no AA amplifies aliasing on thin edges (dash, fences)." }
if ($d['fullScreen'] -eq '1' -and $ms['NumMonitors'] -eq '3') { $flags += "Exclusive full screen on triples needs NVIDIA Surround / AMD Eyefinity; borderless with Independent Flip is normally equivalent (verify PresentMode in the capture)." }
if ($focusLost -eq '1') { $flags += "The sim lowers its frame rate whenever another program has keyboard focus. Harmless if nothing takes focus while racing; a problem with overlays or tools that grab focus. It is not in the UI: the user sets reduceFramerate_WhenFocusLost=0 in $focusSrc with the sim closed; don't edit it for them." }
if ($flags.Count -eq 0) { "none from heuristics" } else { $flags | ForEach-Object { " - $_" } }

if ($Raw) {
  foreach ($sec in 'Graphics Options','MonitorSetup','Display') { ""; "[$sec]"; if ($r[$sec].Count) { $r[$sec].GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } } else { '(section not in this file)' } }
}
