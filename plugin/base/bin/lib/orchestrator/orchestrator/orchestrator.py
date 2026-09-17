"""The run itself: the shared context every module reads, and the loop over it."""

import concurrent.futures
import contextlib
import datetime
import json
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
from ..constants import CONFIG_PATH, LEDGER_PATH, LOG_PATH, ROLES, RUNS_DIR
from ..errors import Infrastructural, Refusal, Stall
from ..findings import conflict_findings, conflict_role, gate_digest
from ..shells import read_shells
from ..state import State, close_timeline, set_phase
from ..util import ISO, now_iso, read_json, write_json_atomic


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

    def preflight(self):
        """Everything that can refuse before there is a plan to read. Each step
        gates the next, and a refusal leaves nothing spawned."""
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

    def plan_step(self):
        """The plan, and the account opened on it."""
        self.plan = startmod.run_plan(self)
        write_json_atomic(os.path.join(self.run_dir, "plan.json"), self.plan)
        self.open_report()

    def start(self):
        self.preflight()
        self.plan_step()
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
        spend_exhausted = False
        while self.state.data["wave_index"] < len(self.state.data["waves"]):
            index = self.state.data["wave_index"]
            runnable, exhausted = self.open_wave(index)
            spend_exhausted = spend_exhausted or exhausted
            if runnable:
                workers = min(self.args.parallel, len(runnable))
                with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
                    for future in [pool.submit(self.run_unit, unit_id) for unit_id in runnable]:
                        future.result()
            self.close_wave(index, spend_exhausted)
            if spend_exhausted:
                break
        self.finish(self.exit_reason(spend_exhausted))

    def open_wave(self, index):
        """A wave's roster: what is left to run once a promoted, stalled or blocked
        unit is skipped, a unit downstream of one is blocked, and the spend ceiling
        has had its say. The one place that policy is written."""
        # `index` is kept: a resume re-enters a wave, and then two entries share it.
        self.state.data["wave_log"].append({"index": index + 1, "started_at": now_iso(),
                                            "ended_at": None})
        runnable = []
        for unit_id in self.state.data["waves"][index]:
            ustate = self.state.unit(unit_id)
            if ustate["status"] in ("promoted", "stalled", "blocked"):
                continue
            blocker = self.blocked_by(unit_id)
            if blocker:
                self.mark_blocked(ustate, "downstream of %s, which is %s"
                                  % (blocker[0], blocker[1]))
                continue
            runnable.append(unit_id)
        exhausted = bool(self.args.budget_usd and
                         self.state.data["spend_usd"] >= self.args.budget_usd)
        if exhausted:
            for unit_id in runnable:
                self.mark_blocked(self.state.unit(unit_id), "spend ceiling reached")
            runnable = []
        return runnable, exhausted

    def close_wave(self, index, spend_exhausted):
        """The wave's account, and — once the ceiling is reached — every unit no
        later wave will now reach."""
        self.state.data["wave_index"] = index + 1
        self.state.data["wave_log"][-1]["ended_at"] = now_iso()
        self.save()
        self.report.write_block(
            reportmod.wave_block(self, index + 1, self.state.data["waves"][index]),
            "wave %d" % (index + 1))
        if spend_exhausted:
            for later in self.state.data["waves"][index + 1:]:
                for unit_id in later:
                    ustate = self.state.unit(unit_id)
                    if ustate["status"] == "pending":
                        self.mark_blocked(ustate, "spend ceiling reached")

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
        with self.unit_guard(ustate):
            self.open_unit(ustate)
            self.drive_unit(ustate)

    @contextlib.contextmanager
    def unit_guard(self, ustate):
        """A stall or an infrastructural failure ends this unit and no other, and
        whichever way it ends the unit is closed and recorded."""
        try:
            yield
        except Stall as stall:
            self.record_stall(ustate, stall)
        except Infrastructural as failure:
            self.record_stall(ustate, Stall("infrastructural", str(failure)))
        finally:
            # A stall leaves `phase` naming the role it stalled at, so only the
            # timeline is closed here.
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
            set_phase(self, ustate, role)
            handoffmod.handoff(self, ustate, role, [])
            ustate["done"].append(role)
            set_phase(self, ustate, None)
        while True:
            set_phase(self, ustate, "gate")
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
            set_phase(self, ustate, role)
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
        self.state.data["ended_at"] = now_iso()
        self.save()
        self.append_ledger()
        self.report.rewrite_status(exit_reason)
        self.report.write_block(reportmod.closing_block(self, exit_reason), "closing")
        sys.stderr.write("emanation %s ended: %s\n" % (self.run_id, exit_reason))

    def append_ledger(self):
        """One line per ended run in `LEDGER_PATH`: the facts that let
        twenty runs be compared without opening twenty state files. Raw facts,
        no sums — the per-spawn records under the run dir carry the tokens."""
        data = self.state.data
        line = {"run_id": self.run_id, "goal_branch": self.goal_branch,
                "launch_branch": self.launch_branch, "exit": data["exit"],
                "started_at": data["started_at"], "ended_at": data["ended_at"],
                "spend_usd": data["spend_usd"], "spawn_count": data["spawn_count"],
                "waves": data["wave_index"],
                "units": dict((unit_id, {"status": unit["status"],
                                         "rework": unit["rework"]})
                              for unit_id, unit in data["units"].items()),
                "run_dir": os.path.relpath(self.run_dir, self.repo)}
        # ponytail: a plain append; one write() of one line, so a kill mid-append
        # can at worst truncate the last line — a reader skips a line that fails to parse.
        with open(os.path.join(self.repo, LEDGER_PATH), "a") as stream:
            stream.write(json.dumps(line, sort_keys=True) + "\n")

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
        # The one place a run written before these keys existed grows them. The
        # run-id stamp is UTC in its own shape, so it converts to the ISO one.
        data.setdefault("started_at", datetime.datetime.strptime(
            data["stamp"], "%Y%m%d-%H%M%S").strftime(ISO))
        data.setdefault("ended_at", None)
        data.setdefault("wave_log", [])
        for unit in data["units"].values():
            for key, blank in (("started_at", None), ("ended_at", None), ("timeline", [])):
                unit.setdefault(key, blank)
        # Whatever the kill left open is closed now: the real end is unrecoverable,
        # so the entry is marked interrupted rather than charged the downtime.
        if data["wave_log"] and data["wave_log"][-1]["ended_at"] is None:
            data["wave_log"][-1]["ended_at"] = "interrupted"
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
                if unit["timeline"] and unit["timeline"][-1]["ended_at"] is None:
                    unit["timeline"][-1]["ended_at"] = "interrupted"
                unit["phase"] = None  # set_phase would stamp a clock that did not run
                unit["status"] = "pending"
        self.save()

