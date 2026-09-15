import json
import os
import tempfile
import unittest

from orchestrator.constants import MIN_CLAUDE_VERSION
from orchestrator.util import parse_jsonl, parse_version, slugify, tail, write_json_atomic


class Slugs(unittest.TestCase):

    def test_runs_of_foreign_characters_collapse_to_one_hyphen(self):
        self.assertEqual(slugify("auth.user.list.."), "auth-user-list")
        self.assertEqual(slugify("inspire_kb/04_domain/auth"), "inspire-kb-04-domain-auth")
        self.assertEqual(slugify("Users::List"), "users-list")


class Versions(unittest.TestCase):

    def test_the_harness_version_is_read_out_of_whatever_it_prints(self):
        self.assertEqual(parse_version("2.1.259 (Claude Code)"), (2, 1, 259))
        self.assertGreaterEqual(parse_version("2.2.0"), MIN_CLAUDE_VERSION)
        self.assertLess(parse_version("2.1.258"), MIN_CLAUDE_VERSION)
        self.assertIsNone(parse_version("unknown"))


class Parsers(unittest.TestCase):

    def test_jsonl_on_stderr_is_read_past_the_prose(self):
        rows = parse_jsonl("SDD review\n{\"severity\":\"error\",\"rule\":\"r\"}\nnot json\n")
        self.assertEqual(rows, [{"severity": "error", "rule": "r"}])

    def test_tail_keeps_the_end(self):
        self.assertEqual(tail("  abcdef  ", 3), "def")


class AtomicWrites(unittest.TestCase):

    def test_a_write_leaves_no_partial_file_and_no_temporary_behind(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "state.json")
            write_json_atomic(path, {"a": 1})
            write_json_atomic(path, {"a": 2})
            self.assertEqual(os.listdir(root), ["state.json"])
            with open(path) as stream:
                self.assertEqual(json.load(stream), {"a": 2})
