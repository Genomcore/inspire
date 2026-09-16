#!/usr/bin/env python3
"""PreToolUse fence for a spawned persona: a file tool may touch nothing outside
the worktree it was spawned in. Reads the hook payload on stdin; exit 2 blocks
the call and the stderr line is what the agent reads. Bash is not fenced here —
the deny rules and the harvest filter cover it."""

import json
import os
import sys

# ponytail: file tools only; a Bash-side fence is the OS sandbox, if ever needed.
PATH_KEYS = ("file_path", "notebook_path", "path")


def outside(path, root):
    real = os.path.realpath(os.path.join(root, path))
    return os.path.commonpath([real, root]) != root


def main():
    payload = json.load(sys.stdin)
    root = os.path.realpath(payload.get("cwd") or os.getcwd())
    target = next((payload.get("tool_input", {}).get(key) for key in PATH_KEYS
                   if payload.get("tool_input", {}).get(key)), None)
    if target and outside(target, root):
        sys.stderr.write("fenced: %s is outside your worktree %s — a persona writes "
                         "nowhere else.\n" % (target, root))
        sys.exit(2)


if __name__ == "__main__":
    main()
