# Changelog

All notable changes to this portable Claude Code setup repo.

## Unreleased

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
