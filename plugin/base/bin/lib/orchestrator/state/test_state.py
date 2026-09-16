import os
import tempfile
import unittest

from orchestrator.constants import STATE_SCHEMA
from orchestrator.state import SpawnResult, State


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
