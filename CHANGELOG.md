# Changelog

All notable changes to this portable Claude Code setup repo.

## Unreleased

- settings.template.json: change default `model` from `opus[1m]` to `sonnet`, and add `advisorModel: opus` — recommended pairing (Sonnet as main model, Opus as advisor) gives near-Opus quality at reduced token usage for many workloads
- hooks (block-trunk-commit.py, block-oauth-leak.py): read stdin as bytes via `json.loads(sys.stdin.buffer.read())` instead of text-mode `json.load(sys.stdin)`, so a leading UTF-8 BOM (prepended by some shells when piping the payload) is stripped instead of throwing — a JSON parse error made the guard silently fail open (exit 0), defeating the hook. Fixes 2 false-negative `test.ps1` failures under a UTF-8-BOM console encoding.
- block-trunk-commit.py: check the explicit `git push ... main/master/trunk` target *before* the local-branch lookup, so a push to a protected remote ref is still blocked when `git branch --show-current` can't run (cwd isn't a git repo, detached HEAD). Same fail-open class as the BOM fix; also makes `test.ps1`'s trunk check pass regardless of the cwd it's invoked from.
- settings.template.json: add `autoUpdatesChannel: latest` so re-running `install.ps1` no longer silently drops it from a live `~/.claude/settings.json` that already had it (closes a repo↔live drift gap)
- README + SETUP.md: statusline layout annotation now includes the `| $cost` field the script actually emits (was stale: stopped at `k-left`)
- statusline-command.ps1: `dir` field now shows the full cwd path (`workspace.current_dir`) instead of just the leaf folder name
- SETUP.md: add Step 10 documenting the VS Code workspace + terminal split-launch pattern (open VS Code at project root for broad file view, but auto-land the integrated terminal in the main code repo so Claude launches with the right CLAUDE.md/.claude/memory)
- statusline-command.ps1: full rewrite into a monochrome grey status line. Format:
  `[model] dir (branch) <mark> <bar> NN% | NNNk left | $cost` (model.display_name / leaf
  folder name / git branch truncated to 24 chars with an ellipsis). Everything is grey; the
  only contrast is the bar (lighter-grey fill on a darker-grey track). The bar uses
  eighth-block sub-cell precision so the partial leading-edge cell blends in with no gap;
  clean vs dirty working tree is shown by the marker glyph (check vs dot), not color.
  `$cost` is the session spend so far (`cost.total_cost_usd`). Uses `[char]27` for ESC
  (PowerShell 5.1 has no `` `e ``) and forces UTF-8 console output so the block glyphs render.
  Dropped the session-id field.
- test.ps1: rewrote check #7 to strip ANSI codes and assert the new colored fallback output (`[Claude]` model default + `?% | ?k left`)

- Add `SECURITY.md` documenting what install/uninstall/hooks do and how to audit
- Add `CHANGELOG.md` (this file)
- Add `.github/PULL_REQUEST_TEMPLATE.md` with secret-sweep checklist
- Document `test.ps1` is Windows-only (PowerShell)
- Wire `block-oauth-leak.py` into `settings.template.json` alongside the trunk hook
- `install.ps1` pre-flight check: warn if `python` is not on PATH (hooks need it)
- `install.ps1` pre-flight check: verify all 5 required source files exist before copying (exits with clear error if any missing, e.g., from incomplete clone)
- `scripts/statusline-command.ps1`: add comment-based help (`Get-Help` now works on it)
- `test.ps1`: add statusline-emits check (8th); now 8/8 pass
- `test.ps1`: add 4 more checks (now 12/12): block-trunk-commit allows feature branches (negative test), block-oauth-leak catches .auth/ paths, block-oauth-leak passes clean diffs (no false positive), install.ps1 pre-flight fires when source files missing
- `test.ps1`: skip hook tests gracefully if `python` not on PATH (instead of failing cryptically)
- README: add Security section with audit-it-yourself snippets
- README: add `test.ps1` to the install command list
- CONTRIBUTING.md: replace manual validation steps with single `.\test.ps1` reference
- `.gitignore`: add `.vs/` (Visual Studio workspace folder)
- SETUP.md Step 6: add `test.ps1` as the canonical verification command
- CONTRIBUTING.md: fix broken numbered list (was 1,2,4); add "Update CHANGELOG.md" as step 4
- CONTRIBUTING.md: reconcile "no CI" rule with shipped `test.ps1` (single local smoke test is OK)
- `install.ps1` / `uninstall.ps1`: guard against empty `$PSScriptRoot` (dot-sourcing produces clear error instead of cryptic file-not-found chain)
- `install.ps1` / `uninstall.ps1`: fix `\$PSScriptRoot` -> `` `$PSScriptRoot `` in the dot-source error message (PowerShell escape for `$` in double-quoted strings is backtick, not backslash; the broken version printed "ERROR: \ is empty")
- README + SECURITY.md: fix audit snippets that produced false positives (`http` regex matched URLs in comments; `-SimpleMatch` disabled the regex syntax). Honest "Expected results" now lists the 2 known false positives instead of claiming clean output.
- README: clarify `test.ps1` doesn't touch `~/.claude/` and explain when to run it (before install / regression check)
- README: add "Updating" section documenting the `git pull && .\install.ps1` workflow for ongoing sync
- Drop all macOS/Linux content: this is a Windows-only setup. Removed "Manual install (macOS/Linux)" section, "Python interpreter on macOS" subsection, cross-platform parity from CONTRIBUTING, and the case-sensitive-on-Linux/Mac note from SETUP.md verification list

## Initial release

The repo was assembled from a real cleanup of a cluttered `~/.claude/`
(roughly 1.5 GB of accumulated session transcripts, dead hooks, undocumented
settings, and bloated skill folders). What ships:

- `CLAUDE.md` - Karpathy 12 rules + TL;DR convention
- `settings.template.json` - `${CLAUDE_HOME}`-templated Claude Code settings
- `install.ps1` - bootstrap into `~/.claude/` with `-DryRun`, `-SkipSettings`
- `uninstall.ps1` - clean removal, preserves customized settings.json
- `test.ps1` - 7-check smoke test of the whole repo
- `hooks/block-trunk-commit.py` - block commits/pushes to trunk/main/master
- `hooks/block-oauth-leak.py` - block commits/pushes with JWTs, `.auth/` files,
  credential filenames (covers both commit AND push)
- `scripts/statusline-command.ps1` - minimal statusline
- `SETUP.md` - 9-step migration guide
- `CONTRIBUTING.md` - what's in/out of scope, pre-PR checklist
- `LICENSE` - MIT
- `.gitignore` - Python, OS, editor, backup, defense-in-depth secrets

Tested by `test.ps1` - 7/7 checks pass.
