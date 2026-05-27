<#
.SYNOPSIS
Bootstrap Claude-Code-set-up into ~/.claude/.

.DESCRIPTION
Copies CLAUDE.md, renders settings.template.json into ~/.claude/settings.json
with $CLAUDE_HOME substituted, and copies hooks/ + scripts/ contents.

Does NOT touch:
  ~/.claude/config.json          (your Anthropic API key)
  ~/.claude/.credentials.json    (your OAuth tokens)
  ~/.claude/memory/              (your auto-memory)
  ~/.claude/projects/            (your session transcripts)

.PARAMETER DryRun
Show what would happen without writing files.

.PARAMETER SkipSettings
Don't overwrite ~/.claude/settings.json (keep your existing one).

.EXAMPLE
.\install.ps1
Install everything.

.EXAMPLE
.\install.ps1 -DryRun
Preview changes without writing.

.EXAMPLE
.\install.ps1 -SkipSettings
Install CLAUDE.md + hooks + scripts but leave settings.json alone.

.LINK
https://github.com/UseTheForceLuke/Claude-Code-set-up
#>

[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$SkipSettings
)

$ErrorActionPreference = "Stop"

$RepoRoot   = $PSScriptRoot
$ClaudeHome = Join-Path $env:USERPROFILE ".claude"

function Write-Step([string]$msg) {
  Write-Host "==> $msg" -ForegroundColor Cyan
}

function Copy-OrDryRun([string]$src, [string]$dst) {
  if ($DryRun) {
    Write-Host "    [dry-run] would copy: $src -> $dst" -ForegroundColor Yellow
  } else {
    Copy-Item -Force $src $dst
    Write-Host "    copied: $(Split-Path $dst -Leaf)" -ForegroundColor Green
  }
}

# --- Sanity: create ~/.claude/ if missing ---
if (-not (Test-Path $ClaudeHome)) {
  if ($DryRun) {
    Write-Host "==> ~/.claude/ doesn't exist (would create)" -ForegroundColor Yellow
  } else {
    Write-Host "==> ~/.claude/ doesn't exist - creating it" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force $ClaudeHome | Out-Null
  }
}

# --- 1. CLAUDE.md ---
Write-Step "Copy CLAUDE.md to ~/.claude/"
Copy-OrDryRun "$RepoRoot\CLAUDE.md" "$ClaudeHome\CLAUDE.md"

# --- 2. settings.json (rendered from template) ---
if ($SkipSettings) {
  Write-Step "Skipping settings.json (-SkipSettings flag set)"
} else {
  Write-Step "Render settings.template.json -> ~/.claude/settings.json"
  $claudeHomeUnix = $ClaudeHome -replace '\\', '/'
  $template       = Get-Content "$RepoRoot\settings.template.json" -Raw
  $rendered       = $template -replace '\$\{CLAUDE_HOME\}', $claudeHomeUnix
  if ($DryRun) {
    Write-Host "    [dry-run] would write rendered template ($($rendered.Length) chars) to ~/.claude/settings.json" -ForegroundColor Yellow
  } else {
    Set-Content -Path "$ClaudeHome\settings.json" -Value $rendered -NoNewline
    Write-Host "    wrote settings.json" -ForegroundColor Green
  }
}

# --- 3. hooks/ ---
Write-Step "Copy hooks/ to ~/.claude/hooks/"
if (-not (Test-Path "$ClaudeHome\hooks")) {
  if (-not $DryRun) { New-Item -ItemType Directory -Force "$ClaudeHome\hooks" | Out-Null }
}
Get-ChildItem "$RepoRoot\hooks\*" -File | ForEach-Object {
  Copy-OrDryRun $_.FullName "$ClaudeHome\hooks\$($_.Name)"
}

# --- 4. scripts/ ---
Write-Step "Copy scripts/ to ~/.claude/scripts/"
if (-not (Test-Path "$ClaudeHome\scripts")) {
  if (-not $DryRun) { New-Item -ItemType Directory -Force "$ClaudeHome\scripts" | Out-Null }
}
Get-ChildItem "$RepoRoot\scripts\*" -File | ForEach-Object {
  Copy-OrDryRun $_.FullName "$ClaudeHome\scripts\$($_.Name)"
}

# --- 5. Validate ---
Write-Step "Sanity check"
if (-not $DryRun) {
  $needsApiKey = -not (Test-Path "$ClaudeHome\config.json")
  if ($needsApiKey) {
    Write-Host "    ! ~/.claude/config.json missing. Add your Anthropic API key:" -ForegroundColor Yellow
    Write-Host '      { "primaryApiKey": "sk-ant-..." }' -ForegroundColor Yellow
  }

  $settingsPath = "$ClaudeHome\settings.json"
  if (Test-Path $settingsPath) {
    try {
      $null = Get-Content $settingsPath -Raw | ConvertFrom-Json
      Write-Host "    settings.json: valid JSON" -ForegroundColor Green
    } catch {
      Write-Host "    settings.json: INVALID JSON - $_" -ForegroundColor Red
    }
  }
}

Write-Host ""
Write-Host "Done. Restart Claude Code to pick up the new settings." -ForegroundColor Green
if ($DryRun) {
  Write-Host "(dry run - nothing was written)" -ForegroundColor Yellow
}
