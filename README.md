# Claude-Code-set-up

Portable Claude Code configuration. Global behavioral rules, a settings
template, plus optional hook and statusline scripts you can wire in.

For migrating an existing cluttered `~/.claude/` to a clean state, see
[CLEANUP.md](CLEANUP.md) — a 9-step guide covering inventory, wipe, replace,
per-project skills, project memory seeding, and artifact location convention.

## Layout

```
Claude-Code-set-up/
├── CLAUDE.md                      Global behavioral rules (Karpathy 12 + TL;DR convention)
├── settings.template.json         settings.json template; ${CLAUDE_HOME} placeholder
├── hooks/
│   ├── block-trunk-commit.py      Blocks accidental commits to trunk/main/master
│   └── block-oauth-leak.py        Blocks commits with JWTs, .auth/ files, credentials (opt-in)
├── scripts/
│   └── statusline-command.ps1     Status line: session-id | %ctx | k-left
├── .gitignore                     __pycache__, *.pyc, .DS_Store, Thumbs.db
├── README.md                      This file
└── CLEANUP.md                     9-step migration guide
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

3. Render settings (substitutes `${CLAUDE_HOME}` with the path to `~/.claude/`):
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

- `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` — enables FleetView / agent teams
- `model: opus[1m]` — Opus with 1M context window
- `effortLevel: xhigh` — max documented effort level (default on Opus 4.7)
- `permissions.defaultMode: auto` + `allow: ["Bash"]` — auto-approve tool calls + pre-approve all Bash
- `hooks.PreToolUse` — wires `block-trunk-commit.py` for git commands
- `statusLine` — wires `statusline-command.ps1`
- `enabledPlugins.frontend-design` — UI/UX design plugin
- `skipDangerousModePermissionPrompt: true` — skip the bypass-mode confirmation

Drop any key to revert that piece to Claude Code's built-in default.

## What's in CLAUDE.md

- **Karpathy 12 Rules** — think before coding, simplicity first, surgical changes,
  goal-driven execution, judgment-only model use, token budgets, surface conflicts,
  read before write, tests verify intent, checkpoint, match conventions, fail loud
- **TL;DR convention** — substantive responses end with a `## TL;DR` block
  (one bullet per distinct point, ≤20% of response length, user-reference only)

## Optional: enable the OAuth leak guard

`hooks/block-oauth-leak.py` scans staged git diffs and blocks commits
containing JWT tokens (`eyJ...`), `.auth/` directory files, or common
credential filenames. It's shipped in the repo but **not wired by default**.

To activate, add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python \"C:/Users/You/.claude/hooks/block-oauth-leak.py\"",
            "if": "Bash(git commit *)"
          }
        ]
      }
    ]
  }
}
```

Adapt the path to your `~/.claude/` location. Bypassable with `git commit --no-verify`
when needed.

## Trim MCP connectors

Account-level MCP connectors (Datadog, ADO, Slack, Notion, etc.) load tool
definitions into context on every turn. Disconnect ones you don't use at
[claude.ai/settings/connectors](https://claude.ai/settings/connectors).

Most servers use deferred loading (name only in context, schema fetched on
demand), so the saving per connector is modest. Trimming 15+ unused ones to
3-4 active ones is still worth a few thousand tokens per turn.

## Adding project-specific skills

This repo doesn't ship skills — they're project-coupled. For per-project
skills (loads only when you `cd` into that project), see **Step 7** of
[CLEANUP.md](CLEANUP.md) for the project-skills repo pattern (`<project>-skills/`
sibling repo + copy or symlink into `<project>/.claude/skills/`).

**Rule of thumb:** if a skill mentions a project name, environment, employee,
or endpoint, it's project-local. Global skills cost tokens on every session
even when irrelevant.

## Seeding project memory

Per-project auto-memory at `~/.claude/projects/<workdir-slug>/memory/`
auto-loads `MEMORY.md` into every session in that workdir. See **Step 8** of
[CLEANUP.md](CLEANUP.md) for:

- Directory layout with `MEMORY.md` index + topic files
- What to seed (verified facts) vs not (inferred preferences, stale citations)
- Concrete examples of `user_role.md`, `reference_<topic>.md`,
  `feedback_<topic>.md` files

## Artifact location convention

Claude tends to write scratch files wherever the conversation is. Over months
this scatters generated files across tracked repos. **Step 9** of
[CLEANUP.md](CLEANUP.md) covers declaring a dedicated `<project>/claude-artifacts/`
folder and pinning the rule via memory.
