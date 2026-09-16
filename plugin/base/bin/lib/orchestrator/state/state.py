"""The run's record on disk, and the one shape a spawn answers in."""

import threading

from ..util import now_iso, read_json, tail, write_json_atomic


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


def close_timeline(ustate):
    timeline = ustate["timeline"]
    if timeline and timeline[-1]["ended_at"] is None:
        timeline[-1]["ended_at"] = now_iso()
