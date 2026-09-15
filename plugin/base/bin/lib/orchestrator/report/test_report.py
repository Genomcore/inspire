import os
import tempfile
import unittest

from orchestrator.report import Report, unit_rows
from orchestrator.test.stubs import stub_unit


class Blocks(unittest.TestCase):

    def test_each_block_is_appended_and_committed_under_its_label(self):
        with tempfile.TemporaryDirectory() as root:
            labels = []
            report = Report(os.path.join(root, "log.md"), labels.append)
            report.truncate()
            report.write_block("# identity\n- **status** — RUNNING", "identity")
            report.write_block("## Wave 1 — closed", "wave 1")
            report.rewrite_status("goal reached")
            with open(report.path) as stream:
                text = stream.read()
        self.assertEqual(labels, ["identity", "wave 1"])
        self.assertIn("- **status** — goal reached", text)
        self.assertNotIn("RUNNING", text)
        self.assertLess(text.index("# identity"), text.index("## Wave 1"))


class UnitRows(unittest.TestCase):

    def test_a_promoted_unit_reads_as_delivered_with_its_trailers(self):
        unit = stub_unit(status="promoted", gate_digest="pass 4/4",
                         trailers={"Emanate-Run": "r1", "Emanate-Gate": "pass 4/4"})
        text = "\n".join(unit_rows(unit))
        self.assertIn("### auth.user — delivered", text)
        self.assertIn("**integration branch** — merged", text)
        self.assertIn("Emanate-Run r1", text)

    def test_a_stalled_unit_carries_its_class_reason_and_findings(self):
        unit = stub_unit(status="stalled", stall_class="rework exhausted", reason="why",
                         findings=[{"source": "s", "title": "t", "issue": "i"}])
        text = "\n".join(unit_rows(unit))
        self.assertIn("rework exhausted: why", text)
        self.assertIn("- s · t — i", text)
        self.assertIn("emanate/all-auth-user-x", text)
