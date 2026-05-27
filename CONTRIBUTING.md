# Contributing

This repo is a personal portable Claude Code setup, but contributions that
make it useful for more people are welcome.

## Things that are in scope

- Fixes to bugs in `install.ps1`, the hooks, or the statusline script
- Better verification commands in `SETUP.md` (e.g., new `/memory` examples)
- New optional hooks that follow the same opt-in pattern as
  `block-oauth-leak.py` (shipped but not wired by default)
- Cross-platform parity: macOS/Linux equivalents of the PowerShell pieces
- README clarity improvements
- New examples in the memory file templates (kept anonymized)

## Things that are NOT in scope

- Skills, agents, slash commands — those are project-coupled by design and
  belong in a separate per-project skills repo. See SETUP.md Step 7.
- Anything that mentions a specific organization, employee, project name,
  endpoint URL, or pipeline ID. The repo is anonymized on purpose.
- Heavyweight CI / linting infrastructure — the repo is 4 files of config +
  3 tiny scripts. It should stay that small.

## Before opening a PR

1. **Secret-sweep your changes.** Grep for:
   ```bash
   sk-ant-          # API keys
   eyJ              # JWT prefix
   credentials      # generic
   ```
   Plus your own org name, employee names, hardcoded usernames.

2. **Validate scripts parse.**
   ```powershell
   python -m py_compile hooks/*.py
   powershell -NoProfile -Command "Get-Content install.ps1 | Out-Null"
   ```

3. **JSON validates.**
   ```powershell
   Get-Content settings.template.json -Raw | ConvertFrom-Json
   ```

4. **Anonymize paths.** Use `<project>`, `<team>`, `<repo-guid>`, `<org>`
   placeholders. Real-world examples should be replaced.

## Commit style

- Subject line: imperative mood, ≤72 chars
- Body: explain *why*, not *what* (the diff shows what)
- Group related changes; don't commit unrelated tweaks together

## License

Contributions are under MIT (see [LICENSE](LICENSE)).
