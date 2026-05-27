#!/usr/bin/env python3
"""PreToolUse hook: block git commits that include OAuth tokens or .auth/ files.

Scans the staged diff for:
  - JWT-shaped strings (eyJ prefix with base64url body, >50 chars)
  - File paths under any .auth/ directory
  - Common credential file names

Exits 1 (blocks the tool) with a message on stderr if a violation is detected.
Exits 0 otherwise. Reads hook JSON from stdin.

Wire it into ~/.claude/settings.json under PreToolUse[matcher=Bash, if=Bash(git commit *)]:

    {
      "type": "command",
      "command": "python \"${CLAUDE_HOME}/hooks/block-oauth-leak.py\"",
      "if": "Bash(git commit *)"
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
    if "git commit" not in cmd:
        return 0

    # Get staged diff (binary-safe)
    try:
        diff = subprocess.check_output(
            ["git", "diff", "--cached"],
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return 0  # Fail open if not in a git repo

    if not diff:
        return 0

    violations = []

    # JWT leak
    if JWT_RE.search(diff):
        violations.append("JWT-shaped string (eyJ... prefix) found in staged diff")

    # .auth/ paths
    try:
        files = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only"],
            text=True,
            stderr=subprocess.DEVNULL,
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
        print("BLOCKED: potential secret leak in staged diff:", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        print(file=sys.stderr)
        print("If this is a false positive, bypass with: git commit --no-verify", file=sys.stderr)
        print("Better: add the path to .gitignore and `git reset HEAD <file>` first.", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
