import unittest

from orchestrator.gate import drill_outcome
from orchestrator.state import SpawnResult


class DrillOutcome(unittest.TestCase):

    def test_a_spawn_that_did_not_exit_is_incomplete(self):
        self.assertEqual(drill_outcome(SpawnResult("timeout")), "drill incomplete — timeout")

    def test_an_unfinished_catalogue_is_incomplete(self):
        result = SpawnResult("exit", structured={"complete": False, "survivors": []})
        self.assertIn("did not finish", drill_outcome(result))

    def test_no_survivors_reads_as_such(self):
        result = SpawnResult("exit", structured={"complete": True, "survivors": []})
        self.assertEqual(drill_outcome(result), "no survivors")

    def test_survivors_are_listed_one_per_mutation(self):
        result = SpawnResult("exit", structured={"complete": True, "survivors": [
            {"file": "source/a.ts", "line": 3, "mutation": "flip <", "missing_test": "bound"}]})
        self.assertEqual(drill_outcome(result), "source/a.ts:3 — flip < → bound")
