"""inspire.emanation-plan/2 — what ``.inspire/bin/emanate-plan.sh`` prints on stdout.

Hand-maintained beside ``emanation-plan.schema.json``, which is the canonical
contract; ``test-plan-schema.sh`` fails if the two drift from the emitter.

Stdlib only, and typed for Python 3.9, so an orchestrator can import it without
taking a dependency::

    import json, subprocess
    from emanation_plan import EmanationPlan, is_refusal, all_units

    proc = subprocess.run(["./.inspire/bin/emanate-plan.sh"],
                          capture_output=True, text=True)
    doc = json.loads(proc.stdout)      # exit 2/5/6/127 print nothing: check first
    if is_refusal(doc):
        ...                            # exit 4: nothing was planned
    else:
        for wave in doc["waves"]:
            for unit in wave["units"]:
                ...

Exit codes and which document you get:

===== ============= =================================================
exit  meaning       stdout
===== ============= =================================================
0     ready         ``EmanationPlan``, ``ready: True``
1     not ready     ``EmanationPlan``, ``ready: False`` (≥1 error finding)
2     usage         empty
4     refused       ``EmanationRefusal`` — nothing was planned
5/6/  roots, internal, empty
127   missing tool
===== ============= =================================================
"""

from typing import Any, Dict, List, Literal, Optional, Union

try:                                   # 3.8+ in the stdlib; the fallback keeps
    from typing import TypedDict       # a 3.7 import from failing outright
except ImportError:                    # pragma: no cover
    from typing_extensions import TypedDict  # type: ignore

__all__ = [
    "SCHEMA_ID", "UnitKind", "Population", "Severity", "FindingCode",
    "RefusalCode", "FINDING_CODES", "REFUSAL_CODES", "EmanationPlan",
    "EmanationRefusal", "EmanationDocument", "Wave", "Unit", "Requirement",
    "Finding", "Reemanate", "Goal", "Preflight", "Component", "RecipeStep",
    "WireConventions", "WireDecision", "Refusal", "is_refusal", "all_units",
    "units_by_id",
]

SCHEMA_ID = "inspire.emanation-plan/2"

# ─────────────────────────────────────────────────────────────────────────────
# Vocabularies
# ─────────────────────────────────────────────────────────────────────────────

#: Derive's five unit kinds — the complete set.
UnitKind = Literal["entity", "action", "screen", "component", "pattern"]

#: Entities only; None on every other kind. Plan decides nothing with it.
Population = Literal["internal", "external"]

Severity = Literal["error", "warning"]

#: Codes that appear in ``findings`` (a plan was computed).
FindingCode = Literal[
    "PR-01",  # derive refused this unit — carries derive's own class verbatim
    "PR-02",  # a requires[] edge resolves to no artifact in the vault
    "PR-03",  # edge resolves, but target is neither stable nor in the frontier
    "PR-04",  # a declared component's **State:** is neither implemented nor to-extract
    "PR-05",  # same for a pattern — or an implemented pattern with no ## Regions
    "PR-06",  # a framework profile reaches no language profile
    "PR-07",  # the unit's framework set is unusable (tied layer, or empty)
    "PR-20",  # --ceiling is below the effective floor       (warning, never blocks)
    "PR-22",  # components declared, but no profile can probe them       (warning)
    "PR-23",  # the goal's screen slice is a rootless nav cycle          (warning)
    "PR-24",  # components declared, but ## Worktree recipe has no step  (warning)
    "PR-25",  # an unheaded entry whose prose names an authz concept     (warning)
    "PR-26",  # a prose-only invariant whose subject may not be this entity (warning)
]

#: Codes that appear in ``refused`` (nothing was planned). Disjoint from FindingCode.
RefusalCode = Literal[
    "PR-10",  # the overseer roster fails its shape
    "PR-11",  # a cycle in the ordering edge set
    "PR-12",  # empty frontier: nothing in scope is at lifecycle: accepted
    "PR-13",  # no stack: 00_bootstrap/stack.md absent or declares no profiles
]

#: The same two vocabularies at runtime, for validating a document by hand.
FINDING_CODES = frozenset(
    ["PR-01", "PR-02", "PR-03", "PR-04", "PR-05", "PR-06", "PR-07",
     "PR-20", "PR-22", "PR-23", "PR-24", "PR-25", "PR-26"])
REFUSAL_CODES = frozenset(["PR-10", "PR-11", "PR-12", "PR-13"])


# ─────────────────────────────────────────────────────────────────────────────
# The plan
# ─────────────────────────────────────────────────────────────────────────────

class Requirement(TypedDict):
    kind: UnitKind
    id: str
    #: False is a deferred reference, which gates readiness but never orders a
    #: wave. True is not a promise of an earlier wave either: navigation and
    #: self edges are dropped from the ordering too.
    ordering: bool


class Unit(TypedDict):
    kind: UnitKind
    #: Dotted and unique across the plan — the join key for requires[].id,
    #: realized, goal.units, reemanate.units and findings[].unit. Not a display
    #: name: a pattern "list" and a screen "samples.list" coexist.
    id: str
    #: Repo-root-relative. Passed unchanged to emanate-derive.sh / emanate-gate.sh.
    path: str
    #: None for the two catalog kinds, which have none.
    module: Optional[str]
    #: The surface a split screens tree puts a screen under; None otherwise.
    surface: Optional[str]
    population: Optional[Population]
    #: The resolved set the unit is emanated under: its framework profile, that
    #: framework's language, and any declared ``layer: language`` profile.
    profiles: List[str]
    #: Derive's edge set verbatim. A target satisfied out of band — stable,
    #: realized, or out of scope — has NO unit record anywhere in the document,
    #: so a consumer drawing a graph must tolerate an unknown edge target.
    requires: List[Requirement]
    #: Claim count from the derived contract; 0 for a refused unit.
    claims: int


class Wave(TypedDict):
    #: 1-based and contiguous. Every unit here has all its in-frontier ordering
    #: dependencies in a strictly lower wave, so one wave builds in parallel.
    wave: int
    #: Sorted by id.
    units: List[Unit]


class Finding(TypedDict):
    code: FindingCode
    severity: Severity
    unit: Optional[str]
    #: The artifact at fault — a path, or a unit id on PR-23.
    target: Optional[str]
    #: The skill that owns the remedy, e.g. "inspire-domain".
    owner: Optional[str]
    message: str
    remedy: str
    #: Derive's own class id on a PR-01; None on every other code.
    derive_class: Optional[str]


class Reemanate(TypedDict):
    #: As typed. Grammar: ``users.list`` · ``users.*`` · ``auth.user.list..``
    #: (dependents) · ``auth.user..users.list`` (segment).
    selectors: List[str]
    #: The resolved union, sorted. Treated as unrealized for this run.
    units: List[str]


class Goal(TypedDict):
    selector: str
    #: The goal's remaining closure — its dependencies, plus the screens that
    #: navigate TO it, transitively, with their own dependencies. Not
    #: waves-shaped: ``waves`` still layers the whole scope.
    units: List[str]
    #: The deepest wave over that closure, and what ``ceiling`` is measured against.
    floor: int


class Component(TypedDict):
    name: str
    purpose: Optional[str]


class RecipeStep(TypedDict):
    step: str
    #: Run as-is in a fresh phase worktree. Never interpreted by plan.
    command: Optional[str]


class Preflight(TypedDict):
    #: stack.md's ``## Test infrastructure``, sorted by name.
    components: List[Component]
    #: Resolved framework profiles carrying a probe recipe for the above.
    #: Empty with components declared is PR-22.
    probe_profiles: List[str]
    #: stack.md's ``## Worktree recipe``, verbatim and never sorted — the order
    #: is the recipe. Empty with components declared is PR-24.
    worktree_recipe: List[RecipeStep]


class WireDecision(TypedDict):
    decision: str
    answer: Optional[str]


class WireConventions(TypedDict):
    """Transport decisions a spawned tester must assert rather than invent."""
    #: The ``wire_conventions:`` frontmatter ids. Empty is legal, not a finding.
    ids: List[str]
    #: The ``## Wire conventions`` rows, in file order.
    decisions: List[WireDecision]


class EmanationPlan(TypedDict):
    schema: str
    #: The --scope paths, LC_ALL=C sorted and deduplicated.
    scope: List[str]
    #: False when at least one finding is severity "error" (exit 1).
    ready: bool
    #: The critical path's depth; equals ``len(waves)``.
    floor: int
    #: --ceiling as given; None when unset.
    ceiling: Optional[int]
    #: min(effective floor, ceiling). The ceiling stops a run; it never chooses
    #: winners.
    deliverable_waves: int
    #: Frontier-eligible units already realized on this branch. Bare ids: these
    #: are not work items and appear in no wave. Empty when no --tests-root was
    #: given; a --reemanate selection is subtracted from it.
    realized: List[str]
    #: Every frontier-eligible unit is realized: floor 0, waves []. "Nothing
    #: left to build" — distinct from PR-12's "nothing to build".
    realized_all: bool
    reemanate: Optional[Reemanate]
    goal: Optional[Goal]
    preflight: Preflight
    wire_conventions: WireConventions
    #: Ascending by wave. Holds only what this run will build.
    waves: List[Wave]
    #: Sorted by (code, unit, target).
    findings: List[Finding]


class Refusal(TypedDict):
    code: RefusalCode
    target: Optional[str]
    message: str
    #: Refusals carry no owner: there is no unit for a skill to own.
    remedy: str


class EmanationRefusal(TypedDict):
    """Exit 4. No ``waves`` or ``floor`` key at all — nothing was planned, and an
    empty key would read as "planned, and it is empty"."""
    schema: str
    scope: List[str]
    ready: bool
    refused: List[Refusal]


EmanationDocument = Union[EmanationPlan, EmanationRefusal]


# ─────────────────────────────────────────────────────────────────────────────
# Narrowing
# ─────────────────────────────────────────────────────────────────────────────

def is_refusal(doc: Dict[str, Any]) -> bool:
    """True when ``doc`` is the exit-4 refusal rather than a plan."""
    return "refused" in doc


def all_units(plan: EmanationPlan) -> List[Unit]:
    """Every unit of the plan, flat, in (wave, id) order."""
    return [unit for wave in plan["waves"] for unit in wave["units"]]


def units_by_id(plan: EmanationPlan) -> Dict[str, Unit]:
    """The lookup the nesting replaced. Note that a ``requires`` target may be
    absent from it: a dependency satisfied out of band has no record here."""
    return {unit["id"]: unit for unit in all_units(plan)}
