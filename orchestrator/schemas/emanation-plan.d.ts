/**
 * inspire.emanation-plan/2 — what `.inspire/bin/emanate-plan.sh` prints on stdout.
 *
 * Hand-maintained beside `emanation-plan.schema.json`, which is the canonical
 * contract; `test-plan-schema.sh` fails if the two drift from the emitter.
 *
 * Exit codes and which document you get:
 *   0  ready      → EmanationPlan, ready: true
 *   1  not ready  → EmanationPlan, ready: false (a plan WAS computed; ≥1 error finding)
 *   2  usage      → empty stdout
 *   4  refused    → EmanationRefusal (nothing was planned)
 *   5  roots missing / 6 internal / 127 missing tool → empty stdout
 */
export type EmanationDocument = EmanationPlan | EmanationRefusal;

// ─────────────────────────────────────────────────────────────────────────────
// Vocabularies
// ─────────────────────────────────────────────────────────────────────────────

/** Derive's five unit kinds — the complete set. */
export type UnitKind = "entity" | "action" | "screen" | "component" | "pattern";

/** Entities only; null on every other kind. Plan decides nothing with it. */
export type Population = "internal" | "external";

/**
 * Project-declared ids, not a closed set. The template ships
 * react · nestjs · angular · ios · android (framework) and typescript (language);
 * a project adds its own.
 */
export type ProfileId = string;

/**
 * The skill that owns a finding's remedy — "inspire-domain", "inspire-screens",
 * "inspire-code", "inspire-bootstrap". Open, since an owner is "the target's
 * layer" and a project may add layers.
 */
export type SkillId = string;

/** Codes that appear in `findings[]` (a plan was computed). */
export type FindingCode =
  | "PR-01"  // derive refused this unit — carries derive's own class verbatim
  | "PR-02"  // a requires[] edge resolves to no artifact in the vault
  | "PR-03"  // edge resolves, but target is neither stable nor in the frontier
  | "PR-04"  // a declared component's **State:** is neither implemented nor to-extract
  | "PR-05"  // same for a pattern — or an implemented pattern with no ## Regions
  | "PR-06"  // a framework profile reaches no language profile
  | "PR-07"  // the unit's framework set is unusable (tied layer, or empty)
  | "PR-20"  // --ceiling is below the effective floor          (warning, never blocks)
  | "PR-22"  // components declared, but no profile can probe them          (warning)
  | "PR-23"  // the goal's screen slice is a rootless nav cycle             (warning)
  | "PR-24"  // components declared, but ## Worktree recipe has no step     (warning)
  | "PR-25"  // an unheaded entry whose prose names an authz concept        (warning)
  | "PR-26"; // a prose-only invariant whose subject may not be this entity (warning)

/** Codes that appear in `refused[]` (nothing was planned). Disjoint from FindingCode. */
export type RefusalCode =
  | "PR-10"  // the overseer roster fails its shape
  | "PR-11"  // a cycle in the ordering edge set
  | "PR-12"  // empty frontier: nothing in scope is at lifecycle: accepted
  | "PR-13"; // no stack: 00_bootstrap/stack.md absent or declares no profiles

export type Severity = "error" | "warning";

// ─────────────────────────────────────────────────────────────────────────────
// The plan
// ─────────────────────────────────────────────────────────────────────────────

export interface EmanationPlan {
  schema: "inspire.emanation-plan/2";

  /** The --scope paths, LC_ALL=C sorted and deduplicated. With none given, the
   *  roots the default sweep walks. */
  scope: string[];

  /** false when ≥1 finding is severity "error". Exit code 1 rather than 0. */
  ready: boolean;

  /** The critical path's depth, known at t=0. Equals `waves.length`. */
  floor: number;
  /** --ceiling as given; null when unset. Budgets are invocation arguments. */
  ceiling: number | null;
  /** min(effective floor, ceiling), where the effective floor is goal.floor when
   *  a goal was named. The ceiling stops a run; it never chooses winners. */
  deliverable_waves: number;

  /**
   * Frontier-eligible units already realized on this branch — every claim of
   * their current derived contract cited under a --tests-root by a token with a
   * matching fingerprint. Bare ids: these are NOT work items and appear in no
   * wave, the way a `stable` artifact does not. Empty when no --tests-root was
   * given; a --reemanate selection is subtracted from it.
   */
  realized: string[];
  /** Every frontier-eligible unit is realized: exit 0, floor 0, waves [].
   *  "Nothing LEFT to build" — distinct from PR-12's "nothing to build". */
  realized_all: boolean;

  /** null unless --reemanate was given. */
  reemanate: Reemanate | null;
  /** null unless --goal was given. */
  goal: Goal | null;

  /** Run-level facts a spawn needs at t=0, from 00_bootstrap/stack.md. */
  preflight: Preflight;
  wire_conventions: WireConventions;

  /**
   * Ascending by `wave`, which is 1-based and contiguous. Holds ONLY what this
   * run will build: realized units are not here, and neither is any dependency
   * satisfied out of band.
   */
  waves: Wave[];

  /** Sorted by (code, unit, target). */
  findings: Finding[];
}

export interface Wave {
  /** 1-based. Every unit here has all its in-frontier ordering dependencies in
   *  a strictly lower wave, so one wave's units may be built in parallel. */
  wave: number;
  /** Sorted by id. */
  units: Unit[];
}

export interface Unit {
  kind: UnitKind;
  /** Dotted and unique across the plan — the join key for requires[].id,
   *  realized[], goal.units[], reemanate.units[] and findings[].unit.
   *  NOT a display name: a pattern `list` and a screen `samples.list` coexist. */
  id: string;
  /** Repo-root-relative. Passed unchanged to emanate-derive.sh and emanate-gate.sh. */
  path: string;
  /** null for the two catalog kinds (component, pattern), which have none. */
  module: string | null;
  /** The surface a split screens tree puts a screen under. null for every other
   *  kind, and for the flat suite-of-one shape. */
  surface: string | null;
  /** Entities only; null otherwise. */
  population: Population | null;
  /** The resolved set this unit is emanated under: its framework profile, that
   *  framework's language, and any declared layer: language profile. */
  profiles: ProfileId[];
  /** Derive's edge set VERBATIM — every declared dependency, ordering or not.
   *  A target satisfied out of band (stable, realized, out of scope) appears
   *  here with NO corresponding Unit anywhere in the document; a consumer
   *  drawing a graph must tolerate an edge whose target it has no node for. */
  requires: Requirement[];
  /** Claim count from the derived contract; 0 for a refused unit. The sizing
   *  signal an orchestrator budgets on, and the unit of gate evidence. */
  claims: number;
}

export interface Requirement {
  kind: UnitKind;
  id: string;
  /**
   * false = a deferred reference (a references(…) field without nonnull), which
   * gates readiness but never orders a wave. true does not promise an earlier
   * wave either: navigation and self edges are dropped from the ordering too.
   */
  ordering: boolean;
}

export interface Finding {
  code: FindingCode;
  severity: Severity;
  /** null on a finding that names no unit. */
  unit: string | null;
  /** The artifact at fault — a path, or a unit id on PR-23. null when none. */
  target: string | null;
  owner: SkillId | null;
  message: string;
  remedy: string;
  /** Derive's own class id on a PR-01; null on every other code. */
  derive_class: string | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Selectors
// ─────────────────────────────────────────────────────────────────────────────

export interface Reemanate {
  /** As typed, in order. Grammar: `users.list` · `users.*` ·
   *  `auth.user.list..` (dependents) · `auth.user..users.list` (segment). */
  selectors: string[];
  /** The resolved union, sorted. Treated as unrealized for this run. */
  units: string[];
}

export interface Goal {
  /** Given once. Same selector grammar as --reemanate. */
  selector: string;
  /** The goal's remaining closure — its dependencies, plus the screens that
   *  navigate TO it, transitively, with their own dependencies. Sorted.
   *  NOT waves-shaped: `waves` still layers the whole scope, this names the
   *  subset a goal-directed run executes. */
  units: string[];
  /** The deepest wave over that closure — the minimum iterations to reach the
   *  goal, and what `ceiling` is measured against. */
  floor: number;
}

// ─────────────────────────────────────────────────────────────────────────────
// t=0 facts, read from 00_bootstrap/stack.md
// ─────────────────────────────────────────────────────────────────────────────

export interface Preflight {
  /** `## Test infrastructure`, sorted by name. */
  components: Component[];
  /** Which resolved framework profiles carry a probe recipe for the above.
   *  Sorted. Empty with components declared is PR-22. */
  probe_profiles: ProfileId[];
  /** `## Worktree recipe`, verbatim and NEVER sorted — the order is the recipe.
   *  Empty with components declared is PR-24. */
  worktree_recipe: RecipeStep[];
}

export interface Component {
  name: string;
  purpose: string | null;
}

export interface RecipeStep {
  step: string;
  /** Run as-is in a fresh phase worktree. Never interpreted by plan. */
  command: string | null;
}

/** Transport decisions a spawned tester must assert rather than invent. */
export interface WireConventions {
  /** The `wire_conventions:` frontmatter ids, sorted. Empty is legal, not a finding. */
  ids: string[];
  /** The `## Wire conventions` rows, in file order. */
  decisions: WireDecision[];
}

export interface WireDecision {
  decision: string;
  answer: string | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// The refusal (exit 4)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * A precondition of planning failed. There is NO waves, floor, preflight,
 * wire_conventions, realized, realized_all, reemanate or goal key at all —
 * nothing was planned, and an empty key would read as "planned, and it is
 * empty". Every class found is reported, not the first.
 */
export interface EmanationRefusal {
  schema: "inspire.emanation-plan/2";
  scope: string[];
  ready: false;
  refused: Refusal[];
}

export interface Refusal {
  code: RefusalCode;
  target: string | null;
  message: string;
  /** Refusals carry no `owner`: there is no unit for a skill to own. */
  remedy: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Narrowing
// ─────────────────────────────────────────────────────────────────────────────

export const isRefusal = (d: EmanationDocument): d is EmanationRefusal =>
  "refused" in d;

/** Every unit of the plan, flat, in (wave, id) order. The lookup the nesting
 *  replaced: `new Map(allUnits(plan).map(u => [u.id, u]))`. */
export const allUnits = (plan: EmanationPlan): Unit[] =>
  plan.waves.flatMap(w => w.units);
