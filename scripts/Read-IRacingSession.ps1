<#
.SYNOPSIS
  Reads the live iRacing SDK shared memory: what session is loaded (track, weather, car count, replay vs live) and the sim's own FPS/CPU/GPU meters.
.DESCRIPTION
  Use this to confirm WHAT a PresentMon capture actually measured. A replay with TV cameras is not a benchmark for
  cockpit driving (no cockpit, no mirror, no three-projection view), and the Replays settings column applies instead of
  Driving. Run while the sim is in the session (it still works during a replay or from the pits).
.PARAMETER Samples
  How many live meter samples to print (about 0.7 s apart). Default 6.
#>
[CmdletBinding()]
param([int]$Samples = 6)

try { $mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting('Local\IRSDKMemMapFileName') } catch { Write-Host "iRacing SDK shared memory not available. The sim is not running or not in a session."; exit 1 }
$acc = $mmf.CreateViewAccessor()
$siLen=$acc.ReadInt32(16); $siOff=$acc.ReadInt32(20); $numVars=$acc.ReadInt32(24); $vhOff=$acc.ReadInt32(28); $numBuf=$acc.ReadInt32(32)
$si = New-Object byte[] $siLen; [void]$acc.ReadArray($siOff,$si,0,$siLen)
$yaml = [System.Text.Encoding]::GetEncoding(28591).GetString($si)
$lines = $yaml -split "`n"

"== Session"
$keys = 'TrackDisplayName','TrackConfigName','EventType','SimMode','NumCarClasses','NumStarters','TrackWeatherType','TrackSkies','TrackPrecipitation','TrackAirTemp','TrackSurfaceTemp','SubSessionID','LeagueID','Official','SessionType','SessionName'
foreach ($l in $lines) { foreach ($k in $keys) { if ($l -match "^\s*$k\s*:") { "  " + $l.Trim() } } }
$drivers = ($lines | Where-Object { $_ -match '^\s*- CarIdx:' }).Count
$pace = ($lines | Where-Object { $_ -match 'CarIsPaceCar: 1' }).Count
"  Drivers listed: $drivers (pace cars: $pace)"
$me = $lines | Where-Object { $_ -match 'CarScreenName:' } | Select-Object -First 1; if ($me) { "  Player car:" + ($me -replace '.*CarScreenName:','') }
"  SimMode 'replay' means the sim was launched to watch a saved replay; 'full' is a live session."

# var headers
$vars = @{}
for ($i=0; $i -lt $numVars; $i++) {
  $base = $vhOff + $i*144
  $nb = New-Object byte[] 32; [void]$acc.ReadArray($base+16,$nb,0,32); $name=[System.Text.Encoding]::ASCII.GetString($nb).TrimEnd([char]0)
  $vars[$name] = @{type=$acc.ReadInt32($base); off=$acc.ReadInt32($base+4)}
}
function ReadVar($name,$bufOff){ $v=$vars[$name]; if(-not $v){return 'NA'}; $o=$bufOff+$v.off; switch($v.type){ 0 {return [char]$acc.ReadByte($o)} 1 {return $acc.ReadByte($o)} 2 {return $acc.ReadInt32($o)} 3 {return $acc.ReadInt32($o)} 4 {return [math]::Round($acc.ReadSingle($o),2)} 5 {return [math]::Round($acc.ReadDouble($o),2)} } }
$want = 'FrameRate','CpuUsageFG','CpuUsageBG','GpuUsage','IsOnTrack','IsReplayPlaying','IsInGarage','Precipitation','WeatherDeclaredWet','TrackWetness','Skies','SessionState'
""; "== Live meters (FrameRate; CpuUsageFG = render thread share 0-1; GpuUsage 0-1; IsOnTrack/IsReplayPlaying; wetness)"
"  " + ($want -join '  ')
for ($s=0; $s -lt $Samples; $s++) {
  $best=-1; $bestTick=-1
  for ($b=0; $b -lt $numBuf; $b++) { $tc=$acc.ReadInt32(48+$b*16); if ($tc -gt $bestTick) { $bestTick=$tc; $best=$acc.ReadInt32(48+$b*16+4) } }
  "  " + (($want | ForEach-Object { ReadVar $_ $best }) -join '  ')
  Start-Sleep -Milliseconds 700
}
"Note: the sim's CpuUsageFG excludes time spent waiting in Reflex/present, so it can read ~40% while the OS shows the render thread at 100%. Use PresentMon for the limiter verdict."
$acc.Dispose(); $mmf.Dispose()
