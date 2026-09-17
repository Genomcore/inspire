"""The `@claim` scan over the tests roots, and its four classes against a contract."""

import re
import subprocess

from ..findings import finding

CLAIM_TOKEN = re.compile(r"@claim\s+(\S+)(?:\s+(sha256:[0-9a-f]+))?")

SOURCE = "citation-check"

MESSAGES = {
    "CI-01": ("CI-01 dangling citation — %s",
              "`@claim %s` names no claim in this unit's derived contract.",
              "copy the id from the contract verbatim, or drop the token."),
    "CI-02": ("CI-02 citation with no fingerprint — %s",
              "`@claim %s` carries no fingerprint, so the claim is covered but the "
              "unit is never realized.",
              "write the second word exactly as the contract emits it: %s"),
    "CI-03": ("CI-03 fingerprint mismatch — %s",
              "`@claim %s` cites %s; the contract emits %s.",
              "copy the contract's fingerprint verbatim."),
    "CI-04": ("CI-04 uncited claim — %s",
              "no test under the tests roots cites this `test`-oracle claim.",
              "write a test for it and cite it with its fingerprint."),
}


def scan_citations(roots, cwd):
    """Every `@claim` token under the tests roots, as {file, line, id, fingerprint}."""
    lines = subprocess.run(
        ["grep", "-rn", "--exclude-dir=.git", "@claim", *roots],
        cwd=cwd, capture_output=True, text=True).stdout.splitlines()
    return [{"file": file, "line": int(number), "id": match.group(1), "fingerprint": match.group(2)}
            for file, number, text in (line.split(":", 2) for line in sorted(lines))
            for match in CLAIM_TOKEN.finditer(text)]


def classify_citations(contract, citations):
    """The four classes of the citation check, over one unit's contract.

    CI-01 a token naming no claim of this unit · CI-02 a citation with no
    fingerprint · CI-03 a fingerprint that does not match the contract's ·
    CI-04 a `test`-oracle claim nothing cites. Coverage reads the id and
    realization reads the fingerprint, so an id-only citation passes the gate and
    leaves the unit unrealized for good — which is why CI-02 is a finding here.
    """
    claims = dict((claim["id"], claim) for claim in contract.get("claims", []))
    prefixes = set(claim_id.split("/", 1)[0] for claim_id in claims)
    unit_id = (contract.get("unit") or {}).get("id")
    if unit_id:
        prefixes.add(unit_id)
    findings = []
    cited = set()
    for citation in citations:
        claim_id = citation["id"]
        where = "%s:%s" % (citation["file"], citation["line"])
        claim = claims.get(claim_id)
        if claim is None:
            if claim_id.split("/", 1)[0] in prefixes:
                title, issue, fix = MESSAGES["CI-01"]
                findings.append(finding(SOURCE, title % where, issue % claim_id, fix,
                                        cls="CI-01"))
            continue
        cited.add(claim_id)
        expected = claim.get("fingerprint")
        if not citation["fingerprint"]:
            title, issue, fix = MESSAGES["CI-02"]
            findings.append(finding(SOURCE, title % where, issue % claim_id,
                                    fix % (expected or "sha256:…"), cls="CI-02"))
        elif expected and citation["fingerprint"] != expected:
            title, issue, fix = MESSAGES["CI-03"]
            findings.append(finding(
                SOURCE, title % where,
                issue % (claim_id, citation["fingerprint"], expected), fix, cls="CI-03"))
    for claim in contract.get("claims", []):
        if claim.get("oracle") == "test" and claim["id"] not in cited:
            title, issue, fix = MESSAGES["CI-04"]
            findings.append(finding(SOURCE, title % claim["id"], issue, fix, cls="CI-04"))
    return findings
