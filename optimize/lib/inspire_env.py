from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from skillopt.datasets.base import SplitDataLoader
from skillopt.envs.base import EnvAdapter

LIB = Path(__file__).resolve().parent
RUN_CHECKS = LIB / "run-checks.ts"
CLAUDE = os.environ.get("CLAUDE_CLI_BIN", "claude")
NODE = os.environ.get("NODE_BIN", "node")
FRONTMATTER = re.compile(r"\A(---\n.*?\n---\n)(.*)\Z", re.S)
ROLLOUT_TOOLS = "Read,Glob,Grep,Write,Edit,Skill,Bash(bash .inspire/bin/*),Bash(.inspire/bin/*)"
NON_INTERACTIVE = (
    "You are running headless and nobody will answer questions. "
    "Never ask for confirmation: make the most reasonable assumption, state it, and finish the task."
)
MAX_FILE_BYTES = 200_000
FILES_HEADER = "\n\n## Files written\n"
RUN_FAILED = "the agent run failed: {}"
CHECKS_FAILED = "the check runner failed: {}"


def split_frontmatter(text: str) -> tuple[str, str]:
    match = FRONTMATTER.match(text)
    return (match.group(1), match.group(2)) if match else ("", text)


def _snapshot(root: Path) -> dict[str, str]:
    return {
        str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in root.rglob("*")
        if p.is_file() and ".git" not in p.relative_to(root).parts
    }


def _changed_files(root: Path, before: dict[str, str]) -> dict[str, str]:
    after = _snapshot(root)
    changed = sorted(path for path, digest in after.items() if before.get(path) != digest)
    files = {}
    for path in changed:
        data = (root / path).read_bytes()
        if len(data) <= MAX_FILE_BYTES:
            files[path] = data.decode("utf-8", errors="replace")
    return files


def _run_agent(work: Path, prompt: str, timeout: int) -> str:
    cmd = [
        CLAUDE, "-p", "--output-format", "json",
        "--permission-mode", "acceptEdits",
        "--allowedTools", ROLLOUT_TOOLS,
        "--strict-mcp-config",
        "--append-system-prompt", NON_INTERACTIVE,
    ]
    try:
        proc = subprocess.run(cmd, input=prompt, cwd=work, capture_output=True, text=True, timeout=timeout)
        return json.loads(proc.stdout).get("result", "") if proc.returncode == 0 else RUN_FAILED.format(proc.stderr.strip())
    except (subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        return RUN_FAILED.format(exc)


def _run_checks(context: Path, checks: list[str]) -> dict:
    proc = subprocess.run([NODE, str(RUN_CHECKS), str(context), *checks], capture_output=True, text=True)
    if proc.returncode != 0:
        return {"score": 0.0, "passed": False, "results": [{"check": "*", "score": 0, "reason": CHECKS_FAILED.format(proc.stderr.strip())}]}
    return json.loads(proc.stdout)


class InspireAdapter(EnvAdapter):
    def __init__(
        self,
        split_dir: str = "",
        skill_name: str = "",
        skill_source: str = "",
        workspace_template: str = "",
        workers: int = 2,
        analyst_workers: int = 2,
        failure_only: bool = False,
        minibatch_size: int = 4,
        edit_budget: int = 4,
        seed: int = 42,
        limit: int = 0,
        exec_timeout: int = 900,
    ) -> None:
        self.skill_name = skill_name
        self.frontmatter = split_frontmatter(Path(skill_source).read_text(encoding="utf-8"))[0]
        self.workspace_template = Path(workspace_template)
        self.workers = workers
        self.analyst_workers = analyst_workers
        self.failure_only = failure_only
        self.minibatch_size = minibatch_size
        self.edit_budget = edit_budget
        self.exec_timeout = int(exec_timeout)
        self.dataloader = SplitDataLoader(split_dir=split_dir, split_mode="split_dir", seed=seed, limit=limit)

    def setup(self, cfg: dict) -> None:
        super().setup(cfg)
        self.dataloader.setup(cfg)

    def get_dataloader(self):
        return self.dataloader

    def build_train_env(self, batch_size: int, seed: int, **kwargs):
        return list(self.dataloader.build_train_batch(batch_size=batch_size, seed=seed, **kwargs).payload or [])

    def build_eval_env(self, env_num: int, split: str, seed: int, **kwargs):
        return list(self.dataloader.build_eval_batch(env_num=env_num, split=split, seed=seed, **kwargs).payload or [])

    def get_task_types(self) -> list[str]:
        items = self.dataloader.train_items + self.dataloader.val_items + self.dataloader.test_items
        return sorted({item["task_type"] for item in items})

    def rollout(self, env_manager, skill_content: str, out_dir: str, **kwargs) -> list[dict]:
        with ThreadPoolExecutor(max_workers=self.workers) as pool:
            return list(pool.map(lambda item: self._rollout_one(item, skill_content, Path(out_dir)), env_manager))

    def _rollout_one(self, item: dict, skill_body: str, out_dir: Path) -> dict:
        work = out_dir / "work" / item["id"]
        shutil.rmtree(work, ignore_errors=True)
        shutil.copytree(self.workspace_template, work, symlinks=True)
        if item.get("fixture"):
            shutil.copytree(item["fixture"], work, dirs_exist_ok=True)
        (work / ".claude" / "skills" / self.skill_name / "SKILL.md").write_text(self.frontmatter + skill_body, encoding="utf-8")

        before = _snapshot(work)
        prompt = f"/{self.skill_name} {item['prompt']}"
        output = _run_agent(work, prompt, self.exec_timeout)
        files = _changed_files(work, before)

        context = out_dir / "work" / f"{item['id']}.context.json"
        context.write_text(json.dumps({"task": prompt, "workdir": str(work), "output": output, "files": files}), encoding="utf-8")
        verdict = _run_checks(context, item["checks"])

        trace = out_dir / "predictions" / item["id"]
        trace.mkdir(parents=True, exist_ok=True)
        conversation = [
            {"role": "system", "content": skill_body},
            {"role": "user", "content": prompt},
            {"role": "assistant", "content": output + FILES_HEADER + "\n".join(files)},
        ]
        (trace / "conversation.json").write_text(json.dumps(conversation, ensure_ascii=False, indent=2), encoding="utf-8")
        (trace / "checks.json").write_text(json.dumps(verdict, ensure_ascii=False, indent=2), encoding="utf-8")

        failures = [f"{r['check']}: {r['reason']}" for r in verdict["results"] if not r.get("passed")]
        return {
            "id": item["id"],
            "hard": int(verdict["passed"]),
            "soft": float(verdict["score"]),
            "task_type": item["task_type"],
            "task_description": item["prompt"],
            "target_user_prompt": prompt,
            "fail_reason": "; ".join(failures),
            "n_turns": 1,
        }
