#!/usr/bin/env python3
"""Run the emanation planner before the OMP Ralph loop."""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Optional, Sequence


def orchestrate(
    repo_root: Path,
    planner_args: Sequence[str],
    *,
    run: bool,
    planner: Optional[Path] = None,
    max_tries: int = 2,
    test_command: str = "bun test",
) -> int:
    """Return the planner or loop exit code; never run the loop on a bad plan."""
    repo_root = repo_root.resolve()
    if planner is None:
        deployed = repo_root / ".inspire/bin/emanate-plan.sh"
        planner = deployed if deployed.is_file() else repo_root / "plugin/base/bin/emanate-plan.sh"

    try:
        result = subprocess.run(
            [str(planner), *planner_args], cwd=repo_root,
            text=True, capture_output=True, check=False,
        )
    except OSError as exc:
        print("orchestrate: cannot start planner: {}".format(exc), file=sys.stderr)
        return 6

    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode not in (0, 1):
        if result.stdout:
            print(result.stdout, end="")
        return result.returncode

    try:
        plan: Dict[str, Any] = json.loads(result.stdout)
        if plan["schema"] != "inspire.emanation-plan/2" or not isinstance(plan["ready"], bool):
            raise ValueError("unexpected plan schema or readiness")
        if (result.returncode == 0) != plan["ready"]:
            raise ValueError("planner exit code disagrees with ready")
    except (ValueError, KeyError, TypeError) as exc:
        print("orchestrate: invalid planner output: {}".format(exc), file=sys.stderr)
        return 6

    if not run or result.returncode != 0:
        print(result.stdout, end="")
        return result.returncode

    command = [
        "bun", "run", str(Path(__file__).parent / "src/cli.ts"),
        "--repo-root", str(repo_root), "--max-tries", str(max_tries),
        "--test-command", test_command,
    ]
    try:
        loop = subprocess.run(
            command, cwd=repo_root, input=result.stdout, text=True, check=False,
        )
    except OSError as exc:
        print("orchestrate: cannot start Ralph loop: {}".format(exc), file=sys.stderr)
        return 6
    return loop.returncode


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "run"))
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--planner", type=Path, help="override planner path")
    parser.add_argument("--scope", action="append", default=[])
    parser.add_argument("--tests-root", action="append", default=[])
    parser.add_argument("--reemanate", action="append", default=[])
    parser.add_argument("--goal")
    parser.add_argument("--ceiling", type=int)
    parser.add_argument("--profiles-root")
    parser.add_argument("--agents-root")
    parser.add_argument("--max-tries", type=int, default=2)
    parser.add_argument("--test-command", default="bun test")
    args = parser.parse_args(argv)
    if args.max_tries < 0:
        parser.error("--max-tries must be nonnegative")
    if not args.test_command.strip():
        parser.error("--test-command must contain a command")

    planner_args = []
    for flag, values in (("--scope", args.scope), ("--tests-root", args.tests_root),
                         ("--reemanate", args.reemanate)):
        for value in values:
            planner_args.extend((flag, value))
    for flag, value in (("--goal", args.goal), ("--ceiling", args.ceiling),
                        ("--profiles-root", args.profiles_root),
                        ("--agents-root", args.agents_root)):
        if value is not None:
            planner_args.extend((flag, str(value)))
    return orchestrate(
        args.repo_root, planner_args, run=args.mode == "run", planner=args.planner,
        max_tries=args.max_tries, test_command=args.test_command,
    )


if __name__ == "__main__":
    sys.exit(main())
