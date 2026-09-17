import os
import tempfile
import unittest

from orchestrator.report import Report, spend_section, unit_rows
from orchestrator.test.stubs import stub_run, stub_unit
from orchestrator.util import write_json_atomic


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


class SpendSection(unittest.TestCase):

    def test_tokens_cost_turns_and_durations_are_summed_from_the_raw_records(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "spawns"))
            records = [
                {"shell": "inspire-tester", "brief": {"unit_id": "auth.user"}, "cost_usd": 0.25,
                 "num_turns": 9, "started_at": "2026-01-01T00:00:00Z",
                 "ended_at": "2026-01-01T00:01:01Z",
                 "usage": {"input_tokens": 100, "output_tokens": 10},
                 "model_usage": {"claude-x": {"inputTokens": 100, "outputTokens": 10,
                                              "costUSD": 0.25}}},
                {"shell": "inspire-implementer", "brief": {"unit_id": "auth.user"},
                 "cost_usd": 0.5, "num_turns": 3, "started_at": "2026-01-01T00:01:01Z",
                 "ended_at": "2026-01-01T00:01:02Z",
                 "usage": {"input_tokens": 50, "cache_read_input_tokens": 7},
                 "model_usage": {"claude-y": {"inputTokens": 50, "costUSD": 0.5}}}]
            for index, record in enumerate(records):
                write_json_atomic(os.path.join(root, "spawns", "%d.json" % index), record)
            unit = stub_unit(status="promoted", started_at="2026-01-01T00:00:00Z",
                             ended_at="2026-01-01T00:10:00Z",
                             rework={"contracter": 0, "tester": 1, "implementer": 0},
                             timeline=[{"phase": "tester", "started_at": "2026-01-01T00:00:00Z",
                                        "ended_at": "2026-01-01T00:02:00Z"},
                                       {"phase": "tester", "started_at": "2026-01-01T00:02:00Z",
                                        "ended_at": "2026-01-01T00:03:00Z"}])
            run = stub_run(run_dir=root, repo=root, config={"max_turns": 10})
            run.state["units"] = {"auth.user": unit}
            run.state["wave_log"] = [{"index": 1, "started_at": "2026-01-01T00:00:00Z",
                                           "ended_at": "2026-01-01T00:10:30Z"}]
            text = "\n".join(spend_section(run))
        self.assertIn("150 in · 10 out · 7 cache read · 0 cache write across 2 spawns", text)
        self.assertIn("| claude-x | 1 | 100 in · 10 out · 0 cache read · 0 cache write | 0.2500 |",
                      text)
        self.assertIn("| inspire-tester | 1 | 0.2500 | 9 | 0h 01m 01s |", text)
        self.assertIn("90% of max_turns** — 1: auth.user/inspire-tester (9)", text)
        self.assertIn("| auth.user | promoted | 2 | 0.7500 | tester 1 | 0h 10m 00s | tester 0h 03m 00s |",
                      text)
        self.assertIn("| 1 | 0h 10m 30s |", text)
