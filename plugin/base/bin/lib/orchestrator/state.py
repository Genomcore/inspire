"""The run's record on disk, and the one shape a spawn answers in."""

import threading

from .util import read_json, tail, write_json_atomic


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
    def __init__(self, ending, text="", structured=None, session_id="", cost_usd=0.0):
        self.ending = ending  # exit | exhausted | budget | timeout | crash | ratelimit
        self.text = text
        self.structured = structured
        self.session_id = session_id
        self.cost_usd = cost_usd

    def record(self, brief, schema):
        return {"brief": brief, "schema": schema, "ending": self.ending,
                "structured": self.structured, "text": tail(self.text, 8000),
                "session_id": self.session_id, "cost_usd": self.cost_usd}
