import os
import tempfile
import unittest

from orchestrator.constants import STATE_SCHEMA
from orchestrator.state import SpawnResult, State, reconcile


class StateWrites(unittest.TestCase):

    def test_the_state_round_trips(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "state.json")
            state = State(path, {"schema": STATE_SCHEMA,
                                 "units": {"auth.user": {"status": "pending"}}})
            state.save()
            state.unit("auth.user")["status"] = "promoted"
            state.save()
            reread = State.load(path)
        self.assertEqual(reread.data["units"]["auth.user"]["status"], "promoted")


class Reconcile(unittest.TestCase):
    """What a resume does to the record beyond reading it back."""

    def killed(self, **over):
        unit = {"status": "in-phase", "phase": "tester", "timeline": [
            {"phase": "tester", "started_at": "t", "ended_at": None}],
            "infra_retries": {"contracter": 0, "tester": 0, "implementer": 0}}
        return {"stamp": "20260101-000000", "started_at": "t", "ended_at": None,
                "wave_log": [{"index": 1, "started_at": "t", "ended_at": None}],
                "units": dict({"auth.user": dict(unit, **over)})}

    def test_the_phase_in_flight_is_an_infrastructural_ending_the_unit_re_enters_at(self):
        data = self.killed()
        reconcile(data)
        unit = data["units"]["auth.user"]
        self.assertEqual(unit["infra_retries"]["tester"], 1)
        self.assertEqual((unit["status"], unit["phase"]), ("pending", None))
        self.assertEqual(unit["timeline"][-1]["ended_at"], "interrupted")
        self.assertEqual(data["wave_log"][-1]["ended_at"], "interrupted")

    def test_a_unit_that_was_not_in_flight_is_left_alone(self):
        data = self.killed(status="promoted", phase=None)
        reconcile(data)
        unit = data["units"]["auth.user"]
        self.assertEqual(unit["infra_retries"]["tester"], 0)
        self.assertEqual(unit["status"], "promoted")

    def test_a_record_written_before_a_key_existed_grows_it(self):
        data = self.killed()
        for key in ("started_at", "ended_at", "wave_log"):
            data.pop(key)
        data["units"]["auth.user"].pop("timeline")
        reconcile(data)
        self.assertEqual(data["started_at"], "2026-01-01T00:00:00Z")
        self.assertEqual((data["ended_at"], data["wave_log"]), (None, []))
        self.assertEqual(data["units"]["auth.user"]["timeline"], [])


class SpawnRecords(unittest.TestCase):

    def test_a_record_carries_the_brief_and_truncates_the_text(self):
        result = SpawnResult("exit", text="x" * 9000, structured={"a": 1}, cost_usd=0.5,
                             usage={"input_tokens": 10}, model_usage={"m": {"costUSD": 0.5}},
                             num_turns="7")
        record = result.record({"role": "tester"}, None)
        self.assertEqual(record["usage"], {"input_tokens": 10})
        self.assertEqual(record["model_usage"], {"m": {"costUSD": 0.5}})
        self.assertEqual(record["num_turns"], 7)
        self.assertEqual(record["brief"], {"role": "tester"})
        self.assertEqual(record["structured"], {"a": 1})
        self.assertEqual(len(record["text"]), 8000)
        self.assertEqual(record["cost_usd"], 0.5)
