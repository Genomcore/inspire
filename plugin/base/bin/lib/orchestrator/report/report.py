import glob
import os
import threading
from collections import Counter

from ..constants import LEDGER_PATH, ROLES, TRAILER_ORDER
from ..util import elapsed_seconds, read_json

STATUS_ROW = "- **status** — %s"
STATUS_RUNNING = "RUNNING"

NONE = "*none*"
NONE_DECLARED = "*none declared*"
NONE_REPORTED = "*none reported*"
NOT_PROMOTED = "*none — not promoted*"
NOT_REACHED = "*not reached*"
NOTHING_DROPPED = "*nothing dropped*"
UNSET = "*unset*"
UNKEYED = "*run*"
NO_REWORK = "none"
NO_PHASES = "—"
MERGED = "merged"
DELIVERED = "delivered"

HMS = "%dh %02dm %02ds"
INTERRUPTED_PHASE = "%s (interrupted)"

IDENTITY = {
    "title": "# Emanation run %s",
    "launch_branch": "- **launch branch** — %s",
    "goal_branch": "- **goal branch** — %s, %s",
    "cut_here": "cut here",
    "advanced": "advanced from an earlier run",
    "goal_worktree": "- **goal worktree** — %s",
    "scope": "- **scope** — %s",
    "goal": "- **goal** — %s",
    "selectors": "- **selectors** — %s",
    "budget": "- **budget** — floor %s · effective floor %s · declared ceiling %s · "
              "waves permitted %s",
    "preflight": "- **preflight** — components: %s, declared, not probed by this process; %s",
    "harness": "- **harness** — %s",
    "warnings": "- **warnings** — %s",
}

WAVE = {
    "title": "## Wave %d — closed",
    "findings": "### Findings",
    "no_findings": "*none recorded by the process*",
    "frontier": "- **frontier after this wave** — %d units",
}

UNIT = {
    "title": "### %s — %s",
    "integration_branch": "- **integration branch** — %s",
    "gate_verdict": "- **gate verdict** — %s",
    "rework": "- **rework cycles** — %s · **infrastructural retries** — %s",
    "dropped": "- **harvest dropped** — %s",
    "drill": "- **drill** — %s",
    "verify": "- **verify, did not halt** — %s",
    "trailers": "- **promote trailers** — %s",
    "stall": "- **stalled or blocked only** — %s: %s. Next act: %s",
    "stall_remedy": "read the integration branch, then re-run",
    "finding": "  - %s · %s — %s",
    "graded": "- **graded on** — derived claims",
}

CLOSING = {
    "title": "## Report — %s",
    "budget": "- **budget answer** — waves actually executed %d, against ceiling %s and "
              "floor %s",
    "spend": "- **spend** — %.4f USD, a client-side estimate: it is the sum of what each "
             "spawn reported, not a billing figure",
    "elapsed": "- **elapsed** — %s, from %s to %s (a resumed run counts from its first "
               "start, downtime included)",
    "delivered": "- **delivered** — %s",
    "delivered_unit": "%s (merged)",
    "stalled": "- **stalled** — %s",
    "stalled_unit": "%s — %s, %s",
    "blocked": "- **blocked** — %s",
    "blocked_unit": "%s — %s",
    "worktrees": "- **worktrees still on disk** — the goal worktree `%s`",
    "pre_pr": "- **pre-PR** — the rules verify did not run "
              "(`profile-gates-installed.sh`, `adr-maturity-matches-features.sh`) and "
              "`criteria-have-tests.sh`'s 🟡 limitation",
    "where": "- **where the work is** — the goal branch `%s`, its worktree `%s`; "
             "`git -C %s log --oneline %s..` shows the effort and "
             "`git -C %s diff --stat %s` its shape. The launch checkout was never moved "
             "and never written.",
    "next_act": "- **next act** — open the PR from the goal branch `%s`%s",
    "next_act_unit": "; %s: %s",
    "next_act_remedy": "read %s and answer the findings above",
    "run_dir": "- **run dir** — %s",
}

SPEND = {
    "title": "### Spend — computed from the run dir, stored nowhere",
    "tokens": "- **tokens** — %s across %d spawns",
    "token_count": "%d %s",
    "by_model": "**by model**",
    "model_header": ("| model | spawns | tokens | cost USD |", "|---|---|---|---|"),
    "model_row": "| %s | %d | %s | %.4f |",
    "by_role": "**by role**",
    "role_header": ("| role | spawns | cost USD | turns%s | wall |", "|---|---|---|---|---|"),
    "max_turns": " (max %d/spawn)",
    "role_row": "| %s | %d | %.4f | %d | %s |",
    "near_max": "- **spawns at or above 90%% of max_turns** — %d%s",
    "near_spawn": "%s/%s (%d)",
    "by_unit": "**by unit**",
    "unit_header": ("| unit | status | spawns | cost USD | rework | wall | phases |",
                    "|---|---|---|---|---|---|---|"),
    "unit_row": "| %s | %s | %d | %.4f | %s | %s | %s |",
    "by_wave": "**by wave**",
    "wave_header": ("| wave | wall |", "|---|---|"),
    "wave_row": "| %d | %s |",
    "ledger": "- **ledger** — one line for this run appended to `%s`",
}


class Report:

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
        with self.lock:
            with open(self.path) as stream:
                text = stream.read()
            text = text.replace(STATUS_ROW % STATUS_RUNNING, STATUS_ROW % status, 1)
            with open(self.path, "w") as stream:
                stream.write(text)


def identity_block(run):
    plan = run.plan
    goal = plan.get("goal") or {}
    warnings = [row for row in plan.get("findings") or []
                if row.get("severity") == "warning"]
    preflight = plan.get("preflight") or {}
    components = ", ".join(item.get("name", "") for item in
                        preflight.get("components") or []) or NONE_DECLARED
    lines = [IDENTITY["title"] % run.run_id, "",
             IDENTITY["launch_branch"] % run.launch_branch,
             IDENTITY["goal_branch"] % (run.goal_branch,
                                        IDENTITY["cut_here"] if run.cut_here
                                        else IDENTITY["advanced"]),
             IDENTITY["goal_worktree"] % os.path.relpath(run.goal_worktree, run.repo),
             IDENTITY["scope"] % (", ".join(run.args.scope) or NONE),
             IDENTITY["goal"] % (run.args.goal or NONE),
             IDENTITY["selectors"] % (", ".join(run.args.reemanate) or NONE),
             IDENTITY["budget"]
             % (plan.get("floor"), goal.get("floor", plan.get("floor")),
                run.args.ceiling or UNSET, len(run.state["waves"])),
             IDENTITY["preflight"] % (components, run.baseline_line),
             IDENTITY["harness"] % run.harness,
             IDENTITY["warnings"]
             % ("; ".join("%s: %s" % (row.get("code"), row.get("message"))
                       for row in warnings) or NONE),
             STATUS_ROW % STATUS_RUNNING]
    return "\n".join(lines)


def wave_block(run, number, wave):
    lines = [WAVE["title"] % number, ""]
    for unit_id in wave:
        unit = run.state["units"][unit_id]
        lines += unit_rows(unit)
    lines += [WAVE["findings"], "", WAVE["no_findings"], "",
              WAVE["frontier"]
              % sum(1 for unit in run.state["units"].values()
                    if unit["status"] not in ("promoted", "stalled", "blocked"))]
    return "\n".join(lines)


def unit_rows(unit):
    status = {"promoted": DELIVERED}.get(unit["status"], unit["status"])
    trailers = unit["trailers"]
    rows = [UNIT["title"] % (unit["id"], status), ""]
    rows.append(UNIT["integration_branch"]
                % (unit["integration_branch"] if unit["status"] != "promoted"
                   else MERGED))
    rows.append(UNIT["gate_verdict"] % (unit["gate_digest"] or NOT_REACHED))
    rows.append(UNIT["rework"]
                % (" · ".join("%s %d" % (role, unit["rework"][role]) for role in ROLES),
                   " · ".join("%s %d" % (role, unit["infra_retries"][role])
                          for role in ROLES)))
    rows.append(UNIT["dropped"] % (", ".join(unit["dropped"]) or NOTHING_DROPPED))
    rows.append(UNIT["drill"] % (unit["drill"] or NOT_REACHED))
    rows.append(UNIT["verify"] % ("; ".join(unit["verify_findings"]) or NONE))
    rows.append(UNIT["trailers"]
                % ("; ".join("%s %s" % (key, trailers[key]) for key in TRAILER_ORDER
                          if key in trailers) or NOT_PROMOTED))
    if unit["status"] in ("stalled", "blocked"):
        remedy = unit["next_act"] or UNIT["stall_remedy"]
        rows.append(UNIT["stall"]
                    % (unit["stall_class"] or "blocked",
                       unit["reason"] or "", remedy))
        for item in unit["findings"]:
            rows.append(UNIT["finding"] % (item["source"], item["title"], item["issue"]))
    rows.append(UNIT["graded"])
    rows.append("")
    return rows


def hms(seconds):
    return HMS % (seconds // 3600, seconds % 3600 // 60, seconds % 60)


def closing_block(run, exit_reason):
    data = run.state
    units = data["units"]
    delivered = [unit for unit in units.values() if unit["status"] == "promoted"]
    stalled = [unit for unit in units.values() if unit["status"] == "stalled"]
    blocked = [unit for unit in units.values() if unit["status"] == "blocked"]
    goal_relative = os.path.relpath(run.goal_worktree, run.repo)
    lines = [CLOSING["title"] % exit_reason, "",
             CLOSING["budget"] % (run.state["wave_index"], run.args.ceiling or UNSET,
                                  run.plan.get("floor")),
             CLOSING["spend"] % run.state["spend_usd"],
             CLOSING["elapsed"]
             % (hms(elapsed_seconds(data["started_at"], data["ended_at"])),
                data["started_at"], data["ended_at"]),
             CLOSING["delivered"]
             % (", ".join(CLOSING["delivered_unit"] % unit["id"] for unit in delivered) or NONE),
             CLOSING["stalled"]
             % ("; ".join(CLOSING["stalled_unit"] % (unit["id"], unit["stall_class"],
                                                  unit["integration_branch"])
                       for unit in stalled) or NONE),
             CLOSING["blocked"]
             % ("; ".join(CLOSING["blocked_unit"] % (unit["id"], unit["reason"])
                       for unit in blocked) or NONE),
             CLOSING["worktrees"] % goal_relative,
             CLOSING["pre_pr"],
             CLOSING["where"]
             % (run.goal_branch, goal_relative, goal_relative, run.launch_branch,
                goal_relative, run.launch_branch),
             CLOSING["next_act"]
             % (run.goal_branch,
                "".join(CLOSING["next_act_unit"]
                        % (unit["id"],
                           unit["next_act"] or
                           CLOSING["next_act_remedy"] % unit["integration_branch"])
                        for unit in stalled)),
             CLOSING["run_dir"] % os.path.relpath(run.run_dir, run.repo)]
    lines += [""] + spend_section(run)
    return "\n".join(lines)


TOKEN_KEYS = (("in", "input_tokens", "inputTokens"),
              ("out", "output_tokens", "outputTokens"),
              ("cache read", "cache_read_input_tokens", "cacheReadInputTokens"),
              ("cache write", "cache_creation_input_tokens", "cacheCreationInputTokens"))


def tokens_of(usage):
    return Counter(dict((label, int(usage.get(snake) or usage.get(camel) or 0))
                        for label, snake, camel in TOKEN_KEYS))


def tokens_text(tokens):
    if not any(tokens.values()):
        return NONE_REPORTED
    return " · ".join(SPEND["token_count"] % (tokens[label], label) for label, _, _ in TOKEN_KEYS)


def spawn_wall(spawn):
    return elapsed_seconds(spawn.get("started_at"), spawn.get("ended_at"))


def blank_row():
    return {"spawns": 0, "cost_usd": 0.0, "turns": 0, "wall": 0, "tokens": Counter()}


def per_key(spawns, key_of):
    rows = {}
    for spawn in spawns:
        row = rows.setdefault(key_of(spawn) or UNKEYED, blank_row())
        row["spawns"] += 1
        row["cost_usd"] += float(spawn.get("cost_usd") or 0.0)
        row["turns"] += int(spawn.get("num_turns") or 0)
        row["wall"] += spawn_wall(spawn)
        row["tokens"] += tokens_of(spawn.get("usage") or {})
    return rows


def per_model(spawns):
    models = {}
    for spawn in spawns:
        for model, usage in (spawn.get("model_usage") or {}).items():
            row = models.setdefault(model, blank_row())
            row["spawns"] += 1
            row["cost_usd"] += float(usage.get("costUSD") or 0.0)
            row["tokens"] += tokens_of(usage)
    return models


def span(started_at, ended_at):
    return "interrupted" if ended_at == "interrupted" else \
        hms(elapsed_seconds(started_at, ended_at))


def phase_durations(unit):
    out = Counter()
    for entry in unit["timeline"]:
        if entry["ended_at"] == "interrupted":
            out[INTERRUPTED_PHASE % entry["phase"]] = 0
        else:
            out[entry["phase"]] += elapsed_seconds(entry["started_at"], entry["ended_at"])
    return out


def spend_section(run):
    spawns = [read_json(path) for path in
              sorted(glob.glob(os.path.join(run.run_dir, "spawns", "*.json")))]
    roles = per_key(spawns, lambda spawn: spawn.get("shell"))
    units = per_key(spawns, lambda spawn: (spawn.get("brief") or {}).get("unit_id"))
    total = sum((row["tokens"] for row in roles.values()), Counter())
    lines = [SPEND["title"], "", SPEND["tokens"] % (tokens_text(total), len(spawns))]

    models = per_model(spawns)
    if models:
        lines += ["", SPEND["by_model"], "", *SPEND["model_header"]]
        lines += [SPEND["model_row"]
                  % (model, row["spawns"], tokens_text(row["tokens"]), row["cost_usd"])
                  for model, row in sorted(models.items())]

    if roles:
        max_turns = (run.config or {}).get("max_turns")
        header, rule = SPEND["role_header"]
        lines += ["", SPEND["by_role"], "",
                  header % (SPEND["max_turns"] % max_turns if max_turns else ""), rule]
        lines += [SPEND["role_row"]
                  % (role, row["spawns"], row["cost_usd"], row["turns"], hms(row["wall"]))
                  for role, row in sorted(roles.items())]
        if max_turns:
            near = [spawn for spawn in spawns
                    if int(spawn.get("num_turns") or 0) >= 0.9 * max_turns]
            near_text = ", ".join(SPEND["near_spawn"]
                                  % ((spawn.get("brief") or {}).get("unit_id"),
                                     spawn.get("shell"), spawn.get("num_turns") or 0)
                                  for spawn in near)
            lines += ["", SPEND["near_max"] % (len(near), ": " + near_text if near else "")]

    lines += ["", SPEND["by_unit"], "", *SPEND["unit_header"]]
    for unit_id, unit in sorted(run.state["units"].items()):
        row = units.get(unit_id) or blank_row()
        rework = ", ".join("%s %d" % (role, n) for role, n in unit["rework"].items() if n) \
            or NO_REWORK
        phases = ", ".join(phase if phase.endswith("(interrupted)") else
                        "%s %s" % (phase, hms(seconds))
                        for phase, seconds in phase_durations(unit).items()) or NO_PHASES
        lines.append(SPEND["unit_row"]
                     % (unit_id, unit["status"], row["spawns"], row["cost_usd"], rework,
                        hms(elapsed_seconds(unit["started_at"], unit["ended_at"])), phases))

    waves = run.state["wave_log"]
    if waves:
        lines += ["", SPEND["by_wave"], "", *SPEND["wave_header"]]
        lines += [SPEND["wave_row"] % (wave["index"], span(wave["started_at"], wave["ended_at"]))
                  for wave in waves]
    lines += ["", SPEND["ledger"] % LEDGER_PATH]
    return lines
