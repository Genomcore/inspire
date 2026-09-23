#!/usr/bin/env python3
"""Initialize or atomically update the run-state sidecar for a plan snapshot."""

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "schemas"))
from emanation_run_state import (  # noqa: E402 - sibling payload module
    PHASES, PERSONAS, RUN_STATUSES, UNIT_STATUSES,
    new_run_state, validate_run_state, write_run_state,
)


def now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def read_plan(path: Path):
    raw = path.read_bytes()
    return json.loads(raw), raw


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    initial = commands.add_parser("init", help="create pending state for every plan unit")
    initial.add_argument("plan", type=Path)
    initial.add_argument("state", type=Path)
    update = commands.add_parser("update", help="record a run or unit transition")
    update.add_argument("plan", type=Path)
    update.add_argument("state", type=Path)
    update.add_argument("--run-status", choices=sorted(RUN_STATUSES))
    update.add_argument("--run-id")
    update.add_argument("--goal-branch")
    update.add_argument("--unit")
    update.add_argument("--status", choices=sorted(UNIT_STATUSES))
    update.add_argument("--phase", choices=sorted(PHASES))
    update.add_argument("--persona", choices=sorted(PERSONAS))
    update.add_argument("--attempt", type=int)
    update.add_argument("--retry", action="store_true", help="start a new attempt after inspecting a stalled or interrupted phase")
    update.add_argument("--reason")
    update.add_argument("--blocked-by", action="append", default=[])
    update.add_argument("--integration-branch")
    update.add_argument("--worktree")
    update.add_argument("--rework-cycles", type=int)
    update.add_argument("--infrastructure-retries", type=int)
    args = parser.parse_args()
    try:
        plan, plan_bytes = read_plan(args.plan)
        if args.command == "init":
            if args.state.exists():
                raise ValueError("state file already exists; use update or choose a new path")
            state = new_run_state(plan, plan_bytes)
            args.state.parent.mkdir(parents=True, exist_ok=True)
        else:
            state = json.loads(args.state.read_bytes())
            validate_run_state(state, plan, plan_bytes)
            if not any([args.run_status, args.run_id, args.goal_branch, args.unit]):
                raise ValueError("update needs a run field or --unit")
            if args.status and not args.unit:
                raise ValueError("--status needs --unit")
            if args.retry and (not args.unit or args.status != "running"):
                raise ValueError("--retry needs --unit and --status running")
            stamp = now()
            if args.run_status:
                state["status"] = args.run_status
            if args.run_id:
                state["run_id"] = args.run_id
            if args.goal_branch:
                state["goal_branch"] = args.goal_branch
            if args.unit:
                if args.unit not in state["units"]:
                    raise ValueError("unit is not in this plan: " + args.unit)
                unit = state["units"][args.unit]
                previous = unit["status"]
                if args.status:
                    unit["status"] = args.status
                    if args.status == "running" and (previous in ("pending", "stalled", "blocked") or args.retry) and args.attempt is None:
                        unit["attempt"] += 1
                    if args.status not in ("stalled", "blocked"):
                        unit.pop("reason", None)
                        unit.pop("blocked_by", None)
                for field in ("phase", "persona", "reason", "integration_branch", "worktree", "rework_cycles", "infrastructure_retries"):
                    value = getattr(args, field)
                    if value is not None:
                        unit[field] = value
                if args.attempt is not None:
                    unit["attempt"] = args.attempt
                if args.blocked_by:
                    unit["blocked_by"] = args.blocked_by
                unit["updated_at"] = stamp
            state["updated_at"] = stamp
            validate_run_state(state, plan, plan_bytes)
        write_run_state(args.state, state)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError, KeyError, TypeError) as error:
        print(f"emanate-run-state: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
