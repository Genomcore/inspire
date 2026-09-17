import os
import re

from ..constants import ARBITER_SHELL, PERSONA_SHELLS, REQUIRED_OVERSEERS, WRITING_TOOLS
from ..errors import Refusal


def parse_tools_line(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for line in lines[1:]:
        if line.strip() == "---":
            return None
        match = re.match(r"tools:\s*(.+)$", line)
        if match:
            body = match.group(1).strip().strip("[]")
            return [item.strip() for item in body.split(",") if item.strip()]
    return None


def is_read_only(tools):
    return tools is not None and not any(tool in WRITING_TOOLS for tool in tools)


def read_shells(run):
    root = os.path.join(run.goal_worktree,
                        run.args.agents_root or os.path.join(".claude", "agents"))
    if not os.path.isdir(root):
        raise Refusal("no agent shells at %s — there is nothing to spawn." % root)
    names = sorted(name for name in os.listdir(root) if name.endswith(".md"))
    required = tuple(PERSONA_SHELLS.values()) + REQUIRED_OVERSEERS + (ARBITER_SHELL,)
    missing = [shell for shell in required if shell not in names]
    if missing:
        raise Refusal("%s missing from %s — this loop refuses to run without them."
                      % (", ".join(missing), root))
    for name in names:
        with open(os.path.join(root, name)) as stream:
            tools = parse_tools_line(stream.read())
        run.shells[name] = tools
        read_only_required = name.endswith("-overseer.md") or name == ARBITER_SHELL
        if read_only_required and not is_read_only(tools):
            raise Refusal("%s declares `tools: %s` — an oracle writes nothing, so its "
                          "allowlist may name none of %s."
                          % (name, ", ".join(tools or []) or "(none)",
                             ", ".join(WRITING_TOOLS)))
