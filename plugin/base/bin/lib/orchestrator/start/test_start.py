import unittest

from orchestrator.constants import ROLES
from orchestrator.errors import Refusal
from orchestrator.start import blank_unit, check_ceiling, compute_goal_slug, select_waves
from orchestrator.test.stubs import stub_args, stub_run


class GoalSlug(unittest.TestCase):

    def test_the_slug_comes_from_goal_then_scope_then_all(self):
        self.assertEqual(compute_goal_slug(stub_run(args=stub_args(goal="auth.user.list"))),
                         "auth-user-list")
        self.assertEqual(compute_goal_slug(stub_run(args=stub_args(
            scope=["inspire_kb/04_domain/auth/", "inspire_kb/05_screens"]))),
            "auth-05-screens")
        self.assertEqual(compute_goal_slug(stub_run()), "all")

    def test_a_variant_is_appended(self):
        run = stub_run(args=stub_args(goal="auth.user", variant="B"))
        self.assertEqual(compute_goal_slug(run), "auth-user-b")


class Waves(unittest.TestCase):

    def plan(self):
        return {"waves": [["a", "b"], ["c"], ["d"]], "goal": None}

    def test_without_a_goal_or_ceiling_the_plan_s_waves_are_the_run_s(self):
        run = stub_run(plan=self.plan())
        planned, waves = select_waves(run)
        self.assertEqual(waves, [["a", "b"], ["c"], ["d"]])
        self.assertFalse(run.truncated)

    def test_a_goal_narrows_to_its_closure_and_drops_empty_waves(self):
        plan = self.plan()
        plan["goal"] = {"units": ["a", "d"]}
        planned, waves = select_waves(stub_run(plan=plan))
        self.assertEqual(waves, [["a"], ["d"]])

    def test_a_ceiling_truncates_and_marks_the_run(self):
        run = stub_run(plan=self.plan(), args=stub_args(ceiling=2))
        planned, waves = select_waves(run)
        self.assertEqual(planned, [["a", "b"], ["c"], ["d"]])
        self.assertEqual(waves, [["a", "b"], ["c"]])
        self.assertTrue(run.truncated)

    def test_a_ceiling_under_the_floor_refuses(self):
        run = stub_run(plan={"goal": {"floor": 3, "selector": "d"}}, args=stub_args(ceiling=2))
        with self.assertRaises(Refusal):
            check_ceiling(run)
        check_ceiling(stub_run(plan={"goal": {"floor": 3}}, args=stub_args(ceiling=3)))


class Units(unittest.TestCase):

    def test_a_blank_unit_starts_pending_with_zeroed_counters(self):
        unit = blank_unit({"id": "auth.user", "kind": "entity", "path": "p"})
        self.assertEqual(unit["status"], "pending")
        self.assertEqual(unit["slug"], "auth-user")
        self.assertEqual(unit["rework"], dict((role, 0) for role in ROLES))
        self.assertEqual(unit["infra_retries"], dict((role, 0) for role in ROLES))
