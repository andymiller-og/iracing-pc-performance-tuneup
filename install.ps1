<#
.SYNOPSIS
  Installs or updates the iracing-pc-performance-tuneup skill for Claude Code, Codex CLI and/or Cursor. No git needed.
.DESCRIPTION
  Downloads the latest main branch as a ZIP from GitHub and places the skill folder where each harness looks for
  personal skills:
    Claude Code / Claude Desktop : %USERPROFILE%\.claude\skills\iracing-pc-performance-tuneup
    OpenAI Codex CLI             : %USERPROFILE%\.codex\skills\iracing-pc-performance-tuneup   (or $env:CODEX_HOME\skills)
    Cursor                       : %USERPROFILE%\.cursor\skills\iracing-pc-performance-tuneup
  With no parameters it installs into every harness it finds on this PC (a .claude, .codex or .cursor folder in your
  profile). If it finds none, it installs for Claude Code. Re-run to update.

  One line, any harness (PowerShell):
    irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1 | iex

  One harness only:
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1))) -Harness codex
.PARAMETER Harness
  auto (default), claude, codex, cursor, or all.
.PARAMETER Dest
  Install to an exact folder instead (e.g. a project's .cursor\skills\iracing-pc-performance-tuneup). Overrides -Harness.
#>
[CmdletBinding()]
param(
  [ValidateSet('auto','claude','codex','cursor','all')][string]$Harness = 'auto',
  [string]$Dest
)

$ErrorActionPreference = 'Stop'
$repo = 'andymiller-og/iracing-pc-performance-tuneup'
$skillName = 'iracing-pc-performance-tuneup'
$zipUrl = "https://github.com/$repo/archive/refs/heads/main.zip"

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$homes = [ordered]@{
  claude = Join-Path $env:USERPROFILE '.claude'
  codex  = $codexHome
  cursor = Join-Path $env:USERPROFILE '.cursor'
}

$targets = @()
if ($Dest) {
  $targets += [pscustomobject]@{ name='custom'; path=$Dest }
} else {
  $chosen = switch ($Harness) {
    'all'  { @('claude','codex','cursor') }
    'auto' { $found = @($homes.Keys | Where-Object { Test-Path $homes[$_] }); if ($found.Count -eq 0) { Write-Host "No Claude Code, Codex or Cursor folder found in your profile; installing for Claude Code."; @('claude') } else { $found } }
    default { @($Harness) }
  }
  foreach ($h in $chosen) { $targets += [pscustomobject]@{ name=$h; path=(Join-Path (Join-Path $homes[$h] 'skills') $skillName) } }
}

$tmp = Join-Path $env:TEMP ("iracing-tuneup-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$zip = Join-Path $tmp 'skill.zip'
Write-Host "Downloading $zipUrl"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like "$skillName-*" } | Select-Object -First 1
if (-not $src) { throw "Unexpected archive layout; nothing extracted." }

foreach ($t in $targets) {
  if (Test-Path $t.path) { Write-Host "Updating $($t.name): $($t.path)"; Get-ChildItem $t.path -Force | Remove-Item -Recurse -Force }
  else { Write-Host "Installing $($t.name): $($t.path)"; New-Item -ItemType Directory -Path $t.path -Force | Out-Null }
  # Leave out eval fixtures and repo housekeeping; an installed skill does not need them.
  Get-ChildItem $src.FullName -Force | Where-Object { $_.Name -notin @('evals', '.gitignore', '.gitattributes', 'install.ps1') } | Copy-Item -Destination $t.path -Recurse -Force
}
Remove-Item $tmp -Recurse -Force

Write-Host ""
Write-Host "Done. Installed to:"; $targets | ForEach-Object { "  [$($_.name)] $($_.path)" }
Write-Host ""
Write-Host "Start a NEW session in your tool, then:"
Write-Host "  Claude Code : type /iracing-pc-performance-tuneup, or ask 'give my iRacing settings a quick check'"
Write-Host "  Codex CLI   : type `$iracing-pc-performance-tuneup, or just ask"
Write-Host "  Cursor      : just ask; the agent picks the skill up from its description"
Write-Host "Intel PresentMon is required for the full tune-up:  winget install --id Intel.PresentMon -e"
