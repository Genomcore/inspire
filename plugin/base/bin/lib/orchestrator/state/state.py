"""The run's record on disk, and the one shape a spawn answers in."""

import datetime
import threading

from ..constants import ROLES
from ..util import ISO, now_iso, read_json, tail, write_json_atomic


class State:
    """`inspire.emanate-state/1` — the run's whole record, written atomically after
    every transition, so a killed process can be resumed against it."""

    def __init__(self, path, data):
        self.path = path
        self.data = data
        self.lock = threading.Lock()

    @classmethod
    def load(cls, path):
        return cls(path, read_json(path))

    def save(self):
        with self.lock:
            write_json_atomic(self.path, self.data)

    def unit(self, unit_id):
        return self.data["units"][unit_id]


class SpawnResult:
    def __init__(self, ending, text="", structured=None, session_id="", cost_usd=0.0,
                 usage=None, model_usage=None, num_turns=0):
        self.ending = ending  # exit | exhausted | budget | timeout | crash | ratelimit
        self.text = text
        self.structured = structured
        self.session_id = session_id
        self.cost_usd = cost_usd
        # `usage` and `model_usage` are the CLI's own `usage` / `modelUsage`
        # objects, kept verbatim: the record is raw facts, and every aggregate
        # (per role, per model, per unit) is computed by the report from these.
        self.usage = usage or {}
        self.model_usage = model_usage or {}
        self.num_turns = int(num_turns or 0)

    def record(self, brief, schema):
        return {"brief": brief, "schema": schema, "ending": self.ending,
                "structured": self.structured, "text": tail(self.text, 8000),
                "session_id": self.session_id, "cost_usd": self.cost_usd,
                "usage": self.usage, "model_usage": self.model_usage,
                "num_turns": self.num_turns}


def set_phase(run, ustate, phase):
    """The only writer of `ustate["phase"]`. Closing the open `timeline` entry and
    opening the next is what makes the timeline the record of where a unit's
    time went; the report turns the entries into durations."""
    close_timeline(ustate)
    if phase is not None:
        ustate["timeline"].append({"phase": phase, "started_at": now_iso(), "ended_at": None})
    ustate["phase"] = phase
    run.save()


def reconcile(data):
    """The three things a resume does to a record beyond reading it back, and the
    one place they are written. A run written before a key existed grows it — the
    run-id stamp is UTC in its own shape, so it converts to the ISO one. Whatever
    the kill left open is closed now: the real end is unrecoverable, so the entry
    is marked interrupted rather than charged the downtime. And the phase that was
    in flight is nobody's judgment, so it counts as an infrastructural ending —
    the unit re-enters at the first role it has not been through."""
    data.setdefault("started_at", datetime.datetime.strptime(
        data["stamp"], "%Y%m%d-%H%M%S").strftime(ISO))
    data.setdefault("ended_at", None)
    data.setdefault("wave_log", [])
    for unit in data["units"].values():
        for key, blank in (("started_at", None), ("ended_at", None), ("timeline", [])):
            unit.setdefault(key, blank)
    if data["wave_log"] and data["wave_log"][-1]["ended_at"] is None:
        data["wave_log"][-1]["ended_at"] = "interrupted"
    for unit in data["units"].values():
        if unit["status"] != "in-phase":
            continue
        if unit["phase"] in ROLES:
            unit["infra_retries"][unit["phase"]] += 1
        if unit["timeline"] and unit["timeline"][-1]["ended_at"] is None:
            unit["timeline"][-1]["ended_at"] = "interrupted"
        unit["phase"] = None  # set_phase would stamp a clock that did not run
        unit["status"] = "pending"


def close_timeline(ustate):
    timeline = ustate["timeline"]
    if timeline and timeline[-1]["ended_at"] is None:
        timeline[-1]["ended_at"] = now_iso()
