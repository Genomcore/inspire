import unittest
from types import SimpleNamespace
from unittest import mock

from orchestrator.constants import ROLES
from orchestrator.errors import Refusal
from orchestrator.start import (blank_unit, check_ceiling, compute_goal_slug,
                                probe_infrastructure, select_waves)
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


class Probe(unittest.TestCase):

    def plan(self, probe_profiles=("nestjs",), components=("postgres", "redis")):
        return {"preflight": {"components": [{"name": name} for name in components],
                              "probe_profiles": list(probe_profiles)}}

    def compose(self, returncode, stderr=""):
        return mock.patch("orchestrator.start.start.subprocess.run",
                          return_value=SimpleNamespace(returncode=returncode, stderr=stderr))

    def test_the_components_are_brought_up_from_the_launch_checkout_and_reported(self):
        run = stub_run(plan=self.plan())
        with self.compose(0) as spawn:
            probe_infrastructure(run)
        self.assertEqual(spawn.call_args.args[0],
                         ["docker", "compose", "up", "-d", "--wait", "postgres", "redis"])
        self.assertEqual(spawn.call_args.kwargs["cwd"], "/repo")
        self.assertEqual(run.probe_line, "components up and healthy: postgres, redis")

    def test_a_component_that_does_not_come_up_healthy_refuses_with_compose_s_output(self):
        run = stub_run(plan=self.plan())
        with self.compose(1, "container postgres is unhealthy\n"), \
                self.assertRaises(Refusal) as ctx:
            probe_infrastructure(run)
        self.assertIn("docker compose up -d --wait postgres redis", str(ctx.exception))
        self.assertIn("container postgres is unhealthy", str(ctx.exception))

    def test_without_a_probe_recipe_or_components_nothing_runs(self):
        cases = [(self.plan(probe_profiles=()), "not brought up"),
                 (self.plan(components=()), "no test-infrastructure components"),
                 ({}, "no test-infrastructure components")]
        with self.compose(0) as spawn:
            for plan, expected in cases:
                with self.subTest(plan=plan):
                    run = stub_run(plan=plan)
                    probe_infrastructure(run)
                    self.assertIn(expected, run.probe_line)
        spawn.assert_not_called()
