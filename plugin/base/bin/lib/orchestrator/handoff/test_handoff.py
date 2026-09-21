import os
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

from orchestrator.errors import Stall
from orchestrator.handoff import (declaration_only_suite, environment_step,
                                  frozen_path_findings, persona_brief, recipe_steps,
                                  spend_rework, tests_root_args, unit_brief)
from orchestrator.test.stubs import stub_args, stub_run, stub_unit


class ReworkBudget(unittest.TestCase):

    def test_a_rework_is_counted_and_the_findings_kept(self):
        run = stub_run(args=stub_args(rework=2))
        unit = stub_unit()
        spend_rework(run, unit, "tester", [{"title": "x"}], "the gate")
        self.assertEqual(unit["rework"]["tester"], 1)
        self.assertEqual(unit["findings"], [{"title": "x"}])

    def test_the_attempt_past_the_budget_stalls_naming_the_role_and_place(self):
        run = stub_run(args=stub_args(rework=2))
        unit = stub_unit(rework={"contracter": 0, "tester": 2, "implementer": 0})
        with self.assertRaises(Stall) as caught:
            spend_rework(run, unit, "tester", [], "promote")
        self.assertEqual(caught.exception.unit_class, "rework exhausted")
        self.assertIn("tester", str(caught.exception))
        self.assertIn("promote", str(caught.exception))


class Briefs(unittest.TestCase):

    def test_the_unit_brief_is_the_four_pointers(self):
        run = stub_run(run_dir="/r")
        brief = unit_brief(run, stub_unit())
        self.assertEqual(sorted(brief), ["contract_path", "unit_id", "unit_path", "unit_slug"])
        self.assertEqual(brief["contract_path"], "/r/contracts/auth.user.json")

    def test_the_persona_brief_carries_owned_paths_profiles_and_findings(self):
        run = stub_run(plan_units={"auth.user": {"profiles": ["nestjs", "typescript"]}},
                       plan={"wire_conventions": {"ids": ["W1"]},
                             "preflight": {"worktree_recipe": [
                                 {"step": "environment", "command": "cp .env.example .env"}]}})
        brief = persona_brief(run, stub_unit(), "implementer", "/wt", [{"title": "f"}])
        self.assertEqual(brief["owned"], ["source", ":(exclude)tests"])
        self.assertEqual(brief["profiles"], ["nestjs", "typescript"])
        self.assertEqual(brief["environment"], "cp .env.example .env")
        self.assertEqual(brief["findings"], [{"title": "f"}])
        self.assertTrue(brief["role_doc"].endswith("roles/implementer.md"))


class Recipe(unittest.TestCase):

    def test_the_recipe_and_its_environment_step_read_off_the_plan(self):
        self.assertEqual(recipe_steps(stub_run(plan={})), [])
        run = stub_run(plan={"preflight": {"worktree_recipe": [
            {"step": "install", "command": "npm ci"},
            {"step": "environment", "command": "cp a b"}]}})
        self.assertEqual([s["step"] for s in recipe_steps(run)], ["install", "environment"])
        self.assertEqual(environment_step(run), "cp a b")
        self.assertIsNone(environment_step(stub_run(plan={})))


class Checks(unittest.TestCase):

    def test_only_tests_roots_that_exist_become_arguments(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "tests"))
            run = stub_run(config={"tests_roots": ["tests", "e2e"]})
            self.assertEqual(tests_root_args(run, root), ["--tests-root", "tests"])

    def test_a_frozen_path_in_the_change_set_is_one_finding(self):
        run = stub_run(config={"frozen_paths": ["package.json"]})
        self.assertEqual(frozen_path_findings(run, ["source/a.ts"]), [])
        [row] = frozen_path_findings(run, ["source/a.ts", "package.json"])
        self.assertEqual(row["source"], "frozen-paths")
        self.assertIn("package.json", row["issue"])


class VacuityRun(unittest.TestCase):

    def repo(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        os.makedirs(os.path.join(root, "source"))
        with open(os.path.join(root, "source", "detail.tsx"), "w") as stream:
            stream.write("export const Detail = () => <div/>\n")
        for arguments in (["init", "-q"], ["add", "-A"],
                          ["-c", "user.email=t@t", "-c", "user.name=t",
                           "commit", "-qm", "seed"]):
            subprocess.run(["git"] + arguments, cwd=root, check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return root

    def test_the_suite_runs_with_bodies_stripped_and_the_tree_comes_back(self):
        root = self.repo()
        run = stub_run(config=dict(
            stub_run().config,
            declaration_only="printf '' > source/detail.tsx; touch source/detail.d.ts"))
        seen = {}
        with mock.patch("orchestrator.handoff.handoff.verify_suite",
                        lambda run, unit, cwd, out: seen.update(
                            body=open(os.path.join(cwd, "source", "detail.tsx")).read())
                        or ({}, "")):
            declaration_only_suite(run, stub_unit(), root)
        self.assertEqual(seen["body"], "")
        self.assertIn("<div/>", open(os.path.join(root, "source", "detail.tsx")).read())
        self.assertFalse(os.path.exists(os.path.join(root, "source", "detail.d.ts")))

    def test_without_a_declaration_only_recipe_the_tree_is_left_alone(self):
        root = self.repo()
        with mock.patch("orchestrator.handoff.handoff.verify_suite",
                        lambda run, unit, cwd, out: ({}, "")):
            with mock.patch("orchestrator.git.restore_tree") as restore:
                declaration_only_suite(stub_run(), stub_unit(), root)
        self.assertFalse(restore.called)
