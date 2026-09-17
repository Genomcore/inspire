#!/usr/bin/env python3

import json
import os
import sys
from pathlib import Path

PATH_KEYS = ("file_path", "notebook_path", "path")


def outside(path, root):
    return not Path(os.path.realpath(os.path.join(root, path))).is_relative_to(root)


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
