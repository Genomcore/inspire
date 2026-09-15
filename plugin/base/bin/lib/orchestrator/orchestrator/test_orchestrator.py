import unittest
from types import SimpleNamespace

from orchestrator.orchestrator import Orchestrator
from orchestrator.test.stubs import stub_args, stub_unit


def orchestrator(units, plan_units=None, **args):
    run = Orchestrator(stub_args(**args))
    run.state = SimpleNamespace(data={"units": units, "waves": []}, save=lambda: None,
                                unit=lambda unit_id: units[unit_id])
    run.plan_units = plan_units or {}
    return run


class ExitReason(unittest.TestCase):

    def test_everything_promoted_is_the_goal_reached(self):
        run = orchestrator({"a": stub_unit("a", status="promoted")})
        self.assertEqual(run.exit_reason(False), "goal reached")

    def test_a_stall_with_a_cascade_is_named_as_one(self):
        run = orchestrator({"a": stub_unit("a", status="stalled"),
                            "b": stub_unit("b", status="blocked",
                                           reason="downstream of a, which is stalled")})
        self.assertEqual(run.exit_reason(False), "stall cascade")

    def test_a_stall_alone_is_the_goal_not_reached(self):
        run = orchestrator({"a": stub_unit("a", status="stalled")})
        self.assertEqual(run.exit_reason(False), "goal not reached — stalled units")

    def test_the_ceilings_are_named(self):
        run = orchestrator({}, ceiling=1)
        run.truncated = True
        self.assertEqual(run.exit_reason(False), "exhausted — ceiling 1 reached")
        run = orchestrator({}, budget_usd=2.5)
        self.assertIn("2.5 USD", run.exit_reason(True))


class Cascade(unittest.TestCase):

    def test_a_unit_downstream_of_a_stalled_or_blocked_one_is_blocked_by_it(self):
        run = orchestrator({"a": stub_unit("a", status="stalled"),
                            "b": stub_unit("b"), "c": stub_unit("c", status="promoted")},
                           plan_units={"b": {"requires": [{"id": "a"}]},
                                       "d": {"requires": [{"id": "c"}]}})
        self.assertEqual(run.blocked_by("b"), ("a", "stalled"))
        self.assertIsNone(run.blocked_by("d"))

    def test_marking_blocked_records_the_reason(self):
        unit = stub_unit("b")
        run = orchestrator({"b": unit})
        run.mark_blocked(unit, "spend ceiling reached")
        self.assertEqual((unit["status"], unit["reason"]), ("blocked", "spend ceiling reached"))
