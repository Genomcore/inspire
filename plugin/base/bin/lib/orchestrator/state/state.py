"""What a resume does to the run's record, and the one shape a spawn answers in."""

import datetime

from ..constants import ROLES
from ..util import ISO, now_iso, tail


class SpawnResult:
    def __init__(self, ending, text="", structured=None, session_id="", cost_usd=0.0,
                 usage=None, model_usage=None, num_turns=0):
        self.ending = ending
        self.text = text
        self.structured = structured
        self.session_id = session_id
        self.cost_usd = cost_usd
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
        unit["phase"] = None
        unit["status"] = "pending"


def close_timeline(ustate):
    timeline = ustate["timeline"]
    if timeline and timeline[-1]["ended_at"] is None:
        timeline[-1]["ended_at"] = now_iso()
