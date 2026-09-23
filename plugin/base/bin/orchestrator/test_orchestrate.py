import contextlib
import io
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).parent))
import orchestrate as ORCHESTRATE


class OrchestrateTests(unittest.TestCase):
    def setUp(self):
        self.plan = json.dumps({
            "schema": "inspire.emanation-plan/2", "ready": True,
            "waves": [], "deliverable_waves": 0,
        })
        self.repo = Path("/tmp/emanate-test-repo")
        self.planner = self.repo / "plugin/base/bin/emanate-plan.sh"
        self.run_args = ("--test-command", '["npm","test"]', "--results-file", "results.json", "--tests-root", "tests")

    def test_ready_plan_is_passed_unchanged_to_loop(self):
        calls = []

        def fake_run(command, **kwargs):
            calls.append((command, kwargs))
            if command[0] == str(self.planner):
                return subprocess.CompletedProcess(command, 0, self.plan, "")
            return subprocess.CompletedProcess(command, 0)

        with patch.object(subprocess, "run", side_effect=fake_run):
            code = ORCHESTRATE.orchestrate("run", self.repo, self.run_args)

        self.assertEqual(code, 0)
        self.assertEqual(calls[0][0], [str(self.planner), "--tests-root", "tests"])
        self.assertEqual(calls[-1][1]["input"], self.plan)
        self.assertIn("src/cli.ts", calls[-1][0][2])
        self.assertIn("--test-command", calls[-1][0])

    def test_plan_prints_planner_output_without_starting_loop(self):
        output = io.StringIO()
        with patch.object(
            subprocess, "run",
            return_value=subprocess.CompletedProcess([], 0, self.plan, ""),
        ) as run, contextlib.redirect_stdout(output):
            code = ORCHESTRATE.orchestrate("plan", self.repo, ("--goal", "users.detail", "--tests-root", "tests"))
        self.assertEqual(code, 0)
        self.assertEqual(output.getvalue(), self.plan)
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0], [str(self.planner), "--goal", "users.detail", "--tests-root", "tests"])

    def test_rejected_plan_never_starts_loop(self):
        rejected = json.dumps({"schema": "inspire.emanation-plan/2", "ready": False})
        with patch.object(
            subprocess, "run",
            return_value=subprocess.CompletedProcess([], 1, rejected, "not ready\n"),
        ) as run, contextlib.redirect_stdout(io.StringIO()):
            code = ORCHESTRATE.orchestrate("run", self.repo, self.run_args)
        self.assertEqual(code, 1)
        run.assert_called_once()

    def test_refusal_never_starts_loop(self):
        refusal = '{"schema":"inspire.emanation-plan/2","refused":[]}'
        with patch.object(
            subprocess, "run",
            return_value=subprocess.CompletedProcess([], 4, refusal, ""),
        ) as run, contextlib.redirect_stdout(io.StringIO()):
            code = ORCHESTRATE.orchestrate("run", self.repo, self.run_args)
        self.assertEqual(code, 4)
        run.assert_called_once()

    def test_run_refuses_without_verification_configuration(self):
        with patch.object(subprocess, "run") as run:
            code = ORCHESTRATE.orchestrate("run", self.repo)
        self.assertEqual(code, 2)
        run.assert_not_called()

    def test_goal_below_ceiling_refuses_before_loop(self):
        plan = json.dumps({"schema": "inspire.emanation-plan/2", "ready": True,
                           "goal": {"floor": 3}, "ceiling": 2})
        with patch.object(subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 0, plan, "")) as run:
            code = ORCHESTRATE.orchestrate("run", self.repo, self.run_args)
        self.assertEqual(code, 1)
        run.assert_called_once()


if __name__ == "__main__":
    unittest.main()
