import os
import tempfile
import unittest

from orchestrator.citations import classify_citations, scan_citations
from orchestrator.test.stubs import citation, claim, contract


class Citations(unittest.TestCase):

    def test_a_matching_citation_is_clean(self):
        findings = classify_citations(contract([claim("f/id/nonnull")]),
                                      [citation("auth.user/f/id/nonnull", "sha256:" + "a" * 8)])
        self.assertEqual(findings, [])

    def test_ci_01_fires_on_a_token_of_this_unit_naming_no_claim(self):
        findings = classify_citations(
            contract([claim("f/id/nonnull")]),
            [citation("auth.user/f/id/nonnull", "sha256:" + "a" * 8),
             citation("auth.user/f/gone/unique", "sha256:" + "a" * 8)])
        self.assertEqual([item["class"] for item in findings], ["CI-01"])
        self.assertIn("tests/user.spec.ts:1", findings[0]["title"])

    def test_another_unit_s_token_is_not_this_unit_s_business(self):
        findings = classify_citations(
            contract([claim("f/id/nonnull")]),
            [citation("auth.user/f/id/nonnull", "sha256:" + "a" * 8),
             citation("audit.event/f/id/nonnull", "sha256:" + "b" * 8)])
        self.assertEqual(findings, [])

    def test_ci_02_fires_on_an_id_only_citation(self):
        findings = classify_citations(contract([claim("f/id/nonnull")]),
                                      [citation("auth.user/f/id/nonnull")])
        self.assertEqual([item["class"] for item in findings], ["CI-02"])
        self.assertIn("sha256:" + "a" * 8, findings[0]["follow_up"])

    def test_ci_03_carries_both_fingerprints(self):
        findings = classify_citations(contract([claim("f/id/nonnull")]),
                                      [citation("auth.user/f/id/nonnull", "sha256:" + "0" * 8)])
        self.assertEqual([item["class"] for item in findings], ["CI-03"])
        self.assertIn("sha256:" + "0" * 8, findings[0]["issue"])
        self.assertIn("sha256:" + "a" * 8, findings[0]["issue"])

    def test_ci_04_fires_on_an_uncited_test_claim_and_never_on_a_store_one(self):
        findings = classify_citations(
            contract([claim("i/I1"), claim("f/id/unique", oracle="store")]), [])
        self.assertEqual([item["class"] for item in findings], ["CI-04"])
        self.assertIn("auth.user/i/I1", findings[0]["title"])

    def test_the_scanner_reads_the_token_grammar_off_disk(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "tests", "auth"))
            with open(os.path.join(root, "tests", "auth", "user.spec.ts"), "w") as stream:
                stream.write("// @claim auth.user/f/id/nonnull sha256:abcd12\n"
                             "it('one', () => {})\n"
                             "// @claim auth.user/i/I1\n"
                             "it('two', () => {})\n")
            found = scan_citations(["tests"], root)
        self.assertEqual([(item["id"], item["fingerprint"], item["line"]) for item in found],
                         [("auth.user/f/id/nonnull", "sha256:abcd12", 1),
                          ("auth.user/i/I1", None, 3)])
        self.assertEqual(found[0]["file"], "tests/auth/user.spec.ts")
