import asyncio
import os
import tempfile
import unittest

from orchestrator.runners.agente import DENY_RULES, AgentRunner, ending_of, fence


class Endings(unittest.TestCase):

    def test_a_clean_result_is_an_exit(self):
        self.assertEqual(ending_of({"subtype": "success", "result": "done"}), "exit")

    def test_the_harness_own_stops_are_named(self):
        self.assertEqual(ending_of({"subtype": "error_max_turns"}), "exhausted")
        self.assertEqual(ending_of({"subtype": "error_max_budget_usd"}), "budget")

    def test_an_error_is_a_crash_unless_it_is_a_rate_limit(self):
        self.assertEqual(ending_of({"is_error": True, "result": "boom"}), "crash")
        self.assertEqual(ending_of({"is_error": True, "result": "Rate limit reached"}),
                         "ratelimit")
        self.assertEqual(ending_of({"is_error": True, "api_error_status": 429}), "ratelimit")

    def test_the_deny_rules_cover_every_ref_moving_git_verb(self):
        for verb in ("push", "update-ref", "merge", "branch", "worktree"):
            self.assertIn("Bash(git %s:*)" % verb, DENY_RULES)


class Options(unittest.TestCase):

    def options(self, schema=None):
        with tempfile.TemporaryDirectory() as cwd:
            os.makedirs(os.path.join(cwd, ".claude", "agents"))
            with open(os.path.join(cwd, ".claude", "agents", "inspire-contracter.md"), "w") as f:
                f.write("---\nname: inspire-contracter\ntools: Read\nmodel: inherit\n---\n\n"
                        "You are the contracter.\n")
            return AgentRunner("/contracts", 10).options("inspire-contracter", ["Read"], cwd,
                                                         schema)

    def test_a_spawn_keeps_the_project_settings_since_they_carry_the_shells_and_skills(self):
        options = self.options()
        self.assertIsNone(options.setting_sources)
        self.assertTrue(options.strict_mcp_config)
        self.assertEqual(options.permission_mode, "dontAsk")
        self.assertEqual(options.hooks["PreToolUse"][0].hooks, [fence])

    def test_the_shell_rides_on_the_claude_code_prompt_and_the_schema_is_kept(self):
        options = self.options(schema={"type": "object"})
        self.assertEqual(options.system_prompt["append"], "You are the contracter.")
        self.assertEqual(options.system_prompt["preset"], "claude_code")
        self.assertEqual(options.output_format["schema"], {"type": "object"})
        self.assertEqual(options.allowed_tools, ["Read"])
        self.assertEqual(options.disallowed_tools, DENY_RULES)


class Fence(unittest.TestCase):

    def verdict(self, tool_input, cwd):
        payload = {"cwd": cwd, "tool_name": "Write", "tool_input": tool_input}
        out = asyncio.run(fence(payload, "t1", {"signal": None}))
        return out.get("hookSpecificOutput", {}).get("permissionDecision", "allow")

    def test_inside_the_worktree_passes_and_outside_is_blocked(self):
        with tempfile.TemporaryDirectory() as cwd:
            cwd = os.path.realpath(cwd)
            self.assertEqual(self.verdict({"file_path": os.path.join(cwd, "a/b.py")}, cwd), "allow")
            self.assertEqual(self.verdict({"file_path": "relative/c.py"}, cwd), "allow")
            self.assertEqual(self.verdict({"file_path": "/etc/hosts"}, cwd), "deny")
            self.assertEqual(self.verdict({"file_path": cwd + "/../x.py"}, cwd), "deny")
            self.assertEqual(self.verdict({"notebook_path": "/tmp/n.ipynb"}, cwd), "deny")
            self.assertEqual(self.verdict({}, cwd), "allow")
