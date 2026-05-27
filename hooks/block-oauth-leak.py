#!/usr/bin/env python3
"""PreToolUse hook: block git commits or pushes that include OAuth tokens / credentials.

Scans for:
  - JWT-shaped strings (eyJ prefix with base64url body, >50 chars)
  - File paths under any .auth/ directory
  - Common credential file names

For `git commit`, scans the staged diff.
For `git push`, scans commits ahead of the upstream tracking branch.

Exits 1 (blocks the tool) with a message on stderr if a violation is detected.
Exits 0 otherwise. Reads hook JSON from stdin.

Wire it into ~/.claude/settings.json under PreToolUse[matcher=Bash]:

    {
      "type": "command",
      "command": "python \"${CLAUDE_HOME}/hooks/block-oauth-leak.py\"",
      "if": "Bash(git commit *) || Bash(git push *)"
    }
"""
import json
import re
import subprocess
import sys

JWT_RE = re.compile(rb"eyJ[A-Za-z0-9_\-]{50,}")
AUTH_PATH_RE = re.compile(r"(^|/)\.auth/", re.IGNORECASE)
SUSPICIOUS_FILENAMES = (
    "credentials.json",
    ".credentials.json",
    "secrets.json",
    "id_rsa",
    "id_ed25519",
)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # Fail open on malformed input

    cmd = (payload.get("tool_input") or {}).get("command", "")
    is_commit = "git commit" in cmd
    is_push   = "git push" in cmd
    if not (is_commit or is_push):
        return 0

    # For commit: scan the STAGED diff (what's about to be committed).
    # For push: scan the diff between local branch and remote tracking branch
    # (everything new that's about to leave the local machine).
    try:
        if is_commit:
            diff = subprocess.check_output(
                ["git", "diff", "--cached"],
                stderr=subprocess.DEVNULL,
            )
        else:
            # `git diff @{u}..HEAD` = commits ahead of upstream
            diff = subprocess.check_output(
                ["git", "diff", "@{u}..HEAD"],
                stderr=subprocess.DEVNULL,
            )
    except Exception:
        return 0  # Fail open if not in a git repo or no upstream

    if not diff:
        return 0

    violations = []
    diff_label = "staged diff" if is_commit else "outgoing commits"

    # JWT leak
    if JWT_RE.search(diff):
        violations.append(f"JWT-shaped string (eyJ... prefix) found in {diff_label}")

    # File-name check — use the same diff range we already scanned
    try:
        if is_commit:
            name_args = ["git", "diff", "--cached", "--name-only"]
        else:
            name_args = ["git", "diff", "@{u}..HEAD", "--name-only"]
        files = subprocess.check_output(
            name_args, text=True, stderr=subprocess.DEVNULL,
        ).splitlines()
    except Exception:
        files = []

    auth_files = [f for f in files if AUTH_PATH_RE.search(f)]
    if auth_files:
        violations.append(f"Files under .auth/ directories: {', '.join(auth_files[:3])}")

    suspicious = [f for f in files if any(f.lower().endswith(s) for s in SUSPICIOUS_FILENAMES)]
    if suspicious:
        violations.append(f"Suspicious credential filenames: {', '.join(suspicious[:3])}")

    if violations:
        print(f"BLOCKED: potential secret leak in {diff_label}:", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        print(file=sys.stderr)
        if is_commit:
            print("If this is a false positive, bypass with: git commit --no-verify", file=sys.stderr)
            print("Better: add the path to .gitignore and `git reset HEAD <file>` first.", file=sys.stderr)
        else:
            print("If this is a false positive, bypass with: git push --no-verify", file=sys.stderr)
            print("Better: amend or reset the offending commit, then push again.", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
