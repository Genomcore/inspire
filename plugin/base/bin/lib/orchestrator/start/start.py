import json
import os
import shutil
import subprocess

from .. import git as gitmod
from ..constants import MIN_CLAUDE_VERSION, ROLES, STATE_SCHEMA, WORKTREES_DIR, RUNS_DIR
from ..errors import Infrastructural, Refusal
from ..handoff import run_recipe, run_suite, tests_root_args
from ..report import identity_block
from ..runners.agente import AgentRunner, harness_version
from ..runners.fake import FakeRunner
from ..util import now_iso, parse_version, slugify, tail

CHECKOUT_MESSAGES = {
    "dirty": "the launch checkout is not clean:\n%s\nCommit those paths or set them aside, "
             "then re-run.",
    "detached": "HEAD is detached. Run from the branch this effort is launched from.",
    "gitignore": "`.gitignore` does not cover %s. Add these lines to `.gitignore` and commit "
                 "them:\n%s\nThis process never writes the launch checkout, `.gitignore` "
                 "included.",
    "merge_conflict": "merging %s into %s conflicts on: %s. Resolve it by hand in %s, then "
                      "re-run — a conflict resolution is a judgment nobody is present to make.",
}
UNKNOWN_PATHS = "unknown paths"

RUNNER_MESSAGES = {
    "no_uv": "`uv` is not on PATH — this process resolves its own dependencies through it. "
             "Install uv and re-run.",
    "no_claude": "the Claude Agent SDK and its bundled `claude` could not be loaded — this run has nothing to spawn with.",
    "old_claude": "claude %s is below the %s this loop needs. Upgrade it and re-run.",
    "no_fake_dir": "no fake-runner directory at %s.",
    "unknown": "unknown runner %r — use `claude` or `fake:DIR`.",
}

PLAN_MESSAGES = {
    "row": "  %s · %s · %s · %s",
    "not_ready": "the plan is not ready:\n%s",
    "refused": "plan refused:\n%s",
    "exited": "emanate-plan.sh exited %d: %s",
    "ceiling_below_floor": "--ceiling %d is below the floor %d to `%s`: this run provably "
                           "cannot reach its goal. Raise the ceiling, or narrow the goal.",
    "beyond_ceiling": "beyond the declared ceiling of %d wave(s)",
    "derive_exited": "emanate-derive.sh exited %d on %s: %s",
}

PROBE_MESSAGES = {
    "skipped": "components %s declared, not brought up — no resolved framework profile "
               "carries a `## Test infrastructure` probe recipe",
    "none": "no test-infrastructure components declared",
    "up": "components up and healthy: %s",
    "failed": "test infrastructure did not come up healthy — `%s` exited %d in %s:\n%s",
}

BASELINE_MESSAGES = {
    "skipped": "baseline skipped — no tests under the tests roots",
    "infra": "the baseline could not be established: %s",
    "red": "the baseline suite is red in realized territory: %s. Emanating onto a red suite "
           "makes every later verdict unreadable.",
    "green": "baseline green in a recipe-provisioned worktree",
}


def write_identity(run):
    run.report.truncate()
    run.report.write_block(identity_block(run), "identity")


def check_launch_checkout(run):
    status = gitmod.git(run, ["status", "--porcelain"]).stdout.strip()
    if status:
        raise Refusal(CHECKOUT_MESSAGES["dirty"] % status)
    head = gitmod.git(run, ["symbolic-ref", "--short", "HEAD"], check=False)
    if head.returncode != 0:
        raise Refusal(CHECKOUT_MESSAGES["detached"])
    run.launch_branch = head.stdout.strip()
    proc = gitmod.git(run, ["check-ignore", WORKTREES_DIR + "/", RUNS_DIR + "/"],
                      check=False)
    ignored = proc.stdout.split()
    uncovered = [path for path in (WORKTREES_DIR, RUNS_DIR)
                 if path + "/" not in ignored]
    if uncovered:
        raise Refusal(CHECKOUT_MESSAGES["gitignore"]
                      % (" and ".join(uncovered),
                         "\n".join("%s/" % path for path in uncovered)))


def compute_goal_slug(run):
    if run.args.goal:
        slug = slugify(run.args.goal)
    elif run.args.scope:
        slug = "-".join(slugify(os.path.basename(path.rstrip("/")))
                        for path in run.args.scope)
    else:
        slug = "all"
    if run.args.variant:
        slug = "%s-%s" % (slug, slugify(run.args.variant))
    return slug


def build_runner(run):
    if shutil.which("uv") is None:
        raise Refusal(RUNNER_MESSAGES["no_uv"])
    contracts = os.path.join(run.run_dir, "contracts")
    spec = run.args.runner
    if spec == "claude":
        try:
            sdk, cli = harness_version()
        except (ImportError, OSError):
            raise Refusal(RUNNER_MESSAGES["no_claude"])
        version = parse_version(cli)
        if version is None or version < MIN_CLAUDE_VERSION:
            raise Refusal(RUNNER_MESSAGES["old_claude"]
                          % (cli or "?", ".".join(str(part) for part in MIN_CLAUDE_VERSION)))
        run.harness = "claude %s (claude-agent-sdk %s)" % (cli, sdk)
        return AgentRunner(contracts, run.config["wall_clock"],
                           run.config.get("max_turns"),
                           run.config.get("spawn_budget_usd"),
                           run.args.agents_root)
    if spec.startswith("fake:"):
        directory = spec[len("fake:"):]
        if not os.path.isdir(directory):
            raise Refusal(RUNNER_MESSAGES["no_fake_dir"] % directory)
        run.harness = "fake:%s" % directory
        return FakeRunner(directory, run.config)
    raise Refusal(RUNNER_MESSAGES["unknown"] % spec)


def open_goal_branch(run):
    gitmod.git_write(run, ["worktree", "prune"])
    run.goal_branch = "emanate/%s" % run.goal_slug
    run.goal_worktree = os.path.join(run.repo, WORKTREES_DIR, "emanate-%s" % run.goal_slug)
    exists = gitmod.git(run, ["rev-parse", "--verify", "--quiet",
                              "refs/heads/" + run.goal_branch],
                        check=False).returncode == 0
    if not exists:
        gitmod.git_write(run, ["worktree", "add", "-b", run.goal_branch, run.goal_worktree,
                               run.launch_branch])
        run.cut_here = True
        return
    run.cut_here = False
    if not os.path.exists(run.goal_worktree):
        gitmod.git_write(run, ["worktree", "add", run.goal_worktree, run.goal_branch])
    merge = gitmod.git_write(run, ["merge", "--no-edit", run.launch_branch],
                             cwd=run.goal_worktree, check=False)
    if merge.returncode != 0:
        conflicts = gitmod.git(run, ["diff", "--name-only", "--diff-filter=U"],
                               cwd=run.goal_worktree, check=False).stdout.split()
        gitmod.git_write(run, ["merge", "--abort"], cwd=run.goal_worktree, check=False)
        raise Refusal(CHECKOUT_MESSAGES["merge_conflict"]
                      % (run.launch_branch, run.goal_branch,
                         ", ".join(conflicts) or UNKNOWN_PATHS, run.goal_worktree))


def plan_command(run):
    command = [os.path.join(run.bin, "emanate-plan.sh")]
    for path in run.args.scope:
        command += ["--scope", path]
    if run.args.goal:
        command += ["--goal", run.args.goal]
    if run.args.ceiling:
        command += ["--ceiling", str(run.args.ceiling)]
    for selector in run.args.reemanate:
        command += ["--reemanate", selector]
    if run.args.profiles_root:
        command += ["--profiles-root", run.args.profiles_root]
    if run.args.agents_root:
        command += ["--agents-root", run.args.agents_root]
    command += tests_root_args(run, run.goal_worktree)
    return command


def run_plan(run):
    proc = subprocess.run(plan_command(run), cwd=run.goal_worktree, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode == 0:
        return json.loads(proc.stdout)
    if proc.returncode == 1:
        plan = json.loads(proc.stdout)
        rows = [PLAN_MESSAGES["row"] % (item.get("code"),
                                        item.get("unit") or item.get("target") or "—",
                                        item.get("message"), item.get("remedy"))
                for item in plan.get("findings", []) if item.get("severity") == "error"]
        raise Refusal(PLAN_MESSAGES["not_ready"] % "\n".join(rows))
    if proc.returncode == 4:
        refused = json.loads(proc.stdout).get("refused", [])
        rows = [PLAN_MESSAGES["row"] % (item.get("code"), item.get("target"),
                                        item.get("message"), item.get("remedy"))
                for item in refused]
        raise Refusal(PLAN_MESSAGES["refused"] % "\n".join(rows))
    raise Refusal(PLAN_MESSAGES["exited"] % (proc.returncode, tail(proc.stderr, 800)))


def check_ceiling(run):
    goal = run.plan.get("goal")
    if goal and run.args.ceiling and run.args.ceiling < goal.get("floor", 0):
        raise Refusal(PLAN_MESSAGES["ceiling_below_floor"]
                      % (run.args.ceiling, goal["floor"], goal.get("selector")))


def select_waves(run):
    planned = [list(wave) for wave in run.plan["waves"]]
    goal = run.plan.get("goal")
    if goal:
        wanted = set(goal.get("units") or [])
        planned = [[unit for unit in wave if unit in wanted] for wave in planned]
        planned = [wave for wave in planned if wave]
    waves = planned
    if run.args.ceiling and run.args.ceiling < len(planned):
        waves = planned[:run.args.ceiling]
        run.truncated = True
    return planned, waves


def plan_roster(run, planned, waves):
    runnable = set(unit for wave in waves for unit in wave)
    planned_ids = set(unit for wave in planned for unit in wave)
    units = {}
    pending = []
    for entry in run.plan["units"]:
        if entry["id"] not in planned_ids:
            continue
        run.plan_units[entry["id"]] = entry
        unit = blank_unit(entry)
        units[entry["id"]] = unit
        if entry["id"] not in runnable:
            unit["status"] = "blocked"
            unit["reason"] = PLAN_MESSAGES["beyond_ceiling"] % run.args.ceiling
            continue
        pending.append(entry)
    return units, pending


def derive_unit(run, entry):
    proc = subprocess.run([os.path.join(run.bin, "emanate-derive.sh"), entry["kind"],
                           "--file", entry["path"]],
                          cwd=run.goal_worktree, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise Refusal(PLAN_MESSAGES["derive_exited"]
                      % (proc.returncode, entry["id"], tail(proc.stderr, 600)))
    with open(gitmod.contract_path(run, entry["id"]), "w") as stream:
        stream.write(proc.stdout)


def blank_unit(entry):
    return {"id": entry["id"], "kind": entry["kind"], "path": entry["path"],
            "slug": slugify(entry["id"]),
            "status": "pending", "phase": None, "done": [],
            "started_at": None, "ended_at": None, "timeline": [],
            "integration_branch": None, "verify_worktree": None,
            "rework": dict((role, 0) for role in ROLES),
            "infra_retries": dict((role, 0) for role in ROLES),
            "dropped": [], "verify_findings": [], "gate_digest": None,
            "drill": None, "trailers": {}, "stall_class": None, "reason": None,
            "next_act": None, "findings": []}


def new_state(run, waves, units):
    run.state_path = os.path.join(run.run_dir, "state.json")
    run.state = {
        "schema": STATE_SCHEMA, "run_id": run.run_id, "stamp": run.stamp,
        "launch_branch": run.launch_branch, "goal_branch": run.goal_branch,
        "goal_worktree": run.goal_worktree, "cut_here": run.cut_here,
        "run_dir": run.run_dir, "config": run.config, "bin": run.bin,
        "args": dict((key, value) for key, value in vars(run.args).items()
                     if key not in ("command", "runner", "bin")),
        "waves": waves, "wave_index": 0, "spend_usd": 0.0, "spawn_count": 0,
        "started_at": now_iso(), "ended_at": None, "wave_log": [],
        "truncated": run.truncated, "harness": run.harness,
        "shells": run.shells, "plan_units": run.plan_units,
        "status": "RUNNING", "exit": None, "units": units}
    run.save()


def probe_infrastructure(run):
    preflight = run.plan.get("preflight") or {}
    names = [item["name"] for item in preflight.get("components") or []]
    if not names:
        run.probe_line = PROBE_MESSAGES["none"]
        return
    if not preflight.get("probe_profiles"):
        run.probe_line = PROBE_MESSAGES["skipped"] % ", ".join(names)
        return
    command = ["docker", "compose", "up", "-d", "--wait"] + names
    proc = subprocess.run(command, cwd=run.repo, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise Refusal(PROBE_MESSAGES["failed"]
                      % (" ".join(command), proc.returncode, run.repo, tail(proc.stderr, 800)))
    run.probe_line = PROBE_MESSAGES["up"] % ", ".join(names)


def baseline(run):
    roots = [root for root in run.config["tests_roots"]
             if any(files for _, _, files in
                    os.walk(os.path.join(run.goal_worktree, root)))]
    if not roots:
        run.baseline_line = BASELINE_MESSAGES["skipped"]
        return
    worktree = gitmod.fresh_worktree(run, "baseline", "baseline", run.goal_branch)
    try:
        try:
            run_recipe(run, worktree)
            results, _ = run_suite(run, worktree, os.path.join(run.run_dir, "baseline"))
        except Infrastructural as failure:
            raise Refusal(BASELINE_MESSAGES["infra"] % failure)
        failed = sorted(set(entry["file"] for entry in results["tests"]
                            if entry["status"] == "failed"))
        if failed:
            raise Refusal(BASELINE_MESSAGES["red"] % ", ".join(failed))
        run.baseline_line = BASELINE_MESSAGES["green"]
    finally:
        gitmod.discard(run, worktree)

