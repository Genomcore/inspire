#!/usr/bin/env bash
# .inspire/bin/lib/plan-checks.sh
#
# Library — the readiness catalogue. Every `PR-*` class lives here: the eight
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
#   every real vault. Ordering on it would make the common case a cycle. It is
#   checked like every other edge: it has to RESOLVE (`PR-02`) and its target
#   has to be stable or in the frontier (`PR-03`). Only the layering is skipped.
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

# plan_fm_has_key <file> <key> — is the key WRITTEN in the frontmatter block?
# `sdd_fm_value` cannot answer it: a key with no value and an absent key both
# read back empty, and telling an operator a line is missing when it is there
# sends them to repair the wrong thing.
plan_fm_has_key() {
  awk -v k="^$2:" '
    /^---[ \t]*$/ { if (++n == 2) exit; next }
    n == 1 && $0 ~ k { found = 1; exit }
    END { exit !found }
  ' "$1"
}

# plan_check_overseers — PR-10. The shape is `roles/README.md` § The roster is
# additive-only, implemented exactly and no further: name ends in
# `-overseer.md`, a `tools:` line is present, and it names none of the five
# tools that can act.
plan_check_overseers() {
  local root="$PLAN_AGENTS_ROOT" base f tools tok bad why ok=0
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
      if plan_fm_has_key "$f" tools; then
        why="its \`tools:\` line names no tool"
      else
        why="it carries no \`tools:\` line"
      fi
      plan_refuse "PR-10" "$(plan_path_norm "$f")" \
        "$why, so it inherits every tool and is not an overseer however it is named" \
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
  local n="$1" kind="$2" path="$3" recf="$PLAN_TMP/c/$n.rec"
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
# rendering the contracter would guess at, so plan reports it as an error. A
# pattern link that resolves to nothing is derive's `DR-R4`, already a `PR-01`.
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
# One rule for every edge — it must resolve, and its target must be stable or in
# the frontier. Navigation is dropped from the ORDERING alone, after both checks
# have run, which is why the `continue` for it sits inside the in-frontier arm.
plan_resolve_edges() {
  local uid upath ukind dkind did dpath lc state
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
    if LC_ALL=C grep -qxF "$did" "$PLAN_TMP/nodes"; then
      [ "$ukind" = "screen" ] && [ "$dkind" = "screen" ] && continue
      printf '%s\t%s\n' "$uid" "$did" >> "$PLAN_TMP/edges.tsv"
      continue
    fi
    lc="$(sdd_fm_value "$dpath" '.lifecycle')"
    case "$lc" in stable|accepted) continue ;; esac
    state="is at lifecycle \`$lc\`"
    [ -n "$lc" ] || state="declares no lifecycle"
    plan_find "PR-03" "error" "$uid" "$dpath" "$(plan_owner "$dpath")" \
      "dependency \`$did\` $state — neither stable nor in the frontier" \
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
# suite-wide set; it does not extend it. The file the list came FROM is recorded
# beside it, because that is the file `PR-07`'s remedy has to name.
plan_declared_for() {
  local key="$1" surface="$2" f="$PLAN_TMP/prof/$key.declared"
  if [ ! -f "$f" ]; then
    printf '%s' "$SDD_KB_ROOT/00_bootstrap/stack.md" > "$f.source"
    if [ "$key" = "suite" ]; then
      cp "$PLAN_TMP/stack-profiles" "$f"
    else
      plan_surface_profiles "$surface" > "$f"
      if [ -s "$f" ]; then
        printf '%s' "$SDD_KB_ROOT/00_bootstrap/surfaces.md" > "$f.source"
      else
        cp "$PLAN_TMP/stack-profiles" "$f"
      fi
    fi
  fi
  printf '%s' "$f"
}

# plan_check_profiles — PR-06 and PR-07, plus the `profiles` spool `units[]`
# renders from. The two are reported independently: a suite naming two framework
# profiles of which one has no rendering table has two defects, and suppressing
# either would hide half the repair.
plan_check_profiles() {
  local uid kind path lifecycle module surface claims key sel pid
  while IFS="$PLAN_FS" read -r uid kind path lifecycle module surface claims; do
    [ -n "$uid" ] || continue
    key="$(plan_unit_profile_key "$kind" "$surface")"
    plan_resolve_profiles "$key" "$(plan_declared_for "$key" "$surface")"
    sel="$(plan_unit_profiles "$key" "$kind")"
    while IFS= read -r pid; do
      [ -n "$pid" ] || continue
      plan_row profiles "$uid" "$pid"
    done < "$sel.set"
    plan_check_language "$uid" "$sel"
    plan_check_framework "$uid" "$kind" "$key" "$sel"
  done < "$PLAN_TMP/units.spool"
}

# plan_check_language — PR-06, one finding per resolved framework profile with
# no rendering home. Set-level was the older shape and it let a mixed suite
# resolve one framework's language and emanate every OTHER framework's units
# under it, which is the guess D5 forbids wearing a clean exit code.
plan_check_language() {
  local uid="$1" sel="$2" why fw gap miss fix
  while IFS=$'\t' read -r why fw gap; do
    [ -n "$why" ] || continue
    case "$why" in
      not-language)
        miss="names \`$gap\` as its language profile and it is not one — its \`layer:\` is not \`language\`"
        fix="point \`$fw\`'s \`language:\` at a \`layer: language\` profile" ;;
      no-language-declared)
        miss="declares no \`language:\` at all"
        fix="add a \`language:\` line to $gap naming a \`layer: language\` profile, and author that profile" ;;
      *)
        miss="names a language profile that is not there — \`$gap\`"
        fix="add $gap, or point \`$fw\`'s \`language:\` at a \`layer: language\` profile that exists" ;;
    esac
    plan_find "PR-06" "error" "$uid" "$(plan_path_norm "$gap")" "inspire-code" \
      "framework profile \`$fw\` $miss, so nothing states how a semantic type renders" \
      "declare a language profile in \`00_bootstrap/stack.md\`, or $fix"
  done < "$sel.gap"
}

# plan_check_framework — PR-07. A persona spawn is briefed with exactly ONE
# framework profile, so two say nothing about which and none says nothing at
# all. The `layer:` narrowing is what keeps the common `[react, nestjs]` suite
# out of this: a screen's frontend set is a singleton there, and only a domain
# unit — whose owning layer nothing on disk states — is left ambiguous.
plan_check_framework() {
  local uid="$1" kind="$2" key="$3" sel="$4" n want src named why miss fix target
  n="$(LC_ALL=C grep -c . "$sel.fw")"
  [ "$n" = 1 ] && return 0
  want="$(plan_unit_layer "$kind")"
  named="${want:+\`layer: $want\` }framework"
  # A screen's owning layer is readable, so its ambiguity is the operator's to
  # narrow; a domain unit's is not, and saying so is what keeps the refusal from
  # reading as a tool defect.
  why=" and nothing states which one this $kind is built under"
  [ -n "$want" ] || why="$why — the domain-versus-service partition is an ADR decision nothing on disk states"
  src="$(plan_path_norm "$(cat "$PLAN_TMP/prof/$key.declared.source")")"
  target="$src"
  if [ "$n" -gt 1 ]; then
    miss="names $n $named profiles ($(plan_id_list "$sel.fw"))$why"
    fix="declare exactly one $named profile in \`$src\`"
  elif [ -s "$PLAN_TMP/prof/$key.missing" ]; then
    target="$(plan_path_norm "$PLAN_PROFILES_ROOT")"
    miss="names no $named profile: $(plan_id_list "$PLAN_TMP/prof/$key.missing") is declared and no profile file of that name is on disk"
    fix="add the missing profile under \`$target\`, or declare a $named profile that is there in \`$src\`"
  else
    miss="names no $named profile, so nothing states how this $kind is built"
    fix="declare a $named profile in \`$src\`"
  fi
  plan_find "PR-07" "error" "$uid" "$target" "$(plan_owner "$target")" \
    "the resolved profile set $miss" "$fix"
}

# plan_id_list <file> — the ids in a one-per-line file as a backticked,
# comma-separated phrase, sorted so a message is stable across runs.
plan_id_list() {
  LC_ALL=C sort "$1" | awk '{ printf "%s`%s`", sep, $0; sep = ", " }'
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
