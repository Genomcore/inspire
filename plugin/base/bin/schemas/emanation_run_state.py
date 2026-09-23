"""inspire.emanation-run-state/1 — mutable state for one plan snapshot.

Typed for Python 3.9 and stdlib-only. The JSON Schema beside this file owns
the shape; ``validate_run_state`` also checks the cross-document unit keys and
the exact plan-byte digest that JSON Schema cannot express.
"""

import hashlib
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Literal, Optional

try:
    from typing import TypedDict
except ImportError:  # pragma: no cover
    from typing_extensions import TypedDict  # type: ignore

SCHEMA_ID = "inspire.emanation-run-state/1"
PLAN_SCHEMA_ID = "inspire.emanation-plan/2"

RunStatus = Literal["planned", "running", "completed", "interrupted"]
UnitStatus = Literal["pending", "running", "delivered", "stalled", "blocked"]
RunPhase = Literal["prepare", "persona", "overseer_gate", "harvest", "verify", "gate", "drill", "promote"]
Persona = Literal["contracter", "tester", "implementer"]

RUN_STATUSES = frozenset(["planned", "running", "completed", "interrupted"])
UNIT_STATUSES = frozenset(["pending", "running", "delivered", "stalled", "blocked"])
PHASES = frozenset(["prepare", "persona", "overseer_gate", "harvest", "verify", "gate", "drill", "promote"])
PERSONAS = frozenset(["contracter", "tester", "implementer"])


class _UnitRunStateRequired(TypedDict):
    status: UnitStatus
    attempt: int
    updated_at: str


class UnitRunState(_UnitRunStateRequired, total=False):
    phase: RunPhase
    persona: Persona
    reason: str
    blocked_by: List[str]
    integration_branch: str
    worktree: str
    rework_cycles: int
    infrastructure_retries: int


class EmanationRunState(TypedDict):
    schema: Literal["inspire.emanation-run-state/1"]
    plan_sha256: str
    run_id: Optional[str]
    goal_branch: Optional[str]
    status: RunStatus
    updated_at: str
    units: Dict[str, UnitRunState]


def _timestamp(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return "T" in value and (value.endswith("Z") or "+" in value[10:] or "-" in value[10:])


def new_run_state(plan: Any, plan_bytes: bytes) -> EmanationRunState:
    """Initialize every planned unit as pending, bound to the exact snapshot."""
    _plan_ids(plan)
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    state: EmanationRunState = {
        "schema": SCHEMA_ID,
        "plan_sha256": hashlib.sha256(plan_bytes).hexdigest(),
        "run_id": None,
        "goal_branch": None,
        "status": "planned",
        "updated_at": now,
        "units": {unit["id"]: {"status": "pending", "attempt": 0, "updated_at": now}
                  for wave in plan["waves"] for unit in wave["units"]},
    }
    validate_run_state(state, plan, plan_bytes)
    return state


def write_run_state(path: Path, state: EmanationRunState) -> None:
    """Atomically replace a run-state file after the caller validates it."""
    payload = (json.dumps(state, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    with tempfile.NamedTemporaryFile(dir=str(path.parent), prefix="." + path.name + ".", delete=False) as file:
        temporary = Path(file.name)
        try:
            file.write(payload)
            file.flush()
            os.fsync(file.fileno())
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    try:
        os.replace(str(temporary), str(path))
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def validate_run_state(state: Any, plan: Any, plan_bytes: bytes) -> None:
    """Raise ValueError for a malformed state or a state bound to another plan."""
    planned_ids = _plan_ids(plan)
    if not isinstance(state, dict) or set(state) != {"schema", "plan_sha256", "run_id", "goal_branch", "status", "updated_at", "units"}:
        raise ValueError("run state has missing or unknown top-level fields")
    if state["schema"] != SCHEMA_ID:
        raise ValueError("run state has an unsupported schema")
    if state["plan_sha256"] != hashlib.sha256(plan_bytes).hexdigest():
        raise ValueError("run state belongs to a different plan snapshot")
    if not isinstance(state["status"], str) or state["status"] not in RUN_STATUSES or not _timestamp(state["updated_at"]):
        raise ValueError("run state has an invalid status or updated_at")
    if not all(value is None or isinstance(value, str) for value in (state["run_id"], state["goal_branch"])):
        raise ValueError("run state run_id and goal_branch must be strings or null")
    units = state["units"]
    if not isinstance(units, dict):
        raise ValueError("run state units must be an object")
    if set(units) != planned_ids:
        raise ValueError("run state units must exactly match the plan's wave unit ids")
    allowed = {"status", "attempt", "updated_at", "phase", "persona", "reason", "blocked_by", "integration_branch", "worktree", "rework_cycles", "infrastructure_retries"}
    for unit_id, unit in units.items():
        if not isinstance(unit, dict) or not {"status", "attempt", "updated_at"} <= set(unit) or set(unit) - allowed:
            raise ValueError("invalid run state fields for " + unit_id)
        if not isinstance(unit["status"], str) or unit["status"] not in UNIT_STATUSES or not _timestamp(unit["updated_at"]):
            raise ValueError("invalid status or updated_at for " + unit_id)
        if type(unit["attempt"]) is not int or unit["attempt"] < 0:
            raise ValueError("invalid attempt for " + unit_id)
        if ((unit["status"] in ("pending", "blocked") and unit["attempt"] != 0) or
                (unit["status"] in ("running", "delivered", "stalled") and unit["attempt"] < 1)):
            raise ValueError("attempt does not match status for " + unit_id)
        if "phase" in unit and (not isinstance(unit["phase"], str) or unit["phase"] not in PHASES):
            raise ValueError("invalid phase for " + unit_id)
        if "persona" in unit and (not isinstance(unit["persona"], str) or unit["persona"] not in PERSONAS):
            raise ValueError("invalid persona for " + unit_id)
        for field in ("reason", "integration_branch", "worktree"):
            if field in unit and not isinstance(unit[field], str):
                raise ValueError("invalid " + field + " for " + unit_id)
        if "blocked_by" in unit:
            blockers = unit["blocked_by"]
            if (not isinstance(blockers, list) or
                    any(not isinstance(key, str) or key not in planned_ids for key in blockers) or
                    len(set(blockers)) != len(blockers)):
                raise ValueError("invalid blocked_by for " + unit_id)
        for field in ("rework_cycles", "infrastructure_retries"):
            if field in unit and (type(unit[field]) is not int or unit[field] < 0):
                raise ValueError("invalid " + field + " for " + unit_id)
        if unit["status"] in ("stalled", "blocked") and not unit.get("reason"):
            raise ValueError("stalled and blocked units require a reason: " + unit_id)
        if unit["status"] == "blocked" and not unit.get("blocked_by"):
            raise ValueError("blocked units require blocked_by: " + unit_id)


def _plan_ids(plan: Any) -> set:
    if (not isinstance(plan, dict) or plan.get("schema") != PLAN_SCHEMA_ID or
            plan.get("ready") is not True or not isinstance(plan.get("waves"), list)):
        raise ValueError("run state requires a ready inspire.emanation-plan/2 plan")
    try:
        ids = [unit["id"] for wave in plan["waves"] for unit in wave["units"]]
    except (KeyError, TypeError) as error:
        raise ValueError("plan has invalid wave units") from error
    if any(not isinstance(unit_id, str) for unit_id in ids) or len(ids) != len(set(ids)):
        raise ValueError("plan unit ids must be unique strings")
    return set(ids)
