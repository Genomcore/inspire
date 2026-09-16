"""One unit's handoff sequence: prepare → spawn → the A/B/C/D boundary, and the
suite runs the boundary and the gate both read."""

import concurrent.futures
import json
import os
import subprocess

from .. import git as gitmod
from ..citations import classify_citations, scan_citations
from ..constants import OVERSEER_SCHEMA, PERSONA_SHELLS
from ..errors import Infrastructural, Stall
from ..findings import finding, targets_unit
from ..util import now_iso, parse_jsonl, read_json, sh, tail, write_json_atomic


# ------------------------------------------------------------- the substrate

def run_suite(run, cwd, out_dir):
    """The whole suite, then `emanate-results.sh` over what it wrote. A suite
    command is tolerated non-zero — a red suite is exactly the case the gate
    needs — but one that leaves no report has not run at all."""
    os.makedirs(out_dir, exist_ok=True)
    reports = []
    dialect = "jest"
    for index, entry in enumerate(run.config["suite"]):
        report = os.path.join(out_dir, "report-%d.json" % index)
        if os.path.exists(report):
            os.remove(report)
        proc = sh(entry["command"].replace("{report}", report), cwd=cwd)
        if not os.path.exists(report):
            raise Infrastructural("the suite command `%s` left no report at %s: %s"
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
        raise Infrastructural("emanate-results.sh exited %d: %s"
                              % (proc.returncode, tail(proc.stderr, 800)))
    results_path = os.path.join(out_dir, "results.json")
    with open(results_path, "w") as stream:
        stream.write(proc.stdout)
    return json.loads(proc.stdout), results_path


def verify_suite(run, ustate, cwd, out_dir):
    try:
        results, results_path = run_suite(run, cwd, out_dir)
    except Infrastructural as failure:
        raise Stall("infrastructural", "verify could not run the suite: %s" % failure)
    run.last_results[ustate["id"]] = results_path
    return results, results_path


def tests_root_args(run, worktree):
    """The tests roots that exist in this tree, as the tools take them."""
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
            raise Infrastructural("the recipe's `%s` step failed in %s: %s"
                                  % (step.get("step"), worktree, tail(proc.stderr, 600)))


# ------------------------------------------------------------------- spawning

def spawn(run, shell, brief, schema, cwd):
    started_at = now_iso()
    result = run.runner.spawn(shell[:-3], run.shells.get(shell), cwd, brief, schema)
    with run.spend_lock:
        run.state.data["spend_usd"] += result.cost_usd
        index = run.state.data["spawn_count"] + 1
        run.state.data["spawn_count"] = index
    path = os.path.join(run.run_dir, "spawns", "%s-%s-%03d.json"
                        % (brief.get("unit_slug", "run"), shell[:-3], index))
    record = result.record(brief, schema)
    # Raw facts only — who and when; the unit is in the brief. The report sums them.
    record.update({"shell": shell[:-3], "started_at": started_at, "ended_at": now_iso()})
    write_json_atomic(path, record)
    run.save()
    return result


def unit_brief(run, ustate):
    """The four pointers every brief carries, whoever reads it."""
    return {"unit_id": ustate["id"], "unit_path": ustate["path"],
            "unit_slug": ustate["slug"],
            "contract_path": gitmod.contract_path(run, ustate["id"])}


def persona_brief(run, ustate, role, worktree, findings):
    entry = run.plan_units[ustate["id"]]
    return {"heading": "%s — %s" % (role, ustate["id"]),
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


# -------------------------------------------------------------- the sequence

def handoff(run, ustate, role, findings):
    """prepare → spawn → A read-only checks → B harvest → C tool checks →
    D overseers, looping on this role's own rejections until the boundary
    clears. A rejection spends a rework attempt; an infrastructural ending
    gets one free retry first, because nobody judged the persona."""
    free_retry_used = False
    while True:
        tip_before = gitmod.tip(run, ustate)
        worktree = None
        try:
            worktree = prepare(run, ustate, role, tip_before)
            result = spawn(run, PERSONA_SHELLS[role],
                           persona_brief(run, ustate, role, worktree, findings),
                           None, worktree)
            if result.ending != "exit":
                raise Infrastructural("the %s spawn ended in %s" % (role, result.ending))
            rejection = checks_a(run, ustate, role, worktree, tip_before)
            if rejection:
                gitmod.discard(run, worktree)
                findings = rejection
                spend_rework(run, ustate, role, findings, "the %s boundary" % role)
                continue
            tip = harvest(run, ustate, role, worktree)
        except Infrastructural as failure:
            if worktree:
                gitmod.discard(run, worktree)
            after_infrastructural(run, ustate, role, str(failure), free_retry_used, findings)
            free_retry_used = True
            continue
        repoint_verify(run, ustate, tip)
        changed = gitmod.git(run, ["diff", "--name-only",
                                   "%s..%s" % (tip_before, tip)]).stdout.split()
        rejection = checks_c(run, ustate, role, changed)
        if not rejection:
            rejection = overseer_gate(run, ustate, role, changed)
        if rejection:
            findings = rejection
            spend_rework(run, ustate, role, findings, "the %s boundary" % role)
            continue
        return tip


def after_infrastructural(run, ustate, role, reason, free_retry_used, findings):
    """Nobody judged the persona, so the first one of a handoff is free; every
    later one spends a rework attempt."""
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
                    "the %s exhausted its rework budget (%d attempts) at %s"
                    % (role, run.args.rework, what), findings)


def prepare(run, ustate, role, tip):
    worktree = gitmod.fresh_worktree(run, ustate["slug"], role, tip)
    try:
        run_recipe(run, worktree)
        if role == "tester" and run.config.get("declaration_only"):
            proc = sh(run.config["declaration_only"], cwd=worktree)
            if proc.returncode != 0:
                raise Infrastructural("the declaration-only recipe failed: %s"
                                      % tail(proc.stderr, 600))
    except Infrastructural:
        gitmod.discard(run, worktree)
        raise
    return worktree


def repoint_verify(run, ustate, tip):
    gitmod.git_write(run, ["checkout", "--detach", tip], cwd=ustate["verify_worktree"])
    # The last results describe a tree that no longer exists. The verdict they
    # produced stays: it is why this boundary is being read again.
    run.last_results.pop(ustate["id"], None)


# ---- A: read-only, in the persona's own worktree, no tool spawn ----

def checks_a(run, ustate, role, worktree, tip_before):
    tip = gitmod.tip(run, ustate)
    if tip != tip_before:
        return [finding(role, "the persona moved the integration branch",
                        "the integration branch is at %s; it was at %s when this phase "
                        "began." % (tip[:12], tip_before[:12]),
                        "work inside the worktree only — the branch is the "
                        "orchestrator's to move.")]
    if not gitmod.git(run, ["status", "--porcelain"], cwd=worktree).stdout.strip():
        raise Infrastructural("the %s emitted nothing" % role)
    proc = gitmod.run_harvest(run, ustate, role, worktree, ["--mode", "plan"])
    dropped = json.loads(proc.stdout).get("dropped") or []
    if dropped:
        ustate["dropped"] = sorted(set(ustate["dropped"]) | set(dropped))
        run.save()
        return [finding(role, "paths outside the %s's owned set" % role,
                        "these paths would be dropped at harvest: %s" % ", ".join(dropped),
                        "emit inside %s and nowhere else."
                        % ", ".join(gitmod.owned_pathspec(run, role)))]
    if role == "tester":
        contract = read_json(gitmod.contract_path(run, ustate["id"]))
        return classify_citations(
            contract, scan_citations(run.config["tests_roots"], worktree))
    return []



# ---- B: harvest ----

def harvest(run, ustate, role, worktree):
    with run.git_lock:
        proc = gitmod.run_harvest(run, ustate, role, worktree, ["--discard"])
    if proc.returncode == 0:
        return json.loads(proc.stdout)["commit"]
    if proc.returncode == 6:
        raise Infrastructural("nothing to harvest from the %s" % role)
    # Every phase worktree is discarded at harvest or at stall: the emission is
    # on the integration branch, which is the autopsy.
    gitmod.discard(run, worktree)
    if proc.returncode == 7:
        raise Stall("harvest conflict",
                    "the %s's emission does not apply onto %s: %s"
                    % (role, ustate["integration_branch"], tail(proc.stderr, 600)))
    raise Stall("tool error", "emanate-harvest.sh exited %d at the %s handoff: %s"
                % (proc.returncode, role, tail(proc.stderr, 600)))


# ---- C: the tool checks, in the verify worktree at the new tip ----

def checks_c(run, ustate, role, changed):
    worktree = ustate["verify_worktree"]
    findings = []
    for entry in run.config["checks"]:
        roles = entry.get("roles")
        if roles and role not in roles:
            continue
        proc = sh(entry["command"], cwd=worktree)
        if proc.returncode != 0:
            findings.append(finding(
                "check:%s" % entry["command"], "the declared check failed",
                tail(proc.stdout + "\n" + proc.stderr, 1200),
                "make `%s` pass." % entry["command"]))
    proc = subprocess.run([os.path.join(run.bin, "escape-hatch-ratchet.sh")],
                          cwd=worktree, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode == 1:
        findings.append(finding(
            "escape-hatch-ratchet", "the escape-hatch count rose",
            tail(proc.stderr, 1200),
            "remove the suppression. The ceiling is raised by hand, in review — "
            "never by the loop."))
    if role == "tester":
        findings += tester_checks(run, ustate)
    if role == "implementer":
        findings += frozen_path_findings(run, changed)
    return findings


def tester_checks(run, ustate):
    """The two repo-scoped rules, scoped to this unit and attributed: only an
    error whose subject is this unit halts it, and the rest are reported. Then
    the all-red invariant, which only holds while no body exists."""
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
                                        row.get("message", ""),
                                        "the rule's subject is this unit — answer it "
                                        "before the gate."))
            else:
                ustate["verify_findings"].append(
                    "%s · %s — %s: %s" % (row.get("severity"), row.get("rule"),
                                          row.get("target"), row.get("message")))
    run.save()
    if "implementer" not in ustate["done"]:
        results, _ = verify_suite(run, ustate, worktree, next_verify_dir(run, ustate))
        claims = set(claim["id"] for claim in
                     read_json(gitmod.contract_path(run, ustate["id"])).get("claims", []))
        citing = set(citation["file"] for citation in
                     scan_citations(run.config["tests_roots"], worktree)
                     if citation["id"] in claims)
        green = sorted(set(entry["file"] for entry in results["tests"]
                           if entry["status"] == "passed" and entry["file"] in citing))
        if green:
            findings.append(finding(
                "all-red", "vacuity: passes without bodies",
                "these files cite this unit's claims and pass in a tree with no "
                "bodies: %s" % ", ".join(green),
                "a test that passes before the body exists asserts nothing."))
    return findings


def frozen_path_findings(run, changed):
    frozen = [path for path in changed if path in run.config["frozen_paths"]]
    if not frozen:
        return []
    return [finding("frozen-paths", "a frozen path was changed",
                    "this phase changed %s, which the project froze."
                    % ", ".join(frozen),
                    "revert those paths — a frozen path is the operator's.")]


# ---- D: the overseers ----

def overseer_gate(run, ustate, role, changed):
    worktree = ustate["verify_worktree"]
    brief = {"heading": "overseer read — %s at the %s boundary" % (ustate["id"], role),
             "role": "overseer", "boundary": role, "unit_kind": ustate["kind"],
             "worktree": worktree, "changed_paths": changed,
             "results_path": run.last_results.get(ustate["id"]),
             "verdict_path": run.last_verdict.get(ustate["id"]),
             "profiles": run.plan_units[ustate["id"]].get("profiles") or [],
             "notes": ["answer in the structured shape: verdict APPROVE or REJECT, "
                       "plus findings."],
             **unit_brief(run, ustate)}
    shells = run.overseer_shells
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(shells)) as pool:
        answers = list(pool.map(
            lambda shell: (shell, spawn(run, shell, dict(brief, heading="%s — %s"
                                                         % (shell[:-3], brief["heading"])),
                                        OVERSEER_SCHEMA, worktree)), shells))
    findings = []
    for shell, result in answers:
        structured = result.structured or {}
        approved = result.ending == "exit" and structured.get("verdict") == "APPROVE"
        rows = structured.get("findings") or []
        if approved:
            for row in rows:
                ustate["verify_findings"].append(
                    "%s · %s — %s" % (row.get("severity", "info"), shell[:-3],
                                      row.get("title", "")))
            continue
        # A REJECT is carried back as the overseer wrote it — the blocking rows
        # if it marked any, all of them otherwise. Only a spawn that answered
        # nothing is reported as one.
        rejection = [row for row in rows if row.get("blocking", True)] or rows
        if structured.get("verdict") != "REJECT" or not rejection:
            rejection = [{"title": "no answer from the overseer",
                          "issue": "the spawn ended in %s and returned %s."
                                   % (result.ending,
                                      structured.get("verdict") or "no verdict"),
                          "follow_up": "re-emit the boundary; the overseer "
                                       "reads it again."}]
        for row in rejection:
            findings.append(finding(shell[:-3], row.get("title", ""),
                                    row.get("issue", ""), row.get("follow_up", ""),
                                    row.get("severity", "error")))
    run.save()
    return findings
