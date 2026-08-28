#!/usr/bin/env bash
# .inspire/bin/lib/plan-checks.sh
#
# Library — the readiness catalogue. Every `PR-*` class lives here: the seven
# findings that leave a plan standing and flip it to not-ready, and the four
# refusals that mean nothing is planned at all. The catalogue itself — what each
# id means, its severity and its owner — is
# `.claude/skills/_references/emanation-plan.md`, and the ids are never
# duplicated into a second table.
#
# Two rules of shape are load-bearing and stated once, here:
#
#   NAVIGATION NEVER ORDERS A WAVE. A `screen`-kinded edge out of a screen unit
#   is a route reference — a route derives from `module` + `screen` without the
#   target existing as code — and list/detail screens navigate to each other in
#   every real vault. Ordering on it would make the common case a cycle. The
#   edge still has to RESOLVE (`PR-02`); it just never layers.
#
#   AN EDGE ORDERS A WAVE ONLY WHEN ITS TARGET IS IN THE FRONTIER. An edge to a
#   `stable` artifact is satisfied out of band, an edge to an `accepted` unit
#   outside the scope is someone else's run, and an edge to a pattern or a
#   component is a readiness check rather than a constraint.
#
# Sourced after `_lib.sh`, `plan-lib.sh`, `plan-scan.sh` and `plan-stack.sh`.

# plan_find <code> <severity> <unit> <target> <owner> <message> <remedy> [class]
# The owner is passed rather than derived, because it is not always the target's
# own layer: `PR-02` names an id that resolves to nothing, and an unresolvable
# id has no layer to read.
plan_find() {
  plan_row findings "$1" "$2" "$3" "$4" "$5" "$(plan_norm "$6")" "$(plan_norm "$7")" "${8:-}"
}

# plan_refuse <code> <target> <message> <remedy> — a precondition of planning
# failed. Refusals carry no owner: nothing was planned, so there is no unit for
# a skill to own.
plan_refuse() {
  plan_row refused "$1" "$2" "$(plan_norm "$3")" "$(plan_norm "$4")"
}

# ─────────────────────────────────────────────────────────────────────────────
# Refusals — evaluated in two tiers. Every class a tier finds is reported, never
# the first; but a later tier's answer depends on an earlier one holding, so a
# tier that refuses stops the run. Deriving six units to discover the overseer
# roster is broken would be work whose answer nothing could use.
# ─────────────────────────────────────────────────────────────────────────────

# plan_check_stack — PR-13. Also leaves the suite-wide declared profile ids in
# `stack-profiles`, which every unit's resolution starts from.
plan_check_stack() {
  local f="$SDD_KB_ROOT/00_bootstrap/stack.md"
  if plan_stack_declared > "$PLAN_TMP/stack-profiles" 2>/dev/null; then
    [ -s "$PLAN_TMP/stack-profiles" ] && return 0
  fi
  : > "$PLAN_TMP/stack-profiles"
  if [ -f "$f" ]; then
    plan_refuse "PR-13" "$(plan_path_norm "$f")" \
      "the stack declares no \`profiles:\` and no \`## Layer: Name\` section an id could be inferred from" \
      "/inspire_bootstrap stack"
  else
    plan_refuse "PR-13" "$(plan_path_norm "$f")" \
      "there is no stack: nothing declares which profiles a unit is emanated under" \
      "/inspire_bootstrap stack"
  fi
  return 1
}

# plan_check_overseers — PR-10. The shape is `roles/README.md` § The roster is
# additive-only, implemented exactly and no further: name ends in
# `-overseer.md`, a `tools:` line is present, and it names none of the five
# tools that can act.
plan_check_overseers() {
  local root="$PLAN_AGENTS_ROOT" base f tools tok bad ok=0
  for base in inspire-security-overseer inspire-quality-overseer; do
    [ -f "$root/$base.md" ] && continue
    ok=1
    plan_refuse "PR-10" "$(plan_path_norm "$root/$base.md")" \
      "the shipped overseer shell \`$base.md\` is absent, and the two INSPIRE ships are non-removable" \
      "restore $base.md from the plugin's agents payload"
  done
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    tools="$(sdd_fm_value "$f" '.tools')"
    if [ -z "$tools" ] || [ "$tools" = "null" ]; then
      ok=1
      plan_refuse "PR-10" "$(plan_path_norm "$f")" \
        "carries no \`tools:\` line, so it inherits every tool and is not an overseer however it is named" \
        "give it a \`tools:\` line naming only read-only tools"
      continue
    fi
    bad=""
    for tok in $(printf '%s' "$tools" | tr ',[]' '   '); do
      case "$tok" in Bash|Write|Edit|NotebookEdit|Agent) bad="$tok"; break ;; esac
    done
    [ -n "$bad" ] || continue
    ok=1
    plan_refuse "PR-10" "$(plan_path_norm "$f")" \
      "its \`tools:\` line names \`$bad\` — an overseer that can write is a participant, and D3 gives an oracle no way to act on what it sees" \
      "remove \`$bad\` from its \`tools:\` line"
  done < <(find "$root" -type f -name '*-overseer.md' 2>/dev/null | LC_ALL=C sort)
  [ "$ok" = 0 ]
}

# plan_check_frontier — PR-12. An empty frontier refuses rather than emitting a
# green zero-wave plan, so `emanate run` cannot build worktrees for nothing.
plan_check_frontier() {
  [ -s "$PLAN_TMP/frontier.tsv" ] && return 0
  plan_refuse "PR-12" "$PLAN_SCOPE_LABEL" \
    "no unit in scope is at \`lifecycle: accepted\` — the frontier is empty and there is nothing to emanate" \
    "promote a unit to accepted, or widen --scope"
  return 1
}

# plan_acyclic_findings — the cycle rule's own findings, as `target<TAB>message`.
# PR-11 reuses `acyclic-deps.sh` rather than re-deriving the cycle: the class has
# one implementation, the way derive runs the rules that own its `OS-*` classes.
plan_acyclic_findings() {
  local s
  {
    if [ -s "$PLAN_TMP/scopes" ]; then
      while IFS= read -r s; do
        [ -n "$s" ] || continue
        bash "$PLAN_BIN/acyclic-deps.sh" "$s" 2>&1 >/dev/null
      done < "$PLAN_TMP/scopes"
    else
      bash "$PLAN_BIN/acyclic-deps.sh" "$SDD_SPEC_ROOT" 2>&1 >/dev/null
    fi
  } | jq -r 'select(.rule? == "acyclic-deps") | [.target, .message] | @tsv' 2>/dev/null \
    | LC_ALL=C sort -u
}

# plan_cycle_refusals — PR-11. The named rule covers action->action `requires:`;
# a cycle the wider edge set forms is reported off the layering, which already
# knows exactly which nodes it could not consume.
plan_cycle_refusals() {
  local target msg id found=0
  while IFS=$'\t' read -r target msg; do
    [ -n "$msg" ] || continue
    found=1
    plan_refuse "PR-11" "$(plan_path_norm "$target")" "$msg" "fix the \`requires:\` chain"
  done < <(plan_acyclic_findings)
  [ "$found" = 0 ] || return 0
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    plan_refuse "PR-11" "$(plan_index_lookup "$PLAN_TMP/idpath.tsv" "$id")" \
      "the ordering edges among the frontier form a cycle: \`$id\` can never reach a wave" \
      "fix the \`requires:\` chain"
  done < "$PLAN_TMP/unconsumed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Findings — the plan stands; `ready` is false and the run exits 1.
# ─────────────────────────────────────────────────────────────────────────────

# plan_ingest — one pass over the derived contracts. Identity, claim count,
# declared edges and the per-unit findings that need only the unit itself
# (`PR-01`, `PR-04`, `PR-05`); edges are spooled for a second pass because an
# edge's ordering question needs the whole frontier to already be known.
plan_ingest() {
  local n=0 path kind code
  : > "$PLAN_TMP/nodes"; : > "$PLAN_TMP/idpath.tsv"; : > "$PLAN_TMP/deps.tsv"
  while IFS=$'\t' read -r path kind; do
    [ -n "$path" ] || continue
    n=$((n + 1))
    code="$(cat "$PLAN_TMP/c/$n.code" 2>/dev/null)"
    case "$code" in
      0|4) ;;
      *) PLAN_BROKE="emanate-derive.sh exited ${code:-?} on $kind $path"; return 1 ;;
    esac
    plan_ingest_one "$n" "$kind" "$path" || return 1
  done < "$PLAN_TMP/frontier.tsv"
}

plan_ingest_one() {
  local n="$1" kind="$2" path="$3" recf="$PLAN_TMP/c/$1.rec"
  local t id lifecycle module claims surface f1 f2 f3 f4
  plan_contract_records "$PLAN_TMP/c/$n.json" > "$recf"
  IFS="$PLAN_FS" read -r t id lifecycle module claims < <(head -1 "$recf")
  if [ "${t:-}" != "U" ] || [ -z "${id:-}" ]; then
    PLAN_BROKE="emanate-derive.sh produced no readable contract for $kind $path"
    return 1
  fi
  surface=""
  [ "$kind" = "screen" ] && surface="$(plan_surface_of "$path")"
  printf '%s\n' "$id" >> "$PLAN_TMP/nodes"
  printf '%s\t%s\n' "$id" "$path" >> "$PLAN_TMP/idpath.tsv"
  plan_row units "$id" "$kind" "$path" "$lifecycle" "$module" "$surface" "$claims"

  while IFS="$PLAN_FS" read -r t f1 f2 f3 f4; do
    case "$t" in
      R) plan_row requires "$id" "$f1" "$f2"
         printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$path" "$kind" "$f1" "$f2" >> "$PLAN_TMP/deps.tsv" ;;
      P) plan_check_pattern "$id" "$f1" "$f2" ;;
      C) plan_check_component "$id" "$f1" "$f2" "$f3" ;;
      X) plan_find "PR-01" "error" "$id" "$(plan_path_norm "$f2")" \
           "$(plan_owner "$f2")" "$f3" "$f4" "$f1" ;;
      *) ;;
    esac
  done < "$recf"
}

# plan_check_pattern — PR-05. `screen-coherence` reports the same shape as a
# warning on the pattern file; at emanation an unverifiable layout join is a
# rendering the contracter would guess at, so plan reports it as an error.
plan_check_pattern() {
  local uid="$1" pid="$2" p
  p="$(plan_path_norm "$3")"
  [ -f "$p" ] || return 0
  sdd_has_section "$p" "Regions" && return 0
  plan_find "PR-05" "error" "$uid" "$p" "$(plan_owner "$p")" \
    "pattern \`$pid\` declares no \`## Regions\` table, so the screen-to-layout join cannot be checked" \
    "add a \`## Regions\` table to $p"
}

# plan_check_component — PR-04 (D10/A10: a screen cannot emanate until the
# components it declares are stable).
plan_check_component() {
  local uid="$1" cid="$2" state="$4" p
  p="$(plan_path_norm "$3")"
  [ "$state" = "implemented" ] && return 0
  plan_find "PR-04" "error" "$uid" "$p" "$(plan_owner "$p")" \
    "declared component \`$cid\` is at \`**State:** ${state:-—}\`, not \`implemented\`" \
    "implement \`$cid\`, then set its \`**State:**\` to \`implemented\`"
}

# plan_resolve_edges — the second pass: PR-02, PR-03 and the ordering edge set.
plan_resolve_edges() {
  local uid upath ukind dkind did dpath lc
  : > "$PLAN_TMP/edges.tsv"
  while IFS=$'\t' read -r uid upath ukind dkind did; do
    [ -n "$uid" ] || continue
    case "$dkind" in pattern|component) continue ;; esac
    dpath="$(plan_dep_path "$dkind" "$did")"
    if [ -z "$dpath" ]; then
      plan_find "PR-02" "error" "$uid" "$did" "$(plan_owner "$upath")" \
        "requires \`$did\` ($dkind), which resolves to no artifact in the vault" \
        "$(plan_define_remedy "$dkind" "$did")"
      continue
    fi
    [ "$ukind" = "screen" ] && [ "$dkind" = "screen" ] && continue
    if LC_ALL=C grep -qxF "$did" "$PLAN_TMP/nodes"; then
      printf '%s\t%s\n' "$uid" "$did" >> "$PLAN_TMP/edges.tsv"
      continue
    fi
    lc="$(sdd_fm_value "$dpath" '.lifecycle')"
    case "$lc" in stable|accepted) continue ;; esac
    plan_find "PR-03" "error" "$uid" "$dpath" "$(plan_owner "$dpath")" \
      "dependency \`$did\` is at lifecycle \`${lc:-—}\` — neither stable nor in the frontier" \
      "$(plan_promote_remedy "$dkind" "$did" "$lc")"
  done < "$PLAN_TMP/deps.tsv"
  LC_ALL=C sort -u "$PLAN_TMP/edges.tsv" -o "$PLAN_TMP/edges.tsv"
}

plan_define_remedy() {
  case "$1" in
    screen) printf '/inspire_screens create %s' "$2" ;;
    *)      printf '/inspire_domain define %s' "$2" ;;
  esac
}

plan_promote_remedy() {
  case "$3" in
    superseded) printf 're-point the edge at what superseded %s' "$2"; return 0 ;;
  esac
  case "$1" in
    screen) printf '/inspire_screens promote %s accepted' "$2" ;;
    *)      printf '/inspire_domain promote %s accepted' "$2" ;;
  esac
}

# plan_declared_for <key> <surface> — the declared id list a unit resolves from,
# materialized once per key. A surface that declares none inherits the
# suite-wide set; it does not extend it.
plan_declared_for() {
  local key="$1" surface="$2" f="$PLAN_TMP/prof/$1.declared"
  if [ ! -f "$f" ]; then
    if [ "$key" = "suite" ]; then
      cp "$PLAN_TMP/stack-profiles" "$f"
    else
      plan_surface_profiles "$surface" > "$f"
      [ -s "$f" ] || cp "$PLAN_TMP/stack-profiles" "$f"
    fi
  fi
  printf '%s' "$f"
}

# plan_check_profiles — PR-06, and the `profiles` spool `units[]` renders from.
plan_check_profiles() {
  local uid kind path lifecycle module surface claims key gap pid
  while IFS="$PLAN_FS" read -r uid kind path lifecycle module surface claims; do
    [ -n "$uid" ] || continue
    key="$(plan_unit_profile_key "$kind" "$surface")"
    plan_resolve_profiles "$key" "$(plan_declared_for "$key" "$surface")"
    while IFS= read -r pid; do
      [ -n "$pid" ] || continue
      plan_row profiles "$uid" "$pid"
    done < "$PLAN_TMP/prof/$key"
    gap="$(cat "$PLAN_TMP/prof/$key.gap")"
    [ -n "$gap" ] || continue
    plan_find "PR-06" "error" "$uid" "$(plan_path_norm "$gap")" "inspire-code" \
      "the resolved profile set yields no language profile — \`$gap\` is not there, so nothing states how a semantic type renders" \
      "declare a language profile in \`00_bootstrap/stack.md\`, or add $gap"
  done < "$PLAN_TMP/units.spool"
}

# plan_check_ceiling — PR-20. A warning, never a blocker: D11 gives a low
# ceiling partial-but-reported delivery in graph order, so it never flips
# `ready` and a run whose only finding is this one exits 0.
plan_check_ceiling() {
  [ -n "$PLAN_CEILING" ] || return 0
  [ "$PLAN_CEILING" -lt "$PLAN_FLOOR" ] || return 0
  plan_find "PR-20" "warning" "" "" "" \
    "the declared ceiling of $PLAN_CEILING wave(s) is below the floor of $PLAN_FLOOR — delivery will be partial, in graph order" \
    "raise --ceiling to $PLAN_FLOOR, or accept partial-but-reported delivery"
}
