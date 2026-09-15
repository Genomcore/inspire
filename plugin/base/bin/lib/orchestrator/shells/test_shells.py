import os
import tempfile
import unittest

from orchestrator.constants import ARBITER_SHELL, PERSONA_SHELLS, REQUIRED_OVERSEERS
from orchestrator.errors import Refusal
from orchestrator.shells import is_read_only, parse_tools_line, read_shells
from orchestrator.test.stubs import stub_args, stub_run


def shell(body):
    return "---\nname: x\ndescription: \"y\"\n%s\nmodel: inherit\n---\n\nbody\n" % body


class ShellTools(unittest.TestCase):

    def test_a_tools_line_is_read_off_the_frontmatter(self):
        self.assertEqual(parse_tools_line(shell("tools: Read, Grep, Glob")),
                         ["Read", "Grep", "Glob"])

    def test_a_bracketed_list_reads_the_same(self):
        self.assertEqual(parse_tools_line(shell("tools: [Read, Glob]")), ["Read", "Glob"])

    def test_a_shell_with_no_tools_line_answers_none(self):
        self.assertIsNone(parse_tools_line(shell("model: inherit")))

    def test_a_body_mentioning_tools_is_not_frontmatter(self):
        self.assertIsNone(parse_tools_line("---\nname: x\n---\n\ntools: Read, Bash\n"))

    def test_an_overseer_is_read_only_only_when_it_names_no_writing_tool(self):
        self.assertTrue(is_read_only(["Read", "Grep", "Glob"]))
        self.assertFalse(is_read_only(["Read", "Bash"]))
        self.assertFalse(is_read_only(["Read", "Agent"]))
        self.assertFalse(is_read_only(None))


class Roster(unittest.TestCase):

    def roster(self, root, overseer_tools="Read, Grep, Glob"):
        for name in tuple(PERSONA_SHELLS.values()) + (ARBITER_SHELL,):
            tools = "Read, Grep, Glob" if name == ARBITER_SHELL else "Read, Bash"
            with open(os.path.join(root, name), "w") as stream:
                stream.write(shell("tools: %s" % tools))
        for name in REQUIRED_OVERSEERS:
            with open(os.path.join(root, name), "w") as stream:
                stream.write(shell("tools: %s" % overseer_tools))

    def test_the_roster_is_read_with_each_shell_s_tools(self):
        with tempfile.TemporaryDirectory() as root:
            self.roster(root)
            run = stub_run(goal_worktree=root, args=stub_args(agents_root="."), shells={})
            read_shells(run)
        self.assertEqual(run.shells["inspire-tester.md"], ["Read", "Bash"])
        self.assertEqual(run.shells["inspire-quality-overseer.md"], ["Read", "Grep", "Glob"])

    def test_a_missing_required_shell_refuses(self):
        with tempfile.TemporaryDirectory() as root:
            self.roster(root)
            os.remove(os.path.join(root, "inspire-security-overseer.md"))
            run = stub_run(goal_worktree=root, args=stub_args(agents_root="."), shells={})
            with self.assertRaises(Refusal) as caught:
                read_shells(run)
        self.assertIn("inspire-security-overseer.md", str(caught.exception))

    def test_an_overseer_that_can_write_refuses(self):
        with tempfile.TemporaryDirectory() as root:
            self.roster(root, overseer_tools="Read, Bash")
            run = stub_run(goal_worktree=root, args=stub_args(agents_root="."), shells={})
            with self.assertRaises(Refusal) as caught:
                read_shells(run)
        self.assertIn("writes nothing", str(caught.exception))
