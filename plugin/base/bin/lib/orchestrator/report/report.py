"""The operator's account: the log file, and the three blocks written into it."""

import glob
import os
import threading
from collections import Counter

from ..constants import LEDGER_PATH, ROLES, TRAILER_ORDER
from ..util import elapsed_seconds, read_json


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
                run.args.ceiling or "*unset*", len(run.state["waves"])),
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
        unit = run.state["units"][unit_id]
        lines += unit_rows(unit)
    lines += ["### Findings", "", "*none recorded by the process*", "",
              "- **frontier after this wave** — %d units"
              % sum(1 for unit in run.state["units"].values()
                    if unit["status"] not in ("promoted", "stalled", "blocked"))]
    return "\n".join(lines)


def unit_rows(unit):
    status = {"promoted": "delivered"}.get(unit["status"], unit["status"])
    trailers = unit["trailers"]
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
        remedy = unit["next_act"] or "read the integration branch, then re-run"
        rows.append("- **stalled or blocked only** — %s: %s. Next act: %s"
                    % (unit["stall_class"] or "blocked",
                       unit["reason"] or "", remedy))
        for item in unit["findings"]:
            rows.append("  - %s · %s — %s" % (item["source"], item["title"],
                                              item["issue"]))
    rows.append("- **graded on** — derived claims")
    rows.append("")
    return rows


def hms(seconds):
    return "%dh %02dm %02ds" % (seconds // 3600, seconds % 3600 // 60, seconds % 60)


def closing_block(run, exit_reason):
    data = run.state
    units = data["units"]
    delivered = [unit for unit in units.values() if unit["status"] == "promoted"]
    stalled = [unit for unit in units.values() if unit["status"] == "stalled"]
    blocked = [unit for unit in units.values() if unit["status"] == "blocked"]
    goal_relative = os.path.relpath(run.goal_worktree, run.repo)
    lines = ["## Report — %s" % exit_reason, "",
             "- **budget answer** — waves actually executed %d, against ceiling %s and "
             "floor %s" % (run.state["wave_index"], run.args.ceiling or "*unset*",
                           run.plan.get("floor")),
             "- **spend** — %.4f USD, a client-side estimate: it is the sum of what each "
             "spawn reported, not a billing figure" % run.state["spend_usd"],
             "- **elapsed** — %s, from %s to %s (a resumed run counts from its first "
             "start, downtime included)"
             % (hms(elapsed_seconds(data["started_at"], data["ended_at"])),
                data["started_at"], data["ended_at"]),
             "- **delivered** — %s"
             % (", ".join("%s (merged)" % unit["id"] for unit in delivered) or "*none*"),
             "- **stalled** — %s"
             % ("; ".join("%s — %s, %s" % (unit["id"], unit["stall_class"],
                                           unit["integration_branch"])
                          for unit in stalled) or "*none*"),
             "- **blocked** — %s"
             % ("; ".join("%s — %s" % (unit["id"], unit["reason"])
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
                                      unit["next_act"] or
                                      "read %s and answer the findings above"
                                      % unit["integration_branch"])
                        for unit in stalled)),
             "- **run dir** — %s" % os.path.relpath(run.run_dir, run.repo)]
    lines += [""] + spend_section(run)
    return "\n".join(lines)


# ------------------------------------------------------------ the spend section
#
# Everything below is computed at write time from the raw records — the
# `spawns/*.json` files and the `timeline` / `wave_log` stamps in state. Nothing
# here is stored back: the JSON stays facts, the report is the only aggregate.

# (label, key in the CLI's `usage`, key in its `modelUsage`)
TOKEN_KEYS = (("in", "input_tokens", "inputTokens"),
              ("out", "output_tokens", "outputTokens"),
              ("cache read", "cache_read_input_tokens", "cacheReadInputTokens"),
              ("cache write", "cache_creation_input_tokens", "cacheCreationInputTokens"))


def tokens_of(usage):
    """A usage object carries one spelling or the other, never both."""
    return Counter(dict((label, int(usage.get(snake) or usage.get(camel) or 0))
                        for label, snake, camel in TOKEN_KEYS))


def tokens_text(tokens):
    if not any(tokens.values()):
        return "*none reported*"
    return " · ".join("%d %s" % (tokens[label], label) for label, _, _ in TOKEN_KEYS)


def spawn_wall(spawn):
    return elapsed_seconds(spawn.get("started_at"), spawn.get("ended_at"))


def blank_row():
    return {"spawns": 0, "cost_usd": 0.0, "turns": 0, "wall": 0, "tokens": Counter()}


def per_key(spawns, key_of):
    """Rows grouped by `key_of(spawn)`: spawns, cost, turns, wall seconds, tokens."""
    rows = {}
    for spawn in spawns:
        row = rows.setdefault(key_of(spawn) or "*run*", blank_row())
        row["spawns"] += 1
        row["cost_usd"] += float(spawn.get("cost_usd") or 0.0)
        row["turns"] += int(spawn.get("num_turns") or 0)
        row["wall"] += spawn_wall(spawn)
        row["tokens"] += tokens_of(spawn.get("usage") or {})
    return rows


def per_model(spawns):
    """{model: row} from each spawn's `modelUsage`, cost included per model."""
    models = {}
    for spawn in spawns:
        for model, usage in (spawn.get("model_usage") or {}).items():
            row = models.setdefault(model, blank_row())
            row["spawns"] += 1
            row["cost_usd"] += float(usage.get("costUSD") or 0.0)
            row["tokens"] += tokens_of(usage)
    return models


def span(started_at, ended_at):
    """`hms` of a stamped span, or the marker a resume left on an interrupted one."""
    return "interrupted" if ended_at == "interrupted" else \
        hms(elapsed_seconds(started_at, ended_at))


def phase_durations(unit):
    """{phase: seconds} over a unit's timeline; a rework of a role adds to its row.
    An interrupted entry adds nothing and is named on its own."""
    out = Counter()
    for entry in unit["timeline"]:
        if entry["ended_at"] == "interrupted":
            out["%s (interrupted)" % entry["phase"]] = 0
        else:
            out[entry["phase"]] += elapsed_seconds(entry["started_at"], entry["ended_at"])
    return out


def spend_section(run):
    spawns = [read_json(path) for path in
              sorted(glob.glob(os.path.join(run.run_dir, "spawns", "*.json")))]
    roles = per_key(spawns, lambda spawn: spawn.get("shell"))
    units = per_key(spawns, lambda spawn: (spawn.get("brief") or {}).get("unit_id"))
    total = sum((row["tokens"] for row in roles.values()), Counter())
    lines = ["### Spend — computed from the run dir, stored nowhere", "",
             "- **tokens** — %s across %d spawns" % (tokens_text(total), len(spawns))]

    models = per_model(spawns)
    if models:
        lines += ["", "**by model**", "", "| model | spawns | tokens | cost USD |",
                  "|---|---|---|---|"]
        lines += ["| %s | %d | %s | %.4f |"
                  % (model, row["spawns"], tokens_text(row["tokens"]), row["cost_usd"])
                  for model, row in sorted(models.items())]

    if roles:
        max_turns = (run.config or {}).get("max_turns")
        lines += ["", "**by role**", "",
                  "| role | spawns | cost USD | turns%s | wall |"
                  % (" (max %d/spawn)" % max_turns if max_turns else ""),
                  "|---|---|---|---|---|"]
        lines += ["| %s | %d | %.4f | %d | %s |"
                  % (role, row["spawns"], row["cost_usd"], row["turns"], hms(row["wall"]))
                  for role, row in sorted(roles.items())]
        if max_turns:
            near = [spawn for spawn in spawns
                    if int(spawn.get("num_turns") or 0) >= 0.9 * max_turns]
            near_text = ", ".join("%s/%s (%d)" % ((spawn.get("brief") or {}).get("unit_id"),
                                                  spawn.get("shell"), spawn.get("num_turns") or 0)
                                  for spawn in near)
            lines += ["", "- **spawns at or above 90%% of max_turns** — %d%s"
                      % (len(near), ": " + near_text if near else "")]

    lines += ["", "**by unit**", "",
              "| unit | status | spawns | cost USD | rework | wall | phases |",
              "|---|---|---|---|---|---|---|"]
    for unit_id, unit in sorted(run.state["units"].items()):
        row = units.get(unit_id) or blank_row()
        rework = ", ".join("%s %d" % (role, n) for role, n in unit["rework"].items() if n) \
            or "none"
        phases = ", ".join(phase if phase.endswith("(interrupted)") else
                           "%s %s" % (phase, hms(seconds))
                           for phase, seconds in phase_durations(unit).items()) or "—"
        lines.append("| %s | %s | %d | %.4f | %s | %s | %s |"
                     % (unit_id, unit["status"], row["spawns"], row["cost_usd"], rework,
                        hms(elapsed_seconds(unit["started_at"], unit["ended_at"])), phases))

    waves = run.state["wave_log"]
    if waves:
        lines += ["", "**by wave**", "", "| wave | wall |", "|---|---|"]
        lines += ["| %d | %s |" % (wave["index"], span(wave["started_at"], wave["ended_at"]))
                  for wave in waves]
    lines += ["", "- **ledger** — one line for this run appended to `%s`" % LEDGER_PATH]
    return lines
