<#
.SYNOPSIS
  Installs or updates the iracing-pc-performance-tuneup skill without git.
.DESCRIPTION
  Downloads the latest main branch as a ZIP from GitHub, extracts it, and places the skill in your personal
  Claude skills folder (%USERPROFILE%\.claude\skills\iracing-pc-performance-tuneup). Re-run to update.
  One-liner (PowerShell):
    irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1 | iex
.PARAMETER Dest
  Install somewhere else, e.g. a project's .claude\skills folder.
#>
[CmdletBinding()]
param([string]$Dest = (Join-Path $env:USERPROFILE '.claude\skills\iracing-pc-performance-tuneup'))

$ErrorActionPreference = 'Stop'
$repo = 'andymiller-og/iracing-pc-performance-tuneup'
$zipUrl = "https://github.com/$repo/archive/refs/heads/main.zip"
$tmp = Join-Path $env:TEMP ("iracing-tuneup-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$zip = Join-Path $tmp 'skill.zip'

Write-Host "Downloading $zipUrl"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like 'iracing-pc-performance-tuneup-*' } | Select-Object -First 1
if (-not $src) { throw "Unexpected archive layout; nothing extracted." }

if (Test-Path $Dest) {
  Write-Host "Updating existing install at $Dest"
  Get-ChildItem $Dest -Force | Remove-Item -Recurse -Force
} else {
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}
# Copy the skill, leaving out the eval fixtures and repo housekeeping that an installed skill does not need.
Get-ChildItem $src.FullName -Force | Where-Object { $_.Name -notin @('evals', '.gitignore', '.gitattributes') } | Copy-Item -Destination $Dest -Recurse -Force
Remove-Item $tmp -Recurse -Force

Write-Host ""
Write-Host "Installed to $Dest"
Write-Host "Files:"; Get-ChildItem $Dest -Recurse -File | ForEach-Object { "  " + $_.FullName.Substring($Dest.Length + 1) }
Write-Host ""
Write-Host "Next: start a new Claude Code session and type  /iracing-pc-performance-tuneup  or just ask to tune your iRacing graphics."
Write-Host "Intel PresentMon is required for measurement:  winget install --id Intel.PresentMon -e"
