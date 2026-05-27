## What changed

<!-- One-sentence summary. -->

## Why

<!-- The motivation. Skip if obvious from the diff. -->

## Checklist

- [ ] Ran `.\test.ps1` and all 7 checks pass
- [ ] Grep'd for secrets: `sk-ant-`, `eyJ` (50+ chars), `AKIA`, `ghp_`, `xoxb-`
- [ ] No personal paths (`C:\Users\<me>`), org names, employee names, or email addresses
- [ ] If touching install.ps1 or uninstall.ps1: actually ran the script with `-DryRun`
- [ ] If touching CLAUDE.md or settings.template.json: noted in CHANGELOG.md
