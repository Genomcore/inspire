import json
import os
import subprocess

from .. import git as gitmod
from ..constants import ARBITER_SCHEMA, ARBITER_SHELL, DRILL_SCHEMA, PERSONA_SHELLS
from ..errors import Infrastructural, Internal, Stall
from ..findings import finding, gate_findings
from ..handoff import (next_verify_dir, run_recipe, spawn, tests_root_args, unit_brief,
                       verify_suite)
from ..state import set_phase
from ..util import tail, write_json_atomic

GATE_DEFECT = ("gate defect",
               "emanate-gate.sh exited %d and reached no verdict: %s",
               "/inspire-lesson note")

ARBITRATION_HEADING = "arbitration — %s"
ARBITRATION_NOTE = ("answer in the structured shape: one verdict per failing test "
                    "file, each naming the party at fault.")
SPECIFICATION_STALL = ("specification",
                       "neither the test nor the body can be squared with the contract for "
                       "%s — the specification is wrong or missing.",
                       "route the finding to the skill that owns the artifact "
                       "(`inspire-domain`, `inspire-screens` or `inspire-feature`)")

DRILL_HEADING = "mutation drill — %s"
DRILL_NOTES = ("run tdd.md step 7's catalogue over this unit's diff "
               "(`git diff --name-only %s..HEAD`), k = 5 to 10, one mutation at "
               "a time, reverting between.",
               "the narrowed test command is `%s`, with `{file}` replaced by the "
               "test file.",
               "NEVER act on a survivor: report it. This worktree is discarded.")
DRILL_SKIPPED = "drill skipped — no narrowed-test command declared"
DRILL_INCOMPLETE = "drill incomplete — %s"
DRILL_UNFINISHED = "drill incomplete — the catalogue did not finish"
DRILL_CLEAN = "no survivors"
DRILL_SURVIVOR = "%s:%s — %s → %s"


def run_gate(run, ustate):
    worktree = ustate["verify_worktree"]
    out_dir = next_verify_dir(run, ustate)
    _, results_path = verify_suite(run, ustate, worktree, out_dir)
    command = [os.path.join(run.bin, "emanate-gate.sh"),
               "--contract", gitmod.contract_path(run, ustate["id"]),
               "--results", results_path]
    command += tests_root_args(run, worktree)
    proc = subprocess.run(command, cwd=worktree, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode not in (0, 1, 4):
        title, issue, next_act = GATE_DEFECT
        raise Stall(title, issue % (proc.returncode, tail(proc.stderr, 600)),
                    next_act=next_act)
    verdict = json.loads(proc.stdout)
    verdict_path = os.path.join(out_dir, "verdict.json")
    write_json_atomic(verdict_path, verdict)
    run.last_verdict[ustate["id"]] = verdict_path
    return verdict, results_path, verdict_path


def arbitrate(run, ustate, verdict, results_path, verdict_path):
    failing = sorted(set(
        citation["file"]
        for claim in verdict.get("claims") or []
        if "GV-03" in (claim.get("findings") or [])
        for citation in claim.get("citations") or []))
    brief = {"heading": ARBITRATION_HEADING % ustate["id"], "role": "arbiter",
             "unit_kind": ustate["kind"],
             "worktree": ustate["verify_worktree"],
             "results_path": results_path, "verdict_path": verdict_path,
             "failing_files": failing,
             "role_doc": ".claude/skills/inspire-code/references/roles/arbiter.md",
             "notes": [ARBITRATION_NOTE],
             **unit_brief(run, ustate)}
    result = spawn(run, ARBITER_SHELL, brief, ARBITER_SCHEMA, ustate["verify_worktree"])
    verdicts = (result.structured or {}).get("verdicts") or []
    findings = []
    for row in verdicts:
        detail = row.get("finding") or {}
        findings.append(finding("inspire-arbiter",
                                detail.get("title", row.get("test_file", "")),
                                detail.get("issue", ""), detail.get("follow_up", "")))
    faults = set(row.get("at_fault") for row in verdicts)
    if "specification" in faults:
        title, issue, next_act = SPECIFICATION_STALL
        raise Stall(title, issue % ustate["id"], findings + gate_findings(verdict),
                    next_act=next_act)
    role = "tester" if "tester" in faults else "implementer"
    return role, findings + gate_findings(verdict)


def drill(run, ustate):
    if not run.config.get("narrowed_test"):
        ustate["drill"] = DRILL_SKIPPED
        run.save()
        return
    set_phase(run, ustate, "drill")
    worktree = None
    try:
        worktree = gitmod.fresh_worktree(run, ustate["slug"], "drill",
                                         gitmod.tip(run, ustate))
        run_recipe(run, worktree)
        catalogue, narrowed, survivor = DRILL_NOTES
        brief = {"heading": DRILL_HEADING % ustate["id"], "role": "drill",
                 "worktree": worktree,
                 "role_doc": ".claude/skills/inspire-code/references/tdd.md",
                 "notes": [catalogue % run.goal_branch,
                           narrowed % run.config["narrowed_test"],
                           survivor],
                 **unit_brief(run, ustate)}
        ustate["drill"] = drill_outcome(
            spawn(run, PERSONA_SHELLS["implementer"], brief, DRILL_SCHEMA, worktree))
    except (Infrastructural, Internal) as failure:
        ustate["drill"] = DRILL_INCOMPLETE % failure
    finally:
        if worktree:
            gitmod.discard(run, worktree)
        set_phase(run, ustate, None)


def drill_outcome(result):
    if result.ending != "exit":
        return DRILL_INCOMPLETE % result.ending
    payload = result.structured or {}
    survivors = payload.get("survivors") or []
    if not payload.get("complete"):
        return DRILL_UNFINISHED
    if not survivors:
        return DRILL_CLEAN
    return "; ".join(DRILL_SURVIVOR % (row.get("file"), row.get("line"),
                                       row.get("mutation"), row.get("missing_test"))
                     for row in survivors)
