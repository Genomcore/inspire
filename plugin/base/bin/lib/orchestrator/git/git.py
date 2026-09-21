import hashlib
import os
import subprocess

from ..constants import LOG_PATH, TRAILER_ORDER, WORKTREES_DIR
from ..errors import Internal, Refusal, Stall
from ..findings import gate_digest
from ..state import set_phase
from ..util import read_json, tail

NOT_A_REPO = "not a git repository — this loop's whole audit trail is git."
GIT_FAILED = "git %s failed: %s"
NO_MERGE = "%s does not merge into %s: %s"

COMMITS = {
    "log": "emanate(log): %s — %s",
    "promote": "emanate: promote %s\n\n%s\n",
    "advance": "emanate: advance %s onto %s\n\nconflicting: %s\n",
    "prepare": "emanate: prepare %s\n",
}


def repo_root():
    proc = subprocess.run(["git", "rev-parse", "--show-toplevel"], text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise Refusal(NOT_A_REPO)
    return proc.stdout.strip()


def git(run, arguments, cwd=None, check=True):
    proc = subprocess.run(["git"] + arguments, cwd=cwd or run.repo, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and proc.returncode != 0:
        raise Internal(GIT_FAILED % (" ".join(arguments), tail(proc.stderr, 600)))
    return proc


def git_write(run, arguments, cwd=None, check=True):
    with run.git_lock:
        return git(run, arguments, cwd=cwd, check=check)


def commit_log(run, label):
    message = COMMITS["log"] % (run.run_id, label)
    with run.git_lock:
        git(run, ["add", "-f", LOG_PATH], cwd=run.goal_worktree)
        git(run, ["commit", "-m", message], cwd=run.goal_worktree)


def contract_path(run, unit_id):
    return os.path.join(run.run_dir, "contracts", "%s.json" % unit_id)


def fresh_worktree(run, unit_slug, phase, ref):
    worktree = os.path.join(run.repo, WORKTREES_DIR, "emanate-%s-%s-%s-%s"
                            % (run.goal_slug, unit_slug, run.stamp, phase))
    if os.path.exists(worktree):
        discard(run, worktree)
    git_write(run, ["worktree", "add", "--detach", worktree, ref])
    return worktree


def integration_branch(run, unit_slug):
    return "emanate/%s-%s-%s" % (run.goal_slug, unit_slug, run.stamp)


def owned_pathspec(run, role):
    if role == "tester":
        return list(run.config["tests_roots"]) + list(run.config["scaffold_paths"])
    return list(run.config["source_roots"]) + \
        [":(exclude)%s" % root for root in run.config["tests_roots"]]


def tip(run, ustate):
    return git(run, ["rev-parse", ustate["integration_branch"]]).stdout.strip()


def commit_prepared(run, worktree, role):
    git(run, ["add", "-A"], cwd=worktree)
    if git(run, ["diff", "--cached", "--quiet"], cwd=worktree, check=False).returncode:
        git(run, ["commit", "-q", "-m", COMMITS["prepare"] % role], cwd=worktree)


def prepared_paths(run, worktree, cut):
    out = git(run, ["-c", "core.quotePath=false", "diff", "--no-renames", "--name-only",
                    "-z", cut, "HEAD"], cwd=worktree).stdout
    return set(path for path in out.split("\0") if path)


def discard(run, worktree):
    git_write(run, ["worktree", "remove", "--force", worktree], check=False)


def run_harvest(run, ustate, role, worktree, extra):
    command = [os.path.join(run.bin, "emanate-harvest.sh"), worktree,
               ustate["integration_branch"], "--label", role] + extra + \
        ["--"] + owned_pathspec(run, role)
    return subprocess.run(command, cwd=run.repo, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def promote(run, ustate, verdict):
    trailers = {"Emanate-Run": run.run_id, "Emanate-Unit": ustate["id"],
                "Emanate-Template-Sha": template_sha(run),
                "Emanate-Profiles": profile_hashes(run, ustate),
                "Emanate-Gate": gate_digest(verdict),
                "Emanate-Harness": run.harness}
    message = COMMITS["promote"] % (
        ustate["id"], "\n".join("%s: %s" % (key, trailers[key]) for key in TRAILER_ORDER))
    with run.git_lock:
        merge = git(run, ["merge", "--no-ff", "-m", message, ustate["integration_branch"]],
                    cwd=run.goal_worktree, check=False)
        if merge.returncode != 0:
            conflicting = git(run, ["diff", "--name-only", "--diff-filter=U"],
                              cwd=run.goal_worktree).stdout.split()
            git(run, ["merge", "--abort"], cwd=run.goal_worktree, check=False)
            if not conflicting:
                raise Stall("promote", NO_MERGE
                            % (ustate["integration_branch"], run.goal_branch,
                               tail(merge.stdout + merge.stderr, 600)))
            return sorted(conflicting)
        git(run, ["branch", "-d", ustate["integration_branch"]], cwd=run.goal_worktree)
    discard(run, ustate["verify_worktree"])
    ustate["verify_worktree"] = None
    ustate["trailers"] = trailers
    ustate["status"] = "promoted"
    set_phase(run, ustate, None)
    return None


def advance_onto_goal(run, ustate, conflicting):
    worktree = ustate["verify_worktree"]
    with run.git_lock:
        git(run, ["merge", "--no-commit", run.goal_branch], cwd=worktree, check=False)
        git(run, ["checkout", "--theirs", "--"] + conflicting, cwd=worktree)
        git(run, ["add", "--"] + conflicting, cwd=worktree)
        git(run, ["commit", "-m", COMMITS["advance"]
                  % (ustate["id"], run.goal_branch, " ".join(conflicting))], cwd=worktree)
        git(run, ["update-ref", "refs/heads/" + ustate["integration_branch"], "HEAD"],
            cwd=worktree)
    run.last_results.pop(ustate["id"], None)


def template_sha(run):
    path = os.path.join(run.repo, ".inspire.lock")
    if not os.path.exists(path):
        return "none"
    return read_json(path).get("template_sha") or "none"


def profile_hashes(run, ustate):
    root = os.path.join(run.goal_worktree,
                        run.args.profiles_root or
                        os.path.join(".claude", "skills", "inspire-code", "profiles"))
    pairs = []
    for profile in run.plan_units[ustate["id"]].get("profiles") or []:
        path = os.path.join(root, "%s.md" % profile)
        if not os.path.exists(path):
            continue
        with open(path, "rb") as stream:
            pairs.append("%s=%s" % (profile, hashlib.sha256(stream.read()).hexdigest()[:12]))
    return ",".join(pairs) or "none"
