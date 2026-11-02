from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import yaml

LIB = Path(__file__).resolve().parent
OPTIMIZE = LIB.parent
REPO = OPTIMIZE.parent
PLUGIN = REPO / "plugin"
SKILLS = PLUGIN / "base" / "skills"
MATERIALIZE = PLUGIN / "scripts" / "materialize.sh"
COMPLAINTS = OPTIMIZE / "complaints.yaml"
RUNS = OPTIMIZE / "runs"
MIN_TASKS = 3
EXEC_TIMEOUT = 1800
WORKERS = 4
FIXTURE_IGNORE = shutil.ignore_patterns(".git", "node_modules", "dist", "coverage", ".claude", ".inspire", ".inspire.lock")

TRAIN = {"batch_size": 4, "num_epochs": 2, "accumulation": 1}
GRADIENT = {"minibatch_size": 4, "merge_batch_size": 4}
EVALUATION = {"gate_metric": "soft"}
MODEL = {"backend": "claude", "optimizer_backend": "claude_chat", "target_backend": "claude_chat", "optimizer": "claude-opus-5-5"}

NO_SKILLOPT_HOME = "SKILLOPT_HOME must point at a source checkout of microsoft/skillopt (its configs/ are not in the wheel)."
NOTHING_TO_DO = "Nothing to optimize: every complaint is optimized: true."
UNKNOWN_SKILL = "{skill}: no such skill under plugin/base/skills/"
TOO_FEW_TASKS = "{skill}: {n} task(s), need at least {min} (val, test and train)."
MISSING_CHECK = "{skill}/{complaint}: check not found: {path}"
NO_CHECKS = "{skill}/{complaint}: no checks"
MISSING_FIXTURE = "{skill}: fixture not found: {path}"
PLAN_LINE = "{skill}: {pending} pending of {total} complaint(s), {checks} check(s), {tasks} task(s)"
RUN_DONE = "{skill}: best skill at {best}\n  review: diff -u {source} {best}"
RUN_FAILED = "{skill}: SkillOpt exited {code}, see {out}"


def fail(message: str) -> None:
    sys.exit(message)


def local_path(value: str) -> Path:
    path = Path(value).expanduser()
    return path if path.is_absolute() else OPTIMIZE / path


def resolve_checks(skill: str, entry: dict) -> list[str]:
    checks: list[str] = []
    for complaint in entry["complaints"]:
        if not complaint.get("checks"):
            fail(NO_CHECKS.format(skill=skill, complaint=complaint["id"]))
        for check in complaint["checks"]:
            path = OPTIMIZE / check
            if not path.is_file():
                fail(MISSING_CHECK.format(skill=skill, complaint=complaint["id"], path=path))
            if str(path) not in checks:
                checks.append(str(path))
    return checks


def resolve_items(skill: str, entry: dict) -> dict[str, list[dict]]:
    tasks = sorted(OPTIMIZE.glob(entry["tasks"]))
    if len(tasks) < MIN_TASKS:
        fail(TOO_FEW_TASKS.format(skill=skill, n=len(tasks), min=MIN_TASKS))
    if entry.get("fixture") and not local_path(entry["fixture"]).is_dir():
        fail(MISSING_FIXTURE.format(skill=skill, path=local_path(entry["fixture"])))
    checks = resolve_checks(skill, entry)
    n_val = max(1, len(tasks) // 3)
    splits: dict[str, list[dict]] = {"train": [], "val": [], "test": []}
    for i, task in enumerate(tasks):
        fixture = task.with_suffix("")
        split = "val" if i < n_val else "test" if i == n_val else "train"
        splits[split].append({
            "id": task.stem,
            "task_type": skill,
            "prompt": task.read_text(encoding="utf-8").strip(),
            "fixture": str(fixture) if fixture.is_dir() else "",
            "checks": checks,
        })
    return splits


def prepare_workspace(skill: str, entry: dict, workspace: Path) -> None:
    workspace.mkdir(parents=True)
    subprocess.run(["git", "init", "-q"], cwd=workspace, check=True)
    subprocess.run(
        ["bash", str(MATERIALIZE), "--mode", "init", "--plugin-root", str(PLUGIN), "--project-root", str(workspace)],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    if entry.get("fixture"):
        shutil.copytree(local_path(entry["fixture"]), workspace, dirs_exist_ok=True, ignore=FIXTURE_IGNORE)



def optimize(skill: str, entry: dict, skillopt_home: Path) -> None:
    from inspire_env import split_frontmatter

    source = SKILLS / skill / "SKILL.md"
    run = RUNS / skill / time.strftime("%Y%m%d-%H%M%S")
    for split, items in resolve_items(skill, entry).items():
        (run / "data" / split).mkdir(parents=True)
        (run / "data" / split / "items.json").write_text(json.dumps(items, indent=2), encoding="utf-8")

    prepare_workspace(skill, entry, run / "workspace")
    shutil.rmtree(run / "workspace" / ".claude" / "skills" / skill, ignore_errors=True)
    shutil.copytree(SKILLS / skill, run / "workspace" / ".claude" / "skills" / skill)
    body = run / "initial_skill.md"
    body.write_text(split_frontmatter(source.read_text(encoding="utf-8"))[1], encoding="utf-8")

    config = {
        "_base_": str(skillopt_home / "configs" / "_base_" / "default.yaml"),
        "model": MODEL,
        "train": TRAIN,
        "gradient": GRADIENT,
        "evaluation": EVALUATION,
        "env": {
            "name": "inspire",
            "skill_init": str(body),
            "split_mode": "split_dir",
            "split_dir": str(run / "data"),
            "out_root": str(run / "skillopt"),
            "exec_timeout": EXEC_TIMEOUT,
            "workers": WORKERS,
            "analyst_workers": WORKERS,
            "skill_name": skill,
            "skill_source": str(source),
            "workspace_template": str(run / "workspace"),
        },
    }
    config_path = run / "config.yaml"
    config_path.write_text(yaml.safe_dump(config, sort_keys=False), encoding="utf-8")

    code = subprocess.run([sys.executable, __file__, "--train", str(config_path)], cwd=run).returncode
    if code != 0:
        fail(RUN_FAILED.format(skill=skill, code=code, out=run / "skillopt"))

    frontmatter = split_frontmatter(source.read_text(encoding="utf-8"))[0]
    best = run / "SKILL.md"
    best.write_text(frontmatter + (run / "skillopt" / "best_skill.md").read_text(encoding="utf-8"), encoding="utf-8")
    print(RUN_DONE.format(skill=skill, best=best, source=source))


def train(config: str) -> None:
    sys.path.insert(0, str(LIB))
    from inspire_env import InspireAdapter
    from scripts import train as skillopt_train

    skillopt_train._ENV_REGISTRY["inspire"] = InspireAdapter
    sys.argv = ["skillopt-train", "--config", config]
    skillopt_train.main()


def main() -> None:
    parser = argparse.ArgumentParser(prog="optimize-skills")
    parser.add_argument("skills", nargs="*", help="limit the run to these skills")
    parser.add_argument("--dry-run", action="store_true", help="list what would run, run nothing")
    parser.add_argument("--train", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.train:
        return train(args.train)

    catalog: dict[str, dict] = yaml.safe_load(COMPLAINTS.read_text(encoding="utf-8")) or {}
    pending = {
        skill: entry
        for skill, entry in catalog.items()
        if (not args.skills or skill in args.skills) and any(not c.get("optimized") for c in entry["complaints"])
    }
    for skill in pending:
        if not (SKILLS / skill / "SKILL.md").is_file():
            fail(UNKNOWN_SKILL.format(skill=skill))
    if not pending:
        print(NOTHING_TO_DO)
        return

    for skill, entry in pending.items():
        splits = resolve_items(skill, entry)
        complaints = entry["complaints"]
        print(PLAN_LINE.format(
            skill=skill,
            pending=sum(not c.get("optimized") for c in complaints),
            total=len(complaints),
            checks=len(resolve_checks(skill, entry)),
            tasks=sum(len(items) for items in splits.values()),
        ))
    if args.dry_run:
        return

    home = os.environ.get("SKILLOPT_HOME")
    if not home or not (Path(home) / "configs" / "_base_" / "default.yaml").is_file():
        fail(NO_SKILLOPT_HOME)
    sys.path.insert(0, str(LIB))
    for skill, entry in pending.items():
        optimize(skill, entry, Path(home))


if __name__ == "__main__":
    main()
