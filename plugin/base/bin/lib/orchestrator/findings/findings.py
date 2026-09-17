from ..constants import TESTER_GATE_CLASSES

FINDINGS_HEADING = "## Findings from the last attempt"
FINDING_HEADING = "### %s · %s — %s"
FINDING_ISSUE = "**Issue.** %s"
FINDING_FOLLOW_UP = "**Suggested follow-up.** %s"

BRIEF_DEFAULT_HEADING = "Emanation handoff"
BRIEF_HEADING = "# %s"
BRIEF_FIELD = "- **%s** — %s"
BRIEF_ENVIRONMENT = "- **environment** — `%s`"
BRIEF_WIRE_CONVENTIONS = "wire conventions"
BRIEF_WIRE_DECISION = "  - %s — %s"
BRIEF_NOTE = "- %s"
BRIEF_SCALAR_LABELS = (("role", "role"), ("role doctrine", "role_doc"),
                       ("unit", "unit_id"), ("kind", "unit_kind"),
                       ("knowledge-base artifact", "unit_path"),
                       ("derived contract", "contract_path"),
                       ("worktree", "worktree"), ("boundary", "boundary"),
                       ("suite results", "results_path"),
                       ("gate verdict", "verdict_path"))
BRIEF_LIST_LABELS = (("resolved profiles", "profiles"), ("tests roots", "tests_roots"),
                     ("owned paths", "owned"), ("changed paths", "changed_paths"),
                     ("failing citations", "failing_files"))

CONFLICT_MESSAGE = (
    "the goal branch moved under this unit",
    "a sibling promoted first and also wrote: %s. The branch now carries "
    "the goal branch's version of each; this unit's own is one commit "
    "back (`git show %s^:<path>`).",
    "re-emit those paths so both units' work coexists.")
GATE_FINDING_TITLE = "%s — %s"
GATE_DIGEST = "%s %s/%s"


def finding(source, title, issue, follow_up, severity="error", cls=None):
    record = {"source": source, "severity": severity, "title": title,
              "issue": issue, "follow_up": follow_up}
    if cls:
        record["class"] = cls
    return record


def render_findings(findings):
    out = [FINDINGS_HEADING, ""]
    for item in findings:
        out.append(FINDING_HEADING
                   % (item["severity"], item["source"], item["title"]))
        out.append("")
        out.append(FINDING_ISSUE % item["issue"])
        out.append("")
        if item["follow_up"]:
            out.append(FINDING_FOLLOW_UP % item["follow_up"])
            out.append("")
    return "\n".join(out)


def render_brief(brief):
    lines = [BRIEF_HEADING % brief.get("heading", BRIEF_DEFAULT_HEADING), ""]
    for label, key in BRIEF_SCALAR_LABELS:
        if brief.get(key):
            lines.append(BRIEF_FIELD % (label, brief[key]))
    for label, key in BRIEF_LIST_LABELS:
        if brief.get(key):
            lines.append(BRIEF_FIELD % (label, ", ".join(brief[key])))
    wire = brief.get("wire_conventions") or {}
    if wire.get("ids"):
        lines.append(BRIEF_FIELD % (BRIEF_WIRE_CONVENTIONS, ", ".join(wire["ids"])))
    for row in wire.get("decisions") or []:
        lines.append(BRIEF_WIRE_DECISION % (row.get("decision"), row.get("answer")))
    if brief.get("environment"):
        lines.append(BRIEF_ENVIRONMENT % brief["environment"])
    for note in brief.get("notes") or []:
        lines.append(BRIEF_NOTE % note)
    lines.append("")
    if brief.get("findings"):
        lines.append(render_findings(brief["findings"]))
    return "\n".join(lines)


def route_gate_verdict(verdict):
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


def conflict_role(tests_roots, paths):
    roots = tuple(root.rstrip("/") + "/" for root in tests_roots)
    return "tester" if all(path.startswith(roots) for path in paths) else "implementer"


def conflict_findings(ustate, paths):
    title, issue, remedy = CONFLICT_MESSAGE
    return [finding("promote", title,
                    issue % (", ".join(paths), ustate["integration_branch"]), remedy)]


def gate_findings(verdict):
    return [finding("emanate-gate", GATE_FINDING_TITLE % (row.get("class"), row.get("target")),
                    row.get("message", ""), row.get("remedy", ""), cls=row.get("class"))
            for row in verdict.get("findings") or []]


def gate_digest(verdict):
    summary = verdict.get("summary") or {}
    return GATE_DIGEST % (verdict.get("verdict", "fail"),
                       summary.get("covered", 0), summary.get("claims", 0))


def targets_unit(target, unit):
    if not target:
        return False
    return target in (unit["path"], unit["id"]) or target.replace("::", ".") == unit["id"]
