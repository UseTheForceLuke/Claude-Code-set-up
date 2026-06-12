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
        # Read bytes so json.loads strips a leading UTF-8 BOM (some shells prepend
        # one when piping stdin); text-mode json.load(sys.stdin) would choke on it
        # and a security guard must not silently fail open on a BOM.
        payload = json.loads(sys.stdin.buffer.read())
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
            # `git push origin trunk` style: explicit protected target. Checked
            # first so it still fires when the branch lookup below can't run
            # (cwd isn't a git repo, detached HEAD) — that path must not fail open.
            if sub == "push":
                for arg in tokens[git_idx + 2 :]:
                    if arg in PROTECTED:
                        print(
                            f"BLOCKED: refusing `git push ... {arg}` to a protected branch.",
                            file=sys.stderr,
                        )
                        return 1

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

    return 0


if __name__ == "__main__":
    sys.exit(main())
