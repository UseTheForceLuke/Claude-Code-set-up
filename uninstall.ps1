# uninstall.ps1 - remove files this repo installed from ~/.claude/
#
# Usage:
#   .\uninstall.ps1              Remove repo-managed files (prompts before each)
#   .\uninstall.ps1 -Force       Skip confirmations
#   .\uninstall.ps1 -DryRun      Show what would be removed without removing
#
# What this removes (only files that match what install.ps1 wrote):
#   ~/.claude/CLAUDE.md
#   ~/.claude/settings.json       (only if it matches our rendered template)
#   ~/.claude/hooks/block-trunk-commit.py
#   ~/.claude/hooks/block-oauth-leak.py
#   ~/.claude/scripts/statusline-command.ps1
#
# What this DOES NOT remove:
#   ~/.claude/config.json         (your API key)
#   ~/.claude/.credentials.json   (your OAuth tokens)
#   ~/.claude/memory/             (your auto-memory)
#   ~/.claude/projects/           (your session transcripts)
#   ~/.claude/skills/             (your skills)
#   Any hooks/scripts you added yourself

[CmdletBinding()]
param(
  [switch]$Force,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$RepoRoot   = $PSScriptRoot
$ClaudeHome = Join-Path $env:USERPROFILE ".claude"

function Confirm-Remove([string]$path) {
  if (-not (Test-Path $path)) {
    Write-Host "    skip (not present): $path" -ForegroundColor DarkGray
    return $false
  }
  if ($DryRun) {
    Write-Host "    [dry-run] would remove: $path" -ForegroundColor Yellow
    return $false
  }
  if ($Force) { return $true }

  $resp = Read-Host "    remove $path ? [y/N]"
  return ($resp -match '^[yY]')
}

Write-Host "==> Uninstall Claude-Code-set-up from $ClaudeHome" -ForegroundColor Cyan
Write-Host ""

# Files from the repo, mapped to install destinations
$targets = @(
  "$ClaudeHome\CLAUDE.md",
  "$ClaudeHome\hooks\block-trunk-commit.py",
  "$ClaudeHome\hooks\block-oauth-leak.py",
  "$ClaudeHome\scripts\statusline-command.ps1"
)

foreach ($t in $targets) {
  if (Confirm-Remove $t) {
    Remove-Item -Force $t
    Write-Host "    removed: $t" -ForegroundColor Green
  }
}

# settings.json is sensitive - only remove if it matches what install.ps1 would
# have produced. Otherwise the user has customized it and we shouldn't touch it.
$settingsPath = "$ClaudeHome\settings.json"
if (Test-Path $settingsPath) {
  $current = Get-Content $settingsPath -Raw
  $template = Get-Content "$RepoRoot\settings.template.json" -Raw
  $claudeHomeUnix = $ClaudeHome -replace '\\', '/'
  $expected = $template -replace '\$\{CLAUDE_HOME\}', $claudeHomeUnix

  if ($current.Trim() -eq $expected.Trim()) {
    if (Confirm-Remove $settingsPath) {
      Remove-Item -Force $settingsPath
      Write-Host "    removed: $settingsPath" -ForegroundColor Green
    }
  } else {
    Write-Host "    skip (customized): $settingsPath" -ForegroundColor Yellow
    Write-Host "      your settings.json differs from the rendered template - leaving alone." -ForegroundColor DarkYellow
    Write-Host "      delete manually if you want it gone." -ForegroundColor DarkYellow
  }
}

# Clean up empty hook/script dirs
foreach ($d in @("$ClaudeHome\hooks", "$ClaudeHome\scripts")) {
  if ((Test-Path $d) -and -not (Get-ChildItem $d -Force)) {
    if ($DryRun) {
      Write-Host "    [dry-run] would remove empty dir: $d" -ForegroundColor Yellow
    } else {
      Remove-Item -Force $d
      Write-Host "    removed empty dir: $d" -ForegroundColor Green
    }
  }
}

Write-Host ""
Write-Host "Done. Your API key, credentials, memory, and skills are untouched." -ForegroundColor Green
if ($DryRun) {
  Write-Host "(dry run - nothing was removed)" -ForegroundColor Yellow
}
