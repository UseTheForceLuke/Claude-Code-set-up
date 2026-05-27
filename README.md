# Claude-Code-set-up

Portable Claude Code configuration. Global behavioral rules, a settings
template, plus optional hook and statusline scripts you can wire in.

For migrating an existing cluttered `~/.claude/` to a clean state, see
[CLEANUP.md](CLEANUP.md).

## Layout

```
Claude-Code-set-up/
├── CLAUDE.md                      Global behavioral rules (Karpathy 12 + personal addendum)
├── settings.template.json         settings.json template; ${CLAUDE_HOME} placeholder
├── hooks/
│   └── block-trunk-commit.py      Blocks accidental commits to trunk/main/master
├── scripts/
│   └── statusline-command.ps1     Status line: session-id | %ctx | k-left
├── README.md                      This file
└── CLEANUP.md                     Step-by-step migration guide
```

## Install on a new machine

1. Clone:
   ```powershell
   git clone https://github.com/UseTheForceLuke/Claude-Code-set-up $env:USERPROFILE\Claude-Code-set-up
   ```

2. Copy the rules:
   ```powershell
   Copy-Item $env:USERPROFILE\Claude-Code-set-up\CLAUDE.md $env:USERPROFILE\.claude\CLAUDE.md
   ```

3. Render settings (substitutes ${CLAUDE_HOME} with the path to ~/.claude/):
   ```powershell
   $claudeHome = "$env:USERPROFILE\.claude" -replace '\\', '/'
   (Get-Content $env:USERPROFILE\Claude-Code-set-up\settings.template.json) `
     -replace '\$\{CLAUDE_HOME\}', $claudeHome |
     Set-Content $env:USERPROFILE\.claude\settings.json
   ```

4. Copy hooks and scripts the template references:
   ```powershell
   New-Item -ItemType Directory -Force $env:USERPROFILE\.claude\hooks   | Out-Null
   New-Item -ItemType Directory -Force $env:USERPROFILE\.claude\scripts | Out-Null
   Copy-Item $env:USERPROFILE\Claude-Code-set-up\hooks\*   $env:USERPROFILE\.claude\hooks\
   Copy-Item $env:USERPROFILE\Claude-Code-set-up\scripts\* $env:USERPROFILE\.claude\scripts\
   ```

5. Anthropic API key goes in `~/.claude/config.json` (not in this repo).

## What lives per-machine (NOT in this repo)

- `config.json` — Anthropic API key
- `.credentials.json` — OAuth tokens
- `memory/` — auto-memory
- Runtime state: `history.jsonl`, `sessions/`, `projects/`, etc.

## What's in settings.template.json

Configures:
- `model: opus[1m]` — Opus with 1M context window. On Max/Team Premium plans this is the default anyway, but explicit is fine.
- `effortLevel: xhigh` — Maximum effort reasoning on Opus 4.7. Also the default; explicit is documentation.
- `permissions.defaultMode: auto` — Auto-approves tool calls (research preview).
- `permissions.bash: allow` — Intended to allow all Bash; note this may not be the documented syntax. Documented form is `"permissions": {"allow": ["Bash"]}`.
- `hooks.PreToolUse` — Wires `block-trunk-commit.py` for git commands.
- `statusLine` — Wires `statusline-command.ps1`.
- `enabledPlugins.frontend-design` — Enables the frontend-design plugin.
- `alwaysThinkingEnabled: false`, `autoDreamEnabled: true`, `skipDangerousModePermissionPrompt: true`, `skipAutoPermissionPrompt: true` — assorted UX toggles.

Drop any of these to revert that piece to Claude Code's built-in default.

## Adding project-specific skills

This repo doesn't ship skills — they're project-coupled. For per-project
skills (loads only when you `cd` into that project), see Step 7 of
[CLEANUP.md](CLEANUP.md) for the project-skills repo pattern.

**Rule of thumb:** if a skill mentions a project name, environment, employee,
or endpoint, it's project-local. Global skills cost tokens on every session
even when irrelevant.
