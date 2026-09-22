import asyncio
import os
import subprocess
import time
from pathlib import Path

from ...findings import render_brief
from ...state import SpawnResult
from ...util import tail

TIMEOUT_TEXT = "wall clock of %ss reached"
NO_RESULT_TEXT = "the session ended without a result"
FENCED_TEXT = "fenced: %s is outside your worktree %s — a persona writes nowhere else."
PATH_KEYS = ("file_path", "notebook_path", "path")
WRITING_TOOLS = "Write|Edit|MultiEdit|NotebookEdit"

DENY_RULES = ["Bash(git push:*)", "Bash(git update-ref:*)", "Bash(git merge:*)",
              "Bash(git branch:*)", "Bash(git worktree:*)",
              "Bash(.inspire/bin/emanate-harvest.sh:*)"]


class AgentRunner:

    def __init__(self, contracts_dir, wall_clock, max_turns=None, spawn_budget=None,
                 agents_root=None, model=None):
        self.contracts_dir = contracts_dir
        self.wall_clock = wall_clock
        self.max_turns = max_turns
        self.spawn_budget = spawn_budget
        self.agents_root = agents_root or os.path.join(".claude", "agents")
        # One model for every spawn of a run, or the harness default when unset.
        # A run that mixed models would not be comparable with another.
        self.model = model
        self.ratelimit_retries = 0

    def options(self, shell_name, shell_tools, cwd, schema):
        from claude_agent_sdk import ClaudeAgentOptions, HookMatcher
        shell = shell_body(os.path.join(cwd, self.agents_root, shell_name + ".md"))
        return ClaudeAgentOptions(
            cwd=cwd, system_prompt={"type": "preset", "preset": "claude_code", "append": shell},
            permission_mode="dontAsk", strict_mcp_config=True,
            tools=list(shell_tools) if shell_tools else None,
            allowed_tools=list(shell_tools or []), disallowed_tools=list(DENY_RULES),
            model=self.model or None,
            max_turns=self.max_turns or None, max_budget_usd=self.spawn_budget or None,
            output_format={"type": "json_schema", "schema": schema} if schema else None,
            add_dirs=[self.contracts_dir],
            hooks={"PreToolUse": [HookMatcher(matcher=WRITING_TOOLS, hooks=[fence])]})

    def spawn(self, shell_name, shell_tools, cwd, brief, schema):
        from claude_agent_sdk import ClaudeSDKError
        options = self.options(shell_name, shell_tools, cwd, schema)
        try:
            result = asyncio.run(asyncio.wait_for(converse(render_brief(brief), options),
                                                  self.wall_clock))
        except asyncio.TimeoutError:
            return SpawnResult("timeout", text=TIMEOUT_TEXT % self.wall_clock)
        except ClaudeSDKError as error:
            return SpawnResult("crash", text=tail(str(error)))
        if result is None:
            return SpawnResult("crash", text=NO_RESULT_TEXT)
        ending = ending_of({"subtype": result.subtype, "is_error": result.is_error,
                            "result": result.result or "",
                            "api_error_status": result.api_error_status})
        if ending == "ratelimit":
            self.ratelimit_retries += 1
            time.sleep(min(60, 5 * self.ratelimit_retries))
        return SpawnResult(ending, text=str(result.result or ""),
                           structured=result.structured_output,
                           session_id=result.session_id,
                           cost_usd=float(result.total_cost_usd or 0.0),
                           usage=result.usage, model_usage=result.model_usage,
                           num_turns=result.num_turns)


async def converse(prompt, options):
    from claude_agent_sdk import ClaudeSDKClient, ResultMessage
    async with ClaudeSDKClient(options) as client:
        await client.query(prompt)
        async for message in client.receive_response():
            if isinstance(message, ResultMessage):
                return message
    return None


async def fence(payload, tool_use_id, context):
    root = os.path.realpath(payload.get("cwd") or os.getcwd())
    tool_input = payload.get("tool_input") or {}
    target = next((tool_input.get(key) for key in PATH_KEYS if tool_input.get(key)), None)
    if target and outside(target, root):
        return {"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                       "permissionDecision": "deny",
                                       "permissionDecisionReason": FENCED_TEXT % (target, root)}}
    return {}


def outside(path, root):
    return not Path(os.path.realpath(os.path.join(root, path))).is_relative_to(root)


def shell_body(path):
    with open(path) as stream:
        text = stream.read()
    if text.startswith("---\n"):
        _, _, text = text[4:].partition("\n---\n")
    return text.strip()


def ending_of(payload):
    subtype = str(payload.get("subtype") or "")
    if "max_turns" in subtype:
        return "exhausted"
    if "budget" in subtype:
        return "budget"
    if payload.get("is_error"):
        limited = payload.get("api_error_status") == 429 \
            or "rate limit" in str(payload.get("result", "")).lower()
        return "ratelimit" if limited else "crash"
    return "exit"


def harness_version():
    from claude_agent_sdk import __version__
    from claude_agent_sdk._internal.transport.subprocess_cli import SubprocessCLITransport
    transport = SubprocessCLITransport.__new__(SubprocessCLITransport)
    proc = subprocess.run([transport._find_bundled_cli(), "--version"],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return __version__, proc.stdout.strip()
