import unittest

from orchestrator.runners.claude import DENY_RULES, ending_of


class Endings(unittest.TestCase):

    def test_a_clean_result_is_an_exit(self):
        self.assertEqual(ending_of({"result": "done"}), "exit")

    def test_the_harness_own_stops_are_named(self):
        self.assertEqual(ending_of({"subtype": "max_turns"}), "exhausted")
        self.assertEqual(ending_of({"subtype": "budget"}), "budget")

    def test_an_error_is_a_crash_unless_it_is_a_rate_limit(self):
        self.assertEqual(ending_of({"is_error": True, "result": "boom"}), "crash")
        self.assertEqual(ending_of({"is_error": True, "result": "Rate limit reached"}),
                         "ratelimit")

    def test_the_deny_rules_cover_every_ref_moving_git_verb(self):
        for verb in ("push", "update-ref", "merge", "branch", "worktree"):
            self.assertIn("Bash(git %s:*)" % verb, DENY_RULES)
