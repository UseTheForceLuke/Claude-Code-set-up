# Claude-Code-set-up

Portable, defaults-only Claude Code configuration. Just the global rules — no
custom skills, no agents, no slash commands, no hooks, no custom statusline.

For migrating an existing cluttered `~/.claude/` to this clean state, see
[CLEANUP.md](CLEANUP.md).

## Layout

```
Claude-Code-set-up/
├── CLAUDE.md                 Global behavioral rules (Karpathy 12 + personal addendum)
├── settings.template.json    Empty {} — Claude Code uses all built-in defaults
├── README.md                 This file
└── CLEANUP.md                Step-by-step migration guide
```

That's it. Four files.

## Install on a new machine

1. Clone:
   ```powershell
   git clone https://github.com/UseTheForceLuke/Claude-Code-set-up $env:USERPROFILE\Claude-Code-set-up
   ```

2. Copy the rules:
   ```powershell
   Copy-Item $env:USERPROFILE\Claude-Code-set-up\CLAUDE.md $env:USERPROFILE\.claude\CLAUDE.md
   ```

3. Settings — either leave `~/.claude/settings.json` absent (Claude Code uses defaults),
   or copy the empty template explicitly:
   ```powershell
   Copy-Item $env:USERPROFILE\Claude-Code-set-up\settings.template.json $env:USERPROFILE\.claude\settings.json
   ```

4. Anthropic API key goes in `~/.claude/config.json` (not in this repo).

## What lives per-machine (NOT in this repo)

- `config.json` — Anthropic API key
- `.credentials.json` — OAuth tokens
- `memory/` — auto-memory
- Runtime state: `history.jsonl`, `sessions/`, `projects/`, etc.

## Adding skills, hooks, statusline back

This repo intentionally ships nothing project- or workflow-specific. If you want
to add things back later:

- **Skills**: put them in `<project>/.claude/skills/` (per-project, loads only
  when you `cd` there) or `~/.claude/skills/` (global, loads every session and
  costs tokens per turn — use sparingly).
- **Hooks** (e.g. block commits to trunk): add to `~/.claude/hooks/` and wire
  via `~/.claude/settings.json`. Example trunk-commit hook and statusline
  scripts are documented in [CLEANUP.md](CLEANUP.md).
- **Slash commands** / **subagents**: project-local in `<project>/.claude/`
  or global in `~/.claude/`.

**Rule of thumb:** if it mentions a project name, environment, employee, or
endpoint, it's project-local. Global skills/commands cost tokens on every
session — even when irrelevant.
