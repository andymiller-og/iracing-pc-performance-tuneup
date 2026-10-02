<#
.SYNOPSIS
  Installs or updates the iracing-pc-performance-tuneup skill for Claude Code, Codex CLI and/or Cursor. No git needed.
.DESCRIPTION
  Downloads the latest main branch (or a tagged release with -Version) as a ZIP from GitHub and places the skill folder
  where each harness looks for personal skills:
    Claude Code / Claude Desktop : %USERPROFILE%\.claude\skills\iracing-pc-performance-tuneup
    OpenAI Codex CLI             : %USERPROFILE%\.codex\skills\iracing-pc-performance-tuneup   (or $env:CODEX_HOME\skills)
    Cursor                       : %USERPROFILE%\.cursor\skills\iracing-pc-performance-tuneup
  With no parameters it installs into every harness it finds on this PC (a .claude, .codex or .cursor folder in your
  profile). If it finds none, it installs for Claude Code. Re-run to update. An existing folder is replaced only if it
  is named iracing-pc-performance-tuneup or already holds a SKILL.md, so -Dest can never empty an unrelated folder.

  One line, any harness (PowerShell):
    irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1 | iex

  One harness only, or a pinned release:
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1))) -Harness codex
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1))) -Version v0.2.0
.PARAMETER Harness
  auto (default), claude, codex, cursor, or all.
.PARAMETER Dest
  Install to an exact folder instead (e.g. a project's .cursor\skills\iracing-pc-performance-tuneup). Overrides -Harness.
.PARAMETER Version
  A release tag (e.g. v0.2.0) to install instead of the latest main branch.
#>
[CmdletBinding()]
param(
  [ValidateSet('auto','claude','codex','cursor','all')][string]$Harness = 'auto',
  [string]$Dest,
  [string]$Version
)

# Child scope: with 'irm | iex' this script runs in the caller's session, so nothing set below may leak into it.
& {
$ErrorActionPreference = 'Stop'
$repo = 'andymiller-og/iracing-pc-performance-tuneup'
$skillName = 'iracing-pc-performance-tuneup'
$ref = if ($Version) { $Version } else { 'main' }
$zipUrl = if ($Version) { "https://github.com/$repo/archive/refs/tags/$Version.zip" } else { "https://github.com/$repo/archive/refs/heads/main.zip" }

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$homes = [ordered]@{
  claude = Join-Path $env:USERPROFILE '.claude'
  codex  = $codexHome
  cursor = Join-Path $env:USERPROFILE '.cursor'
}

$targets = @()
if ($Dest) {
  $targets += [pscustomobject]@{ name='custom'; path=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Dest) }
} else {
  $chosen = switch ($Harness) {
    'all'  { @('claude','codex','cursor') }
    'auto' { $found = @($homes.Keys | Where-Object { Test-Path $homes[$_] }); if ($found.Count -eq 0) { Write-Host "No Claude Code, Codex or Cursor folder found in your profile; installing for Claude Code."; @('claude') } else { $found } }
    default { @($Harness) }
  }
  foreach ($h in $chosen) { $targets += [pscustomobject]@{ name=$h; path=(Join-Path (Join-Path $homes[$h] 'skills') $skillName) } }
}
# Only ever empty a folder that is clearly this skill
foreach ($t in $targets) {
  if ((Test-Path $t.path) -and (Split-Path $t.path -Leaf) -ne $skillName -and -not (Test-Path (Join-Path $t.path 'SKILL.md'))) {
    throw "Refusing to install into $($t.path): it exists, is not named $skillName and holds no SKILL.md, so replacing its contents could delete unrelated files. Point -Dest at a folder named $skillName."
  }
  if (Test-Path (Join-Path $t.path '.git')) { throw "Refusing to install into $($t.path): it is a git working copy. Update it with git, or pick another -Dest." }
}

# GitHub archive ZIPs carry the commit id as the ZIP comment (end-of-central-directory record)
function Get-ZipComment($path) {
  $b = [IO.File]::ReadAllBytes($path)
  for ($i = $b.Length - 22; $i -ge [math]::Max(0, $b.Length - 65557); $i--) { if ($b[$i] -eq 0x50 -and $b[$i+1] -eq 0x4B -and $b[$i+2] -eq 5 -and $b[$i+3] -eq 6) { return [Text.Encoding]::ASCII.GetString($b, $i + 22, [BitConverter]::ToUInt16($b, $i + 20)) } }
  return ''
}

$tmp = Join-Path $env:TEMP ("iracing-tuneup-" + [guid]::NewGuid().ToString('N'))
$oldTls = [Net.ServicePointManager]::SecurityProtocol
try {
  New-Item -ItemType Directory -Path $tmp | Out-Null
  $zip = Join-Path $tmp 'skill.zip'
  Write-Host "Downloading $zipUrl"
  if ($PSVersionTable.PSEdition -ne 'Core') {   # Windows PowerShell 5.1 may default to TLS 1.0; PS 7 uses the OS defaults
    $tls = $oldTls -bor [Net.SecurityProtocolType]::Tls12
    if ([enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls13') { try { $tls = $tls -bor [Net.SecurityProtocolType]::Tls13 } catch { } }
    [Net.ServicePointManager]::SecurityProtocol = $tls
  }
  try { Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing }
  catch { if ($Version) { throw "Could not download release $Version ($($_.Exception.Message)). Check the tag name at https://github.com/$repo/tags." } else { throw } }
  $commit = Get-ZipComment $zip
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $src = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like "$skillName-*" } | Select-Object -First 1
  if (-not $src) { throw "Unexpected archive layout; nothing extracted." }
  $skillVer = Select-String -Path (Join-Path $src.FullName 'SKILL.md') -Pattern '^\s*version:\s*(\S+)' | Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }

  foreach ($t in $targets) {
    if (Test-Path $t.path) { Write-Host "Updating $($t.name): $($t.path)"; Get-ChildItem $t.path -Force | Remove-Item -Recurse -Force }
    else { Write-Host "Installing $($t.name): $($t.path)"; New-Item -ItemType Directory -Path $t.path -Force | Out-Null }
    # Leave out eval fixtures and repo housekeeping; an installed skill does not need them.
    Get-ChildItem $src.FullName -Force | Where-Object { $_.Name -notin @('evals', '.gitignore', '.gitattributes', 'install.ps1') } | Copy-Item -Destination $t.path -Recurse -Force
  }
} finally {
  [Net.ServicePointManager]::SecurityProtocol = $oldTls
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done. Installed version $(if ($skillVer) { $skillVer } else { '(unknown)' }) from $ref$(if ($commit -match '^[0-9a-f]{7,40}$') { " (commit $($commit.Substring(0,12)))" }) to:"; $targets | ForEach-Object { Write-Host "  [$($_.name)] $($_.path)" }
Write-Host ""
Write-Host "Start a NEW session in your tool, then:"
Write-Host "  Claude Code : type /iracing-pc-performance-tuneup, or ask 'give my iRacing settings a quick check'"
Write-Host "  Codex CLI   : type `$iracing-pc-performance-tuneup, or just ask"
Write-Host "  Cursor      : just ask; the agent picks the skill up from its description"
Write-Host "Intel PresentMon is required for the full tune-up:  winget install --id Intel.PresentMon -e"
}
