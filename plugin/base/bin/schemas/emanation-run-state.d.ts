/**
 * inspire.emanation-run-state/1 — mutable progress beside one immutable plan.
 * `emanation-run-state.schema.json` is the canonical shape. Unit keys are the
 * ids in the referenced plan's waves, and plan_sha256 binds its exact bytes.
 */
export type RunStatus = "planned" | "running" | "completed" | "interrupted";
export type UnitStatus = "pending" | "running" | "delivered" | "stalled" | "blocked";
export type RunPhase =
  | "prepare"
  | "persona"
  | "overseer_gate"
  | "harvest"
  | "verify"
  | "gate"
  | "drill"
  | "promote";
export type Persona = "contracter" | "tester" | "implementer";

export interface UnitRunState {
  status: UnitStatus;
  /** 0 while pending; 1-based once work starts. */
  attempt: number;
  /** RFC 3339 timestamp. */
  updated_at: string;
  phase?: RunPhase;
  /** Which persona is acting or being reviewed when phase is persona/overseer_gate/harvest. */
  persona?: Persona;
  /** Human-readable cause of a stall or block. */
  reason?: string;
  /** Ordering prerequisites responsible for a blocked status. */
  blocked_by?: string[];
  integration_branch?: string;
  worktree?: string;
  rework_cycles?: number;
  infrastructure_retries?: number;
}

export interface EmanationRunState {
  schema: "inspire.emanation-run-state/1";
  /** SHA-256 of the exact, immutable plan file bytes. */
  plan_sha256: string;
  /** Null before the run begins. */
  run_id: string | null;
  /** Null before the goal branch exists. */
  goal_branch: string | null;
  status: RunStatus;
  /** RFC 3339 timestamp of the last atomic state rewrite. */
  updated_at: string;
  /** Exactly one entry for each unit in plan.waves; keyed by unit id. */
  units: Record<string, UnitRunState>;
}
