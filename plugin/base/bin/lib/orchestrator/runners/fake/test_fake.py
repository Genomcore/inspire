import json
import os
import tempfile
import unittest

from orchestrator.runners.fake import FakeRunner

CONFIG = {"tests_roots": ["tests"], "source_roots": ["source"]}


def runner(root, script):
    with open(os.path.join(root, "script.json"), "w") as stream:
        json.dump(script, stream)
    return FakeRunner(root, CONFIG)


class Endings(unittest.TestCase):

    def test_the_scripted_sequence_plays_then_exits_forever(self):
        with tempfile.TemporaryDirectory() as root:
            fake = runner(root, {"endings": {"u": {"tester": ["crash", "exit"]}}})
            self.assertEqual([fake._ending("u", "tester") for _ in range(3)],
                             ["crash", "exit", "exit"])
            self.assertEqual(fake._ending("u", "implementer"), "exit")

    def test_positions_persist_on_disk_across_instances(self):
        with tempfile.TemporaryDirectory() as root:
            runner(root, {"endings": {"u": {"tester": ["crash", "exit"]}}})._ending("u", "tester")
            self.assertEqual(FakeRunner(root, CONFIG)._ending("u", "tester"), "exit")


class Stubs(unittest.TestCase):

    def test_the_body_is_named_after_unit_and_role_and_shared_adds_one_more(self):
        with tempfile.TemporaryDirectory() as root:
            fake = runner(root, {})
            brief = {"unit_id": "auth.user", "unit_slug": "auth-user"}
            fake._write_stub(root, brief, "implementer", 1, {"shared": "registry.ts"})
            fake._write_stub(root, brief, "implementer", 2, {})
            listing = sorted(os.listdir(os.path.join(root, "source")))
            with open(os.path.join(root, "source", "registry.ts")) as stream:
                shared = stream.read()
            with open(os.path.join(root, "source", "auth-user.implementer.ts")) as stream:
                body = stream.read()
        self.assertEqual(listing, ["auth-user.implementer.ts", "registry.ts"])
        self.assertIn("registered by auth-user, attempt 1", shared)
        self.assertIn("attempt 2", body)

    def test_skip_body_writes_beside_the_body_s_name_not_at_it(self):
        with tempfile.TemporaryDirectory() as root:
            fake = runner(root, {})
            fake._write_stub(root, {"unit_id": "u", "unit_slug": "u"}, "implementer", 1,
                             {"skip_body": True})
            self.assertEqual(os.listdir(os.path.join(root, "source")),
                             ["u.implementer-partial.ts"])
