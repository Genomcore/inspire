import json
import os
import subprocess
import tempfile
import unittest

from orchestrator.git import (advance_onto_goal, integration_branch, owned_pathspec,
                              template_sha)
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

    def test_template_sha_reads_the_lock_or_says_none(self):
        with tempfile.TemporaryDirectory() as root:
            run = stub_run(repo=root)
            self.assertEqual(template_sha(run), "none")
            with open(os.path.join(root, ".inspire.lock"), "w") as stream:
                json.dump({"template_sha": "abc123"}, stream)
            self.assertEqual(template_sha(run), "abc123")


class AdvanceOntoGoal(unittest.TestCase):
    """Real git: a goal branch that moved under a unit, and the unit's branch
    brought onto it taking the goal's version of the one path both wrote."""

    def test_the_conflicting_path_takes_the_goal_s_version_and_keeps_the_unit_s_behind(self):
        with tempfile.TemporaryDirectory() as root:
            sh(root, "init", "-q", "-b", "main")
            write(root, "base.txt", "base\n")
            sh(root, "add", "-A"); sh(root, "commit", "-qm", "base")
            sh(root, "branch", "emanate/all")
            sh(root, "branch", "emanate/all-b-x")
            # the goal moves: a sibling promoted registry.txt
            sh(root, "checkout", "-q", "emanate/all")
            write(root, "registry.txt", "by a\n")
            sh(root, "add", "-A"); sh(root, "commit", "-qm", "promote a")
            # the unit wrote the same path, and its own body
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
