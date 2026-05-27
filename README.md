# Claude-Code-set-up

Portable Claude Code configuration: global behavioral rules, a settings
template, an OAuth-leak commit guard, a trunk-commit blocker, and a custom
statusline. One repo, syncable across machines via git.

## Why this exists

After months of Claude Code use, `~/.claude/` accumulates:

- Hundreds of MB of stale session transcripts in `projects/`
- Skill folders bundling `node_modules` and `.auth/` token caches
- Dead `.ps1` hooks wired to deleted scripts
- Stale auto-memory entries from finished campaigns
- A `settings.json` with undocumented / fake keys silently ignored

This repo is the **canonical clean state** after a real cleanup. The
[SETUP.md](SETUP.md) guide walks through migrating from a cluttered
`~/.claude/` to this layout — 9 steps, with real numbers from one cleanup
(~1.5 GB → ~9 MB).

## Quick install (Windows)

```powershell
git clone https://github.com/UseTheForceLuke/Claude-Code-set-up $env:USERPROFILE\Claude-Code-set-up
cd $env:USERPROFILE\Claude-Code-set-up
.\install.ps1
```

The script copies `CLAUDE.md`, renders `settings.template.json` into
`~/.claude/settings.json` with `${CLAUDE_HOME}` substituted, and copies
`hooks/` + `scripts/`. It does NOT touch your API key, OAuth tokens, memory,
or session transcripts.

- `.\install.ps1 -DryRun` to preview without writing
- `.\install.ps1 -SkipSettings` to keep your existing `settings.json`
- `.\uninstall.ps1` to back out cleanly (preserves customized settings)

**Restart Claude Code after install.** Settings, hooks, and statusline only
re-load at session start. If you're already in a session, `Ctrl+D` to exit,
then `claude` to relaunch.

## Manual install (macOS / Linux)

The repo ships PowerShell scripts (`install.ps1`, `statusline-command.ps1`),
which won't run as-is on Unix. The CLAUDE.md, settings template, hooks, and
SETUP.md are all platform-neutral — install them by hand:

```bash
REPO=~/Claude-Code-set-up
CLAUDE_HOME=~/.claude

git clone https://github.com/UseTheForceLuke/Claude-Code-set-up $REPO

# 1. CLAUDE.md
cp $REPO/CLAUDE.md $CLAUDE_HOME/CLAUDE.md

# 2. Render settings.json (substitute ${CLAUDE_HOME})
sed "s|\${CLAUDE_HOME}|$CLAUDE_HOME|g" $REPO/settings.template.json > $CLAUDE_HOME/settings.json

# 3. Hooks
mkdir -p $CLAUDE_HOME/hooks
cp $REPO/hooks/*.py $CLAUDE_HOME/hooks/

# 4. Statusline — the PowerShell script will NOT work on macOS/Linux.
#    Either skip the statusLine block in settings.json, or write your own
#    shell-script equivalent. The script reads session JSON from stdin and
#    prints "session-id | NN% ctx | NNNk left".
```

Drop the `statusLine` block from your settings.json if you don't have a Unix
equivalent — Claude Code falls back to its built-in statusline cleanly.

## Layout

This repo (what gets cloned):

```
Claude-Code-set-up/
├── CLAUDE.md                      Global behavioral rules (Karpathy 12 + TL;DR convention)
├── settings.template.json         settings.json template; ${CLAUDE_HOME} placeholder
├── hooks/
│   ├── block-trunk-commit.py      Blocks accidental commits to trunk/main/master
│   └── block-oauth-leak.py        Blocks commits with JWTs, .auth/ files, credentials (opt-in)
├── scripts/
│   └── statusline-command.ps1     Status line: session-id | %ctx | k-left
├── install.ps1                    One-command bootstrap into ~/.claude/
├── .gitignore                     __pycache__, *.pyc, .DS_Store, Thumbs.db
├── README.md                      This file
└── SETUP.md                       9-step migration guide
```

After `install.ps1` runs, your `~/.claude/` looks like:

```
~/.claude/
├── config.json                    Anthropic API key (you provide)
├── .credentials.json              OAuth tokens (Claude Code manages)
├── CLAUDE.md                      ← copied from this repo
├── settings.json                  ← rendered from settings.template.json
├── hooks/                         ← copied from this repo
│   ├── block-trunk-commit.py
│   └── block-oauth-leak.py
├── scripts/
│   └── statusline-command.ps1     ← copied from this repo
├── skills/                        EMPTY at user level (skills are per-project)
├── agents/                        EMPTY
├── commands/                      EMPTY
└── projects/
    └── <workdir-slug>/
        └── memory/                ← auto-memory grows here as you work
            ├── MEMORY.md          Index (auto-loaded every session)
            ├── user_role.md       Who you are, primary dir, stack
            ├── reference_<x>.md   IDs, endpoints, pipeline numbers
            └── feedback_<x>.md    Conventions, workflow rules
```

Example `MEMORY.md` index (in a real project memory folder):

```markdown
- [User role](user_role.md) — Backend dev; works in <project>/apis
- [PR workflow](feedback_pr_workflow.md) — Use the team's pr-create skill; never raw `az repos pr create`
- [Backend style](feedback_backend_style.md) — `_underscore` fields, AAA tests, SonarCloud rules
- [ADO reference](reference_ado.md) — Org, project id, repo id, pipeline 285, PR-threads endpoint
- [Artifact location](feedback_artifact_location.md) — Generated files go to <project>/claude-artifacts/
```

Each linked file has YAML frontmatter (`name`, `description`, `metadata.type`)
plus the actual content. See [SETUP.md Step 8](SETUP.md) for full examples
of each type (`user`, `reference`, `feedback`).

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

`hooks/block-oauth-leak.py` scans git diffs and blocks both **commits and
pushes** that contain JWT tokens (`eyJ...`), `.auth/` directory files, or
common credential filenames. It's shipped in the repo but **not wired by
default**.

- For `git commit`: scans the staged diff
- For `git push`: scans commits ahead of upstream (catches an already-committed
  leak before it leaves the machine)

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
            "if": "Bash(git commit *) || Bash(git push *)"
          }
        ]
      }
    ]
  }
}
```

Adapt the path to your `~/.claude/` location. Bypassable with `--no-verify`
when needed (`git commit --no-verify` or `git push --no-verify`).

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
[SETUP.md](SETUP.md) for the project-skills repo pattern (`<project>-skills/`
sibling repo + copy or symlink into `<project>/.claude/skills/`).

**Rule of thumb:** if a skill mentions a project name, environment, employee,
or endpoint, it's project-local. Global skills cost tokens on every session
even when irrelevant.

## Seeding project memory

Per-project auto-memory at `~/.claude/projects/<workdir-slug>/memory/`
auto-loads `MEMORY.md` into every session in that workdir. See **Step 8** of
[SETUP.md](SETUP.md) for:

- Directory layout with `MEMORY.md` index + topic files
- What to seed (verified facts) vs not (inferred preferences, stale citations)
- Concrete examples of `user_role.md`, `reference_<topic>.md`,
  `feedback_<topic>.md` files

## Artifact location convention

Claude tends to write scratch files wherever the conversation is. Over months
this scatters generated files across tracked repos. **Step 9** of
[SETUP.md](SETUP.md) covers declaring a dedicated `<project>/claude-artifacts/`
folder and pinning the rule via memory.

## License

MIT — see [LICENSE](LICENSE). Use this, fork it, adapt it to your stack.
