"""Fixtures shared by the orchestrator's unit tests, loaded by `00-unit.sh`.

It lives here rather than beside the tests because everything under
`plugin/base/bin/lib/orchestrator/` materializes into a project, and pytest is a
dependency of this repo alone. `00-unit.sh` loads it with `-p conftest`, so the
rootdir stays the shipped package.

Only setup worth a fixture is here. The `run` and unit stubs stay a plain
`from orchestrator.test.stubs import stub_run` — a fixture around a factory that
needs no teardown would buy an implicit parameter and nothing else.

The existing `unittest` classes cannot request a fixture; a module rewritten as
plain functions — only ever when it is touched for another reason — asks for
these by name.
"""

import functools

import pytest

from orchestrator.shells.test_shells import Roster


@pytest.fixture
def roster():
    """Write the shell roster `read_shells` demands into a directory.

    The writer is the one `test_shells` already owns, which reads no `self`.
    """
    return functools.partial(Roster.roster, None)


@pytest.fixture
def agents_root(tmp_path, roster):
    """A worktree whose default `.claude/agents/` carries a valid roster."""
    root = tmp_path / ".claude" / "agents"
    root.mkdir(parents=True)
    roster(root)
    return tmp_path
