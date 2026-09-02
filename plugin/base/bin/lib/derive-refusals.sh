#!/usr/bin/env bash
# .inspire/bin/lib/derive-refusals.sh
#
# Library — the strict parser's refusal half (design D7). Sourced after
# `_lib.sh`, `_keyed-heads.sh` and `derive-json.sh`. It carries: the refusal
# spool and its remedies, the target registry a finding is filtered against,
# `derive_class_of` (the message-to-class map), and the rule sweep.
#
# Derive re-implements no check. It RUNS the rule that owns each `OS-*` class
# and reads its findings back, so a class cannot drift between the gate and the
# review; what derive adds is the posture — it refuses whatever severity the
# rule reported, and `W-1` alone is never a refusal. The argument, the rules
# consulted per kind, and the `DR-*` catalogue are in
# `.claude/skills/_references/derived-contract.md` § "How the classes are
# checked". The `OS-*` catalogue is `_references/keyed-heads.md`'s, never copied.

# Consumers that source these units instead of running the entry get the same
# default the entry sets: the directory holding the rules is the one above lib/.
: "${DERIVE_BIN:=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"

DERIVE_RULES_DOMAIN="keys-present constraints-mechanics head-referents sections-present"
DERIVE_RULES_SCREEN="screen-coherence sections-present"
# A catalog entry's own shape is owned by NO review rule — `screen-coherence`
# reaches a pattern only through an adopting screen, and a pattern-scoped run
# has no screen to reach it from. So the catalog kinds consult none, and their
# `DR-C*` classes are the whole of the strictness rather than half of it.
DERIVE_RULES_CATALOG=""

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
    screen)            printf '/inspire_screens update %s' "$id" ;;
    component|pattern) printf '/inspire_screens extract %s %s' "$kind" "$id" ;;
    *)                 printf '/inspire_domain update %s' "$id" ;;
  esac
}

# derive_target <path> <id> <kind> — register an artifact this derivation reads.
# Normalised, as a finding's own `target` is before the two are compared: a rule
# reports `spec/sdd/…` however its scope was spelled, so `./spec/sdd/…` here
# would match nothing and every refusal would read as acceptance.
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
        *" section order:"*)                         printf 'DR-D2' ;;
        *)                                           printf 'DR-U1' ;;
      esac ;;
    *) printf 'DR-U1' ;;
  esac
}

# The sweep is SPLIT to overlap the derivation: 0.65 s against 1.06 s in
# sequence, per unit. It is also the strictness, so a rule that is missing, that
# dies, or that prints anything but a finding is an integrity failure here —
# each of the three used to disable every class in silence.
DERIVE_SWEEP_JOBS=0
DERIVE_SWEEP_DIRS=""

derive_sweep_rules() {
  case "$1" in
    screen)            printf '%s' "$DERIVE_RULES_SCREEN" ;;
    component|pattern) printf '%s' "$DERIVE_RULES_CATALOG" ;;
    *)                 printf '%s' "$DERIVE_RULES_DOMAIN" ;;
  esac
}

# derive_sweep_require <kind>
#   Every rule this kind consults is present and executable. They are required
#   tools for derive exactly as `jq` is — an operator may legitimately delete a
#   validator, and derive may not answer "clean" when it did.
derive_sweep_require() {
  local rule missing=""
  for rule in $(derive_sweep_rules "$1"); do
    if [ ! -f "$DERIVE_BIN/$rule.sh" ] || [ ! -x "$DERIVE_BIN/$rule.sh" ]; then
      missing="${missing:+$missing }$rule.sh"
    fi
  done
  [ -z "$missing" ] && return 0
  echo "error: missing or non-executable rule script(s): $missing" >&2
  echo "       derive checks each OS-* class by running the rule that owns it" >&2
  return 1
}

# derive_sweep_start <kind> <dir>...
#   Launches the consulted rules over each directory, once per directory it has
#   not already covered. Callable again as derivation discovers a document in a
#   directory the first call did not reach — an action's touched entity in
#   another module.
derive_sweep_start() {
  local kind="$1" rule dir
  shift
  for dir in "$@"; do
    [ -n "$dir" ] || continue
    case "$DERIVE_SWEEP_DIRS" in *"|$dir|"*) continue ;; esac
    DERIVE_SWEEP_DIRS="$DERIVE_SWEEP_DIRS|$dir|"
    for rule in $(derive_sweep_rules "$kind"); do
      DERIVE_SWEEP_JOBS=$((DERIVE_SWEEP_JOBS + 1))
      bash "$DERIVE_BIN/$rule.sh" "$dir" >/dev/null 2>"$DERIVE_TMP/sweep.$DERIVE_SWEEP_JOBS" &
      printf '%s%s%s%s%s\n' "$DERIVE_SWEEP_JOBS" "$DERIVE_FS" "$rule" "$DERIVE_FS" "$!" \
        >> "$DERIVE_TMP/jobs"
    done
  done
}

# derive_sweep_broke <rule> <message>
derive_sweep_broke() {
  derive_refuse "DR-U1" "$U_PATH" \
    "DR-U1: the sweep could not trust \`$1.sh\`: $2" \
    "check .inspire/bin/$1.sh — derive refuses rather than report a class it did not check"
}

# derive_sweep_collect <kind>
#   Waits for every launched rule, covers any directory a target reached that the
#   first launch did not, checks each job's integrity, and refuses on every
#   finding aimed at a registered target. Filtering happens here, with the target
#   list complete.
derive_sweep_collect() {
  local kind="$1" path dir idx rule pid status
  local rectype tag f_sev f_target f_msg f_rule class
  # A kind that consults no rule has nothing to wait for and no findings to
  # filter — and `jobs` was never created, which is not a broken run.
  [ -n "$(derive_sweep_rules "$kind")" ] || return 0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in */*) dir="${path%/*}" ;; *) dir="." ;; esac
    case "$DERIVE_SWEEP_DIRS" in *"|$dir|"*) ;; *) derive_sweep_start "$kind" "$dir" ;; esac
  done < <(cut -f1 "$DERIVE_TMP/targets.tsv")

  # Each line is tagged with the rule and the job that produced it, so an
  # unparseable one can name its author. A whitespace-only line is dropped
  # rather than refused: no rule emits one, and a stray newline is not a defect.
  : > "$DERIVE_TMP/sweeplines"
  : > "$DERIVE_TMP/status"
  while IFS="$DERIVE_FS" read -r idx rule pid; do
    [ -n "$idx" ] || continue
    wait "$pid"
    status=$?
    printf '%s%s%s%s%s\n' "$idx" "$DERIVE_FS" "$rule" "$DERIVE_FS" "$status" \
      >> "$DERIVE_TMP/status"
    awk -v tag="$rule:$idx" -v fs="$DERIVE_FS" \
      '{ line = $0; gsub(/[ \t\r]/, "", line); if (line != "") print tag fs $0 }' \
      "$DERIVE_TMP/sweep.$idx" >> "$DERIVE_TMP/sweeplines"
  done < "$DERIVE_TMP/jobs"

  jq -rR --arg fs "$DERIVE_FS" '
      (index($fs)) as $i
      | .[0:$i] as $tag
      | .[$i+1:] as $body
      | ($body | fromjson? // null) as $o
      | if ($o | type) == "object" and ($o.target? != null) and ($o.message? != null)
        then ["F", $tag, ($o.severity // ""), $o.target, $o.message]
        else ["X", $tag, "", "", $body] end
      | join($fs)
    ' "$DERIVE_TMP/sweeplines" | LC_ALL=C sort -u > "$DERIVE_TMP/findings"

  # A rule that exited anything but 0 (clean) or 1 (errors found) died; a rule
  # that claims errors and produced no finding is telling us two different
  # things. Either way derive did not check that rule's classes.
  while IFS="$DERIVE_FS" read -r idx rule status; do
    [ -n "$idx" ] || continue
    case "$status" in
      0) ;;
      1) awk -F"$DERIVE_FS" -v t="$rule:$idx" '$1 == "F" && $2 == t { f = 1; exit } END { exit !f }' \
           "$DERIVE_TMP/findings" \
           || derive_sweep_broke "$rule" "it reported errors and printed no finding" ;;
      *) derive_sweep_broke "$rule" "it exited $status" ;;
    esac
  done < "$DERIVE_TMP/status"

  while IFS="$DERIVE_FS" read -r rectype tag f_sev f_target f_msg; do
    f_rule="${tag%%:*}"
    if [ "$rectype" = "X" ]; then
      derive_sweep_broke "$f_rule" "it printed a line that is not a finding: $f_msg"
      continue
    fi
    [ -n "$f_target" ] || continue
    f_target="$(sdd_scope_norm "$f_target")"
    awk -F'\t' -v p="$f_target" '$1 == p { f = 1; exit } END { exit !f }' \
      "$DERIVE_TMP/targets.tsv" || continue
    class="$(derive_class_of "$f_rule" "$f_msg")" || continue
    derive_refuse "$class" "$f_target" "$f_msg" "$(derive_remedy "$f_target")"
  done < "$DERIVE_TMP/findings"
}
