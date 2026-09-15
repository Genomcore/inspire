#!/usr/bin/env python3
"""Unit tests for the `orchestrator` package's pure logic.

The process end to end is `plugin/test/orchestrator/01-fake-runner.sh`'s business:
it drives a scratch repo with the fake runner. What is worth testing in isolation
is the judgment-free half — the four citation classes, how a gate verdict routes,
what a shell's `tools:` line says, whether a config is usable, and that the state
file is never left half-written.

    python3 -m unittest plugin/base/bin/test/test-orchestrator.py
"""

import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))

from orchestrator.citations import classify_citations, scan_citations
from orchestrator.config import load_config, validate_config
from orchestrator.constants import MIN_CLAUDE_VERSION, STATE_SCHEMA
from orchestrator.errors import Refusal
from orchestrator.findings import (conflict_role, finding, gate_digest, gate_findings,
                                   render_brief, render_findings, route_gate_verdict,
                                   targets_unit)
from orchestrator.shells import is_read_only, parse_tools_line
from orchestrator.state import State
from orchestrator.util import parse_jsonl, parse_version, slugify, write_json_atomic


def contract(claims):
    return {"schema": "inspire.derived-contract/1",
            "unit": {"kind": "entity", "id": "auth.user",
                     "path": "inspire_kb/04_domain/auth/user/auth.user.md",
                     "lifecycle": "accepted"},
            "claims": claims}


def claim(key, oracle="test"):
    return {"id": "auth.user/%s" % key, "oracle": oracle,
            "fingerprint": "sha256:" + "a" * 8}


def citation(claim_id, fingerprint=None):
    return {"file": "tests/user.spec.ts", "line": 1, "id": claim_id,
            "fingerprint": fingerprint}


class Slugs(unittest.TestCase):

    def test_runs_of_foreign_characters_collapse_to_one_hyphen(self):
        self.assertEqual(slugify("auth.user.list.."), "auth-user-list")
        self.assertEqual(slugify("inspire_kb/04_domain/auth"),
                         "inspire-kb-04-domain-auth")
        self.assertEqual(slugify("Users::List"), "users-list")


class Citations(unittest.TestCase):

    def test_a_matching_citation_is_clean(self):
        model = contract([claim("f/id/nonnull")])
        findings = classify_citations(
            model, [citation("auth.user/f/id/nonnull", "sha256:" + "a" * 8)])
        self.assertEqual(findings, [])

    def test_ci_01_fires_on_a_token_of_this_unit_naming_no_claim(self):
        model = contract([claim("f/id/nonnull")])
        findings = classify_citations(
            model, [citation("auth.user/f/id/nonnull", "sha256:" + "a" * 8),
                    citation("auth.user/f/gone/unique", "sha256:" + "a" * 8)])
        self.assertEqual([item["class"] for item in findings], ["CI-01"])
        self.assertIn("tests/user.spec.ts:1", findings[0]["title"])

    def test_another_unit_s_token_is_not_this_unit_s_business(self):
        model = contract([claim("f/id/nonnull")])
        findings = classify_citations(
            model, [citation("auth.user/f/id/nonnull", "sha256:" + "a" * 8),
                    citation("audit.event/f/id/nonnull", "sha256:" + "b" * 8)])
        self.assertEqual(findings, [])

    def test_ci_02_fires_on_an_id_only_citation(self):
        model = contract([claim("f/id/nonnull")])
        findings = classify_citations(
            model, [citation("auth.user/f/id/nonnull")])
        self.assertEqual([item["class"] for item in findings], ["CI-02"])
        self.assertIn("sha256:" + "a" * 8, findings[0]["follow_up"])

    def test_ci_03_carries_both_fingerprints(self):
        model = contract([claim("f/id/nonnull")])
        findings = classify_citations(
            model, [citation("auth.user/f/id/nonnull", "sha256:" + "0" * 8)])
        self.assertEqual([item["class"] for item in findings], ["CI-03"])
        self.assertIn("sha256:" + "0" * 8, findings[0]["issue"])
        self.assertIn("sha256:" + "a" * 8, findings[0]["issue"])

    def test_ci_04_fires_on_an_uncited_test_claim_and_never_on_a_store_one(self):
        model = contract([claim("i/I1"), claim("f/id/unique", oracle="store")])
        findings = classify_citations(model, [])
        self.assertEqual([item["class"] for item in findings], ["CI-04"])
        self.assertIn("auth.user/i/I1", findings[0]["title"])

    def test_the_scanner_reads_the_token_grammar_off_disk(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "tests", "auth"))
            path = os.path.join(root, "tests", "auth", "user.spec.ts")
            with open(path, "w") as stream:
                stream.write("// @claim auth.user/f/id/nonnull sha256:abcd12\n"
                             "it('one', () => {})\n"
                             "// @claim auth.user/i/I1\n"
                             "it('two', () => {})\n")
            found = scan_citations(["tests"], root)
        self.assertEqual([(item["id"], item["fingerprint"], item["line"]) for item in found],
                         [("auth.user/f/id/nonnull", "sha256:abcd12", 1),
                          ("auth.user/i/I1", None, 3)])
        self.assertEqual(found[0]["file"], "tests/auth/user.spec.ts")


class GateRouting(unittest.TestCase):

    def verdict(self, result, classes):
        return {"verdict": result,
                "findings": [{"class": cls, "target": "t", "message": "m", "remedy": "r"}
                             for cls in classes],
                "summary": {"claims": 4, "covered": 3}}

    def test_a_pass_is_a_pass(self):
        self.assertEqual(route_gate_verdict(self.verdict("pass", [])),
                         ("pass", None))

    def test_a_contract_class_stalls_rather_than_reworks(self):
        self.assertEqual(route_gate_verdict(self.verdict("fail", ["GV-00"])),
                         ("stall", "GV-00"))
        self.assertEqual(route_gate_verdict(self.verdict("fail", ["GV-06"])),
                         ("stall", "GV-06"))

    def test_a_failed_citing_test_goes_to_arbitration(self):
        self.assertEqual(route_gate_verdict(self.verdict("fail", ["GV-03"])),
                         ("arbitrate", None))

    def test_a_stall_class_wins_over_arbitration(self):
        self.assertEqual(
            route_gate_verdict(self.verdict("fail", ["GV-03", "GV-06"])),
            ("stall", "GV-06"))

    def test_tester_shaped_classes_route_back_to_the_tester(self):
        for cls in ("GV-01", "GV-02", "GV-04"):
            self.assertEqual(route_gate_verdict(self.verdict("fail", [cls])),
                             ("rework", "tester"))

    def test_everything_else_is_the_implementer_s(self):
        self.assertEqual(route_gate_verdict(self.verdict("fail", ["GV-05"])),
                         ("rework", "implementer"))

    def test_the_digest_reads_the_summary(self):
        self.assertEqual(gate_digest(self.verdict("pass", [])), "pass 3/4")

    def test_the_findings_carry_the_gate_s_own_grammar(self):
        findings = gate_findings(self.verdict("fail", ["GV-05"]))
        self.assertEqual(findings[0]["source"], "emanate-gate")
        self.assertEqual(findings[0]["class"], "GV-05")
        self.assertEqual(findings[0]["issue"], "m")
        self.assertEqual(findings[0]["follow_up"], "r")


class ShellTools(unittest.TestCase):

    def shell(self, body):
        return "---\nname: x\ndescription: \"y\"\n%s\nmodel: inherit\n---\n\nbody\n" % body

    def test_a_tools_line_is_read_off_the_frontmatter(self):
        self.assertEqual(parse_tools_line(self.shell("tools: Read, Grep, Glob")),
                         ["Read", "Grep", "Glob"])

    def test_a_bracketed_list_reads_the_same(self):
        self.assertEqual(parse_tools_line(self.shell("tools: [Read, Glob]")),
                         ["Read", "Glob"])

    def test_a_shell_with_no_tools_line_answers_none(self):
        self.assertIsNone(parse_tools_line(self.shell("model: inherit")))

    def test_a_body_mentioning_tools_is_not_frontmatter(self):
        self.assertIsNone(parse_tools_line(
            "---\nname: x\n---\n\ntools: Read, Bash\n"))

    def test_an_overseer_is_read_only_only_when_it_names_no_writing_tool(self):
        self.assertTrue(is_read_only(["Read", "Grep", "Glob"]))
        self.assertFalse(is_read_only(["Read", "Bash"]))
        self.assertFalse(is_read_only(["Read", "Agent"]))
        self.assertFalse(is_read_only(None))


class ConfigValidation(unittest.TestCase):

    def usable(self):
        return {"schema": "inspire.emanate-config/1", "tests_roots": ["tests"],
                "source_roots": ["source"],
                "suite": [{"command": "npm test -- --json --outputFile={report}",
                           "format": "jest"}]}

    def test_the_shipped_shape_is_usable(self):
        self.assertEqual(validate_config(self.usable()), [])

    def test_a_foreign_schema_is_named(self):
        config = self.usable()
        config["schema"] = "inspire.emanate-config/0"
        self.assertEqual(len(validate_config(config)), 1)
        self.assertIn("schema", validate_config(config)[0])

    def test_the_four_required_keys_are_required(self):
        for key in ("schema", "tests_roots", "source_roots", "suite"):
            config = self.usable()
            del config[key]
            self.assertTrue(validate_config(config),
                            "%s should be required" % key)

    def test_an_empty_suite_is_no_suite(self):
        config = self.usable()
        config["suite"] = []
        self.assertTrue(validate_config(config))

    def test_a_suite_entry_needs_a_command(self):
        config = self.usable()
        config["suite"] = [{"format": "jest"}]
        self.assertTrue(validate_config(config))

    def test_the_optional_keys_are_optional_and_still_typed(self):
        config = self.usable()
        config["frozen_paths"] = ["package.json"]
        config["checks"] = [{"command": "npx tsc --noEmit", "roles": ["implementer"]}]
        config["narrowed_test"] = "npx jest {file}"
        self.assertEqual(validate_config(config), [])
        config["checks"] = [{"roles": ["implementer"]}]
        self.assertTrue(validate_config(config))

    def test_a_missing_file_refuses_with_the_remedy(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(Refusal) as caught:
                load_config(os.path.join(root, "emanate.json"))
        self.assertIn("inspire.emanate-config/1", str(caught.exception))

    def test_defaults_are_filled_in_on_load(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "emanate.json")
            with open(path, "w") as stream:
                json.dump(self.usable(), stream)
            config = load_config(path)
        self.assertEqual(config["frozen_paths"], [])
        self.assertEqual(config["checks"], [])


class StateWrites(unittest.TestCase):

    def test_the_state_round_trips(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "state.json")
            state = State(path, {"schema": STATE_SCHEMA,
                                              "units": {"auth.user": {"status": "pending"}}})
            state.save()
            state.unit("auth.user")["status"] = "promoted"
            state.save()
            reread = State.load(path)
        self.assertEqual(reread.data["units"]["auth.user"]["status"], "promoted")

    def test_a_write_leaves_no_partial_file_and_no_temporary_behind(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "state.json")
            write_json_atomic(path, {"a": 1})
            write_json_atomic(path, {"a": 2})
            self.assertEqual(os.listdir(root), ["state.json"])
            with open(path) as stream:
                self.assertEqual(json.load(stream), {"a": 2})


class ConflictRouting(unittest.TestCase):

    def test_only_test_paths_go_to_the_tester(self):
        self.assertEqual(conflict_role(["tests"], ["tests/a.spec.ts", "tests/b.spec.ts"]),
                         "tester")

    def test_any_source_path_goes_to_the_implementer(self):
        self.assertEqual(conflict_role(["tests"], ["tests/a.spec.ts", "source/x.ts"]),
                         "implementer")
        self.assertEqual(conflict_role(["tests"], ["tests-fixtures/x.ts"]), "implementer")


class Findings(unittest.TestCase):

    def test_a_finding_renders_the_three_slots(self):
        rendered = render_findings([finding(
            "inspire-quality-overseer", "the assertion is vacuous",
            "it asserts the mock", "assert the behaviour")])
        self.assertIn("### error · inspire-quality-overseer — the assertion is vacuous",
                      rendered)
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

    def test_jsonl_on_stderr_is_read_past_the_prose(self):
        rows = parse_jsonl(
            "SDD review\n{\"severity\":\"error\",\"rule\":\"r\",\"target\":\"t\","
            "\"message\":\"m\"}\nnot json\n")
        self.assertEqual(rows, [{"severity": "error", "rule": "r", "target": "t",
                                 "message": "m"}])


class Versions(unittest.TestCase):

    def test_the_harness_version_is_read_out_of_whatever_it_prints(self):
        self.assertEqual(parse_version("2.1.259 (Claude Code)"), (2, 1, 259))
        self.assertGreaterEqual(parse_version("2.2.0"),
                                MIN_CLAUDE_VERSION)
        self.assertLess(parse_version("2.1.258"),
                        MIN_CLAUDE_VERSION)
        self.assertIsNone(parse_version("unknown"))


if __name__ == "__main__":
    unittest.main()
