# Security

## What this repo does and does not do

### Does NOT do
- Make network calls during install or runtime
- Read your Anthropic API key from `~/.claude/config.json`
- Read your OAuth tokens from `~/.claude/.credentials.json`
- Read your auto-memory or session transcripts
- Write outside `~/.claude/`
- Send telemetry anywhere

### Does
- Copy files from this repo into `~/.claude/` (CLAUDE.md, settings.json, hooks, scripts)
- Run local-only `git` subprocesses inside the optional pre-commit hooks
- Print messages to stderr when the hooks decide to block a commit/push

## What's in the repo by category

| Path | Touches | Risk |
|---|---|---|
| `install.ps1` | Reads template + writes `~/.claude/`. No network. | Low |
| `uninstall.ps1` | Removes only files it wrote. No network. | Low |
| `test.ps1` | Creates a temp git repo in `$env:TEMP`, runs hooks, deletes the temp dir. | Low |
| `hooks/block-trunk-commit.py` | Runs `git branch --show-current` only. | Low |
| `hooks/block-oauth-leak.py` | Runs `git diff --cached` / `git diff @{u}..HEAD` only. | Low |
| `scripts/statusline-command.ps1` | Reads stdin (session JSON from Claude Code), prints to stdout. | Low |

## Audit it yourself

Before installing, audit what the code does:

```powershell
# 1. Outbound network calls in any script
Select-String -Path install.ps1, uninstall.ps1, test.ps1, hooks/*.py, scripts/*.ps1 `
  -Pattern "Invoke-RestMethod|Invoke-WebRequest|System\.Net\.Http|urllib|requests\.|socket\.|http\.client|urlopen|curl\s|wget\s"

# 2. Any embedded secrets (regex - don't use -SimpleMatch)
Select-String -Path install.ps1, uninstall.ps1, test.ps1, hooks/*.py, scripts/*.ps1 `
  -Pattern "sk-ant-|eyJ[A-Za-z0-9_-]{50,}|AKIA[0-9A-Z]{16}|ghp_|xoxb-"

# 3. Reads of credential files (looking for Get-Content/open() calls, not just the word "credentials")
Select-String -Path install.ps1, uninstall.ps1, hooks/*.py `
  -Pattern "Get-Content.*\.credentials|Get-Content.*config\.json|open\([\""'].*\.credentials|open\([\""'].*config\.json"
```

Expected results:
- Network: no matches (the tightened regex excludes substring "http" in
  comments/warnings - it looks for actual cmdlet names like Invoke-WebRequest)
- Secrets: two matches, both false positives -
  - `install.ps1` contains the literal string `sk-ant-...` inside a yellow
    warning message telling the user what their `config.json` should look
    like (not a real key)
  - `test.ps1` contains the deliberately-fake JWT fixture for the smoke test
    (decoded header: `{"kid":"...","ver":"1.0"}`, no valid payload/signature)
- Credential files: no matches (install.ps1 only does `Test-Path` on config.json
  to print a reminder; never `Get-Content` to read it)

## Reporting a vulnerability

If you find something the audit above missed, open an issue on GitHub or
fork + send a PR with the fix. There's no formal disclosure channel —
this is a small portable-config repo, not commercial software.

## What the hooks actually do

### `block-trunk-commit.py`
Reads PreToolUse hook payload from stdin. If the user is about to run a
`git commit`, `git push`, `git merge`, `git rebase`, or `git reset` while
on branch `trunk`, `main`, or `master`, the hook exits 1 with a message,
blocking the operation. Bypassable per-command with `--no-verify`.

### `block-oauth-leak.py`
Reads PreToolUse hook payload from stdin. On `git commit`, scans the
staged diff. On `git push`, scans commits ahead of upstream. If a JWT-shaped
string (`eyJ` + 50+ base64url chars), a `.auth/` path, or a credential-shaped
filename (`credentials.json`, `id_rsa`, etc.) appears, the hook exits 1,
blocking the operation. Bypassable per-command with `--no-verify`.

Both hooks emit only stderr text. Neither calls out to a network.

### Known limitations of the OAuth guard

The hook **fails open** (returns 0, allows the operation) in these cases:

- `git push` from a branch with no upstream tracking branch set
  (`git diff @{u}..HEAD` errors out). The push goes through unscanned.
  Workaround: run `git diff main..HEAD | grep eyJ` manually first if you're
  paranoid about a brand-new branch.
- Operations outside a git repo (`git diff` errors out).
- Malformed PreToolUse payload from Claude Code.

It also **misses non-JWT secrets**: AWS access keys, GitHub PATs, Slack tokens,
OpenAI keys, etc. The regex only catches `eyJ`-prefixed base64url strings.
For broader coverage, add additional patterns to `JWT_RE` and
`SUSPICIOUS_FILENAMES` in the hook, or use a dedicated tool like
[gitleaks](https://github.com/gitleaks/gitleaks) or
[trufflehog](https://github.com/trufflesecurity/trufflehog).

The hook is a useful seatbelt, not a comprehensive secret scanner.
