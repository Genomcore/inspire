#!/usr/bin/env python3
"""Replay a build-loop example against the clean three-wave sample plan.

The matching run-state sidecar is rewritten atomically after each step. This
only simulates state transitions; it does not run the build agents.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "schemas"))
from emanation_run_state import new_run_state, validate_run_state, write_run_state  # noqa: E402


SAMPLE = Path(__file__).resolve().parent.parent / "test/fixtures/emanate-plan/clean-three-waves/expected-stdout.json"
UNIT_IDS = {"audit.event", "auth.org", "auth.user", "auth.user.list"}


def now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def main() -> int:
    parser = argparse.ArgumentParser(description="Animate the sample KB build loop in the plan viewer.")
    parser.add_argument("state", type=Path, help="sidecar path served with --run-state")
    parser.add_argument("--plan", type=Path, default=SAMPLE, help="the clean three-wave sample plan")
    parser.add_argument("--step-seconds", type=float, default=3, help="pause between transitions (default: 3)")
    parser.add_argument("--hold-seconds", type=float, default=12, help="pause after completion before replaying")
    parser.add_argument("--once", action="store_true", help="play one cycle and exit")
    args = parser.parse_args()
    if args.step_seconds < 0 or args.hold_seconds < 0:
        parser.error("pause durations cannot be negative")
    plan_bytes = args.plan.read_bytes()
    plan = json.loads(plan_bytes)
    ids = {unit["id"] for wave in plan["waves"] for unit in wave["units"]}
    if ids != UNIT_IDS:
        parser.error("this demo requires the clean three-wave sample plan")

    def publish(state: dict, message: str) -> None:
        state["updated_at"] = now()
        validate_run_state(state, plan, plan_bytes)
        write_run_state(args.state, state)
        print(message, flush=True)

    def unit(state: dict, unit_id: str, status: str, *, phase: Optional[str] = None,
             persona: Optional[str] = None, reason: Optional[str] = None,
             blocked_by: Optional[List[str]] = None) -> None:
        entry = state["units"][unit_id]
        if status == "running" and entry["status"] != "running":
            entry["attempt"] += 1
        entry["status"] = status
        entry["updated_at"] = now()
        for field in ("phase", "persona", "reason", "blocked_by"):
            entry.pop(field, None)
        if phase is not None:
            entry["phase"] = phase
        if persona is not None:
            entry["persona"] = persona
        if reason is not None:
            entry["reason"] = reason
        if blocked_by is not None:
            entry["blocked_by"] = blocked_by

    while True:
        state = new_run_state(plan, plan_bytes)
        state["run_id"] = "DEMO · sample KB"
        publish(state, "Reset: four units pending")
        time.sleep(args.step_seconds)

        state["status"] = "running"
        unit(state, "auth.org", "running", phase="persona", persona="contracter")
        publish(state, "Wave 1: auth.org contracter started")
        time.sleep(args.step_seconds)

        unit(state, "audit.event", "running", phase="persona", persona="implementer")
        unit(state, "auth.org", "delivered", phase="promote")
        publish(state, "Wave 1: auth.org delivered; audit.event running")
        time.sleep(args.step_seconds)

        unit(state, "audit.event", "delivered", phase="promote")
        unit(state, "auth.user", "running", phase="persona", persona="tester")
        publish(state, "Wave 2: auth.user tester started")
        time.sleep(args.step_seconds)

        unit(state, "auth.user", "stalled", phase="verify", reason="Demo: a verification check failed")
        unit(state, "auth.user.list", "blocked", reason="Waiting for auth.user", blocked_by=["auth.user"])
        publish(state, "Stall: auth.user failed verification; auth.user.list blocked")
        time.sleep(args.step_seconds * 2)

        unit(state, "auth.user", "running", phase="persona", persona="implementer")
        publish(state, "Retry: auth.user attempt 2 started")
        time.sleep(args.step_seconds)

        unit(state, "auth.user", "delivered", phase="promote")
        unit(state, "auth.user.list", "running", phase="persona", persona="implementer")
        publish(state, "Wave 3: auth.user delivered; auth.user.list unblocked and running")
        time.sleep(args.step_seconds)

        unit(state, "auth.user.list", "delivered", phase="promote")
        state["status"] = "completed"
        publish(state, "Completed: all four units delivered")
        if args.once:
            break
        time.sleep(args.hold_seconds)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
