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

.NOTES
Windows-only (PowerShell). Requires Python on PATH for the hook tests
(skipped gracefully if missing). Requires git on PATH for the OAuth-leak
test that creates a temp git repo.

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

# Hook tests need Python. Skip gracefully if missing.
$hasPython = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
if (-not $hasPython) {
  Write-Host "  SKIP  block-trunk-commit.py / block-oauth-leak.py tests (python not on PATH)" -ForegroundColor Yellow
} else {

# 4. block-trunk-commit.py
$payload = '{"tool_input": {"command": "git push origin main"}}'
$out = $payload | python "$RepoRoot\hooks\block-trunk-commit.py" 2>&1
$trunkBlocked = ($LASTEXITCODE -eq 1) -and ($out -match "BLOCKED")
Assert $trunkBlocked "block-trunk-commit.py blocks push to main"

# 4b. block-trunk-commit.py allows feature branches (negative test)
$payload = '{"tool_input": {"command": "git commit -m feature"}}'
$tmpFeat = Join-Path $env:TEMP "cc-setup-test-feat-$(Get-Random)"
try {
  New-Item -ItemType Directory -Force $tmpFeat | Out-Null
  Push-Location $tmpFeat
  & git init -q -b feature/test
  "x" | Set-Content "a.txt"
  & git add a.txt
  & git -c user.email=t@t -c user.name=t commit -q -m init
  $out = $payload | python "$RepoRoot\hooks\block-trunk-commit.py" 2>&1
  $trunkAllowed = ($LASTEXITCODE -eq 0)
  Assert $trunkAllowed "block-trunk-commit.py allows commit on feature branch"
} finally {
  Pop-Location
  Remove-Item -Recurse -Force $tmpFeat -ErrorAction SilentlyContinue
}

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

# 5b. block-oauth-leak.py blocks staged file under .auth/ (path-based detection)
$tmpAuth = Join-Path $env:TEMP "cc-setup-test-auth-$(Get-Random)"
try {
  New-Item -ItemType Directory -Force "$tmpAuth\.auth" | Out-Null
  Push-Location $tmpAuth
  & git init -q
  "harmless content" | Set-Content ".auth\token.json"
  & git add .auth/token.json
  $payload = '{"tool_input": {"command": "git commit -m auth"}}'
  $out = $payload | python "$RepoRoot\hooks\block-oauth-leak.py" 2>&1
  $authBlocked = ($LASTEXITCODE -eq 1) -and ($out -match "\.auth/")
  Assert $authBlocked "block-oauth-leak.py blocks staged file under .auth/"
} finally {
  Pop-Location
  Remove-Item -Recurse -Force $tmpAuth -ErrorAction SilentlyContinue
}

# 5c. block-oauth-leak.py passes a clean diff (negative test - no false positives)
$tmpClean = Join-Path $env:TEMP "cc-setup-test-clean-$(Get-Random)"
try {
  New-Item -ItemType Directory -Force $tmpClean | Out-Null
  Push-Location $tmpClean
  & git init -q
  "Hello, world. This is plain code with no secrets." | Set-Content "main.txt"
  & git add main.txt
  $payload = '{"tool_input": {"command": "git commit -m main"}}'
  $out = $payload | python "$RepoRoot\hooks\block-oauth-leak.py" 2>&1
  $cleanPassed = ($LASTEXITCODE -eq 0)
  Assert $cleanPassed "block-oauth-leak.py allows clean diff (no false positive)"
} finally {
  Pop-Location
  Remove-Item -Recurse -Force $tmpClean -ErrorAction SilentlyContinue
}

}  # end Python-available branch

# 6. Get-Help on install/uninstall
$help1 = Get-Help "$RepoRoot\install.ps1" 2>&1 | Out-String
Assert ($help1 -match "Bootstrap Claude-Code-set-up") "install.ps1 exposes SYNOPSIS via Get-Help"

$help2 = Get-Help "$RepoRoot\uninstall.ps1" 2>&1 | Out-String
Assert ($help2 -match "Remove files this repo installed") "uninstall.ps1 exposes SYNOPSIS via Get-Help"

# 7. statusline-command.ps1 runs and produces output (even fallback)
$statusOut = & powershell -NoProfile -Command "echo '{}' | & '$RepoRoot\scripts\statusline-command.ps1'" 2>&1
Assert ($statusOut -match "\| \?% ctx \| \?k left") "statusline-command.ps1 emits output (fallback path)"

# 8. install.ps1 pre-flight fires when a required source file is missing
$tmpRepo = Join-Path $env:TEMP "cc-setup-test-installpf-$(Get-Random)"
try {
  New-Item -ItemType Directory -Force $tmpRepo | Out-Null
  # Copy install.ps1 + 4 of 5 required files (intentionally skip CLAUDE.md)
  Copy-Item "$RepoRoot\install.ps1" $tmpRepo\
  Copy-Item "$RepoRoot\settings.template.json" $tmpRepo\
  New-Item -ItemType Directory -Force "$tmpRepo\hooks" | Out-Null
  Copy-Item "$RepoRoot\hooks\*" "$tmpRepo\hooks\"
  New-Item -ItemType Directory -Force "$tmpRepo\scripts" | Out-Null
  Copy-Item "$RepoRoot\scripts\*" "$tmpRepo\scripts\"
  $out = & powershell -NoProfile -File "$tmpRepo\install.ps1" -DryRun 2>&1
  $preflightFired = ($LASTEXITCODE -eq 1) -and ($out -match "required source files are missing")
  Assert $preflightFired "install.ps1 errors when required source files are missing"
} finally {
  Remove-Item -Recurse -Force $tmpRepo -ErrorAction SilentlyContinue
}

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "All checks passed." -ForegroundColor Green
  exit 0
} else {
  Write-Host "$($failures.Count) failure(s):" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
