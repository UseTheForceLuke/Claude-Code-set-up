# Setup: from cluttered `~/.claude/` to a globals-only portable Claude Code

A 9-step migration guide. The first half cleans up an over-grown `~/.claude/`;
the second half wires this repo in, adds project-specific skills, seeds memory,
and pins an artifact-location convention. Run this when your `~/.claude/`
has accumulated old skills, dead hooks, secrets, project-specific tools, and
multi-GB of stale session/state data.

> **Tip:** if you're starting fresh on a new machine instead of cleaning up an
> existing setup, jump to **Step 5** (replace `~/.claude/` files with the
> portable versions) — or just run `install.ps1` from this repo's root.

> ⚠️ This is destructive. Read the **Before you start** section before running any
> commands.

## Contents

- [Before you start](#before-you-start) — backups, close other Claude windows, skill inventory
- [Step 1 — Build the portable globals repo first](#step-1--build-the-portable-globals-repo-first)
- [Step 2 — Project-specific skills go in a SEPARATE portable repo](#step-2--project-specific-skills-go-in-a-separate-portable-repo)
- [Step 3 — Inventory `~/.claude/` before nuking](#step-3--inventory-claude-before-nuking)
- [Step 4 — Wipe scratch and stale state, KEEP load-bearing items](#step-4--wipe-scratch-and-stale-state-keep-load-bearing-items)
- [Step 5 — Replace `~/.claude/` files with the portable versions](#step-5--replace-claude-files-with-the-portable-versions)
- [Step 6 — Verify](#step-6--verify)
- [Step 7 — Per-project: hook the project-skills repo in](#step-7--per-project-hook-the-project-skills-repo-in)
- [Step 8 — Seed project memory (only verified facts)](#step-8--seed-project-memory-only-verified-facts)
- [Step 9 — Set an artifact location convention](#step-9--set-an-artifact-location-convention)
- [Step 10 — VS Code workspace + terminal launch dir](#step-10---vs-code-workspace--terminal-launch-dir-split-pattern)
- [Real numbers from one cleanup](#real-numbers-from-one-cleanup)
- [What we learned](#what-we-learned)

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
    └── statusline-command.ps1     Statusline: [model] dir (branch) <mark> <ctx-bar> NN% | k-left
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
# Find your CURRENT session UUID via the most recently modified .jsonl
# (the statusline no longer prints the session-id)
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

# settings.json should be valid JSON and reference only files that exist
Get-Content $env:USERPROFILE\.claude\settings.json -Raw | ConvertFrom-Json

# Hooks present (only the ones from this repo)
Get-ChildItem $env:USERPROFILE\.claude\hooks
```

Or run the repo's smoke test - 12 checks `test.ps1` runs:

```powershell
cd $env:USERPROFILE\Claude-Code-set-up
.\test.ps1
```

Exit code 0 + "All checks passed." = green. Exit 1 = something regressed.

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
`C:\Users\You\work\<project>`, the slug is `c--Users-You-work-<project>`.

### Directory layout

```
~/.claude/projects/c--Users-You-work-<project>/
└── memory/
    ├── MEMORY.md                          Index — auto-loaded every session
    │                                      Keep under ~10 lines
    │
    ├── user_role.md                       type: user
    │                                      Who you are, primary dir, stack
    │
    ├── reference_<topic>.md               type: reference
    │                                      IDs, endpoints, pipeline numbers
    │
    └── feedback_<topic>.md                type: feedback
                                           Conventions, workflow rules
```

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
- **Conventions you haven't read.** Citing `<project>/CLAUDE.md says X` without
  reading current `<project>/CLAUDE.md` violates Karpathy Rule 8 ("Read before
  you write"). Stale citations are worse than no citations.
- **Project initiatives.** Memory entries that name a campaign / spike / sprint
  decay within weeks; they cost tokens long after the work shipped.
- **Anything that fits in the project's tracked CLAUDE.md.** If the team
  already documents PR conventions in `<repo>/CLAUDE.md`, the memory entry
  duplicates without adding value — and rots independently.

### Example: MEMORY.md (the index)

```markdown
- [User role](user_role.md) — Backend dev on the team; works in <project>/apis
- [PR workflow](feedback_pr_workflow.md) — Use the team's pr-create skill; never raw `az repos pr create`
- [Backend style](feedback_backend_style.md) — `_underscore` fields, AAA tests, SonarCloud rules
- [ADO reference](reference_ado.md) — Org, project id, repo id, pipeline ids, PR-threads endpoint
- [Artifact location](feedback_artifact_location.md) — All generated files go to <project>/claude-artifacts/
```

### Example: `user_role.md` (type: user)

```markdown
---
name: user-role
description: Backend developer on the <team> team; primary stack is C# / .NET 8 in <project>/apis
metadata:
  type: user
---

Backend developer on the <team> team.

- Primary working directory: `<project>/apis/` — C# / .NET 8.
- Local testing path: `<project>/experiment.LocalBootstrapper/` — separate
  .NET solution with an app host. When the user says "spin it up locally"
  or "local test", default to this path before assuming docker/compose.

How to apply: tailor explanations to a backend perspective; don't over-explain
dotnet CLI, LINQ, or EF Core basics; for "local run" requests default to
LocalBootstrapper.
```

### Example: `reference_ado.md` (type: reference)

```markdown
---
name: reference-ado
description: Azure DevOps coordinates — org URL, project id, repo id, pipeline ids, PR-threads endpoint
metadata:
  type: reference
---

Azure DevOps coordinates. Pull from here rather than re-grepping the project's CLAUDE.md.

- Org: `https://dev.azure.com/<org>`
- Project: `<project-name>` (id: `<project-guid>`)
- Backend repo id: `<repo-guid>`
- Tenant read-only SQL pipeline: `definitionId=<id>`

PR threads / comments endpoint (one call returns reviewer comments +
SonarCloud annotations + policy status):

`az devops invoke --area git --resource pullRequestThreads --route-parameters project=<project-guid> repositoryId=<repo-guid> pullRequestId=<PR_ID> --api-version 7.1`

Verification note: ids captured YYYY-MM-DD from `<project>/CLAUDE.md`.
If an API call returns 404 / "project not found", re-check these against
`az devops project show --project <project-name>` before assuming memory is wrong.
```

### Example: `feedback_pr_workflow.md` (type: feedback)

```markdown
---
name: feedback-pr-workflow
description: Always create PRs via the team's pr-create skill; never raw `az repos pr create`
metadata:
  type: feedback
---

Always create pull requests by invoking the `<team>:pr-create` skill via the
Skill tool. Never call `az repos pr create` directly.

For retrieving PR comments/threads/SonarCloud/policy status, use:

`az devops invoke --area git --resource pullRequestThreads ...`

(see [[reference-ado]] for the full command)

Why: documented policy in `<project>/CLAUDE.md`. The pr-create skill wraps
team conventions (templates, reviewers, work-item linking) that raw CLI skips.

How to apply: any time the user asks to create a PR, open a PR, push for
review, or fetch PR comments for the project. If the skill is not installed,
advise installing per the team's plugin docs rather than falling through to
the raw CLI.

Related: [[reference-ado]].
```

### Example: `feedback_backend_style.md` (type: feedback)

```markdown
---
name: feedback-backend-style
description: C# conventions — _underscore fields, AAA tests, Method_Given_Should naming, SonarCloud rules
metadata:
  type: feedback
---

C# coding conventions for `<project>/apis/`:

Naming & layout:
- Class fields: `_underscorePrefix` (e.g. `_userRepository`)
- Locals/parameters: `camelCase`
- Methods/classes/types: `PascalCase`
- Interfaces in the same file as the implementing class, after `using` block
- Prefer early returns to deep nesting

Tests:
- AAA pattern (Arrange / Act / Assert), explicitly delimited
- Test naming: `<MethodName>_Given<scenario>_Should<expectedOutcome>`
- Mock externals with Moq

SonarCloud rules:
- `collection.Count == 0` instead of `!collection.Any()`
- Mark static members `static` explicitly

Why: documented in `<project>/CLAUDE.md` and enforced by SonarCloud at CI.

How to apply: any C# write/edit in `<project>/apis/`. Default to these
conventions without being prompted.
```

### Verification

Open a fresh Claude Code session in the project directory. The first system
prompt should include your `MEMORY.md` content. If it doesn't show up:

1. Check the workdir slug matches your cwd. On Windows, the slug uses one `-`
   per backslash, so `C:\Users\You\work\proj` becomes `C--Users-You-work-proj`.
2. Confirm `MEMORY.md` exists in that directory (`Get-ChildItem` it).
3. Inside Claude Code, run `/memory` to see all loaded memory files, or
   `/context` to see their token cost.

## Step 9 — Set an artifact location convention

Claude tends to write scratch files (analysis docs, draft scripts, intermediate
outputs, handoff dumps) wherever the conversation happens to be. Over months,
this scatters generated files across your tracked repos.

Fix: declare a single, dedicated artifact folder outside any tracked repo, and
add a memory file pinning the rule.

### The folder

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\work\<project>\claude-artifacts"
```

Sits at the project root, parallel to tracked repos. Not git-tracked itself.

### If the project root IS a git repo

Add `claude-artifacts/` to `.gitignore` so the folder doesn't accidentally get
committed:

```powershell
Add-Content "$env:USERPROFILE\work\<project>\.gitignore" "`nclaude-artifacts/"
```

If the project root is NOT a git repo (it's just a holding directory for
multiple sibling repos, like our `eScribe/` example), the `.gitignore` step
is unnecessary — nothing's tracking it anyway.

### The memory file

`feedback_artifact_location.md` in your project memory dir:

```markdown
---
name: feedback-artifact-location
description: All Claude-generated artifacts go to <project>/claude-artifacts/ regardless of launch dir
metadata:
  type: feedback
---

Default location for all Claude-generated artifacts:
`<project>/claude-artifacts/`. Applies regardless of which subdirectory
Claude Code was launched from.

Applies to: scratch scripts, draft docs, intermediate JSON/CSV, handoff
context dumps, milestone bundles, anything `_*` prefixed.

Does NOT apply to: real code changes in tracked repos, skill-internal
working dirs, files the user names a specific path for.

How to apply: when asked to "save the analysis", "write a draft",
"dump context", default the target path to
`<project>/claude-artifacts/<descriptive-name>.md`.
```

### Workdir-slug gotcha

Memory at `~/.claude/projects/<slug>/memory/` only loads when cwd matches
the slug. If you launch Claude Code from a deeper path
(`<project>/<subrepo>/`), the slug differs and the memory won't auto-load.

Two ways to handle:

1. **Always launch from project root** — single memory dir, no drift
2. **Mirror the memory to deeper-path slugs** — files duplicated, drift risk
   when one copy gets edited

The first is cleaner if you can stick to it. If your shell habits push you
into subdirs (e.g., `cd` directly into a service repo), mirror and accept
the manual re-sync.

### Why this matters

In one real cleanup, this convention would have prevented ~400 scratch files
accumulating at the project root over a multi-month spike. Generated files
mixed with real artifacts, hard to triage what to keep vs delete.

## Step 10 - VS Code workspace + terminal launch dir (split pattern)

When the project root holds several sibling repos but Claude's most useful
context lives inside one of them (the main code repo with the team's
`CLAUDE.md`, `.claude/agents`, etc.), the cleanest setup is to **split where
VS Code opens from where Claude launches**:

- **VS Code folder**: project root (broad file explorer - sees all sibling
  repos at once)
- **Claude Code launch dir**: the main code repo (narrow, high-quality
  context - team `CLAUDE.md` auto-loads, team `.claude/` loads, project memory
  loads)

### Config

Drop a `.vscode/settings.json` in the project root that points the
integrated terminal cwd at the main repo:

```json
{
  "terminal.integrated.cwd": "${workspaceFolder}/<main-repo>",
  "terminal.integrated.defaultProfile.windows": "PowerShell"
}
```

Now: open VS Code at the project root, `Ctrl+`` for a new integrated terminal,
it lands inside `<main-repo>/`, run `claude` - the right `CLAUDE.md` /
`.claude/` / memory all auto-load.

### Tradeoffs

- The memory dir is tied to the launch slug (`c--Users-You-work-<project>-<main-repo>`),
  not to the VS Code workspace. Pick one launch dir as primary and stick with it,
  or accept manual sync across multiple memory dirs.
- Personal skills at the project-root `.claude/skills/` don't load when launched
  from a deeper subdir. Either move them into `<main-repo>/.claude/skills/` (if
  you control that .claude/), or open a second terminal in the project root for
  sessions that need them.

### When to override

`cd ..` in the integrated terminal moves it back to the project root for one
session - useful for cross-repo greps. Future new terminals still land at the
configured `terminal.integrated.cwd`.

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
