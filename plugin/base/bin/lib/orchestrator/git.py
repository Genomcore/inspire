"""Git, serialized: every write to a ref, a worktree or a commit — and the paths
this run derives from them."""

import hashlib
import os
import subprocess

from .constants import LOG_PATH, TRAILER_ORDER, WORKTREES_DIR
from .errors import Internal, Refusal, Stall
from .findings import gate_digest
from .util import read_json, tail


def repo_root():
    proc = subprocess.run(["git", "rev-parse", "--show-toplevel"], text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise Refusal("not a git repository — this loop's whole audit trail is git.")
    return proc.stdout.strip()


def git(run, arguments, cwd=None, check=True):
    proc = subprocess.run(["git"] + arguments, cwd=cwd or run.repo, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and proc.returncode != 0:
        raise Internal("git %s failed: %s" % (" ".join(arguments), tail(proc.stderr, 600)))
    return proc


def git_write(run, arguments, cwd=None, check=True):
    with run.git_lock:
        return git(run, arguments, cwd=cwd, check=check)


def commit_log(run, label):
    message = "emanate(log): %s — %s" % (run.run_id, label)
    with run.git_lock:
        # -f: the process chose this path, so a project-wide `*.log` rule is
        # not the operator declining it.
        git(run, ["add", "-f", LOG_PATH], cwd=run.goal_worktree)
        git(run, ["commit", "-m", message], cwd=run.goal_worktree)


# ---- paths ----

def contract_path(run, unit_id):
    return os.path.join(run.run_dir, "contracts", "%s.json" % unit_id)


def phase_worktree(run, unit_slug, phase):
    return os.path.join(run.repo, WORKTREES_DIR, "emanate-%s-%s-%s-%s"
                        % (run.goal_slug, unit_slug, run.stamp, phase))


def fresh_worktree(run, unit_slug, phase, ref):
    """A phase worktree at `ref`, cut anew: a tree left behind by a killed run is
    discarded rather than reused half-built."""
    worktree = phase_worktree(run, unit_slug, phase)
    if os.path.exists(worktree):
        discard(run, worktree)
    git_write(run, ["worktree", "add", "--detach", worktree, ref])
    return worktree


def integration_branch(run, unit_slug):
    return "emanate/%s-%s-%s" % (run.goal_slug, unit_slug, run.stamp)


def owned_pathspec(run, role):
    if role == "tester":
        return list(run.config["tests_roots"])
    return list(run.config["source_roots"]) + \
        [":(exclude)%s" % root for root in run.config["tests_roots"]]


def tip(run, ustate):
    return git(run, ["rev-parse", ustate["integration_branch"]]).stdout.strip()


def discard(run, worktree):
    git_write(run, ["worktree", "remove", "--force", worktree], check=False)


def run_harvest(run, ustate, role, worktree, extra):
    command = [os.path.join(run.bin, "emanate-harvest.sh"), worktree,
               ustate["integration_branch"], "--label", role] + extra + \
        ["--"] + owned_pathspec(run, role)
    return subprocess.run(command, cwd=run.repo, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


# ---- promote ----

def promote(run, ustate, verdict):
    trailers = {"Emanate-Run": run.run_id, "Emanate-Unit": ustate["id"],
                "Emanate-Template-Sha": template_sha(run),
                "Emanate-Profiles": profile_hashes(run, ustate),
                "Emanate-Gate": gate_digest(verdict),
                "Emanate-Harness": run.harness}
    message = "emanate: promote %s\n\n%s\n" % (
        ustate["id"], "\n".join("%s: %s" % (key, trailers[key]) for key in TRAILER_ORDER))
    with run.git_lock:
        merge = git(run, ["merge", "--no-ff", "-m", message, ustate["integration_branch"]],
                    cwd=run.goal_worktree, check=False)
        if merge.returncode != 0:
            git(run, ["merge", "--abort"], cwd=run.goal_worktree, check=False)
            raise Stall("promote conflict",
                        "%s does not merge into %s: %s"
                        % (ustate["integration_branch"], run.goal_branch,
                           tail(merge.stdout + merge.stderr, 600)))
        git(run, ["branch", "-d", ustate["integration_branch"]], cwd=run.goal_worktree)
    discard(run, ustate["verify_worktree"])
    ustate["verify_worktree"] = None
    ustate["trailers"] = trailers
    ustate["status"] = "promoted"
    ustate["phase"] = None
    run.save()


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
