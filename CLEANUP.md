# Cleanup: from cluttered `~/.claude/` to a globals-only portable setup

A real-world record of how to shrink an over-grown Claude Code configuration to
a minimal, portable globals-only state. Run this when your `~/.claude/`
has accumulated old skills, dead hooks, secrets, project-specific tools, and
multi-GB of stale session/state data.

> ⚠️ This is destructive. Read the **Before you start** section before running any
> commands.

## Before you start

1. **Back up your API key and credentials.** Even though we don't delete them,
   accidents happen.
   ```powershell
   $backup = "$env:USERPROFILE\claude-backup-$(Get-Date -Format yyyy-MM-dd)"
   New-Item -ItemType Directory -Force $backup | Out-Null
   Copy-Item $env:USERPROFILE\.claude\config.json $backup\
   Copy-Item $env:USERPROFILE\.claude\.credentials.json $backup\credentials.json
   ```

2. **Close every other Claude Code window.** The cleanup deletes session state.
   If two Claude Code sessions are open, one will end abruptly.

3. **Identify what kind of skills you have.** Run this first:
   ```powershell
   Get-ChildItem $env:USERPROFILE\.claude\skills -Directory | Select Name
   ```
   For each skill, ask: *is this truly generic or does it hardcode one project's
   paths/IDs/employee names?* Project-specific ones don't belong in `~/.claude/skills/`
   because they load into **every** session's context, costing tokens you don't use.

4. **Decide what's worth keeping before deletion.** If any skill references files,
   credentials, or test data that aren't backed up elsewhere, capture those first.
   We hit a real example: a Playwright skill had OAuth `.auth/` token caches that
   would have been published if we'd naively pushed to GitHub.

## Step 1 — Build the portable globals repo first

Don't delete anything until you have a clean replacement ready.

Create `~/claude-setup/` containing only the portable globals:
```
claude-setup/
├── CLAUDE.md                      Behavioral rules (e.g. Karpathy 12)
├── settings.template.json         Renders to ~/.claude/settings.json with ${CLAUDE_HOME} substituted
├── hooks/
│   └── block-trunk-commit.py      Generic, works in any git repo
└── scripts/
    └── statusline-command.ps1     Statusline: session-id | %ctx | k-left
```

That's it. No skills, no agents, no slash commands. The whole repo is under 10 KB.

Init the repo:
```powershell
cd ~\claude-setup
git init
git add -A
git commit -m "Initial portable globals-only setup"
```

## Step 2 — Project-specific skills go in a SEPARATE portable repo

If you had skills like `local-bootstrapper`, `permission-xlsx`, `prod-read-sql`, etc.
that hardcode one project's coordinates, **don't put them in claude-setup**. Make a
second portable repo per project:

```
~/<project>-skills/
├── README.md
├── .gitignore                     Block .auth/, node_modules/, test-results/, secrets
├── skills/                        One folder per skill
├── commands/                      One .md per slash command
└── agents/                        One .md per subagent
```

**Critical: scrub for secrets before committing.** Common landmines:
- `.auth/` folders with OAuth JWTs (live access tokens!)
- Hardcoded `C:\Users\<your-name>\...` paths
- `teams.json` or similar files with employee names
- Test data referencing real customer emails
- API endpoints / org IDs / pipeline IDs

Run these greps before `git commit`:
```powershell
$repo = "$env:USERPROFILE\<project>-skills"
Get-ChildItem $repo -Recurse -File | Select-String -Pattern "sk-ant-" -SimpleMatch
Get-ChildItem $repo -Recurse -File | Select-String -Pattern "eyJ" -SimpleMatch  # JWT prefix
Get-ChildItem $repo -Recurse -File | Select-String -Pattern "C:\\Users\\$env:USERNAME" -SimpleMatch
```

If anything turns up: anonymize doc references (`<repo-root>`, `<project>`,
`<you>`), and delete actual credential files entirely.

## Step 3 — Inventory `~/.claude/` before nuking

Before deleting, see what's there:
```powershell
Get-ChildItem $env:USERPROFILE\.claude -Force |
  ForEach-Object {
    $size = if ($_.PSIsContainer) {
      (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    } else { $_.Length }
    [PSCustomObject]@{ Name = $_.Name; SizeMB = [math]::Round($size / 1MB, 2) }
  } | Sort-Object SizeMB -Descending
```

Common bloat sources observed in one real cleanup:
- `projects/` — **1.1 GB** of per-project session transcripts, including stale ones
- `skills/<x>/node_modules/` — **321 MB** if any skill is a Playwright/npm project
- `file-history/` — **51 MB** of undo state for files that no longer exist
- `backups/` — **22 MB** of auto-backups
- `plans/`, `paste-cache/`, `shell-snapshots/`, `sounds/` — several MB each
- Old notification scripts (`notify-hook.ps1`, `telegram-watcher.ps1`, etc.)

## Step 4 — Wipe scratch and stale state, KEEP load-bearing items

### KEEP (do NOT delete)
- `config.json` — Anthropic API key
- `.credentials.json` — OAuth tokens
- `plugins/` — installed plugin registrations (e.g. `frontend-design`)
- `sessions/`, `session-env/` — active session state
- The current session's `projects/<workdir>/<session-uuid>.jsonl`

### DELETE — pure scratch / regeneratable
```powershell
$claude = "$env:USERPROFILE\.claude"
$dirs = @(
  'backups', 'debug', 'hook-logs', 'paste-cache', 'image-cache',
  'shell-snapshots', 'file-history', 'plans', 'session-env',
  'ide', 'cache', 'tasks', 'teams', 'telemetry', 'sounds'
)
$files = @(
  'statusline-debug.json', '.last-cleanup', 'notifications.disabled',
  'mcp-needs-auth-cache.json', 'guard-data.json', 'policy-limits.json',
  'stats-cache.json', 'usage-stats.json', 'cost-log.csv',
  'STATUSLINE_SETUP.md',
  # Old notification scripts if you no longer use them:
  'notify-hook.ps1', 'notify-toggle.ps1', 'play-random-notification.ps1',
  'set-bot-avatar.ps1', 'usage-aggregator.ps1', 'telegram-watcher.ps1',
  'trigger-demo.ps1'
)
$dirs  | ForEach-Object { Remove-Item -Recurse -Force "$claude\$_" -ErrorAction SilentlyContinue }
$files | ForEach-Object { Remove-Item -Force "$claude\$_" -ErrorAction SilentlyContinue }
```

### Strip skill bloat
If any skill has npm/Playwright dependencies, strip them — they regenerate via `npm install`:
```powershell
Get-ChildItem $claude\skills -Directory | ForEach-Object {
  Remove-Item -Recurse -Force "$($_.FullName)\node_modules" -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force "$($_.FullName)\playwright-report" -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force "$($_.FullName)\test-results" -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force "$($_.FullName)\.auth" -ErrorAction SilentlyContinue
}
Get-ChildItem $claude -Recurse -Directory -Filter __pycache__ -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force
```

### Wipe project transcripts, keep current session
```powershell
# Find your CURRENT session UUID — visible in the statusline if you configured it,
# or use the most recently modified .jsonl
$projects = "$claude\projects"
$currentSession = Get-ChildItem "$projects\*\*.jsonl" |
  Sort-Object LastWriteTime -Descending | Select -First 1
Write-Host "Current session: $($currentSession.FullName)"

# Move current session aside
$tmp = "$env:TEMP\claude-session-keep.jsonl"
Move-Item $currentSession.FullName $tmp

# Wipe everything
Remove-Item -Recurse -Force "$projects\*"

# Restore current session into its dir
$workdirName = Split-Path $currentSession.DirectoryName -Leaf
New-Item -ItemType Directory -Force "$projects\$workdirName" | Out-Null
Move-Item $tmp "$projects\$workdirName\"
```

### Delete history (optional)
```powershell
# Frees ~2-3 MB of prompt history. You lose ↑-recall across past chats.
Remove-Item -Force "$claude\history.jsonl"
```

### Decide on `memory/`
`memory/` lives at `~/.claude/projects/<workdir>/memory/`, so the projects wipe
above will delete it. If you want to preserve auto-memory:
- Move `memory/` aside before the projects wipe and restore after
- Or accept the reset and start fresh

In one real cleanup, ~75 stale memory entries from a closed-out spike were
discarded — the operator chose to reset rather than curate.

## Step 5 — Replace `~/.claude/` files with the portable versions

```powershell
$src = "$env:USERPROFILE\claude-setup"
$dst = "$env:USERPROFILE\.claude"

# CLAUDE.md
Copy-Item -Force "$src\CLAUDE.md" "$dst\CLAUDE.md"

# settings.json — substitute ${CLAUDE_HOME}
$claudeHomeUnix = $dst -replace '\\', '/'
(Get-Content "$src\settings.template.json") `
  -replace '\$\{CLAUDE_HOME\}', $claudeHomeUnix |
  Set-Content "$dst\settings.json"

# hooks/ and scripts/
Remove-Item -Recurse -Force "$dst\hooks" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$src\hooks" "$dst\hooks"

New-Item -ItemType Directory -Force "$dst\scripts" | Out-Null
Copy-Item -Force "$src\scripts\*" "$dst\scripts\"

# Empty out skills/agents/commands so they're loaded per-project
Remove-Item -Recurse -Force "$dst\skills","$dst\agents","$dst\commands" -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dst\skills,$dst\agents,$dst\commands | Out-Null
```

## Step 6 — Verify

```powershell
# Final size — should be < 10 MB (vs. 1-2 GB before)
Get-ChildItem $env:USERPROFILE\.claude -Recurse -Force -ErrorAction SilentlyContinue |
  Measure-Object -Property Length -Sum |
  ForEach-Object { "{0:N2} MB" -f ($_.Sum / 1MB) }

# settings.json should not reference any deleted scripts
Get-Content $env:USERPROFILE\.claude\settings.json

# Check that the only hook is block-trunk-commit.py
Get-ChildItem $env:USERPROFILE\.claude\hooks
```

Restart Claude Code. The skills list in your first system reminder should
**shrink** dramatically — that's the win. Project-specific skills now load only
when you `cd` into the project that has them.

## Step 7 — Per-project: hook the project-skills repo in

For each project that needs its own skills, hold them in a sibling repo
(e.g. `~/work/<project>-skills/`) and pull skills into the project's
`.claude/` folder as needed.

### Layout

```
~/work/
├── <project>/                       The project itself (Platform, app code, etc.)
│   └── .claude/
│       ├── skills/                  Skills available when you cd into <project>
│       │   ├── deploy-db/
│       │   └── prod-read-sql/
│       ├── commands/                /slash-commands for this project
│       └── agents/                  Subagents for this project
│
└── <project>-skills/                The portable repo with ALL skills (source of truth)
    ├── skills/                      Master list — keep more than you've activated
    │   ├── deploy-db/
    │   ├── handoff/
    │   ├── local-bootstrapper/
    │   ├── prod-read-sql/
    │   └── stale-branches/
    ├── commands/
    └── agents/
```

The idea: **`<project>-skills/` holds everything**. The project's `.claude/`
holds **only what you actually use**. Different machines or branches can
activate different subsets.

### Option A — Copy individual skills (simplest, no Windows prereqs)

Pull skills in one at a time. Works without Developer Mode or admin:

```powershell
$project    = "$env:USERPROFILE\work\<project>"
$skillsRepo = "$env:USERPROFILE\work\<project>-skills"

# Ensure target dirs exist
New-Item -ItemType Directory -Force "$project\.claude\skills"   | Out-Null
New-Item -ItemType Directory -Force "$project\.claude\commands" | Out-Null
New-Item -ItemType Directory -Force "$project\.claude\agents"   | Out-Null

# Copy one skill in
Copy-Item -Recurse "$skillsRepo\skills\prod-read-sql" "$project\.claude\skills\"

# Copy a slash command
Copy-Item "$skillsRepo\commands\deploy-db.md" "$project\.claude\commands\"
```

**Trade-off:** edits in `<project>-skills/` aren't reflected in `<project>/.claude/`
until you re-copy. After `git pull` on the skills repo, refresh the copies you
care about.

### Option B — Symlink whole folders (needs Developer Mode or admin)

If you want live two-way sync:

```powershell
# One-time: enable Developer Mode in Windows Settings -> Privacy & security
# -> For developers, OR run PowerShell as Administrator

$project    = "$env:USERPROFILE\work\<project>"
$skillsRepo = "$env:USERPROFILE\work\<project>-skills"

New-Item -ItemType SymbolicLink "$project\.claude\skills"   -Target "$skillsRepo\skills"
New-Item -ItemType SymbolicLink "$project\.claude\commands" -Target "$skillsRepo\commands"
New-Item -ItemType SymbolicLink "$project\.claude\agents"   -Target "$skillsRepo\agents"
```

All skills in the repo become available immediately. Edits sync both ways.

### Verify

After either approach, the skill loads only when you `cd <project>`:

```powershell
Get-ChildItem "$project\.claude\skills"
# Should list the skills you copied/symlinked.

# Inside Claude Code, the first system reminder will include these
# skills only when your working directory is under <project>.
```

### Real example (this repo's own workflow)

```powershell
# Setup once: clone the portable skill repo
git clone <your-private-url> $env:USERPROFILE\work\escribe-skills

# Per-skill activation: pull prod-read-sql into the eScribe project
Copy-Item -Recurse `
  $env:USERPROFILE\work\escribe-skills\skills\prod-read-sql `
  $env:USERPROFILE\work\eScribe\.claude\skills\

# Now /prod-read-sql is available in Claude Code only when cd'd into eScribe.
# Other projects don't see it; the token budget stays small there.
```

## Step 8 — Seed project memory (only verified facts)

Auto-memory lives at `~/.claude/projects/<workdir-slug>/memory/` and auto-loads
`MEMORY.md` into every session running in that workdir. Topic files lazy-load
when their MEMORY.md index entry is referenced.

The workdir slug is the cwd with separators replaced by `-`. For
`C:\Users\Andrey\work\<project>`, the slug is `c--Users-Andrey-work-<project>`.

### What to seed

Only facts you can **cite a source for**. Reading the project's CLAUDE.md and
extracting verified items beats inferring preferences from session behavior.

Useful categories:

- **`user_role.md`** (type: `user`) — what you work on, primary directory, stack
  version. Don't invent preferences ("DDD fluency", "light context on
  frontend") unless explicitly stated.
- **`reference_<topic>.md`** (type: `reference`) — IDs, endpoint URLs, pipeline
  numbers, repo slugs. Cite the source file (project CLAUDE.md line / skill
  SKILL.md) so future-you can re-verify if the value changes.
- **`feedback_<topic>.md`** (type: `feedback`) — coding conventions, PR
  workflow rules, anti-patterns. Quote the project CLAUDE.md verbatim where
  possible.

### What NOT to seed

- **Inferred preferences.** "User prefers terse responses" based on two `tldr?`
  asks is fragile — the same user wants depth on a different topic next week.
- **Conventions you haven't read.** Citing `Platform/CLAUDE.md says X` without
  reading current `Platform/CLAUDE.md` violates Karpathy Rule 8 ("Read before
  you write"). Stale citations are worse than no citations.
- **Project initiatives.** Memory entries that name a campaign / spike / sprint
  decay within weeks; they cost tokens long after the work shipped.
- **Anything that fits in the project's tracked CLAUDE.md.** If the team
  already documents PR conventions in `<repo>/CLAUDE.md`, the memory entry
  duplicates without adding value — and rots independently.

### Example MEMORY.md (anonymized)

```markdown
- [User role](user_role.md) — Backend dev on Platform team; works in Platform/apis and experiment.LocalBootstrapper
- [PR workflow](feedback_pr_workflow.md) — Use the team's pr-create skill; never raw `az repos pr create`
- [Backend C# style](feedback_backend_style.md) — `_underscore` fields, AAA tests, SonarCloud rules
- [ADO reference](reference_ado.md) — Org, project id, repo id, tenant SQL pipeline id, PR-threads endpoint
```

Keep the index under ~10 lines so it always fits in context.

### Verification

Open a fresh Claude Code session in the project directory. The first system
prompt should include your `MEMORY.md` content. If it doesn't show up:

1. Check the workdir slug matches your cwd — it's case-sensitive on Linux/Mac.
2. On Windows, the slug uses one `-` per backslash, so
   `C:\Users\You\work\proj` becomes `C--Users-You-work-proj`.
3. Confirm `MEMORY.md` exists in that directory (`Get-ChildItem` it).

## Real numbers from one cleanup

| Before | After |
|---|---|
| `~/.claude/` total: **~1.5 GB** | **6.5 MB** (99.6% reduction) |
| `projects/`: 1.1 GB | 1.5 MB (current session only) |
| `skills/`: 321 MB (Playwright `node_modules`) | 0 (moved to project-skills repo) |
| `file-history/`: 51 MB | 0 |
| `backups/`: 22 MB | 0 |
| 7 different `.ps1` scripts wired in settings.json | 0 (kept only `statusline-command.ps1`) |
| 75 memory entries | reset to 0 |
| Global skill index entries loaded every turn | 0 (down from 5) |

## What we learned

1. **"Globals" should mean truly generic.** Anything that mentions a project name,
   employee, or environment ID belongs in a project-local `.claude/`, not
   `~/.claude/`. Global skills cost tokens on every turn even when unused.

2. **`projects/` is enormous and silent.** Each conversation writes a `.jsonl`
   transcript here; subagent runs add more. After months of use it can dominate
   `~/.claude/` size. Wipe it periodically, keeping only your active session.

3. **Skills that bundle a runtime (Playwright, npm, Python) drag dependencies
   along** — `node_modules`, `test-results`, `.auth/` token caches. Strip these
   before committing to git; restore via `npm install` on each machine.

4. **OAuth tokens hide inside skill folders.** Auth caches generated by test
   runs (`.auth/*.json`) contain live JWTs. Add `**/.auth/` to `.gitignore`
   before any first commit, and grep for `eyJ` to catch leaks.

5. **Memory entries decay.** Long-running campaigns generate dozens of
   "burned on v89 R5" tactical memories that lose value once the work ships.
   Reset the index occasionally and re-seed with only the truly load-bearing
   facts (your profile, architecture references, environment coordinates).

6. **Backup what's load-bearing BEFORE you start.** API key in `config.json`
   and OAuth tokens in `.credentials.json` are the only truly irreplaceable
   files. Everything else regenerates.
