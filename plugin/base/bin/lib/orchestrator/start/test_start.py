import json
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

    def compose(self, services, rows):
        calls = []

        def fake_run(command, **kwargs):
            calls.append(command[2:])
            if command[2] == "config":
                return SimpleNamespace(returncode=0, stdout="\n".join(services) + "\n",
                                       stderr="")
            return SimpleNamespace(returncode=0, stderr="",
                                   stdout="\n".join(json.dumps(row) for row in rows))
        return calls, mock.patch("orchestrator.start.start.subprocess.run", fake_run)

    def test_healthy_components_let_the_run_proceed_and_are_reported(self):
        run = stub_run(plan=self.plan())
        calls, patch = self.compose(["postgres", "redis", "api"],
                                    [{"Service": "postgres", "State": "running",
                                      "Health": "healthy"},
                                     {"Service": "redis", "State": "running", "Health": ""}])
        with patch:
            probe_infrastructure(run)
        self.assertEqual(run.probe_line,
                         "components probed: postgres healthy, redis healthy")
        self.assertEqual([call[0] for call in calls], ["config", "ps"])

    def test_an_unhealthy_or_absent_component_refuses_naming_it_and_the_fix(self):
        run = stub_run(plan=self.plan())
        _, patch = self.compose(["postgres", "redis"],
                                [{"Service": "postgres", "State": "running",
                                  "Health": "starting"}])
        with patch, self.assertRaises(Refusal) as ctx:
            probe_infrastructure(run)
        message = str(ctx.exception)
        self.assertIn("postgres starting", message)
        self.assertIn("redis absent", message)
        self.assertIn("docker compose up -d --wait postgres redis", message)

    def test_up_is_not_healthy_when_a_healthcheck_exists(self):
        run = stub_run(plan=self.plan(components=("postgres",)))
        _, patch = self.compose(["postgres"], [{"Service": "postgres", "State": "running",
                                                "Health": "unhealthy"}])
        with patch, self.assertRaises(Refusal):
            probe_infrastructure(run)

    def test_a_component_without_a_compose_service_refuses(self):
        run = stub_run(plan=self.plan(components=("postgres",)))
        _, patch = self.compose(["api"], [])
        with patch, self.assertRaises(Refusal) as ctx:
            probe_infrastructure(run)
        self.assertIn("postgres", str(ctx.exception))

    def test_a_json_array_from_an_older_compose_is_read_too(self):
        run = stub_run(plan=self.plan(components=("postgres",)))
        rows = [{"Service": "postgres", "State": "running", "Health": "healthy"}]

        def fake_run(command, **kwargs):
            out = "postgres\n" if command[2] == "config" else json.dumps(rows)
            return SimpleNamespace(returncode=0, stdout=out, stderr="")
        with mock.patch("orchestrator.start.start.subprocess.run", fake_run):
            probe_infrastructure(run)
        self.assertEqual(run.probe_line, "components probed: postgres healthy")

    def test_without_a_probe_recipe_or_components_nothing_runs(self):
        with mock.patch("orchestrator.start.start.subprocess.run") as spawn:
            run = stub_run(plan=self.plan(probe_profiles=()))
            probe_infrastructure(run)
            self.assertIn("not probed", run.probe_line)
            run = stub_run(plan={"preflight": {"components": [], "probe_profiles": ["x"]}})
            probe_infrastructure(run)
            self.assertIn("no test-infrastructure components", run.probe_line)
            run = stub_run(plan={})
            probe_infrastructure(run)
        spawn.assert_not_called()
