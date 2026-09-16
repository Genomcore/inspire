import unittest

from orchestrator.findings import (conflict_findings, conflict_role, finding, gate_digest,
                                   gate_findings, render_brief, render_findings,
                                   route_gate_verdict, targets_unit)
from orchestrator.test.stubs import stub_unit


def verdict(result, classes):
    return {"verdict": result,
            "findings": [{"class": cls, "target": "t", "message": "m", "remedy": "r"}
                         for cls in classes],
            "summary": {"claims": 4, "covered": 3}}


class GateRouting(unittest.TestCase):

    def test_a_pass_is_a_pass(self):
        self.assertEqual(route_gate_verdict(verdict("pass", [])), ("pass", None))

    def test_a_contract_class_stalls_rather_than_reworks(self):
        self.assertEqual(route_gate_verdict(verdict("fail", ["GV-00"])), ("stall", "GV-00"))
        self.assertEqual(route_gate_verdict(verdict("fail", ["GV-06"])), ("stall", "GV-06"))

    def test_a_failed_citing_test_goes_to_arbitration(self):
        self.assertEqual(route_gate_verdict(verdict("fail", ["GV-03"])), ("arbitrate", None))

    def test_a_stall_class_wins_over_arbitration(self):
        self.assertEqual(route_gate_verdict(verdict("fail", ["GV-03", "GV-06"])),
                         ("stall", "GV-06"))

    def test_tester_shaped_classes_route_back_to_the_tester(self):
        for cls in ("GV-01", "GV-02", "GV-04"):
            self.assertEqual(route_gate_verdict(verdict("fail", [cls])), ("rework", "tester"))

    def test_everything_else_is_the_implementer_s(self):
        self.assertEqual(route_gate_verdict(verdict("fail", ["GV-05"])),
                         ("rework", "implementer"))

    def test_the_digest_reads_the_summary(self):
        self.assertEqual(gate_digest(verdict("pass", [])), "pass 3/4")

    def test_the_findings_carry_the_gate_s_own_grammar(self):
        findings = gate_findings(verdict("fail", ["GV-05"]))
        self.assertEqual(findings[0]["source"], "emanate-gate")
        self.assertEqual(findings[0]["class"], "GV-05")
        self.assertEqual(findings[0]["issue"], "m")
        self.assertEqual(findings[0]["follow_up"], "r")


class ConflictRouting(unittest.TestCase):

    def test_only_test_paths_go_to_the_tester(self):
        self.assertEqual(conflict_role(["tests"], ["tests/a.spec.ts", "tests/b.spec.ts"]),
                         "tester")

    def test_any_source_path_goes_to_the_implementer(self):
        self.assertEqual(conflict_role(["tests"], ["tests/a.spec.ts", "source/x.ts"]),
                         "implementer")
        self.assertEqual(conflict_role(["tests"], ["tests-fixtures/x.ts"]), "implementer")

    def test_the_conflict_finding_names_the_paths_and_where_the_old_version_is(self):
        unit = stub_unit(integration_branch="emanate/all-auth-user-x")
        [row] = conflict_findings(unit, ["source/registry.ts"])
        self.assertEqual(row["source"], "promote")
        self.assertIn("source/registry.ts", row["issue"])
        self.assertIn("emanate/all-auth-user-x^:", row["issue"])


class Rendering(unittest.TestCase):

    def test_a_finding_renders_the_three_slots(self):
        rendered = render_findings([finding("inspire-quality-overseer", "the assertion is vacuous",
                                            "it asserts the mock", "assert the behaviour")])
        self.assertIn("### error · inspire-quality-overseer — the assertion is vacuous", rendered)
        self.assertIn("**Issue.** it asserts the mock", rendered)
        self.assertIn("**Suggested follow-up.** assert the behaviour", rendered)

    def test_a_brief_carries_the_findings_verbatim(self):
        brief = {"role": "tester", "unit_id": "auth.user",
                 "findings": [finding("citation-check", "CI-03", "stale", "copy it")]}
        rendered = render_brief(brief)
        self.assertIn("- **role** — tester", rendered)
        self.assertIn("CI-03", rendered)
        self.assertIn("stale", rendered)

    def test_a_rule_finding_is_attributed_to_this_unit_by_path_or_id(self):
        unit = {"path": "inspire_kb/04_domain/auth/user/auth.user.md", "id": "auth.user"}
        self.assertTrue(targets_unit(unit["path"], unit))
        self.assertTrue(targets_unit("auth.user", unit))
        self.assertTrue(targets_unit("auth::user", unit))
        self.assertFalse(targets_unit("auth::org", unit))
        self.assertFalse(targets_unit("", unit))
