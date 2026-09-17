"""The `@claim` scan over the tests roots, and its four classes against a contract."""

import re
import subprocess

from ..findings import finding

# The tester's own grammar (`roles/tester.md` § Citing a claim), shared with
# `lib/gate-citations.sh`: an id, and an optional fingerprint after it.
CLAIM_TOKEN = re.compile(r"@claim\s+(\S+)(?:\s+(sha256:[0-9a-f]+))?")


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
        if claim_id not in claims:
            # Prefix-scoped exactly as GV-04 is: a shared tests tree holds every
            # other unit's tokens, and those are not this unit's business.
            if claim_id.split("/", 1)[0] in prefixes:
                findings.append(finding(
                    "citation-check", "CI-01 dangling citation — %s" % where,
                    "`@claim %s` names no claim in this unit's derived contract." % claim_id,
                    "copy the id from the contract verbatim, or drop the token.",
                    cls="CI-01"))
            continue
        cited.add(claim_id)
        expected = claims[claim_id].get("fingerprint")
        if not citation["fingerprint"]:
            findings.append(finding(
                "citation-check", "CI-02 citation with no fingerprint — %s" % where,
                "`@claim %s` carries no fingerprint, so the claim is covered but the "
                "unit is never realized." % claim_id,
                "write the second word exactly as the contract emits it: %s"
                % (expected or "sha256:…"), cls="CI-02"))
        elif expected and citation["fingerprint"] != expected:
            findings.append(finding(
                "citation-check", "CI-03 fingerprint mismatch — %s" % where,
                "`@claim %s` cites %s; the contract emits %s."
                % (claim_id, citation["fingerprint"], expected),
                "copy the contract's fingerprint verbatim.", cls="CI-03"))
    for claim in contract.get("claims", []):
        if claim.get("oracle") == "test" and claim["id"] not in cited:
            findings.append(finding(
                "citation-check", "CI-04 uncited claim — %s" % claim["id"],
                "no test under the tests roots cites this `test`-oracle claim.",
                "write a test for it and cite it with its fingerprint.", cls="CI-04"))
    return findings
