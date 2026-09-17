"""The flow, declared: the same modules, wired as a graph instead of a loop.

Every node here calls a function that already exists — `start`, `handoff`, `gate`,
`git`, `report`. What the graph carries is only the control flow around them: the
wave loop, the handoff's `while True`, and `gate_loop`'s verdict machine. The
judgment, the subprocesses and the records are untouched.

The `run` — an `Orchestrator`, the shared context every module reads — travels in
the invocation's `configurable` rather than in the state: it holds locks, an open
report and a runner, none of which is a value. What the state carries is the run's
record — the roster, the waves, the spend, and the pointers the run computed at
t=0 — so the flow routes on the state rather than on the run. The record's own
dicts travel, not copies: a node spends a rework where it is spent, and the state
carries the same object the run saved. `units` takes a reducer because a wave's
units answer in parallel.
"""

import operator
import os

from typing import Annotated, TypedDict

from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import Send

from .. import gate as gatemod
from .. import git as gitmod
from .. import handoff as handoffmod
from .. import start as startmod
from ..constants import OVERSEER_SCHEMA, PERSONA_SHELLS, ROLES
from ..errors import Infrastructural, Stall
from ..findings import (conflict_findings, conflict_role, gate_digest, gate_findings,
                        route_gate_verdict)
from ..shells import read_shells
from ..state import set_phase


def collect(left, right):
    """The overseers' fan-in, with a reset: `None` empties it, so the next
    boundary is read on its own answers."""
    if right is None:
        return []
    return (left or []) + right


class RunState(TypedDict, total=False):
    """The run's record, and what the flow routes on: what `run.state.data` holds
    (`units`, `waves`, `spend_usd`, `spawn_count`) plus the pointers the run
    computed at t=0 and has carried as attributes (`run_dir`, `goal_branch`,
    `goal_worktree`, `plan`). The per-unit halves — `timeline`, `infra_retries`,
    `rework` — are on `UnitState`, which is where the record keeps them."""
    run_dir: str
    goal_branch: str
    goal_worktree: str
    plan: dict
    waves: list
    wave_index: int
    pending: list
    runnable: list
    # The one fan-in: each unit of a wave answers with its own record, never
    # the roster, so the answers merge rather than the last one winning.
    units: Annotated[dict, operator.or_]
    spend_usd: float
    spawn_count: int
    spend_exhausted: bool
    exit_reason: str


class UnitState(TypedDict, total=False):
    """One unit's trip around the boundary, and the unit's own counters: `rework`
    is what `stalled` cuts on, `infra_retries` what the free retry spends, and
    `timeline` where its time went. They are the record's own objects, seeded at
    `prepare` and spent in place, so the state and the record never disagree."""
    unit_id: str
    rework: dict
    infra_retries: dict
    timeline: list
    role: str
    findings: list
    changed: list
    tip_before: str
    worktree: str
    free_retry_used: bool
    retry: bool
    verdict: dict
    results_path: str
    verdict_path: str
    shell: str
    rejections: Annotated[list, collect]


def _run(config):
    return config["configurable"]["run"]


def _next_role(ustate):
    """The first persona this unit has not been through. None when the sequence
    is spent — a resumed unit re-enters at the gate."""
    return next((role for role in ROLES if role not in ustate["done"]), None)


# ------------------------------------------------------------------ t = 0

def preflight(state, config):
    """The identity the run is recorded under, into the state. `run.preflight()`
    itself runs in `run_graph`, before the invocation — the checkpoint file and the
    thread are named after what it computes — so what is left here is its record."""
    run = _run(config)
    return {"run_dir": run.run_dir, "goal_branch": run.goal_branch,
            "goal_worktree": run.goal_worktree}


def plan(state, config):
    run = _run(config)
    run.plan_step()
    if run.plan.get("realized_all") or not run.plan.get("waves"):
        return {"plan": run.plan,
                "exit_reason": "goal reached — nothing left to build"}
    return {"plan": run.plan}


def route_plan(state):
    """A goal already reached still gets its account; nothing else runs."""
    if state.get("exit_reason"):
        return ["identity"]
    return ["ceiling", "shells", "derive_units", "baseline"]


def ceiling(state, config):
    startmod.check_ceiling(_run(config))
    return {}


def shells(state, config):
    read_shells(_run(config))
    return {}


def derive_units(state, config):
    """The roster this run starts from. The contracts it still owes are derived by
    the graph rather than by a pool of this node's own."""
    run = _run(config)
    planned, waves = startmod.select_waves(run)
    units, pending = startmod.plan_roster(run, planned, waves)
    return {"waves": waves, "units": units, "pending": pending}


def fan_derive(state):
    """One `Send` per contract: the derivations are independent, so the graph
    schedules them the way it schedules a wave's units."""
    return ([Send("derive", {"entry": entry}) for entry in state["pending"]]
            or "identity")


def derive(payload, config):
    startmod.derive_unit(_run(config), payload["entry"])
    return {}


def baseline(state, config):
    startmod.baseline(_run(config))
    return {}


def identity(state, config):
    """Step 9, and the first thing a run writes: everything above it can still
    refuse, and a refusal may not empty the last run's account."""
    run = _run(config)
    startmod.new_state(run, state.get("waves") or [], state.get("units") or {})
    startmod.write_identity(run)
    return {}


# ------------------------------------------------------------- the waves

def wave(state, config):
    run = _run(config)
    runnable, exhausted = run.open_wave(state["wave_index"])
    return {"runnable": runnable, "spend_exhausted": exhausted}


def fan_out(state):
    """`--parallel` is the invocation's `max_concurrency`: the graph schedules a
    wave's units, so nothing here counts workers."""
    if not state["runnable"]:
        return "wave_close"
    return [Send("unit", {"unit_id": unit_id}) for unit_id in state["runnable"]]


def wave_close(state, config):
    run = _run(config)
    index = state["wave_index"]
    run.close_wave(index, state.get("spend_exhausted", False))
    return {"wave_index": index + 1, "spend_usd": run.state.data["spend_usd"],
            "spawn_count": run.state.data["spawn_count"]}


def route_wave(state):
    if state.get("spend_exhausted") or state["wave_index"] >= len(state["waves"]):
        return "report"
    return "wave"


def report(state, config):
    run = _run(config)
    run.finish(state.get("exit_reason")
               or run.exit_reason(state.get("spend_exhausted", False)))
    return {"exit_reason": run.state.data["exit"]}


# -------------------------------------------------------------- one unit

def unit(payload, config):
    """The subgraph, run for one unit, under the same guard the loop ran it under:
    a stall or an infrastructural failure ends this unit and no other."""
    run = _run(config)
    ustate = run.state.unit(payload["unit_id"])
    with run.unit_guard(ustate):
        UNIT.invoke({"unit_id": ustate["id"], "findings": []},
                    {"configurable": {"run": run},
                     "recursion_limit": unit_recursion_limit(run)})
    return {"units": {ustate["id"]: ustate}}


def unit_recursion_limit(run):
    """Every rework is another trip around a boundary, eight or so supersteps.
    The budget is the operator's, so the ceiling follows it."""
    return 64 + 8 * len(ROLES) * (run.args.rework + 1)


def prepare(state, config):
    run = _run(config)
    ustate = run.state.unit(state["unit_id"])
    run.open_unit(ustate)
    return {"free_retry_used": False, "findings": [],
            "rework": ustate["rework"], "infra_retries": ustate["infra_retries"],
            "timeline": ustate["timeline"]}


def route_prepare(state, config):
    return _next_role(_run(config).state.unit(state["unit_id"])) or "gate"


def persona(role):
    """prepare → spawn → A read-only checks. A rejection here spends a rework and
    the edge comes straight back; an infrastructural ending is nobody's judgment,
    so the first one of a boundary is free."""
    def node(state, config):
        run = _run(config)
        ustate = run.state.unit(state["unit_id"])
        if ustate["phase"] != role:
            set_phase(run, ustate, role)
        findings = state.get("findings") or []
        tip_before = gitmod.tip(run, ustate)
        worktree = None
        try:
            worktree = handoffmod.prepare(run, ustate, role, tip_before)
            result = handoffmod.spawn(
                run, PERSONA_SHELLS[role],
                handoffmod.persona_brief(run, ustate, role, worktree, findings),
                None, worktree)
            if result.ending != "exit":
                raise Infrastructural("the %s spawn ended in %s" % (role, result.ending))
            rejection = handoffmod.checks_a(run, ustate, role, worktree, tip_before)
        except Infrastructural as failure:
            if worktree:
                gitmod.discard(run, worktree)
            handoffmod.after_infrastructural(run, ustate, role, str(failure),
                                             state.get("free_retry_used", False), findings)
            return {"role": role, "retry": True, "free_retry_used": True}
        if rejection:
            gitmod.discard(run, worktree)
            handoffmod.spend_rework(run, ustate, role, rejection,
                                    "the %s boundary" % role)
            return {"role": role, "retry": True, "findings": rejection}
        return {"role": role, "retry": False, "worktree": worktree,
                "tip_before": tip_before}
    return node


def route_retry(state):
    """The one shape every boundary node answers in: back to the persona, or on."""
    return state["role"] if state.get("retry") else None


def harvest(state, config):
    run = _run(config)
    ustate = run.state.unit(state["unit_id"])
    role = state["role"]
    try:
        tip = handoffmod.harvest(run, ustate, role, state["worktree"])
    except Infrastructural as failure:
        gitmod.discard(run, state["worktree"])
        handoffmod.after_infrastructural(run, ustate, role, str(failure),
                                         state.get("free_retry_used", False),
                                         state.get("findings") or [])
        return {"retry": True, "free_retry_used": True}
    handoffmod.repoint_verify(run, ustate, tip)
    changed = gitmod.git(run, ["diff", "--name-only",
                               "%s..%s" % (state["tip_before"], tip)]).stdout.split()
    return {"retry": False, "changed": changed}


def route_persona(state):
    return route_retry(state) or "harvest"


def route_harvest(state):
    return route_retry(state) or "verify"


def verify(state, config):
    """C: the tool checks, in the verify worktree at the new tip."""
    run = _run(config)
    ustate = run.state.unit(state["unit_id"])
    rejection = handoffmod.checks_c(run, ustate, state["role"], state["changed"])
    if rejection:
        handoffmod.spend_rework(run, ustate, state["role"], rejection,
                                "the %s boundary" % state["role"])
        return {"retry": True, "findings": rejection}
    return {"retry": False, "rejections": None}


def route_verify(state, config):
    """D: one `Send` per overseer. The roster is additive-only, so the fan-out is
    as wide as the project declared it, never two."""
    return route_retry(state) or [Send("overseer", dict(state, shell=shell))
                                  for shell in _run(config).overseer_shells]


def overseer(state, config):
    run = _run(config)
    ustate = run.state.unit(state["unit_id"])
    shell = state["shell"]
    brief = handoffmod.overseer_brief(run, ustate, state["role"], state["changed"])
    result = handoffmod.spawn(
        run, shell, dict(brief, heading="%s — %s" % (shell[:-3], brief["heading"])),
        OVERSEER_SCHEMA, brief["worktree"])
    return {"rejections": handoffmod.overseer_answer(run, ustate, shell, result)}


def overseers(state, config):
    """The join. One overseer's rejection is the boundary's."""
    run = _run(config)
    ustate = run.state.unit(state["unit_id"])
    rejections = state.get("rejections") or []
    if rejections:
        handoffmod.spend_rework(run, ustate, state["role"], rejections,
                                "the %s boundary" % state["role"])
        return {"retry": True, "findings": rejections}
    if state["role"] not in ustate["done"]:
        ustate["done"].append(state["role"])
    set_phase(run, ustate, None)
    return {"retry": False, "findings": [], "free_retry_used": False}


def route_overseers(state, config):
    return (route_retry(state)
            or _next_role(_run(config).state.unit(state["unit_id"])) or "gate")


# -------------------------------------------------------------- the gate

def gate(state, config):
    run = _run(config)
    ustate = run.state.unit(state["unit_id"])
    if ustate["phase"] != "gate":
        set_phase(run, ustate, "gate")
    verdict, results_path, verdict_path = gatemod.run_gate(run, ustate)
    if route_gate_verdict(verdict)[0] == "pass":
        ustate["gate_digest"] = gate_digest(verdict)
        run.save()
    return {"verdict": verdict, "results_path": results_path,
            "verdict_path": verdict_path}


def route_gate(state):
    """The gate's four answers. `drill` is the pass — a measurement, never a
    gate — and promotion is the node behind it."""
    action, _ = route_gate_verdict(state["verdict"])
    return {"pass": "drill", "stall": "stalled", "arbitrate": "arbitrate"}.get(
        action, "rework")


def stalled(state, config):
    """A class no persona can answer. The cut is the exception the unit node reads."""
    _, subject = route_gate_verdict(state["verdict"])
    findings = gate_findings(state["verdict"])
    raise Stall("gate", "the gate returned %s: %s"
                % (subject, "; ".join(row["issue"] for row in findings)), findings)


def rework(state, config):
    run = _run(config)
    _, role = route_gate_verdict(state["verdict"])
    findings = gate_findings(state["verdict"])
    handoffmod.spend_rework(run, run.state.unit(state["unit_id"]), role, findings,
                            "the gate")
    return {"role": role, "findings": findings, "free_retry_used": False}


def arbitrate(state, config):
    run = _run(config)
    ustate = run.state.unit(state["unit_id"])
    role, findings = gatemod.arbitrate(run, ustate, state["verdict"],
                                       state["results_path"], state["verdict_path"])
    handoffmod.spend_rework(run, ustate, role, findings, "the gate")
    return {"role": role, "findings": findings, "free_retry_used": False}


def route_role(state):
    return state["role"]


def drill(state, config):
    run = _run(config)
    gatemod.drill(run, run.state.unit(state["unit_id"]))
    return {}


def promote(state, config):
    """A sibling that promoted first onto a path this unit also wrote is one more
    edge back to the persona that owns it — and the whole boundary again."""
    run = _run(config)
    ustate = run.state.unit(state["unit_id"])
    conflicting = gitmod.promote(run, ustate, state["verdict"])
    if not conflicting:
        return {"retry": False}
    gitmod.advance_onto_goal(run, ustate, conflicting)
    role = conflict_role(run.config["tests_roots"], conflicting)
    findings = conflict_findings(ustate, conflicting)
    handoffmod.spend_rework(run, ustate, role, findings, "promote")
    return {"retry": True, "role": role, "findings": findings,
            "free_retry_used": False}


def route_promote(state):
    return route_retry(state) or END


# --------------------------------------------------------------- the graphs

def build_unit():
    builder = StateGraph(UnitState)
    for name, node in (("prepare", prepare), ("harvest", harvest), ("verify", verify),
                       ("overseer", overseer), ("overseers", overseers), ("gate", gate),
                       ("rework", rework), ("arbitrate", arbitrate),
                       ("stalled", stalled), ("drill", drill), ("promote", promote)):
        builder.add_node(name, node)
    for role in ROLES:
        builder.add_node(role, persona(role))

    builder.add_edge(START, "prepare")
    builder.add_conditional_edges("prepare", route_prepare, list(ROLES) + ["gate"])
    for role in ROLES:
        builder.add_conditional_edges(role, route_persona, [role, "harvest"])
    builder.add_conditional_edges("rework", route_role, list(ROLES))
    builder.add_conditional_edges("harvest", route_harvest,
                                  list(ROLES) + ["verify"])
    builder.add_conditional_edges("verify", route_verify, list(ROLES) + ["overseer"])
    builder.add_edge("overseer", "overseers")
    builder.add_conditional_edges("overseers", route_overseers, list(ROLES) + ["gate"])
    builder.add_conditional_edges("gate", route_gate,
                                  ["drill", "stalled", "arbitrate", "rework"])
    builder.add_conditional_edges("arbitrate", route_role, list(ROLES))
    builder.add_edge("stalled", END)
    builder.add_edge("drill", "promote")
    builder.add_conditional_edges("promote", route_promote, list(ROLES) + [END])
    return builder.compile()


def build(checkpointer=None):
    builder = StateGraph(RunState)
    for name, node in (("preflight", preflight), ("plan", plan), ("ceiling", ceiling),
                       ("shells", shells), ("derive_units", derive_units),
                       ("derive", derive), ("baseline", baseline),
                       ("identity", identity), ("wave", wave), ("unit", unit),
                       ("wave_close", wave_close), ("report", report)):
        builder.add_node(name, node)

    builder.add_edge(START, "preflight")
    builder.add_edge("preflight", "plan")
    builder.add_conditional_edges("plan", route_plan,
                                  ["ceiling", "shells", "derive_units", "baseline",
                                   "identity"])
    builder.add_conditional_edges("derive_units", fan_derive, ["derive", "identity"])
    # One barrier rather than three edges and a fourth: the derivations are a
    # superstep deeper than their siblings, and a node reached by an edge runs as
    # soon as that edge fires — twice, if two branches answer in different rounds.
    builder.add_edge(["ceiling", "shells", "baseline", "derive"], "identity")
    builder.add_conditional_edges("identity", route_wave, ["wave", "report"])
    builder.add_conditional_edges("wave", fan_out, ["unit", "wave_close"])
    builder.add_edge("unit", "wave_close")
    builder.add_conditional_edges("wave_close", route_wave, ["wave", "report"])
    builder.add_edge("report", END)
    return builder.compile(checkpointer=checkpointer)


UNIT = build_unit()


def invoke(run, state):
    """One invocation is one run: threaded on the run id, checkpointed under the
    run dir, and `--parallel` wide. `state` is the run's opening record, or `None`
    to pick the thread up where it was killed.

    The final state is the run's record as the graph carried it, and is returned.
    `state.json` is projected rather than returned: every node that mutates the
    record mutates the record's own objects — which is what the state carries —
    and `run.save()` writes the file, so the projection is the same one call the
    loop made. The arbiter is an agent rather than a human, so no node interrupts."""
    with SqliteSaver.from_conn_string(os.path.join(run.run_dir,
                                                   "checkpoint.sqlite")) as saver:
        return build(saver).invoke(
            state, {"configurable": {"run": run, "thread_id": run.run_id},
                    "recursion_limit": 128,
                    "max_concurrency": max(1, run.args.parallel)})


def run_graph(run):
    """A new run. Naming the thread and the checkpoint file needs the identity
    `preflight` computes, so that step runs here, before the graph it also opens."""
    run.preflight()
    return invoke(run, {"wave_index": 0, "waves": [], "units": {}})


def resume_graph(run):
    """A killed run, picked up from its own checkpoint. What the checkpointer does
    not carry is the run — locks, an open report, a runner — so that is rebuilt
    from `state.json` first, and `reconcile` is what the kill left open: the
    interrupted timeline entry, the free infrastructural retry, and any key an
    older schema never wrote."""
    run.resume()
    return invoke(run, None)
