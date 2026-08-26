#!/usr/bin/env bash
# .inspire/bin/lib/derive-refusals.sh
#
# Library — the strict parser's refusal half (design D7). Sourced after
# `_lib.sh`, `_keyed-heads.sh` and `derive-json.sh`.
#
# ONE DEFINITION PER REFUSAL CLASS, and the mechanism is the point. Every
# `OS-*` class already has exactly one implementation — the review rule that
# owns it — so derive does not re-implement one. It RUNS those rules over the
# unit's own directory and reads their JSON findings back off stderr, filtered
# to the artifacts this derivation must read. A class therefore cannot drift
# between the gate and the review: there is one check, and both callers see the
# same finding. What derive adds is only the POSTURE: it refuses on the class
# whatever severity the rule reported it at, so the 0.8 grace on the five
# presence classes (`_keyed-heads.sh` § Severity) never softens the gate, and
# `W-1` — a prose heuristic — is never a refusal.
#
# The rules consulted, by unit kind, and nothing else:
#   entity, action  keys-present · constraints-mechanics · head-referents ·
#                   sections-present
#   screen          screen-coherence · sections-present
# Everything else `review.sh` runs is readiness, which the `plan` script owns.
#
# NOTHING A CONSULTED RULE REPORTS AGAINST THIS UNIT IS EVER IGNORED. A message
# carrying an `OS-*` prefix is filed under that class; the rest are mapped by
# `derive_class_of` to a `DR-*` id this package owns; anything neither is filed
# under `DR-U1` rather than dropped. A silent pass is the one outcome a strict
# parser may not produce, so an unrecognised finding refuses too.
#
# The `DR-*` catalogue — ids, meanings and remedies — is in
# `.claude/skills/_references/derived-contract.md`. The `OS-*` catalogue is
# `_references/keyed-heads.md`'s and is never copied.

DERIVE_RULES_DOMAIN="keys-present constraints-mechanics head-referents sections-present"
DERIVE_RULES_SCREEN="screen-coherence sections-present"

# derive_refuse <class> <target> <message> <remedy>
derive_refuse() {
  derive_row refused "$1" "$2" "$(derive_norm "$3")" "$4"
}

# derive_remedy <path> — the touch command for the skill that owns the file,
# looked up in the target map the caller built (path -> id -> kind).
derive_remedy() {
  local path="$1" id kind
  id="$(awk -F'\t' -v p="$path" '$1 == p { print $2; exit }' "$DERIVE_TMP/targets.tsv")"
  kind="$(awk -F'\t' -v p="$path" '$1 == p { print $3; exit }' "$DERIVE_TMP/targets.tsv")"
  case "$kind" in
    screen) printf '/inspire_screens update %s' "$id" ;;
    *)      printf '/inspire_domain update %s' "$id" ;;
  esac
}

# derive_target <path> <id> <kind> — register an artifact this derivation reads.
# A finding against anything else is another unit's business.
#
# The path is normalised through `sdd_scope_norm`, and so is a finding's own
# `target` before the two are compared: a rule normalises the scope it is given
# and reports `spec/sdd/…` however it was spelled, so `./spec/sdd/…` on derive's
# side would match nothing and every refusal would read as acceptance.
derive_target() {
  printf '%s\t%s\t%s\n' "$(sdd_scope_norm "$1")" "$2" "$3" >> "$DERIVE_TMP/targets.tsv"
}

# derive_class_of <rule> <message> — the class id a finding belongs to. The
# `OS-*` prefix wins wherever a rule carries one; the table below is only for
# the shapes whose rules predate any catalogue.
derive_class_of() {
  local rule="$1" msg="$2"
  case "$msg" in
    OS-[A-Z][0-9]*:*) printf '%s' "${msg%%:*}"; return 0 ;;
    W-1:*)            return 1 ;;
  esac
  case "$rule" in
    screen-coherence)
      case "$msg" in
        "screen missing frontmatter field(s)"*)      printf 'DR-S1' ;;
        "invalid screen lifecycle value"*|"screen id shape"*|\
        "screen module mismatch"*|"screen superseded without"*|\
        "superseded_by target does not resolve"*|"duplicate screen id"*|\
        "route collision"*)                          printf 'DR-S2' ;;
        "screen carries an authored route"*)         printf 'DR-S3' ;;
        "binding rows sit under no subsection"*|\
        "unknown bindings subsection"*)              printf 'DR-S6' ;;
        "binding row has no key"*|"duplicate binding key"*) printf 'DR-S7' ;;
        "unresolved outcome"*|"navigate outcome is route-shaped"*) printf 'DR-S8' ;;
        "navigation target is"*)                     printf 'DR-S9' ;;
        "state not anchored"*)                       printf 'DR-S10' ;;
        "pattern join:"*)                            printf 'DR-S11' ;;
        "stable screen declares a to-extract component"*) printf 'DR-S12' ;;
        *)                                           printf 'DR-U1' ;;
      esac ;;
    sections-present)
      case "$msg" in
        "screen file missing required part(s)"*|"screen file has empty section(s)"*) printf 'DR-S4' ;;
        "screen file carries a retired section"*)    printf 'DR-S5' ;;
        *" missing required section"*|*" has empty section"*) printf 'DR-D1' ;;
        *)                                           printf 'DR-U1' ;;
      esac ;;
    *) printf 'DR-U1' ;;
  esac
}

# The sweep is SPLIT so that it overlaps the derivation instead of following it.
# Both halves cost roughly the same, they need nothing from each other until the
# filtering step, and a derivation that ran them in sequence would pay for both
# — measured at 1.06 s against 0.65 s overlapped, per unit, every time.
DERIVE_SWEEP_JOBS=0
DERIVE_SWEEP_DIRS=""

# derive_sweep_start <kind> <dir>...
#   Launches the consulted rules over each directory, once per directory it has
#   not already covered. Callable again as derivation discovers a document in a
#   directory the first call did not reach — an action's touched entity in
#   another module.
derive_sweep_start() {
  local kind="$1" rules rule dir
  shift
  case "$kind" in
    screen) rules="$DERIVE_RULES_SCREEN" ;;
    *)      rules="$DERIVE_RULES_DOMAIN" ;;
  esac
  for dir in "$@"; do
    [ -n "$dir" ] || continue
    case "$DERIVE_SWEEP_DIRS" in *"|$dir|"*) continue ;; esac
    DERIVE_SWEEP_DIRS="$DERIVE_SWEEP_DIRS|$dir|"
    for rule in $rules; do
      DERIVE_SWEEP_JOBS=$((DERIVE_SWEEP_JOBS + 1))
      bash "$DERIVE_BIN/$rule.sh" "$dir" >/dev/null 2>"$DERIVE_TMP/sweep.$DERIVE_SWEEP_JOBS" &
    done
  done
}

# derive_sweep_collect <kind>
#   Waits for the launched rules, covers any directory a target reached that the
#   first launch did not, and refuses on every finding aimed at a registered
#   target. Filtering happens here, with the target list complete.
derive_sweep_collect() {
  local kind="$1" path dir f_rule f_sev f_target f_msg class
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in */*) dir="${path%/*}" ;; *) dir="." ;; esac
    case "$DERIVE_SWEEP_DIRS" in *"|$dir|"*) ;; *) derive_sweep_start "$kind" "$dir" ;; esac
  done < <(cut -f1 "$DERIVE_TMP/targets.tsv")
  wait

  cat "$DERIVE_TMP"/sweep.* 2>/dev/null \
    | jq -r --arg fs "$DERIVE_FS" 'select(type == "object")
        | [.rule, .severity, .target, .message] | join($fs)' 2>/dev/null \
    | LC_ALL=C sort -u > "$DERIVE_TMP/findings"

  while IFS="$DERIVE_FS" read -r f_rule f_sev f_target f_msg; do
    [ -n "$f_target" ] || continue
    f_target="$(sdd_scope_norm "$f_target")"
    awk -F'\t' -v p="$f_target" '$1 == p { f = 1; exit } END { exit !f }' \
      "$DERIVE_TMP/targets.tsv" || continue
    class="$(derive_class_of "$f_rule" "$f_msg")" || continue
    derive_refuse "$class" "$f_target" "$f_msg" "$(derive_remedy "$f_target")"
  done < "$DERIVE_TMP/findings"
}
