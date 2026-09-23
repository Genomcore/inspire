#!/usr/bin/env python3
"""Plan emanation, then run its ready waves through the OMP Ralph loop."""

import argparse
import json
import subprocess
import sys
from pathlib import Path


def orchestrate(mode: str, repo_root: Path, planner_args: tuple[str, ...] = ()) -> int:
    try:
        parser = argparse.ArgumentParser(add_help=False)
        parser.add_argument("--test-command")
        parser.add_argument("--results-file")
        parser.add_argument("--tests-root", action="append", default=[])
        options, args = parser.parse_known_args(planner_args)
        if mode == "run" and (not options.test_command or not options.results_file or not options.tests_root):
            print("run requires --test-command JSON array, --results-file and --tests-root", file=sys.stderr)
            return 2
        args.extend(arg for root in options.tests_root for arg in ("--tests-root", root))
        deployed = repo_root / ".inspire/bin/emanate-plan.sh"
        planner = deployed if deployed.is_file() else repo_root / "plugin/base/bin/emanate-plan.sh"
        result = subprocess.run(
            [str(planner), *args], cwd=repo_root, text=True, capture_output=True, check=False,
        )
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        if result.returncode != 0 or mode == "plan":
            print(result.stdout, end="")
            return result.returncode

        plan = json.loads(result.stdout)
        if plan.get("goal") and plan.get("ceiling") is not None and plan["ceiling"] < plan["goal"]["floor"]:
            print("orchestrate: goal ceiling is below its required floor", file=sys.stderr)
            return 1

        package = Path(__file__).parent
        if not (package / "node_modules/@oh-my-pi/pi-coding-agent").is_dir():
            installed = subprocess.run(["bun", "install", "--frozen-lockfile"], cwd=package, check=False)
            if installed.returncode != 0:
                return installed.returncode
        return subprocess.run(
            ["bun", "run", str(package / "src/cli.ts"),
             "--test-command", options.test_command,
             "--results-file", options.results_file,
             *(arg for root in options.tests_root for arg in ("--tests-root", root))],
            cwd=repo_root, input=result.stdout, text=True, check=False,
        ).returncode
    except (OSError, ValueError) as exc:
        print("orchestrate: {}".format(exc), file=sys.stderr)
        return 6


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("plan", "run"):
        print("usage: orchestrate.py plan|run [planner options]", file=sys.stderr)
        sys.exit(2)
    sys.exit(orchestrate(sys.argv[1], Path.cwd(), tuple(sys.argv[2:])))
