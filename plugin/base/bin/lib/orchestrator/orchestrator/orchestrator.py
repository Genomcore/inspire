"""The run itself: the shared context every module reads, and the loop over it."""

import concurrent.futures
import datetime
import os
import sys
import threading
import uuid

from .. import gate as gatemod
from .. import git as gitmod
from .. import handoff as handoffmod
from .. import report as reportmod
from .. import start as startmod
from ..config import load_config
from ..constants import CONFIG_PATH, LOG_PATH, ROLES, RUNS_DIR
from ..errors import Infrastructural, Refusal, Stall
from ..findings import conflict_findings, conflict_role, gate_digest
from ..shells import read_shells
from ..state import State
from ..util import read_json, write_json_atomic


class Orchestrator:

    def __init__(self, args):
        self.args = args
        self.git_lock = threading.Lock()
        self.spend_lock = threading.Lock()
        self.harness = ""
        self.verify_rounds = {}
        self.last_results = {}
        self.last_verdict = {}
        self.baseline_line = "baseline skipped — nothing planned"
        self.truncated = False
        self.plan_units = {}
        self.shells = {}

    @property
    def overseer_shells(self):
        return [name for name in sorted(self.shells) if name.endswith("-overseer.md")]

    def save(self):
        self.state.save()

    def open_report(self):
        """The account, opened on the goal worktree — the same whether this run is
        starting or resuming."""
        self.report = reportmod.Report(os.path.join(self.goal_worktree, LOG_PATH),
                                       lambda label: gitmod.commit_log(self, label))

    # ---------------------------------------------------------------- t = 0

    def start(self):
        """Everything that can refuse, refuses here. Each step gates the next, and
        a refusal leaves nothing spawned."""
        self.repo = gitmod.repo_root()
        startmod.check_launch_checkout(self)

        self.config = load_config(os.path.join(self.repo, CONFIG_PATH))
        self.bin = self.args.bin or os.environ.get("INSPIRE_BIN") or \
            os.path.join(self.repo, ".inspire", "bin")
        if not os.path.exists(os.path.join(self.bin, "emanate-plan.sh")):
            raise Refusal("no emanate-plan.sh under %s — point --bin (or $INSPIRE_BIN) at "
                          "this project's `.inspire/bin`." % self.bin)

        self.goal_slug = startmod.compute_goal_slug(self)
        self.stamp = datetime.datetime.utcnow().strftime("%Y%m%d-%H%M%S")
        self.run_id = "%s-%s" % (self.stamp, uuid.uuid4().hex[:4])
        self.run_dir = os.path.join(self.repo, RUNS_DIR, self.run_id)
        os.makedirs(os.path.join(self.run_dir, "contracts"), exist_ok=True)
        os.makedirs(os.path.join(self.run_dir, "spawns"), exist_ok=True)

        self.runner = startmod.build_runner(self)
        startmod.open_goal_branch(self)
        self.plan = startmod.run_plan(self)
        write_json_atomic(os.path.join(self.run_dir, "plan.json"), self.plan)

        self.open_report()

        if self.plan.get("realized_all") or not self.plan.get("waves"):
            startmod.new_state(self, [], {})
            startmod.write_identity(self)
            self.finish("goal reached — nothing left to build")
            return

        startmod.check_ceiling(self)
        read_shells(self)
        planned, waves = startmod.select_waves(self)
        units = startmod.derive_units(self, planned, waves)
        startmod.new_state(self, waves, units)
        startmod.baseline(self)
        startmod.write_identity(self)

    # ------------------------------------------------------------ the waves

    def wave_loop(self):
        waves = self.state.data["waves"]
        spend_exhausted = False
        while self.state.data["wave_index"] < len(waves):
            index = self.state.data["wave_index"]
            wave = waves[index]
            runnable = []
            for unit_id in wave:
                ustate = self.state.unit(unit_id)
                if ustate["status"] in ("promoted", "stalled", "blocked"):
                    continue
                blocker = self.blocked_by(unit_id)
                if blocker:
                    self.mark_blocked(ustate, "downstream of %s, which is %s"
                                      % (blocker[0], blocker[1]))
                    continue
                runnable.append(unit_id)
            if self.args.budget_usd and \
                    self.state.data["spend_usd"] >= self.args.budget_usd:
                spend_exhausted = True
                for unit_id in runnable:
                    self.mark_blocked(self.state.unit(unit_id), "spend ceiling reached")
                runnable = []
            if runnable:
                workers = min(self.args.parallel, len(runnable))
                with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
                    for future in [pool.submit(self.run_unit, unit_id) for unit_id in runnable]:
                        future.result()
            self.state.data["wave_index"] = index + 1
            self.save()
            self.report.write_block(reportmod.wave_block(self, index + 1, wave),
                                    "wave %d" % (index + 1))
            if spend_exhausted:
                for later in waves[index + 1:]:
                    for unit_id in later:
                        ustate = self.state.unit(unit_id)
                        if ustate["status"] == "pending":
                            self.mark_blocked(ustate, "spend ceiling reached")
                break
        self.finish(self.exit_reason(spend_exhausted))

    def blocked_by(self, unit_id):
        for edge in self.plan_units[unit_id].get("requires") or []:
            other = self.state.data["units"].get(edge.get("id"))
            if other and other["status"] in ("stalled", "blocked"):
                return (edge["id"], other["status"])
        return None

    def mark_blocked(self, ustate, reason):
        ustate["status"] = "blocked"
        ustate["reason"] = reason
        self.save()

    def exit_reason(self, spend_exhausted):
        units = list(self.state.data["units"].values())
        stalled = [unit for unit in units if unit["status"] == "stalled"]
        blocked = [unit for unit in units if unit["status"] == "blocked"]
        if spend_exhausted:
            return "exhausted — spend ceiling %s USD reached" % self.args.budget_usd
        cascade = [unit for unit in blocked
                   if (unit["reason"] or "").startswith("downstream of")]
        if stalled and cascade:
            return "stall cascade"
        if stalled:
            return "goal not reached — stalled units"
        if self.truncated:
            return "exhausted — ceiling %d reached" % self.args.ceiling
        return "goal reached"

    # ------------------------------------------------------------- one unit

    def run_unit(self, unit_id):
        ustate = self.state.unit(unit_id)
        try:
            self.open_unit(ustate)
            self.drive_unit(ustate)
        except Stall as stall:
            self.record_stall(ustate, stall)
        except Infrastructural as failure:
            self.record_stall(ustate, Stall("infrastructural", str(failure)))

    def open_unit(self, ustate):
        ustate["status"] = "in-phase"
        branch = ustate["integration_branch"] or gitmod.integration_branch(self,
                                                                          ustate["slug"])
        ustate["integration_branch"] = branch
        if gitmod.git(self, ["rev-parse", "--verify", "--quiet", "refs/heads/" + branch],
                      check=False).returncode != 0:
            gitmod.git_write(self, ["branch", branch, self.goal_branch])
        # Recorded only once the recipe has run in it: a tree killed mid-provision
        # is cut again on a resume rather than reused half-built.
        if not ustate["verify_worktree"]:
            worktree = gitmod.fresh_worktree(self, ustate["slug"], "verify", branch)
            handoffmod.run_recipe(self, worktree)
            ustate["verify_worktree"] = worktree
        self.save()

    def drive_unit(self, ustate):
        for role in ROLES:
            if role in ustate["done"]:
                continue
            ustate["phase"] = role
            self.save()
            handoffmod.handoff(self, ustate, role, [])
            ustate["done"].append(role)
            ustate["phase"] = None
            self.save()
        while True:
            ustate["phase"] = "gate"
            self.save()
            verdict = gatemod.gate_loop(self, ustate)
            ustate["gate_digest"] = gate_digest(verdict)
            self.save()
            gatemod.drill(self, ustate)
            conflicting = gitmod.promote(self, ustate, verdict)
            if not conflicting:
                return
            # A sibling promoted first onto a path this unit also wrote. One more
            # edge back to the persona that owns the path, inside its rework
            # budget, and the whole boundary — overseers, gate, promote — again.
            gitmod.advance_onto_goal(self, ustate, conflicting)
            role = conflict_role(self.config["tests_roots"], conflicting)
            findings = conflict_findings(ustate, conflicting)
            handoffmod.spend_rework(self, ustate, role, findings, "promote")
            handoffmod.handoff(self, ustate, role, findings)

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

    # ------------------------------------------------------------ the report

    def finish(self, exit_reason):
        self.state.data["status"] = "ENDED"
        self.state.data["exit"] = exit_reason
        self.save()
        self.report.rewrite_status(exit_reason)
        self.report.write_block(reportmod.closing_block(self, exit_reason), "closing")
        sys.stderr.write("emanation %s ended: %s\n" % (self.run_id, exit_reason))

    # ------------------------------------------------------------- resuming

    def resume(self):
        """A killed run is resumed against its own state: the phase that was in
        flight counts as an infrastructural ending — nobody judged it — and a unit
        past its personas re-enters at verify and the gate."""
        self.repo = gitmod.repo_root()
        self.run_dir = os.path.join(self.repo, RUNS_DIR, self.args.run_id)
        state_path = os.path.join(self.run_dir, "state.json")
        if not os.path.exists(state_path):
            raise Refusal("no run %s under %s." % (self.args.run_id, RUNS_DIR))
        self.state = State(state_path, read_json(state_path))
        data = self.state.data
        if data["status"] == "ENDED":
            raise Refusal("run %s already ended: %s. Start a new run toward the same goal."
                          % (self.args.run_id, data["exit"]))
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
        for unit in data["units"].values():
            if unit["status"] == "in-phase":
                phase = unit["phase"]
                if phase in ROLES:
                    unit["infra_retries"][phase] += 1
                unit["phase"] = None
                unit["status"] = "pending"
        self.save()
