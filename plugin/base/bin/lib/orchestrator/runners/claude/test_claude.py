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


class Command(unittest.TestCase):

    def command(self, schema=None):
        import os
        import tempfile
        from unittest import mock
        from orchestrator.runners.claude import ClaudeRunner
        with tempfile.TemporaryDirectory() as cwd:
            os.makedirs(os.path.join(cwd, ".claude", "agents"))
            with open(os.path.join(cwd, ".claude", "agents", "inspire-contracter.md"), "w") as f:
                f.write("---\nname: inspire-contracter\ntools: Read\nmodel: inherit\n---\n\n"
                        "You are the contracter.\n")
            with mock.patch("subprocess.run") as run:
                run.return_value = mock.Mock(stdout='{"result": "ok"}', stderr="")
                ClaudeRunner("/contracts", 10).spawn("inspire-contracter", ["Read"], cwd,
                                                     {}, schema)
        return run.call_args[0][0]

    def test_a_spawn_is_never_restricted_since_that_hides_the_shells_and_skills(self):
        command = self.command()
        self.assertNotIn("--restricted", command)
        self.assertIn("--strict-mcp-config", command)
        self.assertIn("fence.py", command[command.index("--settings") + 1])

    def test_the_shell_travels_as_the_system_prompt_since_agent_drops_the_schema(self):
        command = self.command(schema={"type": "object"})
        self.assertNotIn("--agent", command)
        self.assertEqual(command[command.index("--append-system-prompt") + 1],
                         "You are the contracter.")
        self.assertIn("--json-schema", command)


class Fence(unittest.TestCase):

    def verdict(self, tool_input, cwd):
        import json
        import os
        import subprocess
        from orchestrator.runners.claude import FENCE
        payload = json.dumps({"cwd": cwd, "tool_name": "Write", "tool_input": tool_input})
        return subprocess.run(["python3", FENCE], input=payload, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode

    def test_inside_the_worktree_passes_and_outside_is_blocked(self):
        import os
        import tempfile
        with tempfile.TemporaryDirectory() as cwd:
            cwd = os.path.realpath(cwd)
            self.assertEqual(self.verdict({"file_path": os.path.join(cwd, "a/b.py")}, cwd), 0)
            self.assertEqual(self.verdict({"file_path": "relative/c.py"}, cwd), 0)
            self.assertEqual(self.verdict({"file_path": "/etc/hosts"}, cwd), 2)
            self.assertEqual(self.verdict({"file_path": cwd + "/../x.py"}, cwd), 2)
            self.assertEqual(self.verdict({"notebook_path": "/tmp/n.ipynb"}, cwd), 2)
            self.assertEqual(self.verdict({}, cwd), 0)
