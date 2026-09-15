"""The real runner: one spawn is one fresh headless `claude` session."""

import json
import subprocess
import time
import uuid

from ..findings import render_brief
from ..state import SpawnResult
from ..util import tail

# Deny rules for every spawned agent. These match the COMMAND STRING and are a
# speed bump, not a fence: an agent that spells the same call differently walks
# past them. The robust form is a PreToolUse deny hook, which is planned and not
# yet shipped; until it is, the harvest filter (only a phase's owned paths leave
# its worktree) is what actually holds.
DENY_RULES = ["Bash(git push:*)", "Bash(git update-ref:*)", "Bash(git merge:*)",
              "Bash(git branch:*)", "Bash(git worktree:*)",
              "Bash(.inspire/bin/emanate-harvest.sh:*)"]


class ClaudeRunner:
    """One spawn is one fresh headless session. Never `--resume`, never `--bare`:
    a persona that carried context from the last attempt would be reworking from
    memory rather than from the findings it was handed."""

    def __init__(self, contracts_dir, wall_clock, max_turns=None, spawn_budget=None):
        self.contracts_dir = contracts_dir
        self.wall_clock = wall_clock
        self.max_turns = max_turns
        self.spawn_budget = spawn_budget
        self.ratelimit_retries = 0

    def spawn(self, shell_name, shell_tools, cwd, brief, schema):
        command = ["claude", "-p", render_brief(brief),
                   "--agent", shell_name,
                   "--permission-mode", "dontAsk",
                   "--permission-prompts", "none",
                   "--restricted",
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
            return SpawnResult("timeout", text="wall clock of %ss reached" % self.wall_clock)
        try:
            payload = json.loads(proc.stdout)
        except ValueError:
            return SpawnResult("crash", text=tail(proc.stdout) + "\n" + tail(proc.stderr))
        text = str(payload.get("result", ""))
        ending = "exit"
        subtype = payload.get("subtype")
        if subtype == "max_turns":
            ending = "exhausted"
        elif subtype == "budget":
            ending = "budget"
        elif payload.get("is_error"):
            if "rate limit" in text.lower():
                ending = "ratelimit"
                self.ratelimit_retries += 1
                time.sleep(min(60, 5 * self.ratelimit_retries))
            else:
                ending = "crash"
        return SpawnResult(ending, text=text, structured=payload.get("structured_output"),
                           session_id=payload.get("session_id", ""),
                           cost_usd=float(payload.get("total_cost_usd") or 0.0))
