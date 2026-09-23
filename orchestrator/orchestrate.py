#!/usr/bin/env python3
"""Plan emanation, then run its ready waves through the OMP Ralph loop."""

import sys
from pathlib import Path

from loop_utils import run_loop
from plan_utils import require_ready_plan, run_plan


def orchestrate(mode: str, repo_root: Path) -> int:
    try:
        result = run_plan(repo_root)
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        if result.returncode != 0 or mode == "plan":
            print(result.stdout, end="")
            return result.returncode

        require_ready_plan(result.stdout)
        return run_loop(repo_root, result.stdout)
    except (OSError, ValueError) as exc:
        print("orchestrate: {}".format(exc), file=sys.stderr)
        return 6


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("plan", "run"):
        print("usage: orchestrate.py plan|run", file=sys.stderr)
        sys.exit(2)
    sys.exit(orchestrate(sys.argv[1], Path.cwd()))
