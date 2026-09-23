"""Run the emanation planner and check its ready output."""

import json
import subprocess
from pathlib import Path


def run_plan(repo_root: Path) -> subprocess.CompletedProcess:
    deployed = repo_root / ".inspire/bin/emanate-plan.sh"
    planner = deployed if deployed.is_file() else repo_root / "plugin/base/bin/emanate-plan.sh"
    return subprocess.run(
        [str(planner)], cwd=repo_root, text=True, capture_output=True, check=False,
    )


def require_ready_plan(output: str) -> None:
    try:
        plan = json.loads(output)
        if plan["schema"] != "inspire.emanation-plan/2" or plan["ready"] is not True:
            raise ValueError("planner did not produce a ready plan")
    except (KeyError, TypeError) as exc:
        raise ValueError("planner did not produce a ready plan") from exc
