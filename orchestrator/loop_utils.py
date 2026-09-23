"""Launch the OMP Ralph loop with a ready plan."""

import subprocess
from pathlib import Path


def run_loop(repo_root: Path, plan_json: str) -> int:
    result = subprocess.run(
        ["bun", "run", str(Path(__file__).parent / "src/cli.ts")],
        cwd=repo_root, input=plan_json, text=True, check=False,
    )
    return result.returncode
