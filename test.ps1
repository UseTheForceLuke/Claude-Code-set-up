<#
.SYNOPSIS
Smoke-test the repo: validate all scripts parse, hooks block their target patterns,
JSON template renders, and Get-Help works on install/uninstall.

.DESCRIPTION
Run this after changes to install.ps1, uninstall.ps1, block-trunk-commit.py,
or block-oauth-leak.py to make sure nothing is silently broken. Does NOT touch
~/.claude/.

Tests:
  1. settings.template.json is valid JSON
  2. install.ps1 -DryRun runs without errors
  3. uninstall.ps1 -DryRun runs without errors
  4. block-trunk-commit.py blocks `git push origin main` payload (exit 1)
  5. block-oauth-leak.py blocks a staged JWT in a temp git repo (exit 1)
  6. Get-Help install.ps1 / uninstall.ps1 produces SYNOPSIS output

.EXAMPLE
.\test.ps1
Run all checks, print pass/fail per check, exit non-zero on any failure.

.LINK
https://github.com/UseTheForceLuke/Claude-Code-set-up
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"
$RepoRoot = $PSScriptRoot
$failures = @()

function Assert([bool]$condition, [string]$name) {
  if ($condition) {
    Write-Host "  PASS  $name" -ForegroundColor Green
  } else {
    Write-Host "  FAIL  $name" -ForegroundColor Red
    $script:failures += $name
  }
}

Write-Host "==> Smoke-testing Claude-Code-set-up" -ForegroundColor Cyan
Write-Host ""

# 1. JSON template parses
try {
  $null = Get-Content "$RepoRoot\settings.template.json" -Raw | ConvertFrom-Json
  Assert $true "settings.template.json parses as JSON"
} catch {
  Assert $false "settings.template.json parses as JSON ($_)"
}

# 2. install.ps1 -DryRun
$out = & powershell -NoProfile -File "$RepoRoot\install.ps1" -DryRun 2>&1
$installOk = ($LASTEXITCODE -eq 0) -and ($out -match "Done\. Restart Claude Code")
Assert $installOk "install.ps1 -DryRun runs cleanly"

# 3. uninstall.ps1 -DryRun
$out = & powershell -NoProfile -File "$RepoRoot\uninstall.ps1" -DryRun 2>&1
$uninstallOk = ($LASTEXITCODE -eq 0) -and ($out -match "Your API key, credentials")
Assert $uninstallOk "uninstall.ps1 -DryRun runs cleanly"

# 4. block-trunk-commit.py
$payload = '{"tool_input": {"command": "git push origin main"}}'
$out = $payload | python "$RepoRoot\hooks\block-trunk-commit.py" 2>&1
$trunkBlocked = ($LASTEXITCODE -eq 1) -and ($out -match "BLOCKED")
Assert $trunkBlocked "block-trunk-commit.py blocks push to main"

# 5. block-oauth-leak.py - real git repo with staged JWT
$tmp = Join-Path $env:TEMP "cc-setup-test-$(Get-Random)"
try {
  New-Item -ItemType Directory -Force $tmp | Out-Null
  Push-Location $tmp
  & git init -q
  "valid" | Set-Content "a.txt"
  & git add a.txt
  & git -c user.email=test@test -c user.name=test commit -q -m init
  # JWT header that's 50+ base64url chars before the first dot (matches the
  # regex eyJ[A-Za-z0-9_\-]{50,}). Real JWTs split into 3 dot-separated
  # base64url segments; the regex catches any one segment that's 50+ chars.
  "fake jwt: eyJraWQiOiJyaHlDRGtrRHNNeXRvLXkzaWNFMGpaS1JnMFhHTmVNUDhJeU1MOFY2Zmg4IiwidmVyIjoiMS4wIn0.fakepayload.fakesig" | Set-Content "leak.txt"
  & git add leak.txt
  $payload = '{"tool_input": {"command": "git commit -m leak"}}'
  $out = $payload | python "$RepoRoot\hooks\block-oauth-leak.py" 2>&1
  $oauthBlocked = ($LASTEXITCODE -eq 1) -and ($out -match "JWT-shaped")
  Assert $oauthBlocked "block-oauth-leak.py blocks staged JWT"
} finally {
  Pop-Location
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# 6. Get-Help on install/uninstall
$help1 = Get-Help "$RepoRoot\install.ps1" 2>&1 | Out-String
Assert ($help1 -match "Bootstrap Claude-Code-set-up") "install.ps1 exposes SYNOPSIS via Get-Help"

$help2 = Get-Help "$RepoRoot\uninstall.ps1" 2>&1 | Out-String
Assert ($help2 -match "Remove files this repo installed") "uninstall.ps1 exposes SYNOPSIS via Get-Help"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "All checks passed." -ForegroundColor Green
  exit 0
} else {
  Write-Host "$($failures.Count) failure(s):" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
