import contextlib
import importlib.util
import io
import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("orchestrate.py")
SPEC = importlib.util.spec_from_file_location("orchestrate", MODULE_PATH)
ORCHESTRATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ORCHESTRATE)


class OrchestrateTests(unittest.TestCase):
    def setUp(self):
        self.plan = json.dumps({
            "schema": "inspire.emanation-plan/2", "ready": True,
            "waves": [], "deliverable_waves": 0,
        })
        self.repo = Path("/tmp/emanate-test-repo")
        self.planner = self.repo / "plugin/base/bin/emanate-plan.sh"

    def test_ready_plan_is_passed_unchanged_to_loop(self):
        calls = []

        def fake_run(command, **kwargs):
            calls.append((command, kwargs))
            if len(calls) == 1:
                return subprocess.CompletedProcess(command, 0, self.plan, "")
            return subprocess.CompletedProcess(command, 0)

        with patch.object(ORCHESTRATE.subprocess, "run", side_effect=fake_run):
            code = ORCHESTRATE.orchestrate("run", self.repo)

        self.assertEqual(code, 0)
        self.assertEqual(calls[0][0], [str(self.planner)])
        self.assertEqual(calls[1][1]["input"], self.plan)
        self.assertIn("src/cli.ts", calls[1][0][2])
        self.assertEqual(len(calls[1][0]), 3)

    def test_rejected_plan_never_starts_loop(self):
        rejected = json.dumps({"schema": "inspire.emanation-plan/2", "ready": False})
        with patch.object(
            ORCHESTRATE.subprocess, "run",
            return_value=subprocess.CompletedProcess([], 1, rejected, "not ready\n"),
        ) as run, contextlib.redirect_stdout(io.StringIO()):
            code = ORCHESTRATE.orchestrate("run", self.repo)
        self.assertEqual(code, 1)
        run.assert_called_once()

    def test_refusal_never_starts_loop(self):
        refusal = '{"schema":"inspire.emanation-plan/2","refused":[]}'
        with patch.object(
            ORCHESTRATE.subprocess, "run",
            return_value=subprocess.CompletedProcess([], 4, refusal, ""),
        ) as run, contextlib.redirect_stdout(io.StringIO()):
            code = ORCHESTRATE.orchestrate("run", self.repo)
        self.assertEqual(code, 4)
        run.assert_called_once()


if __name__ == "__main__":
    unittest.main()
