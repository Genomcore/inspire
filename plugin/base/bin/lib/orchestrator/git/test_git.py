import json
import os
import subprocess
import tempfile
import unittest

from orchestrator.git import (advance_onto_goal, commit_prepared, integration_branch,
                              owned_pathspec, prepared_paths, template_sha)
from orchestrator.test.stubs import stub_run, stub_unit

ENV = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@x", GIT_COMMITTER_NAME="t",
           GIT_COMMITTER_EMAIL="t@x", GIT_CONFIG_NOSYSTEM="1")


def sh(cwd, *args):
    return subprocess.run(["git"] + list(args), cwd=cwd, env=ENV, check=True, text=True,
                          stdout=subprocess.PIPE).stdout.strip()


def write(root, rel, text):
    with open(os.path.join(root, rel), "w") as stream:
        stream.write(text)


class Names(unittest.TestCase):

    def test_the_integration_branch_carries_goal_unit_and_stamp(self):
        run = stub_run(goal_slug="all", stamp="20260101-000000")
        self.assertEqual(integration_branch(run, "auth-user"),
                         "emanate/all-auth-user-20260101-000000")

    def test_owned_paths_split_tests_from_source(self):
        run = stub_run()
        self.assertEqual(owned_pathspec(run, "tester"), ["tests"])
        self.assertEqual(owned_pathspec(run, "implementer"), ["source", ":(exclude)tests"])

    def test_the_tester_also_owns_the_declared_scaffold(self):
        run = stub_run()
        run.config["scaffold_paths"] = ["source/vitest.config.ts"]
        self.assertEqual(owned_pathspec(run, "tester"), ["tests", "source/vitest.config.ts"])
        self.assertEqual(owned_pathspec(run, "implementer"), ["source", ":(exclude)tests"])

    def test_template_sha_reads_the_lock_or_says_none(self):
        with tempfile.TemporaryDirectory() as root:
            run = stub_run(repo=root)
            self.assertEqual(template_sha(run), "none")
            with open(os.path.join(root, ".inspire.lock"), "w") as stream:
                json.dump({"template_sha": "abc123"}, stream)
            self.assertEqual(template_sha(run), "abc123")


class Prepared(unittest.TestCase):

    def test_what_prepare_wrote_is_committed_and_named_so_the_persona_is_not_blamed(self):
        with tempfile.TemporaryDirectory() as root:
            sh(root, "init", "-q", "-b", "main")
            write(root, "detail.tsx", "body\n")
            sh(root, "add", "-A"); sh(root, "commit", "-qm", "base")
            cut = sh(root, "rev-parse", "HEAD")
            run = stub_run(repo=root)
            commit_prepared(run, root, "tester")
            self.assertEqual(sh(root, "rev-parse", "HEAD"), cut, "nothing to commit, no commit")
            os.remove(os.path.join(root, "detail.tsx"))
            write(root, "detail.d.ts", "export declare const x: number;\n")
            commit_prepared(run, root, "tester")
            self.assertEqual(sh(root, "status", "--porcelain"), "")
            self.assertEqual(sh(root, "log", "-1", "--format=%s"), "emanate: prepare tester")
            self.assertEqual(prepared_paths(run, root, cut), {"detail.tsx", "detail.d.ts"})
            self.assertEqual(sh(root, "merge-base", "HEAD", cut), cut)


class AdvanceOntoGoal(unittest.TestCase):

    def test_the_conflicting_path_takes_the_goal_s_version_and_keeps_the_unit_s_behind(self):
        with tempfile.TemporaryDirectory() as root:
            sh(root, "init", "-q", "-b", "main")
            write(root, "base.txt", "base\n")
            sh(root, "add", "-A"); sh(root, "commit", "-qm", "base")
            sh(root, "branch", "emanate/all")
            sh(root, "branch", "emanate/all-b-x")
            sh(root, "checkout", "-q", "emanate/all")
            write(root, "registry.txt", "by a\n")
            sh(root, "add", "-A"); sh(root, "commit", "-qm", "promote a")
            sh(root, "checkout", "-q", "emanate/all-b-x")
            write(root, "registry.txt", "by b\n"); write(root, "b.txt", "body b\n")
            sh(root, "add", "-A"); sh(root, "commit", "-qm", "harvest b")
            verify = os.path.join(root, "verify")
            sh(root, "worktree", "add", "-q", "--detach", verify, "emanate/all-b-x")
            sh(root, "checkout", "-q", "main")

            run = stub_run(repo=root, goal_branch="emanate/all")
            unit = stub_unit("b", integration_branch="emanate/all-b-x", verify_worktree=verify)
            advance_onto_goal(run, unit, ["registry.txt"])

            tip = sh(root, "rev-parse", "emanate/all-b-x")
            self.assertEqual(sh(root, "show", "%s:registry.txt" % tip), "by a")
            self.assertEqual(sh(root, "show", "%s:b.txt" % tip), "body b")
            self.assertEqual(sh(root, "show", "%s^:registry.txt" % tip), "by b")
            self.assertEqual(sh(verify, "rev-parse", "HEAD"), tip,
                             "the verify worktree sits at the advanced tip")
            self.assertEqual(sh(root, "rev-list", "--count", "emanate/all..emanate/all-b-x"),
                             "2")
            self.assertEqual(sh(root, "rev-list", "--count", "emanate/all-b-x..emanate/all"),
                             "0", "the goal branch is now an ancestor: the promote merges clean")
