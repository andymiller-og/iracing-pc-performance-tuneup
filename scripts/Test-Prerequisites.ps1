<#
.SYNOPSIS
  Checks that this PC has what the iRacing tune-up needs and prints install commands for anything missing.
.NOTES
  Read-only. Safe to run at any time. Works on Windows PowerShell 5.1 and PowerShell 7.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'
$rows = New-Object System.Collections.Generic.List[object]
function Add-Row($item, $status, $detail, $fix) { $rows.Add([pscustomobject]@{ Item=$item; Status=$status; Detail=$detail; Fix=$fix }) }

# OS
$os = Get-CimInstance Win32_OperatingSystem
Add-Row 'Windows' 'OK' "$($os.Caption) build $($os.BuildNumber)" ''

# Admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Add-Row 'Running as Administrator' $(if ($isAdmin) {'OK'} else {'INFO'}) $(if ($isAdmin) {'yes'} else {'no (PresentMon capture will self-elevate and ask for consent)'}) ''

# Execution policy: client Windows defaults to Restricted, which blocks every .ps1 unless run with -ExecutionPolicy Bypass
$epl = @{}; foreach ($e in Get-ExecutionPolicy -List) { $epl["$($e.Scope)"] = "$($e.ExecutionPolicy)" }
$epList = (@('MachinePolicy','UserPolicy','Process','CurrentUser','LocalMachine') | Where-Object { $epl[$_] -and $epl[$_] -ne 'Undefined' } | ForEach-Object { "$_=$($epl[$_])" }) -join ', '
$gpo = @('MachinePolicy','UserPolicy' | Where-Object { $epl[$_] -and $epl[$_] -ne 'Undefined' }) | Select-Object -First 1
$plain = @('MachinePolicy','UserPolicy','CurrentUser','LocalMachine' | Where-Object { $epl[$_] -and $epl[$_] -ne 'Undefined' } | ForEach-Object { $epl[$_] }) | Select-Object -First 1
if (-not $plain) { $plain = 'Restricted (Windows client default)' }
$motw = $null -ne (Get-Item -LiteralPath $PSCommandPath -Stream Zone.Identifier -ErrorAction SilentlyContinue)
$detail = "without -ExecutionPolicy Bypass: $plain$(if ($epList) { "   (scopes: $epList)" })$(if ($motw) { '; these scripts carry the downloaded-from-internet mark' })"
if ($gpo -and $epl[$gpo] -notin 'Bypass','Unrestricted') { Add-Row 'PowerShell execution policy' 'MISSING' "$detail; set by Group Policy ($gpo), which -ExecutionPolicy Bypass cannot override" 'Ask the PC owner/IT to allow scripts, or run the steps by hand' }
elseif ($plain -match 'Restricted|AllSigned' -or ($plain -eq 'RemoteSigned' -and $motw)) { Add-Row 'PowerShell execution policy' 'INFO' $detail 'Run every script as: powershell -NoProfile -ExecutionPolicy Bypass -File <script>  (that process only; no system change)' }
else { Add-Row 'PowerShell execution policy' 'OK' $detail '' }

# winget (missing on LTSC/Server and when App Installer is absent)
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) { Add-Row 'winget' 'OK' "$($winget.Source)" '' }
else { Add-Row 'winget' 'INFO' 'not found (Windows LTSC/Server, or App Installer not installed); the winget commands in the Fix column will not work' 'Install App Installer from the Microsoft Store, or download PresentMon from github.com/GameTechDev/PresentMon/releases' }

# iRacing install
$installDir = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\iRacing.com Motorsport Simulations\iRacing').InstallDir
if (-not $installDir) { foreach ($c in @("${env:ProgramFiles(x86)}\iRacing", "$env:ProgramFiles\iRacing", "C:\iRacing")) { if (Test-Path "$c\iRacingSim64DX11.exe") { $installDir = $c } } }
if (-not $installDir) { $p = Get-Process iRacingSim64DX11 | Select-Object -First 1; if ($p) { $installDir = Split-Path $p.Path } }
if ($installDir -and (Test-Path "$installDir\iRacingSim64DX11.exe")) { Add-Row 'iRacing sim' 'OK' "$installDir\iRacingSim64DX11.exe" '' }
else { Add-Row 'iRacing sim' 'MISSING' 'iRacingSim64DX11.exe not found' 'Install iRacing, or tell the user to point you at the install folder' }

# iRacing documents folder (handles OneDrive-redirected Documents)
$docs = [Environment]::GetFolderPath('MyDocuments')
$irDocs = Join-Path $docs 'iRacing'
if (Test-Path $irDocs) {
  $cfgs = Get-ChildItem $irDocs -Filter 'renderer*.ini' | Select-Object -ExpandProperty Name
  Add-Row 'iRacing settings folder' 'OK' "$irDocs  (configs: $($cfgs -join ', '))" ''
} else { Add-Row 'iRacing settings folder' 'MISSING' "expected $irDocs" 'Launch the sim once so it creates its settings files' }

# PresentMon (Intel). Console app is what the capture script uses.
$pmConsole = Get-ChildItem "$env:ProgramFiles\Intel\PresentMon\PresentMonConsoleApplication" -Filter 'PresentMon*.exe' | Select-Object -First 1 -ExpandProperty FullName
if (-not $pmConsole) { $pmConsole = (Get-Command presentmon).Source }
$pmUI = Test-Path "$env:ProgramFiles\Intel\PresentMon\PresentMonApplication\PresentMon.exe"
if ($pmConsole) { Add-Row 'Intel PresentMon (console)' 'OK' $pmConsole '' }
else { Add-Row 'Intel PresentMon (console)' 'MISSING' 'needed for per-frame CPU/GPU timing' 'winget install --id Intel.PresentMon -e   (installs both the app and the console tool)' }
Add-Row 'Intel PresentMon (app)' $(if ($pmUI) {'OK'} else {'INFO'}) $(if ($pmUI) {'installed'} else {'not installed; console tool is enough'}) ''
$pmSvc = Get-Service -Name 'PresentMonService'
if ($pmSvc) { Add-Row 'PresentMon service' $(if ($pmSvc.Status -eq 'Running') {'OK'} else {'INFO'}) "status $($pmSvc.Status) (GPU power/temperature columns need it running)" $(if ($pmSvc.Status -ne 'Running') {'Start-Service PresentMonService  (as Administrator)'} else {''}) }

# HWiNFO (optional)
$hw = Get-ChildItem "$env:ProgramFiles\HWiNFO64\HWiNFO64.EXE","${env:ProgramFiles(x86)}\HWiNFO64\HWiNFO64.EXE","$env:ProgramFiles\HWiNFO\HWiNFO64.EXE" | Select-Object -First 1
if ($hw) { Add-Row 'HWiNFO64 (optional)' 'OK' $hw.FullName '' }
else { Add-Row 'HWiNFO64 (optional)' 'INFO' 'not installed; Get-SystemSnapshot.ps1 covers most of what we need' 'winget install --id REALiX.HWiNFO -e' }

# GPU vendor and vendor tooling
$gpus = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Virtual|Basic|Meta' }
foreach ($g in $gpus) {
  Add-Row 'GPU' 'OK' "$($g.Name)  driver $($g.DriverVersion)" ''
}
$smi = Get-Command nvidia-smi
if ($smi) { $drv = & nvidia-smi --query-gpu=driver_version,power.limit,memory.total --format=csv,noheader; Add-Row 'nvidia-smi' 'OK' "driver/power limit/VRAM: $drv" '' }
elseif ($gpus.Name -match 'NVIDIA') { Add-Row 'nvidia-smi' 'INFO' 'not on PATH; usually at C:\Windows\System32\nvidia-smi.exe' '' }
if ($gpus.Name -match 'AMD|Radeon') { Add-Row 'AMD GPU detected' 'INFO' 'SMP (Simultaneous Multi-Projection) is not available; see references/amd.md' '' }

# Sim running?
$sim = Get-Process iRacingSim64DX11
Add-Row 'Sim running now' 'INFO' $(if ($sim) {"yes (PID $($sim.Id))"} else {'no'}) ''

($rows | Format-Table -AutoSize -Wrap | Out-String -Width 220).TrimEnd()   # explicit width so redirected output keeps the Fix column
$missing = $rows | Where-Object { $_.Status -eq 'MISSING' }
if ($missing) { "`nMISSING items must be resolved before the baseline capture. Install commands are in the Fix column." } else { "`nAll required items present." }
