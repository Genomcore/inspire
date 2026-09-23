#!/usr/bin/env python3
"""Plan emanation, then run its ready waves through the OMP Ralph loop."""

import json
import subprocess
import sys
from pathlib import Path


def orchestrate(mode: str, repo_root: Path) -> int:
    deployed = repo_root / ".inspire/bin/emanate-plan.sh"
    planner = deployed if deployed.is_file() else repo_root / "plugin/base/bin/emanate-plan.sh"

    try:
        result = subprocess.run(
            [str(planner)], cwd=repo_root, text=True, capture_output=True, check=False,
        )
    except OSError as exc:
        print("orchestrate: cannot start planner: {}".format(exc), file=sys.stderr)
        return 6

    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0 or mode == "plan":
        print(result.stdout, end="")
        return result.returncode

    try:
        plan = json.loads(result.stdout)
        if plan["schema"] != "inspire.emanation-plan/2" or plan["ready"] is not True:
            raise ValueError("planner did not produce a ready plan")
    except (ValueError, KeyError, TypeError) as exc:
        print("orchestrate: invalid planner output: {}".format(exc), file=sys.stderr)
        return 6

    try:
        loop = subprocess.run(
            ["bun", "run", str(Path(__file__).parent / "src/cli.ts")],
            cwd=repo_root, input=result.stdout, text=True, check=False,
        )
    except OSError as exc:
        print("orchestrate: cannot start Ralph loop: {}".format(exc), file=sys.stderr)
        return 6
    return loop.returncode


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("plan", "run"):
        print("usage: orchestrate.py plan|run", file=sys.stderr)
        sys.exit(2)
    sys.exit(orchestrate(sys.argv[1], Path.cwd()))
