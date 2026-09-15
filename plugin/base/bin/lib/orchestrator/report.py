"""The operator's account: the log file, and the three blocks written into it."""

import os
import threading

from .constants import ROLES, TRAILER_ORDER


class Report:
    """`report-skeleton.md` filled, never composed: an identity block at t=0, one
    block as each wave closes, one closing block at the exit. Each is committed on
    the goal branch as it is written, so the account travels with the work."""

    def __init__(self, path, commit):
        self.path = path
        self.commit = commit
        self.lock = threading.Lock()

    def write_block(self, block, label):
        with self.lock:
            with open(self.path, "a") as stream:
                stream.write(block.rstrip() + "\n\n")
            self.commit(label)

    def truncate(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, "w"):
            pass

    def rewrite_status(self, status):
        """`status` is the one line this file corrects in place — the worked example
        of the skeleton's own "the last position wins"."""
        with self.lock:
            with open(self.path) as stream:
                text = stream.read()
            text = text.replace("- **status** — RUNNING", "- **status** — %s" % status, 1)
            with open(self.path, "w") as stream:
                stream.write(text)


def identity_block(run):
    plan = run.plan
    goal = plan.get("goal") or {}
    warnings = [row for row in plan.get("findings") or []
                if row.get("severity") == "warning"]
    preflight = plan.get("preflight") or {}
    components = ", ".join(item.get("name", "") for item in
                           preflight.get("components") or []) or "*none declared*"
    lines = ["# Emanation run %s" % run.run_id, "",
             "- **launch branch** — %s" % run.launch_branch,
             "- **goal branch** — %s, %s" % (run.goal_branch,
                                             "cut here" if run.cut_here
                                             else "advanced from an earlier run"),
             "- **goal worktree** — %s" % os.path.relpath(run.goal_worktree, run.repo),
             "- **scope** — %s" % (", ".join(run.args.scope) or "*none*"),
             "- **goal** — %s" % (run.args.goal or "*none*"),
             "- **selectors** — %s" % (", ".join(run.args.reemanate) or "*none*"),
             "- **budget** — floor %s · effective floor %s · declared ceiling %s · "
             "waves permitted %s"
             % (plan.get("floor"), goal.get("floor", plan.get("floor")),
                run.args.ceiling or "*unset*", len(run.state.data["waves"])),
             "- **preflight** — components: %s, declared, not probed by this process; "
             "%s" % (components, run.baseline_line),
             "- **harness** — %s" % run.harness,
             "- **warnings** — %s"
             % ("; ".join("%s: %s" % (row.get("code"), row.get("message"))
                          for row in warnings) or "*none*"),
             "- **status** — RUNNING"]
    return "\n".join(lines)


def wave_block(run, number, wave):
    lines = ["## Wave %d — closed" % number, ""]
    for unit_id in wave:
        unit = run.state.unit(unit_id)
        lines += unit_rows(unit)
    lines += ["### Findings", "", "*none recorded by the process*", "",
              "- **frontier after this wave** — %d units" % frontier(run)]
    return "\n".join(lines)


def unit_rows(unit):
    status = {"promoted": "delivered"}.get(unit["status"], unit["status"])
    trailers = unit.get("trailers") or {}
    rows = ["### %s — %s" % (unit["id"], status), ""]
    rows.append("- **integration branch** — %s"
                % (unit["integration_branch"] if unit["status"] != "promoted"
                   else "merged"))
    rows.append("- **gate verdict** — %s" % (unit["gate_digest"] or "*not reached*"))
    rows.append("- **rework cycles** — %s · **infrastructural retries** — %s"
                % (" · ".join("%s %d" % (role, unit["rework"][role]) for role in ROLES),
                   " · ".join("%s %d" % (role, unit["infra_retries"][role])
                              for role in ROLES)))
    rows.append("- **harvest dropped** — %s"
                % (", ".join(unit["dropped"]) or "*nothing dropped*"))
    rows.append("- **drill** — %s" % (unit["drill"] or "*not reached*"))
    rows.append("- **verify, did not halt** — %s"
                % ("; ".join(unit["verify_findings"]) or "*none*"))
    rows.append("- **promote trailers** — %s"
                % ("; ".join("%s %s" % (key, trailers[key]) for key in TRAILER_ORDER
                             if key in trailers) or "*none — not promoted*"))
    if unit["status"] in ("stalled", "blocked"):
        remedy = unit.get("next_act") or "read the integration branch, then re-run"
        rows.append("- **stalled or blocked only** — %s: %s. Next act: %s"
                    % (unit.get("stall_class") or "blocked",
                       unit.get("reason") or "", remedy))
        for item in unit.get("findings") or []:
            rows.append("  - %s · %s — %s" % (item.get("source"), item.get("title"),
                                              item.get("issue")))
    rows.append("- **graded on** — %s" % unit["graded_on"])
    rows.append("")
    return rows


def frontier(run):
    return sum(1 for unit in run.state.data["units"].values()
               if unit["status"] not in ("promoted", "stalled", "blocked"))


def closing_block(run, exit_reason):
    units = run.state.data["units"]
    delivered = [unit for unit in units.values() if unit["status"] == "promoted"]
    stalled = [unit for unit in units.values() if unit["status"] == "stalled"]
    blocked = [unit for unit in units.values() if unit["status"] == "blocked"]
    goal_relative = os.path.relpath(run.goal_worktree, run.repo)
    lines = ["## Report — %s" % exit_reason, "",
             "- **budget answer** — waves actually executed %d, against ceiling %s and "
             "floor %s" % (run.state.data["wave_index"], run.args.ceiling or "*unset*",
                           run.plan.get("floor")),
             "- **spend** — %.4f USD, a client-side estimate: it is the sum of what each "
             "spawn reported, not a billing figure" % run.state.data["spend_usd"],
             "- **delivered** — %s"
             % (", ".join("%s (merged)" % unit["id"] for unit in delivered) or "*none*"),
             "- **stalled** — %s"
             % ("; ".join("%s — %s, %s" % (unit["id"], unit.get("stall_class"),
                                           unit["integration_branch"])
                          for unit in stalled) or "*none*"),
             "- **blocked** — %s"
             % ("; ".join("%s — %s" % (unit["id"], unit.get("reason"))
                          for unit in blocked) or "*none*"),
             "- **worktrees still on disk** — the goal worktree `%s`" % goal_relative,
             "- **pre-PR** — the rules verify did not run "
             "(`profile-gates-installed.sh`, `adr-maturity-matches-features.sh`) and "
             "`criteria-have-tests.sh`'s 🟡 limitation",
             "- **where the work is** — the goal branch `%s`, its worktree `%s`; "
             "`git -C %s log --oneline %s..` shows the effort and "
             "`git -C %s diff --stat %s` its shape. The launch checkout was never moved "
             "and never written."
             % (run.goal_branch, goal_relative, goal_relative, run.launch_branch,
                goal_relative, run.launch_branch),
             "- **next act** — open the PR from the goal branch `%s`%s"
             % (run.goal_branch,
                "".join("; %s: %s" % (unit["id"],
                                      unit.get("next_act") or
                                      "read %s and answer the findings above"
                                      % unit["integration_branch"])
                        for unit in stalled)),
             "- **run dir** — %s" % os.path.relpath(run.run_dir, run.repo)]
    return "\n".join(lines)
