"""Fixtures shared by the orchestrator's unit tests, loaded by `00-unit.sh`.

It lives here rather than beside the tests because everything under
`plugin/base/bin/lib/orchestrator/` materializes into a project, and pytest is a
dependency of this repo alone. `00-unit.sh` loads it with `-p conftest`, so the
rootdir stays the shipped package.

The existing `unittest` classes cannot request a fixture; a module rewritten as
plain functions — only ever when it is touched for another reason — asks for
these by name.
"""

import pytest

from orchestrator.constants import ARBITER_SHELL, PERSONA_SHELLS, REQUIRED_OVERSEERS
from orchestrator.test import stubs


@pytest.fixture
def stub_run():
    """The `run` the modules read: `stub_run(plan={...})`, attributes, no behaviour."""
    return stubs.stub_run


@pytest.fixture
def roster():
    """Write the shell roster `read_shells` demands into a directory."""
    def write(root, overseer_tools="Read, Grep, Glob"):
        body = "---\nname: x\ndescription: \"y\"\ntools: %s\nmodel: inherit\n---\n\nbody\n"
        for name in PERSONA_SHELLS.values():
            (root / name).write_text(body % "Read, Bash")
        (root / ARBITER_SHELL).write_text(body % "Read, Grep, Glob")
        for name in REQUIRED_OVERSEERS:
            (root / name).write_text(body % overseer_tools)
        return root
    return write


@pytest.fixture
def agents_root(tmp_path, roster):
    """A worktree whose default `.claude/agents/` carries a valid roster."""
    root = tmp_path / ".claude" / "agents"
    root.mkdir(parents=True)
    roster(root)
    return tmp_path
