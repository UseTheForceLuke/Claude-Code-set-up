#!/usr/bin/env python3
"""PreToolUse hook: block git commits/pushes to trunk/main/master.

Reads hook JSON from stdin. Exits 1 (blocks the tool) with a message on stderr
if a violation is detected. Exits 0 otherwise.
"""
import json
import re
import shlex
import subprocess
import sys

PROTECTED = {"trunk", "main", "master"}


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # Fail open on malformed input

    cmd = (payload.get("tool_input") or {}).get("command", "")
    if not cmd or "git" not in cmd:
        return 0

    # Split on shell separators so we inspect each pipeline segment
    for segment in re.split(r"[;&|]+", cmd):
        segment = segment.strip()
        if not segment:
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            continue

        if "git" not in tokens:
            continue

        # Find the git subcommand
        try:
            git_idx = tokens.index("git")
        except ValueError:
            continue

        sub = tokens[git_idx + 1] if git_idx + 1 < len(tokens) else ""

        # commit / push / merge / rebase / reset on trunk are the danger ops
        if sub in {"commit", "push", "merge", "rebase", "reset"}:
            # What branch are we on?
            try:
                branch = subprocess.check_output(
                    ["git", "branch", "--show-current"],
                    text=True,
                    stderr=subprocess.DEVNULL,
                ).strip()
            except Exception:
                continue

            if branch in PROTECTED:
                print(
                    f"BLOCKED: refusing `git {sub}` while on protected branch '{branch}'.\n"
                    f"Create a feature branch first: git checkout -b <branch-name>",
                    file=sys.stderr,
                )
                return 1

            # `git push origin trunk` style: explicit protected target
            if sub == "push":
                for arg in tokens[git_idx + 2 :]:
                    if arg in PROTECTED:
                        print(
                            f"BLOCKED: refusing `git push ... {arg}` to a protected branch.",
                            file=sys.stderr,
                        )
                        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
