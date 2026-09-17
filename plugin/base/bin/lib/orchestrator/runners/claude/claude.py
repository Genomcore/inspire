import json
import os
import subprocess
import time
import uuid

from ...findings import render_brief
from ...state import SpawnResult
from ...util import tail

TIMEOUT_TEXT = "wall clock of %ss reached"

DENY_RULES = ["Bash(git push:*)", "Bash(git update-ref:*)", "Bash(git merge:*)",
              "Bash(git branch:*)", "Bash(git worktree:*)",
              "Bash(.inspire/bin/emanate-harvest.sh:*)"]


FENCE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fence.py")
FENCE_SETTINGS = json.dumps({"hooks": {"PreToolUse": [
    {"matcher": "Write|Edit|MultiEdit|NotebookEdit",
     "hooks": [{"type": "command", "command": "python3 %s" % FENCE}]}]}})


class ClaudeRunner:

    def __init__(self, contracts_dir, wall_clock, max_turns=None, spawn_budget=None,
                 agents_root=None):
        self.contracts_dir = contracts_dir
        self.wall_clock = wall_clock
        self.max_turns = max_turns
        self.spawn_budget = spawn_budget
        self.agents_root = agents_root or os.path.join(".claude", "agents")
        self.ratelimit_retries = 0

    def spawn(self, shell_name, shell_tools, cwd, brief, schema):
        shell = shell_body(os.path.join(cwd, self.agents_root, shell_name + ".md"))
        command = ["claude", "-p", render_brief(brief),
                   "--append-system-prompt", shell,
                   "--permission-mode", "dontAsk",
                   "--permission-prompts", "none",
                   "--strict-mcp-config", "--settings", FENCE_SETTINGS,
                   "--output-format", "json",
                   "--session-id", str(uuid.uuid4()),
                   "--add-dir", self.contracts_dir]
        if shell_tools:
            joined = ",".join(shell_tools)
            command += ["--tools", joined, "--allowedTools", joined]
        if self.max_turns:
            command += ["--max-turns", str(self.max_turns)]
        if self.spawn_budget:
            command += ["--max-budget-usd", str(self.spawn_budget)]
        if schema:
            command += ["--json-schema", json.dumps(schema)]
        command += ["--disallowedTools"] + DENY_RULES
        try:
            proc = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, text=True, timeout=self.wall_clock)
        except subprocess.TimeoutExpired:
            return SpawnResult("timeout", text=TIMEOUT_TEXT % self.wall_clock)
        try:
            payload = json.loads(proc.stdout)
        except ValueError:
            return SpawnResult("crash", text=tail(proc.stdout) + "\n" + tail(proc.stderr))
        text = str(payload.get("result", ""))
        ending = ending_of(payload)
        if ending == "ratelimit":
            self.ratelimit_retries += 1
            time.sleep(min(60, 5 * self.ratelimit_retries))
        return SpawnResult(ending, text=text, structured=payload.get("structured_output"),
                           session_id=payload.get("session_id", ""),
                           cost_usd=float(payload.get("total_cost_usd") or 0.0),
                           usage=payload.get("usage"),
                           model_usage=payload.get("modelUsage"),
                           num_turns=payload.get("num_turns"))


def shell_body(path):
    with open(path) as stream:
        text = stream.read()
    if text.startswith("---\n"):
        _, _, text = text[4:].partition("\n---\n")
    return text.strip()


def ending_of(payload):
    subtype = payload.get("subtype")
    if subtype == "max_turns":
        return "exhausted"
    if subtype == "budget":
        return "budget"
    if payload.get("is_error"):
        return "ratelimit" if "rate limit" in str(payload.get("result", "")).lower() \
            else "crash"
    return "exit"
