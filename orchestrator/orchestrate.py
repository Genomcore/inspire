#!/usr/bin/env python3
"""Plan emanation, then run its ready waves through the OMP Ralph loop."""

import subprocess
import sys
from pathlib import Path


def orchestrate(mode: str, repo_root: Path) -> int:
    try:
        deployed = repo_root / ".inspire/bin/emanate-plan.sh"
        planner = deployed if deployed.is_file() else repo_root / "plugin/base/bin/emanate-plan.sh"
        result = subprocess.run(
            [str(planner)], cwd=repo_root, text=True, capture_output=True, check=False,
        )
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        if result.returncode != 0 or mode == "plan":
            print(result.stdout, end="")
            return result.returncode

        return subprocess.run(
            ["bun", "run", str(Path(__file__).parent / "src/cli.ts")],
            cwd=repo_root, input=result.stdout, text=True, check=False,
        ).returncode
    except (OSError, ValueError) as exc:
        print("orchestrate: {}".format(exc), file=sys.stderr)
        return 6


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("plan", "run"):
        print("usage: orchestrate.py plan|run", file=sys.stderr)
        sys.exit(2)
    sys.exit(orchestrate(sys.argv[1], Path.cwd()))
