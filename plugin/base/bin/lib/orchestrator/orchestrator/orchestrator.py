import contextlib
import datetime
import json
import os
import sys
import threading
import uuid

from .. import git as gitmod
from .. import handoff as handoffmod
from .. import report as reportmod
from .. import start as startmod
from ..config import load_config
from ..constants import CONFIG_PATH, LEDGER_PATH, LOG_PATH, RUNS_DIR
from ..errors import Infrastructural, Refusal, Stall
from ..state import close_timeline, reconcile
from ..util import now_iso, read_json, write_json_atomic

BASELINE_SKIPPED_NOTHING_PLANNED = "baseline skipped — nothing planned"

REFUSALS = {
    "no-plan-script": "no emanate-plan.sh under %s — point --bin (or $INSPIRE_BIN) at "
                      "this project's `.inspire/bin`.",
    "no-run": "no run %s under %s.",
    "run-ended": "run %s already ended: %s. Start a new run toward the same goal.",
}

BLOCKED_DOWNSTREAM_PREFIX = "downstream of"
BLOCKED = {
    "downstream": BLOCKED_DOWNSTREAM_PREFIX + " %s, which is %s",
    "spend-ceiling": "spend ceiling reached",
}

EXIT_REASONS = {
    "spend-exhausted": "exhausted — spend ceiling %s USD reached",
    "stall-cascade": "stall cascade",
    "stalled": "goal not reached — stalled units",
    "ceiling-exhausted": "exhausted — ceiling %d reached",
    "reached": "goal reached",
}

WAVE_LABEL = "wave %d"
ENDED_LINE = "emanation %s ended: %s\n"


class Orchestrator:

    def __init__(self, args):
        self.args = args
        self.git_lock = threading.Lock()
        self.state_lock = threading.Lock()
        self.spend_lock = threading.Lock()
        self.harness = ""
        self.verify_rounds = {}
        self.last_results = {}
        self.last_verdict = {}
        self.baseline_line = BASELINE_SKIPPED_NOTHING_PLANNED
        self.probe_line = startmod.PROBE_MESSAGES["none"]
        self.truncated = False
        self.plan_units = {}
        self.shells = {}

    @property
    def overseer_shells(self):
        return [name for name in sorted(self.shells) if name.endswith("-overseer.md")]

    def save(self):
        with self.state_lock:
            write_json_atomic(self.state_path, self.state)

    def open_report(self):
        self.report = reportmod.Report(os.path.join(self.goal_worktree, LOG_PATH),
                                       lambda label: gitmod.commit_log(self, label))

    def preflight(self):
        self.repo = gitmod.repo_root()
        startmod.check_launch_checkout(self)

        self.config = load_config(os.path.join(self.repo, CONFIG_PATH))
        self.bin = self.args.bin or os.environ.get("INSPIRE_BIN") or \
            os.path.join(self.repo, ".inspire", "bin")
        if not os.path.exists(os.path.join(self.bin, "emanate-plan.sh")):
            raise Refusal(REFUSALS["no-plan-script"] % self.bin)

        self.goal_slug = startmod.compute_goal_slug(self)
        self.stamp = datetime.datetime.utcnow().strftime("%Y%m%d-%H%M%S")
        self.run_id = "%s-%s" % (self.stamp, uuid.uuid4().hex[:4])
        self.run_dir = os.path.join(self.repo, RUNS_DIR, self.run_id)
        os.makedirs(os.path.join(self.run_dir, "contracts"), exist_ok=True)
        os.makedirs(os.path.join(self.run_dir, "spawns"), exist_ok=True)

        self.runner = startmod.build_runner(self)
        startmod.open_goal_branch(self)

    def plan_step(self):
        self.plan = startmod.run_plan(self)
        write_json_atomic(os.path.join(self.run_dir, "plan.json"), self.plan)
        self.open_report()

    def open_wave(self, index):
        self.state["wave_log"].append({"index": index + 1, "started_at": now_iso(),
                                       "ended_at": None})
        runnable = []
        for unit_id in self.state["waves"][index]:
            ustate = self.state["units"][unit_id]
            if ustate["status"] in ("promoted", "stalled", "blocked"):
                continue
            blocker = self.blocked_by(unit_id)
            if blocker:
                self.mark_blocked(ustate, BLOCKED["downstream"] % (blocker[0], blocker[1]))
                continue
            runnable.append(unit_id)
        exhausted = bool(self.args.budget_usd and
                         self.state["spend_usd"] >= self.args.budget_usd)
        if exhausted:
            for unit_id in runnable:
                self.mark_blocked(self.state["units"][unit_id], BLOCKED["spend-ceiling"])
            runnable = []
        return runnable, exhausted

    def close_wave(self, index, spend_exhausted):
        self.state["wave_index"] = index + 1
        self.state["wave_log"][-1]["ended_at"] = now_iso()
        self.save()
        self.report.write_block(
            reportmod.wave_block(self, index + 1, self.state["waves"][index]),
            WAVE_LABEL % (index + 1))
        if spend_exhausted:
            for later in self.state["waves"][index + 1:]:
                for unit_id in later:
                    ustate = self.state["units"][unit_id]
                    if ustate["status"] == "pending":
                        self.mark_blocked(ustate, BLOCKED["spend-ceiling"])

    def blocked_by(self, unit_id):
        for edge in self.plan_units[unit_id].get("requires") or []:
            other = self.state["units"].get(edge.get("id"))
            if other and other["status"] in ("stalled", "blocked"):
                return (edge["id"], other["status"])
        return None

    def mark_blocked(self, ustate, reason):
        ustate["status"] = "blocked"
        ustate["reason"] = reason
        self.save()

    def exit_reason(self, spend_exhausted):
        units = list(self.state["units"].values())
        stalled = [unit for unit in units if unit["status"] == "stalled"]
        blocked = [unit for unit in units if unit["status"] == "blocked"]
        if spend_exhausted:
            return EXIT_REASONS["spend-exhausted"] % self.args.budget_usd
        cascade = [unit for unit in blocked
                   if (unit["reason"] or "").startswith(BLOCKED_DOWNSTREAM_PREFIX)]
        if stalled and cascade:
            return EXIT_REASONS["stall-cascade"]
        if stalled:
            return EXIT_REASONS["stalled"]
        if self.truncated:
            return EXIT_REASONS["ceiling-exhausted"] % self.args.ceiling
        return EXIT_REASONS["reached"]

    @contextlib.contextmanager
    def unit_guard(self, ustate):
        try:
            yield
        except Stall as stall:
            self.record_stall(ustate, stall)
        except Infrastructural as failure:
            self.record_stall(ustate, Stall("infrastructural", str(failure)))
        finally:
            close_timeline(ustate)
            ustate["ended_at"] = now_iso()
            self.save()

    def open_unit(self, ustate):
        ustate["status"] = "in-phase"
        ustate["started_at"] = ustate["started_at"] or now_iso()
        branch = ustate["integration_branch"] or gitmod.integration_branch(self,
                                                                          ustate["slug"])
        ustate["integration_branch"] = branch
        if gitmod.git(self, ["rev-parse", "--verify", "--quiet", "refs/heads/" + branch],
                      check=False).returncode != 0:
            gitmod.git_write(self, ["branch", branch, self.goal_branch])
        if not ustate["verify_worktree"]:
            worktree = gitmod.fresh_worktree(self, ustate["slug"], "verify", branch)
            handoffmod.run_recipe(self, worktree)
            ustate["verify_worktree"] = worktree
        self.save()

    def record_stall(self, ustate, stall):
        ustate["status"] = "stalled"
        ustate["stall_class"] = stall.unit_class
        ustate["reason"] = str(stall)
        ustate["findings"] = stall.findings or ustate["findings"]
        ustate["next_act"] = stall.next_act
        if ustate["verify_worktree"]:
            gitmod.discard(self, ustate["verify_worktree"])
            ustate["verify_worktree"] = None
        self.save()

    def finish(self, exit_reason):
        self.state["status"] = "ENDED"
        self.state["exit"] = exit_reason
        self.state["ended_at"] = now_iso()
        self.save()
        self.append_ledger()
        self.report.rewrite_status(exit_reason)
        self.report.write_block(reportmod.closing_block(self, exit_reason), "closing")
        sys.stderr.write(ENDED_LINE % (self.run_id, exit_reason))

    def append_ledger(self):
        data = self.state
        line = {"run_id": self.run_id, "goal_branch": self.goal_branch,
                "launch_branch": self.launch_branch, "exit": data["exit"],
                "started_at": data["started_at"], "ended_at": data["ended_at"],
                "spend_usd": data["spend_usd"], "spawn_count": data["spawn_count"],
                "waves": data["wave_index"],
                "units": dict((unit_id, {"status": unit["status"],
                                         "rework": unit["rework"]})
                              for unit_id, unit in data["units"].items()),
                "run_dir": os.path.relpath(self.run_dir, self.repo)}
        with open(os.path.join(self.repo, LEDGER_PATH), "a") as stream:
            stream.write(json.dumps(line, sort_keys=True) + "\n")

    def resume(self):
        self.repo = gitmod.repo_root()
        self.run_dir = os.path.join(self.repo, RUNS_DIR, self.args.run_id)
        state_path = os.path.join(self.run_dir, "state.json")
        if not os.path.exists(state_path):
            raise Refusal(REFUSALS["no-run"] % (self.args.run_id, RUNS_DIR))
        self.state_path = state_path
        self.state = read_json(state_path)
        data = self.state
        reconcile(data)
        if data["status"] == "ENDED":
            raise Refusal(REFUSALS["run-ended"] % (self.args.run_id, data["exit"]))
        self.config = data["config"]
        self.bin = self.args.bin or data["bin"]
        self.run_id = data["run_id"]
        self.stamp = data["stamp"]
        self.launch_branch = data["launch_branch"]
        self.goal_branch = data["goal_branch"]
        self.goal_worktree = data["goal_worktree"]
        self.goal_slug = self.goal_branch.split("/", 1)[1]
        self.cut_here = data["cut_here"]
        self.shells = data["shells"]
        self.plan_units = data["plan_units"]
        self.plan = read_json(os.path.join(self.run_dir, "plan.json"))
        self.truncated = data["truncated"]
        for key, value in data["args"].items():
            if getattr(self.args, key, None) in (None, [], 0):
                setattr(self.args, key, value)
        self.runner = startmod.build_runner(self)
        self.open_report()
        self.save()

