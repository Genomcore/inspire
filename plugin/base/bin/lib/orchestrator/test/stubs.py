import threading
from types import SimpleNamespace

from ..constants import ROLES


def stub_args(**over):
    args = dict(goal=None, ceiling=None, scope=[], rework=2, variant=None, reemanate=[],
                runner="fake:x", parallel=1, budget_usd=None, bin=None,
                profiles_root=None, agents_root=None)
    args.update(over)
    return SimpleNamespace(**args)


def stub_run(**over):
    run = SimpleNamespace(
        config={"tests_roots": ["tests"], "source_roots": ["source"],
                "suite": [{"command": "true"}], "checks": [], "frozen_paths": []},
        args=stub_args(), plan={}, plan_units={}, repo="/repo", run_dir="/repo/run",
        goal_branch="emanate/all", goal_worktree="/repo/goal", launch_branch="main",
        goal_slug="all", stamp="20260101-000000", run_id="20260101-000000-abcd",
        harness="fake", cut_here=True, truncated=False, baseline_line="baseline skipped",
        last_results={}, last_verdict={}, git_lock=threading.Lock(),
        state={"units": {}, "waves": []})
    run.save = lambda: None
    for key, value in over.items():
        setattr(run, key, value)
    return run


def stub_unit(unit_id="auth.user", **over):
    unit = {"id": unit_id, "kind": "entity", "path": "spec/sdd/auth/user/auth.user.md",
            "slug": unit_id.replace(".", "-"), "status": "pending", "phase": None,
            "done": [], "started_at": None, "ended_at": None, "timeline": [],
            "integration_branch": "emanate/all-%s-x" % unit_id.replace(".", "-"),
            "verify_worktree": None,
            "rework": dict((role, 0) for role in ROLES),
            "infra_retries": dict((role, 0) for role in ROLES),
            "dropped": [], "verify_findings": [], "gate_digest": None, "drill": None,
            "trailers": {}, "stall_class": None, "reason": None, "next_act": None,
            "findings": []}
    unit.update(over)
    return unit


def contract(claims):
    return {"schema": "inspire.derived-contract/1",
            "unit": {"kind": "entity", "id": "auth.user",
                     "path": "inspire_kb/04_domain/auth/user/auth.user.md",
                     "lifecycle": "accepted"},
            "claims": claims}


def claim(key, oracle="test"):
    return {"id": "auth.user/%s" % key, "oracle": oracle, "fingerprint": "sha256:" + "a" * 8}


def citation(claim_id, fingerprint=None):
    return {"file": "tests/user.spec.ts", "line": 1, "id": claim_id, "fingerprint": fingerprint}
