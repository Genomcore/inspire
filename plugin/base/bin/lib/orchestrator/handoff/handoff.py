import json
import os
import subprocess

from .. import git as gitmod
from ..citations import classify_citations, scan_citations
from ..errors import Infrastructural, Stall
from ..findings import finding, targets_unit
from ..util import now_iso, parse_jsonl, read_json, sh, tail, write_json_atomic

SUITE_NO_REPORT = "the suite command `%s` left no report at %s: %s"
RESULTS_EXITED = "emanate-results.sh exited %d: %s"
VERIFY_COULD_NOT_RUN = "verify could not run the suite: %s"
RECIPE_STEP_FAILED = "the recipe's `%s` step failed in %s: %s"
DECLARATION_ONLY_FAILED = "the declaration-only recipe failed: %s"
PERSONA_HEADING = "%s — %s"
REWORK_EXHAUSTED = "the %s exhausted its rework budget (%d attempts) at %s"
EMITTED_NOTHING = "the %s emitted nothing"
NOTHING_TO_HARVEST = "nothing to harvest from the %s"
HARVEST_CONFLICT = "the %s's emission does not apply onto %s: %s"
HARVEST_TOOL_ERROR = "emanate-harvest.sh exited %d at the %s handoff: %s"
VERIFY_FINDING_ROW = "%s · %s — %s: %s"
OVERSEER_HEADING = "overseer read — %s at the %s boundary"
OVERSEER_NOTE = "answer in the structured shape: verdict APPROVE or REJECT, plus findings."
OVERSEER_FINDING_ROW = "%s · %s — %s"
NO_VERDICT = "no verdict"

MESSAGES = {
    "branch-moved": ("the persona moved the integration branch",
                     "the integration branch is at %s; it was at %s when this phase began.",
                     "work inside the worktree only — the branch is the orchestrator's to move."),
    "outside-owned": ("paths outside the %s's owned set",
                      "these paths would be dropped at harvest: %s",
                      "emit inside %s and nowhere else."),
    "check-failed": ("the declared check failed", "make `%s` pass."),
    "escape-hatch": ("the escape-hatch count rose",
                     "remove the suppression. The ceiling is raised by hand, in review — "
                     "never by the loop."),
    "rule-error": ("the rule's subject is this unit — answer it before the gate.",),
    "all-red": ("vacuity: passes without bodies",
                "these files cite this unit's claims and pass in a tree with no bodies: %s",
                "a test that passes before the body exists asserts nothing."),
    "frozen-paths": ("a frozen path was changed",
                     "this phase changed %s, which the project froze.",
                     "revert those paths — a frozen path is the operator's."),
    "no-answer": ("no answer from the overseer",
                  "the spawn ended in %s and returned %s.",
                  "re-emit the boundary; the overseer reads it again."),
}


def run_suite(run, cwd, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    reports = []
    dialect = "jest"
    for index, entry in enumerate(run.config["suite"]):
        report = os.path.join(out_dir, "report-%d.json" % index)
        if os.path.exists(report):
            os.remove(report)
        proc = sh(entry["command"].replace("{report}", report), cwd=cwd)
        if not os.path.exists(report):
            raise Infrastructural(SUITE_NO_REPORT
                                  % (entry["command"], report, tail(proc.stderr, 800)))
        reports.append(report)
        if entry.get("format"):
            dialect = entry["format"]
    command = [os.path.join(run.bin, "emanate-results.sh")]
    for report in reports:
        command += ["--from", report]
    command += ["--format", dialect, "--root", cwd]
    proc = subprocess.run(command, cwd=cwd, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise Infrastructural(RESULTS_EXITED % (proc.returncode, tail(proc.stderr, 800)))
    results_path = os.path.join(out_dir, "results.json")
    with open(results_path, "w") as stream:
        stream.write(proc.stdout)
    return json.loads(proc.stdout), results_path


def verify_suite(run, ustate, cwd, out_dir):
    try:
        results, results_path = run_suite(run, cwd, out_dir)
    except Infrastructural as failure:
        raise Stall("infrastructural", VERIFY_COULD_NOT_RUN % failure)
    run.last_results[ustate["id"]] = results_path
    return results, results_path


def tests_root_args(run, worktree):
    return [a for r in run.config["tests_roots"]
            if os.path.isdir(os.path.join(worktree, r))
            for a in ("--tests-root", r)]


def next_verify_dir(run, ustate):
    round_number = run.verify_rounds.get(ustate["id"], 0) + 1
    run.verify_rounds[ustate["id"]] = round_number
    return os.path.join(run.run_dir, "verify", "%s-%d" % (ustate["slug"], round_number))


def recipe_steps(run):
    return run.plan.get("preflight", {}).get("worktree_recipe") or []


def run_recipe(run, worktree):
    for step in recipe_steps(run):
        proc = sh(step["command"], cwd=worktree)
        if proc.returncode != 0:
            raise Infrastructural(RECIPE_STEP_FAILED
                                  % (step.get("step"), worktree, tail(proc.stderr, 600)))


def spawn(run, shell, brief, schema, cwd):
    started_at = now_iso()
    result = run.runner.spawn(shell[:-3], run.shells.get(shell), cwd, brief, schema)
    with run.spend_lock:
        run.state["spend_usd"] += result.cost_usd
        index = run.state["spawn_count"] + 1
        run.state["spawn_count"] = index
    path = os.path.join(run.run_dir, "spawns", "%s-%s-%03d.json"
                        % (brief.get("unit_slug", "run"), shell[:-3], index))
    record = result.record(brief, schema)
    record.update({"shell": shell[:-3], "started_at": started_at, "ended_at": now_iso()})
    write_json_atomic(path, record)
    run.save()
    return result


def unit_brief(run, ustate):
    return {"unit_id": ustate["id"], "unit_path": ustate["path"],
            "unit_slug": ustate["slug"],
            "contract_path": gitmod.contract_path(run, ustate["id"])}


def persona_brief(run, ustate, role, worktree, findings):
    entry = run.plan_units[ustate["id"]]
    return {"heading": PERSONA_HEADING % (role, ustate["id"]),
            "role": role,
            "role_doc": ".claude/skills/inspire-code/references/roles/%s.md" % role,
            "unit_kind": ustate["kind"],
            "worktree": worktree,
            "profiles": entry.get("profiles") or [],
            "wire_conventions": run.plan.get("wire_conventions") or {},
            "tests_roots": run.config["tests_roots"],
            "owned": gitmod.owned_pathspec(run, role),
            "environment": environment_step(run),
            "findings": findings,
            **unit_brief(run, ustate)}


def environment_step(run):
    return next((step.get("command") for step in recipe_steps(run)
                 if step.get("step") == "environment"), None)


def after_infrastructural(run, ustate, role, reason, free_retry_used, findings):
    ustate["infra_retries"][role] += 1
    run.save()
    if free_retry_used:
        spend_rework(run, ustate, role, findings, reason)


def spend_rework(run, ustate, role, findings, what):
    ustate["rework"][role] += 1
    ustate["findings"] = findings
    run.save()
    if ustate["rework"][role] > run.args.rework:
        raise Stall("rework exhausted",
                    REWORK_EXHAUSTED % (role, run.args.rework, what), findings)


def strip_bodies(run, worktree):
    if not run.config.get("declaration_only"):
        return False
    proc = sh(run.config["declaration_only"], cwd=worktree)
    if proc.returncode != 0:
        raise Infrastructural(DECLARATION_ONLY_FAILED % tail(proc.stderr, 600))
    return True


def declaration_only_suite(run, ustate, worktree):
    try:
        stripped = strip_bodies(run, worktree)
    except Infrastructural as failure:
        raise Stall("infrastructural", VERIFY_COULD_NOT_RUN % failure)
    try:
        return verify_suite(run, ustate, worktree, next_verify_dir(run, ustate))
    finally:
        if stripped:
            gitmod.restore_tree(run, worktree)


def prepare(run, ustate, role, tip):
    worktree = gitmod.fresh_worktree(run, ustate["slug"], role, tip)
    try:
        run_recipe(run, worktree)
        if role == "tester":
            strip_bodies(run, worktree)
        gitmod.commit_prepared(run, worktree, role)
    except Infrastructural:
        gitmod.discard(run, worktree)
        raise
    return worktree


def repoint_verify(run, ustate, tip):
    gitmod.git_write(run, ["checkout", "--detach", tip], cwd=ustate["verify_worktree"])
    run.last_results.pop(ustate["id"], None)


def checks_a(run, ustate, role, worktree, tip_before):
    tip = gitmod.tip(run, ustate)
    if tip != tip_before:
        title, issue, fix = MESSAGES["branch-moved"]
        return [finding(role, title, issue % (tip[:12], tip_before[:12]), fix)]
    if not gitmod.git(run, ["status", "--porcelain"], cwd=worktree).stdout.strip():
        raise Infrastructural(EMITTED_NOTHING % role)
    proc = gitmod.run_harvest(run, ustate, role, worktree, ["--mode", "plan"])
    dropped = sorted(set(json.loads(proc.stdout).get("dropped") or [])
                     - gitmod.prepared_paths(run, worktree, tip_before))
    if dropped:
        ustate["dropped"] = sorted(set(ustate["dropped"]) | set(dropped))
        run.save()
        title, issue, fix = MESSAGES["outside-owned"]
        return [finding(role, title % role, issue % ", ".join(dropped),
                        fix % ", ".join(gitmod.owned_pathspec(run, role)))]
    if role == "tester":
        contract = read_json(gitmod.contract_path(run, ustate["id"]))
        return classify_citations(
            contract, scan_citations(run.config["tests_roots"], worktree))
    return []


def harvest(run, ustate, role, worktree):
    with run.git_lock:
        proc = gitmod.run_harvest(run, ustate, role, worktree, ["--discard"])
    if proc.returncode == 0:
        return json.loads(proc.stdout)["commit"]
    if proc.returncode == 6:
        raise Infrastructural(NOTHING_TO_HARVEST % role)
    gitmod.discard(run, worktree)
    if proc.returncode == 7:
        raise Stall("harvest conflict", HARVEST_CONFLICT
                    % (role, ustate["integration_branch"], tail(proc.stderr, 600)))
    raise Stall("tool error", HARVEST_TOOL_ERROR
                % (proc.returncode, role, tail(proc.stderr, 600)))


def checks_c(run, ustate, role, changed):
    worktree = ustate["verify_worktree"]
    findings = []
    for entry in run.config["checks"]:
        roles = entry.get("roles")
        if roles and role not in roles:
            continue
        proc = sh(entry["command"], cwd=worktree)
        if proc.returncode != 0:
            title, fix = MESSAGES["check-failed"]
            findings.append(finding(
                "check:%s" % entry["command"], title,
                tail(proc.stdout + "\n" + proc.stderr, 1200),
                fix % entry["command"]))
    proc = subprocess.run([os.path.join(run.bin, "escape-hatch-ratchet.sh")],
                          cwd=worktree, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode == 1:
        title, fix = MESSAGES["escape-hatch"]
        findings.append(finding("escape-hatch-ratchet", title, tail(proc.stderr, 1200), fix))
    if role == "tester":
        findings += tester_checks(run, ustate)
    if role == "implementer":
        findings += frozen_path_findings(run, changed)
    return findings


def tester_checks(run, ustate):
    worktree = ustate["verify_worktree"]
    scope = os.path.dirname(ustate["path"]) or "."
    env = dict(os.environ)
    env["SDD_TEST_SCOPE"] = run.config["tests_roots"][0]
    findings = []
    for rule in ("declared-errors-tested.sh", "criteria-have-tests.sh"):
        proc = subprocess.run([os.path.join(run.bin, rule), scope],
                              cwd=worktree, env=env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for row in parse_jsonl(proc.stderr):
            if row.get("severity") == "error" and targets_unit(row.get("target"), ustate):
                findings.append(finding(row.get("rule", rule), row.get("target", ""),
                                        row.get("message", ""), MESSAGES["rule-error"][0]))
            else:
                ustate["verify_findings"].append(
                    VERIFY_FINDING_ROW % (row.get("severity"), row.get("rule"),
                                          row.get("target"), row.get("message")))
    run.save()
    if "implementer" not in ustate["done"]:
        results, _ = declaration_only_suite(run, ustate, worktree)
        claims = set(claim["id"] for claim in
                     read_json(gitmod.contract_path(run, ustate["id"])).get("claims", []))
        citing = set(citation["file"] for citation in
                     scan_citations(run.config["tests_roots"], worktree)
                     if citation["id"] in claims)
        green = sorted(set(entry["file"] for entry in results["tests"]
                           if entry["status"] == "passed" and entry["file"] in citing))
        if green:
            title, issue, fix = MESSAGES["all-red"]
            findings.append(finding("all-red", title, issue % ", ".join(green), fix))
    return findings


def frozen_path_findings(run, changed):
    frozen = [path for path in changed if path in run.config["frozen_paths"]]
    if not frozen:
        return []
    title, issue, fix = MESSAGES["frozen-paths"]
    return [finding("frozen-paths", title, issue % ", ".join(frozen), fix)]


def overseer_brief(run, ustate, role, changed):
    return {"heading": OVERSEER_HEADING % (ustate["id"], role),
            "role": "overseer", "boundary": role, "unit_kind": ustate["kind"],
            "worktree": ustate["verify_worktree"], "changed_paths": changed,
            "results_path": run.last_results.get(ustate["id"]),
            "verdict_path": run.last_verdict.get(ustate["id"]),
            "profiles": run.plan_units[ustate["id"]].get("profiles") or [],
            "notes": [OVERSEER_NOTE],
            **unit_brief(run, ustate)}


def overseer_answer(run, ustate, shell, result):
    structured = result.structured or {}
    approved = result.ending == "exit" and structured.get("verdict") == "APPROVE"
    rows = structured.get("findings") or []
    if approved:
        for row in rows:
            ustate["verify_findings"].append(
                OVERSEER_FINDING_ROW % (row.get("severity", "info"), shell[:-3],
                                        row.get("title", "")))
        run.save()
        return []
    rejection = [row for row in rows if row.get("blocking", True)] or rows
    if structured.get("verdict") != "REJECT" or not rejection:
        title, issue, fix = MESSAGES["no-answer"]
        rejection = [{"title": title,
                      "issue": issue % (result.ending,
                                        structured.get("verdict") or NO_VERDICT),
                      "follow_up": fix}]
    run.save()
    return [finding(shell[:-3], row.get("title", ""), row.get("issue", ""),
                    row.get("follow_up", ""), row.get("severity", "error"))
            for row in rejection]
