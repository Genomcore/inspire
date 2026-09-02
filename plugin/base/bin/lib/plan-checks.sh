#!/usr/bin/env bash
# .inspire/bin/lib/plan-checks.sh
#
# Library — the readiness catalogue. Every `PR-*` class lives here: the ten
# findings that leave a plan standing (seven of which flip it to not-ready; the
# ceiling, preflight and reachability classes are warnings), and the four
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
#   `stable` artifact is satisfied out of band and an edge to an `accepted` unit
#   outside the scope is someone else's run. A pattern and a component are units
#   like the rest since ED10, so their edges order like the rest: a screen waits
#   for its layout's and its components' wave rather than refusing over them.
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
  : > "$PLAN_TMP/nodes.all"; : > "$PLAN_TMP/idpath.tsv"; : > "$PLAN_TMP/deps.tsv"
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
  # `comm` reads both sides in order, and realization is a set difference over
  # this file. Frontier order is by path, which is not id order.
  LC_ALL=C sort -u "$PLAN_TMP/nodes.all" -o "$PLAN_TMP/nodes.all"
}

plan_ingest_one() {
  local n="$1" kind="$2" path="$3"
  local recf="$PLAN_TMP/c/$n.rec"
  local t id lifecycle module claims surface f1 f2 f3 f4
  plan_contract_records "$PLAN_TMP/c/$n.json" > "$recf"
  IFS="$PLAN_FS" read -r t id lifecycle module claims < <(head -1 "$recf")
  if [ "${t:-}" != "U" ] || [ -z "${id:-}" ]; then
    PLAN_BROKE="emanate-derive.sh produced no readable contract for $kind $path"
    return 1
  fi
  surface=""
  [ "$kind" = "screen" ] && surface="$(plan_surface_of "$path")"
  printf '%s\n' "$id" >> "$PLAN_TMP/nodes.all"
  printf '%s\t%s\n' "$id" "$path" >> "$PLAN_TMP/idpath.tsv"
  plan_row units "$id" "$kind" "$path" "$lifecycle" "$module" "$surface" "$claims"

  while IFS="$PLAN_FS" read -r t f1 f2 f3 f4; do
    case "$t" in
      R) plan_row requires "$id" "$f1" "$f2"
         printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$path" "$kind" "$f1" "$f2" >> "$PLAN_TMP/deps.tsv" ;;
      X) plan_find "PR-01" "error" "$id" "$(plan_path_norm "$f2")" \
           "$(plan_owner "$f2")" "$f3" "$f4" "$f1" ;;
      *) ;;
    esac
  done < "$recf"
}

# plan_resolve_edges — the second pass: PR-02, PR-03/04/05 and the ordering edge
# set. One rule for every edge, whatever its kind — it must resolve, and its
# target must be stable or in the frontier. Navigation is dropped from the
# ORDERING alone, after both checks have run, which is why the in-frontier arm
# leaves the layering to `plan_ordering_edges`.
#
# ED10 is what makes that one rule reach the catalog kinds. They used to be
# skipped here and answered by two bespoke readiness errors, which meant a
# screen could not emanate until its UI kit had been hand-built first. Now a
# to-extract component is a unit like any other and the screen simply WAITS for
# its wave; the error form survives only where it always belonged — a target
# that is neither delivered nor emanatable.
#
# The edge set itself is `plan_ordering_edges`', over the post-realization node
# set: which edges ORDER is one question, and the selector closures ask it too.
plan_resolve_edges() {
  local uid upath ukind dkind did dpath lc state
  plan_ordering_edges "$PLAN_TMP/nodes" > "$PLAN_TMP/edges.tsv"
  while IFS=$'\t' read -r uid upath ukind dkind did; do
    [ -n "$uid" ] || continue
    # A realized unit is out of the frontier, so its edges are nobody's
    # readiness question this run — exactly as an out-of-scope unit's are.
    LC_ALL=C grep -qxF "$uid" "$PLAN_TMP/nodes" || continue
    dpath="$(plan_dep_path "$dkind" "$did")"
    if [ -z "$dpath" ]; then
      plan_find "PR-02" "error" "$uid" "$did" "$(plan_owner "$upath")" \
        "requires \`$did\` ($dkind), which resolves to no artifact in the vault" \
        "$(plan_define_remedy "$dkind" "$did")"
      continue
    fi
    # In the frontier: the ordering was already decided above, and neither
    # lifecycle arm below applies to a unit this run is building.
    LC_ALL=C grep -qxF "$did" "$PLAN_TMP/nodes" && continue
    lc="$(plan_lifecycle_of "$dpath" "$dkind")"
    if [ "$lc" = "stable" ] && [ "$dkind" = "pattern" ]; then
      plan_check_regions "$uid" "$did" "$dpath"
      continue
    fi
    case "$lc" in stable|accepted) continue ;; esac
    case "$dkind" in
      pattern|component) plan_find_catalog "$uid" "$dkind" "$did" "$dpath"; continue ;;
    esac
    state="is at lifecycle \`$lc\`"
    [ -n "$lc" ] || state="declares no lifecycle"
    plan_find "PR-03" "error" "$uid" "$dpath" "$(plan_owner "$dpath")" \
      "dependency \`$did\` $state — neither stable nor in the frontier" \
      "$(plan_promote_remedy "$dkind" "$did" "$lc")"
  done < "$PLAN_TMP/deps.tsv"
}

# plan_find_catalog — PR-04 (component) and PR-05 (pattern): the entry's
# `**State:**` is neither `implemented` nor `to-extract`, so it is neither
# delivered nor a unit anything can emanate, and the screen naming it has
# nothing to wait for. A `to-extract` entry outside the scope is treated the way
# an out-of-scope `accepted` unit is — someone else's run.
plan_find_catalog() {
  local uid="$1" dkind="$2" did="$3" dpath="$4" owner state msg fix
  owner="$(plan_owner "$dpath")"
  state="$(sdd_catalog_state "$dpath")"
  msg="declared $dkind \`$did\` is at \`**State:** ${state:-—}\` — neither \`implemented\` nor \`to-extract\`, so it is neither delivered nor emanatable"
  fix="set its \`**State:**\` to \`to-extract\` so it enters the frontier, or to \`implemented\` once its code exists"
  # Both ids spelled out rather than picked into a variable: `test-plan-lib.sh`
  # holds the catalogue and the code to the same set of literals, and an id the
  # grep cannot see is an id the document is free to drift from.
  case "$dkind" in
    component) plan_find "PR-04" "error" "$uid" "$dpath" "$owner" "$msg" "$fix" ;;
    *)         plan_find "PR-05" "error" "$uid" "$dpath" "$owner" "$msg" "$fix" ;;
  esac
}

# plan_check_regions — PR-05's other half, and the only one an `implemented`
# pattern can reach: a delivered layout is never derived, so nothing else would
# ever notice that it declares no holes. `screen-coherence` reports the same
# shape as a warning on the pattern file; at emanation an unverifiable join is a
# rendering the contracter would guess at.
plan_check_regions() {
  local uid="$1" pid="$2" dpath="$3"
  sdd_has_section "$dpath" "Regions" && return 0
  plan_find "PR-05" "error" "$uid" "$dpath" "$(plan_owner "$dpath")" \
    "pattern \`$pid\` declares no \`## Regions\` table, so the screen-to-layout join cannot be checked" \
    "add a \`## Regions\` table to $dpath"
}

plan_define_remedy() {
  case "$1" in
    screen)            printf '/inspire_screens create %s' "$2" ;;
    pattern|component) printf '/inspire_screens extract %s %s' "$1" "$2" ;;
    *)                 printf '/inspire_domain define %s' "$2" ;;
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
    # Only per-framework repairs are offered: the check is per framework, so a
    # language profile declared in `stack.md` satisfies no branch of it and an
    # operator who does that first sees nothing change.
    plan_find "PR-06" "error" "$uid" "$(plan_path_norm "$gap")" "inspire-code" \
      "framework profile \`$fw\` $miss, so nothing states how a semantic type renders" \
      "$fix"
  done < "$sel.gap"
}

# plan_check_framework — PR-07, in two arms. A spawn is briefed with the whole
# matching SET and applies the union of its members' rules, so a suite spanning
# several layers is the ordinary case and no longer a finding (R8'). Two ties are
# left: 2+ frameworks sharing ONE `layer:`, where nothing says which of the two
# builds the unit, and an empty set, which states no architecture at all.
plan_check_framework() {
  local uid="$1" kind="$2" key="$3" sel="$4" src layer n
  src="$(plan_path_norm "$(cat "$PLAN_TMP/prof/$key.declared.source")")"
  LC_ALL=C cut -f2 "$sel.fw" | LC_ALL=C sort | LC_ALL=C uniq -d > "$sel.tied-layers"
  if [ -s "$sel.tied-layers" ]; then
    while IFS= read -r layer; do
      [ -n "$layer" ] || continue
      awk -F'\t' -v l="$layer" '$2 == l { print $1 }' "$sel.fw" > "$sel.tied"
      n="$(LC_ALL=C grep -c . "$sel.tied")"
      plan_find "PR-07" "error" "$uid" "$src" "$(plan_owner "$src")" \
        "the resolved profile set names $n \`layer: $layer\` framework profiles ($(plan_id_list "$sel.tied")) and nothing states which one this $kind is built under" \
        "declare exactly one \`layer: $layer\` framework profile in \`$src\`"
    done < "$sel.tied-layers"
    return 0
  fi
  [ -s "$sel.fw" ] && return 0
  plan_check_framework_none "$uid" "$kind" "$key" "$sel" "$src"
}

# plan_check_framework_none <uid> <kind> <key> <sel> <src> — PR-07's empty-set
# arm. An absence is not a count ambiguity: nothing was resolved to brief a spawn
# with, so the three sub-cases each name a different repair — a declared id whose
# file is missing, a declared profile on neither axis (read and discarded, which
# would otherwise read as "you declared nothing"), and a genuinely empty set.
plan_check_framework_none() {
  local uid="$1" kind="$2" key="$3" sel="$4" src="$5" want named miss fix target
  want="$(plan_unit_layer "$kind")"
  named="${want:+\`layer: $want\` }framework"
  target="$src"
  if [ -s "$PLAN_TMP/prof/$key.missing" ]; then
    target="$(plan_path_norm "$PLAN_PROFILES_ROOT")"
    miss="names no $named profile: $(plan_id_list "$PLAN_TMP/prof/$key.missing") is declared and no profile file of that name is on disk"
    fix="add the missing profile under \`$target\`, or declare a $named profile that is there in \`$src\`"
  elif [ -s "$sel.odd" ]; then
    miss="names no $named profile: $(plan_odd_list "$sel.odd") was read and discarded, naming neither a framework layer nor \`language\`"
    fix="correct that profile's \`layer:\`, or declare a $named profile in \`$src\`"
  else
    miss="names no $named profile, so nothing states how this $kind is built"
    fix="declare a $named profile in \`$src\`"
  fi
  plan_find "PR-07" "error" "$uid" "$target" "$(plan_owner "$target")" \
    "the resolved profile set $miss" "$fix"
}

# plan_id_list <file> — the ids in the FIRST tab-separated column as a
# backticked, comma-separated phrase, sorted so a message is stable across runs.
plan_id_list() {
  LC_ALL=C sort "$1" | awk -F'\t' '{ printf "%s`%s`", sep, $1; sep = ", " }'
}

# plan_odd_list <file> — the same for `id<TAB>layer` records, each carrying the
# layer that got it discarded, since that is what the operator has to correct.
plan_odd_list() {
  LC_ALL=C sort "$1" | awk -F'\t' '
    { printf "%s`%s` (%s)", sep, $1, ($2 == "" ? "no `layer:`" : "`layer: " $2 "`")
      sep = ", " }'
}

# plan_check_preflight — PR-22, and the `preflight` / `wire_conventions` spools
# the plan renders them from (ED11-R5/R6). Both blocks are reporting: an
# undecided wire row is a RECORDED decision (the convention's own default
# applies), so there is nothing there to refuse.
#
# PR-22 is the one finding, and a warning: components declared with no profile
# able to probe them means an unattended run would read a connection error as
# red, burn the unit's whole rework budget proving nothing, then cascade the
# stall. Learning that at t=0 costs a warning; learning it after a four-hour run
# costs the run. Plan itself never probes and never starts anything — the probe
# is stack-specific and therefore profile-owned.
plan_check_preflight() {
  local name purpose decision answer id n
  plan_test_components > "$PLAN_TMP/components.tsv"
  plan_probe_profiles  > "$PLAN_TMP/probes"
  while IFS=$'\t' read -r name purpose; do
    [ -n "$name" ] || continue
    plan_row components "$name" "$purpose"
  done < "$PLAN_TMP/components.tsv"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    plan_row probes "$id"
  done < "$PLAN_TMP/probes"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    plan_row wireids "$id"
  done < <(plan_wire_ids)
  while IFS=$'\t' read -r decision answer; do
    [ -n "$decision" ] || continue
    plan_row wirerows "$decision" "$answer"
  done < <(plan_wire_rows)

  [ -s "$PLAN_TMP/components.tsv" ] || return 0
  [ -s "$PLAN_TMP/probes" ] && return 0
  n="$(LC_ALL=C grep -c . "$PLAN_TMP/components.tsv")"
  plan_find "PR-22" "warning" "" \
    "$(plan_path_norm "$SDD_KB_ROOT/00_bootstrap/stack.md")" "inspire-bootstrap" \
    "the stack declares $n test-infrastructure component(s) ($(plan_id_list "$PLAN_TMP/components.tsv")) and no resolved framework profile carries a \`## Test infrastructure\` probe recipe, so nothing can tell a healthy component from a suite that never ran" \
    "add a \`## Test infrastructure\` section to a resolved framework profile under \`$(plan_path_norm "$PLAN_PROFILES_ROOT")\`, or remove the components that no longer apply"
}

# plan_check_ceiling — PR-20. A warning, never a blocker: D11 gives a low
# ceiling partial-but-reported delivery in graph order, so it never flips
# `ready` and a run whose only finding is this one exits 0.
# The ceiling is measured against the floor the run actually has to reach, which
# a `--goal` shortens: a ceiling that covers the goal is not under-budgeted just
# because some deeper unit is also in scope.
plan_check_ceiling() {
  [ -n "$PLAN_CEILING" ] || return 0
  [ "$PLAN_CEILING" -lt "$PLAN_EFFECTIVE_FLOOR" ] || return 0
  plan_find "PR-20" "warning" "" "" "" \
    "the declared ceiling of $PLAN_CEILING wave(s) is below the floor of $PLAN_EFFECTIVE_FLOOR — delivery will be partial, in graph order" \
    "raise --ceiling to $PLAN_EFFECTIVE_FLOOR, or accept partial-but-reported delivery"
}

# plan_closure_screens — the goal closure's screen ids, sorted. The kind comes
# from the join of `idpath.tsv` with `scanned.tsv`, never from the path: a
# pattern and a component live under `05_screens/` too.
plan_closure_screens() {
  awk -F'\t' -v scanf="$PLAN_TMP/scanned.tsv" -v idpathf="$PLAN_TMP/idpath.tsv" '
    FILENAME == scanf   { if ($2 == "screen") screen[$1] = 1; next }
    FILENAME == idpathf { if ($2 in screen) sid[$1] = 1; next }
    $1 in sid
  ' "$PLAN_TMP/scanned.tsv" "$PLAN_TMP/idpath.tsv" "$PLAN_TMP/goal.closure"
}

# plan_check_reachable — PR-23. The frontier and the disk are the whole of what
# is consulted, and neither omission loses an entry: a delivered screen that
# must GAIN a nav link is itself work and therefore in the frontier, and a
# `draft` is not emanated. What is left is a slice every screen of which is
# linked only from inside it — a rootless cycle.
plan_check_reachable() {
  local screens first
  [ -n "$PLAN_GOAL" ] || return 0
  plan_closure_screens > "$PLAN_TMP/goal.screens"
  [ -s "$PLAN_TMP/goal.screens" ] || return 0
  # On disk, not run-scoped: a `--reemanate` rebuild does not un-deliver a page.
  LC_ALL=C comm -12 "$PLAN_TMP/goal.screens" "$PLAN_TMP/realized.delivered" \
    | LC_ALL=C grep -q . && return 0
  # A nav root — nothing in the frontier navigates to it — is the app's entry.
  awk -F'\t' -v screensf="$PLAN_TMP/goal.screens" '
    FILENAME == screensf { s[$1] = 1; next }
    $2 in s { print $2 }
  ' "$PLAN_TMP/goal.screens" "$PLAN_TMP/nav.all" \
    | LC_ALL=C sort -u > "$PLAN_TMP/goal.reached"
  LC_ALL=C comm -23 "$PLAN_TMP/goal.screens" "$PLAN_TMP/goal.reached" \
    | LC_ALL=C grep -q . && return 0
  screens="$(awk '{ printf "%s`%s`", sep, $0; sep = ", " }' "$PLAN_TMP/goal.screens")"
  # No single screen is at fault, so the target is the slice's first by id.
  first="$(plan_path_norm \
    "$(plan_index_lookup "$PLAN_TMP/idpath.tsv" "$(head -1 "$PLAN_TMP/goal.screens")")")"
  plan_find "PR-23" "warning" "" "$first" "$(plan_owner "$first")" \
    "the goal \`$PLAN_GOAL\` resolves a slice whose screens ($screens) have no navigable entry — every link in comes from inside the slice, and none of them is already delivered, so the run would build pages with no way in" \
    "author a navigation binding into one of those screens from a screen this run can see — one already in the frontier, or a delivered one promoted back to \`accepted\`, since editing it to carry the link is itself work; widening the goal cannot fix it, as a goal already pulls in every screen that navigates to it"
}
