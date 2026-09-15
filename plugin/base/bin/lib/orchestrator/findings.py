"""The one finding shape, how a brief renders it, and what a gate verdict means."""

from .constants import TESTER_GATE_CLASSES


def finding(source, title, issue, follow_up, severity="error", cls=None):
    """The one finding shape this process hands around, rendered by
    `_references/findings-format.md`'s three slots."""
    record = {"source": source, "severity": severity, "title": title,
              "issue": issue, "follow_up": follow_up}
    if cls:
        record["class"] = cls
    return record


def render_findings(findings):
    out =["## Findings from the last attempt", ""]
    for item in findings:
        out.append("### %s · %s — %s"
                   % (item["severity"], item["source"], item["title"]))
        out.append("")
        out.append("**Issue.** %s" % item["issue"])
        out.append("")
        if item["follow_up"]:
            out.append("**Suggested follow-up.** %s" % item["follow_up"])
            out.append("")
    return "\n".join(out)


def render_brief(brief):
    """A brief is pointers and facts. Nothing here says what the role emits — the
    role doc says that, and the derived contract says what this unit needs."""
    lines = ["# %s" % brief.get("heading", "Emanation handoff"), ""]
    for label, key in (("role", "role"), ("role doctrine", "role_doc"),
                       ("unit", "unit_id"), ("kind", "unit_kind"),
                       ("knowledge-base artifact", "unit_path"),
                       ("derived contract", "contract_path"),
                       ("worktree", "worktree"), ("boundary", "boundary"),
                       ("suite results", "results_path"),
                       ("gate verdict", "verdict_path")):
        if brief.get(key):
            lines.append("- **%s** — %s" % (label, brief[key]))
    for label, key in (("resolved profiles", "profiles"), ("tests roots", "tests_roots"),
                       ("owned paths", "owned"), ("changed paths", "changed_paths"),
                       ("failing citations", "failing_files")):
        if brief.get(key):
            lines.append("- **%s** — %s" % (label, ", ".join(brief[key])))
    wire = brief.get("wire_conventions") or {}
    if wire.get("ids"):
        lines.append("- **wire conventions** — %s" % ", ".join(wire["ids"]))
    for row in wire.get("decisions") or []:
        lines.append("  - %s — %s" % (row.get("decision"), row.get("answer")))
    if brief.get("environment"):
        lines.append("- **environment** — `%s`" % brief["environment"])
    for note in brief.get("notes") or []:
        lines.append("- %s" % note)
    lines.append("")
    if brief.get("findings"):
        lines.append(render_findings(brief["findings"]))
    return "\n".join(lines)


def route_gate_verdict(verdict):
    """What a gate verdict means for the loop: (action, subject).

    `pass` · `stall` on a class no persona can answer · `arbitrate` on GV-03,
    where only the contract can say who is at fault · `rework` for one role.
    GV-01/02/04 are tester-shaped and reach the gate only when the tester's own
    checks missed them, so they route back there rather than to the implementer.
    """
    findings = verdict.get("findings") or []
    classes = [item.get("class") for item in findings]
    if verdict.get("verdict") == "pass":
        return ("pass", None)
    for blocked in ("GV-00", "GV-06"):
        if blocked in classes:
            return ("stall", blocked)
    if "GV-03" in classes:
        return ("arbitrate", None)
    if any(cls in TESTER_GATE_CLASSES for cls in classes):
        return ("rework", "tester")
    return ("rework", "implementer")


def gate_findings(verdict):
    """The gate's own `{class, target, message, remedy}` rows, in this process's shape."""
    return [finding("emanate-gate", "%s — %s" % (row.get("class"), row.get("target")),
                    row.get("message", ""), row.get("remedy", ""), cls=row.get("class"))
            for row in verdict.get("findings") or []]


def gate_digest(verdict):
    summary = verdict.get("summary") or {}
    return "%s %s/%s" % (verdict.get("verdict", "fail"),
                         summary.get("covered", 0), summary.get("claims", 0))


def targets_unit(target, unit):
    """A rule's finding is this unit's when it names this unit's path or id — the
    display form with `::` included. Everything else in the scoped path is a
    sibling, and grading it here would halt the wave on its own remaining work."""
    if not target:
        return False
    return target in (unit["path"], unit["id"]) or target.replace("::", ".") == unit["id"]
