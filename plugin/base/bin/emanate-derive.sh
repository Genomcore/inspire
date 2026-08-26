#!/usr/bin/env bash
# .inspire/bin/emanate-derive.sh
#
# derive — a unit's KB artifacts -> the DERIVED CONTRACT, on stdout, as JSON
# (D5/D7/D8). One of the emanation loop's four independent bin scripts (derive,
# plan, gate, harvest); the shared bulk lives in `lib/derive-{json,types,
# refusals,domain,screen}.sh`, sourceable on its own — the reuse surface `plan`
# and `gate` compose on.
#
# STRICT, AND THAT IS THE ONE NEW BEHAVIOUR IN THE LOOP (D7): an old shape is a
# DERIVATION ERROR naming the skill to touch the artifact with, never a
# silently-empty section, and never softened by the 0.8 lifecycle grace review
# gives the five presence classes. Each `OS-*` class is checked by RUNNING the
# rule that owns it, so no class has a second implementation here to drift from
# the one review uses.
#
# The JSON shape field by field, the claim ids, the fingerprint rule and the
# `DR-*` classes: `.claude/skills/_references/derived-contract.md`.
#
# Usage:
#   emanate-derive.sh <kind> <id>
#   emanate-derive.sh <kind> --file <path>
#
#   <kind>    entity | action | screen. The positional kind is not redundant
#             with the id: a 2-segment id is an entity OR a screen, and a
#             3-segment id an action OR a collision-minted screen.
#   <id>      the artifact's own id — `auth.user`, `auth.user.create`,
#             `users.list`, `admin.users.list`. The colon display form is
#             accepted and read as the dotted one.
#   --file    the artifact's path, in place of <id>; the kind is still given.
#             The plan tool usually holds the path already.
#
# Roots, as everywhere in base/bin/: the current working directory is the repo
# root; $SDD_SPEC_ROOT (default inspire_kb/04_domain) is the domain tree and
# $SDD_KB_ROOT (default inspire_kb) is the KB as a whole. BOTH are required even
# for a domain kind: the project's own semantic types live under $SDD_KB_ROOT,
# and a type that cannot be resolved is a refusal rather than a guess.
#
# Exit codes — distinct and documented, never a generic catch-all:
#   0    derived. The contract is on stdout.
#   2    usage — bad kind, missing id, unknown flag, both an id and --file.
#   3    unit not found: no artifact of THAT KIND carries that id, or the
#        --file path does not exist or is not an artifact of that kind. The
#        kind is asserted from the artifact itself (the `_lib.sh` finders), so
#        `action auth.user` and a pattern entry passed as `action --file` are
#        both 3 rather than an empty contract. A screen sitting deeper than
#        05_screens/{surface}/{module}/{screen}.md lands here too — the screen
#        finders do not reach past that depth, so nothing in the vault can see
#        it.
#   4    REFUSED. The artifact, or a document it must read to derive (an
#        action's touched entity documents), is old-shape or otherwise
#        underivable. Stdout carries every refusal class found, not the first.
#   5    roots missing — $SDD_KB_ROOT, or $SDD_SPEC_ROOT for a domain kind, is
#        not a directory. This is not a knowledge base.
#   127  a required tool is missing (jq, yq, or a sha256 digest).
#
# Stdout is JSON on every one of those exits that produces a verdict:
#   exit 0  the contract
#   exit 4  {"schema", "unit": {…}, "refused": [{class, target, message,
#           remedy}, …]} — and no `claims` key, because a refused unit makes
#           no claims. `plan` aggregates these objects and must never parse
#           stderr.
# Stderr carries the grouped human report, the `--mode plan` ethos.
#
# WRITES NOTHING. No file, no log, no KB edit, no git state — a scratch
# directory under $TMPDIR is all, and the EXIT trap removes it.

set -uo pipefail

EXIT_OK=0
EXIT_USAGE=2
EXIT_NOT_FOUND=3
EXIT_REFUSED=4
EXIT_NO_ROOTS=5
EXIT_MISSING_TOOL=127

DERIVE_SCHEMA="inspire.derived-contract/1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DERIVE_BIN="$SCRIPT_DIR"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_keyed-heads.sh"
source "$SCRIPT_DIR/lib/derive-json.sh"
source "$SCRIPT_DIR/lib/derive-types.sh"
source "$SCRIPT_DIR/lib/derive-refusals.sh"
source "$SCRIPT_DIR/lib/derive-domain.sh"
source "$SCRIPT_DIR/lib/derive-screen.sh"

usage() {
  echo "usage: emanate-derive.sh <entity|action|screen> <id>" >&2
  echo "       emanate-derive.sh <entity|action|screen> --file <path>" >&2
  exit "$EXIT_USAGE"
}

KIND=""; UNIT_ARG=""; UNIT_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file) [ $# -ge 2 ] || usage; UNIT_FILE="$2"; shift 2 ;;
    --file=*) UNIT_FILE="${1#--file=}"; shift ;;
    -h|--help) usage ;;
    -*) echo "emanate-derive.sh: unknown option $1" >&2; usage ;;
    *)
      if [ -z "$KIND" ]; then KIND="$1"
      elif [ -z "$UNIT_ARG" ]; then UNIT_ARG="$1"
      else echo "emanate-derive.sh: unexpected argument $1" >&2; usage
      fi
      shift ;;
  esac
done

case "$KIND" in entity|action|screen) ;; *) usage ;; esac
[ -n "$UNIT_ARG" ] && [ -n "$UNIT_FILE" ] && usage
[ -z "$UNIT_ARG" ] && [ -z "$UNIT_FILE" ] && usage

sdd_require_tools || exit "$EXIT_MISSING_TOOL"
derive_sweep_require "$KIND" || exit "$EXIT_MISSING_TOOL"
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
  echo "error: missing required tool: sha256sum or shasum" >&2
  exit "$EXIT_MISSING_TOOL"
fi

[ -d "$SDD_KB_ROOT" ] || {
  echo "emanate-derive.sh: \$SDD_KB_ROOT ($SDD_KB_ROOT) is not a directory — not a knowledge base" >&2
  exit "$EXIT_NO_ROOTS"; }
case "$KIND" in
  entity|action)
    [ -d "$SDD_SPEC_ROOT" ] || {
      echo "emanate-derive.sh: \$SDD_SPEC_ROOT ($SDD_SPEC_ROOT) is not a directory — not a knowledge base" >&2
      exit "$EXIT_NO_ROOTS"; } ;;
esac

derive_scratch >/dev/null || exit "$EXIT_MISSING_TOOL"
trap 'rm -rf "$DERIVE_TMP"' EXIT
: > "$DERIVE_TMP/targets.tsv"
derive_init_spools requires claims refused

# ─────────────────────────────────────────────────────────────────────────────
# Locating the unit — by path convention for a domain id, by the id index for a
# screen, whose id is minted write-once and never re-derived from location (A12).
# ─────────────────────────────────────────────────────────────────────────────

not_found() {
  echo "emanate-derive.sh: no $KIND carries id '$1'" >&2
  if [ "$KIND" = "screen" ]; then
    echo "  (a screen deeper than 05_screens/{surface}/{module}/{screen}.md is not reachable by the screen finders, so it cannot be found by id either)" >&2
  fi
  exit "$EXIT_NOT_FOUND"
}

# domain_path_for <id> — {module}/{entity}/{id}.md, the one layout both domain
# kinds share; the segment count in the leaf name is what tells them apart.
domain_path_for() {
  local id="$1" rest="${1#*.}"
  printf '%s/%s/%s/%s.md' "$SDD_SPEC_ROOT" "${id%%.*}" "${rest%%.*}" "$id"
}

# domain_scan <id> — the descriptor or document whose frontmatter `id` is that
# id, wherever it sits. The fallback for a file whose name and id diverge; only
# ever walked when the convention missed.
domain_scan() {
  local id="$1" f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ "$(kh_dotted "$(sdd_fm_value "$f" '.id')")" = "$id" ] && { printf '%s' "$f"; return 0; }
  done < <(if [ "$KIND" = entity ]; then sdd_find_entities "$SDD_SPEC_ROOT"; else sdd_find_actions "$SDD_SPEC_ROOT"; fi)
  return 1
}

# kind_holds <path> <kind> — exit 0 when the finder for that kind reaches that
# path. The finders in `_lib.sh` are the one definition of what an entity, an
# action and a screen file are, so asking them is what stops `action auth.user`
# — or a pattern entry passed as `action --file` — from rendering an empty
# contract with a clean exit.
kind_holds() {
  local path="$1" want="$2"
  case "$want" in
    screen)
      derive_screen_index
      awk -F'\t' -v p="$path" '$1 == p { f = 1; exit } END { exit !f }' \
        "$DERIVE_TMP/screens.tsv" ;;
    entity) sdd_find_entities "$SDD_SPEC_ROOT" | grep -qxF "$path" ;;
    action) sdd_find_actions "$SDD_SPEC_ROOT" | grep -qxF "$path" ;;
  esac
}

U_PATH=""
if [ -n "$UNIT_FILE" ]; then
  [ -f "$UNIT_FILE" ] || { echo "emanate-derive.sh: no such file: $UNIT_FILE" >&2; exit "$EXIT_NOT_FOUND"; }
  U_PATH="$UNIT_FILE"
else
  U_ARG_DOTTED="$(kh_dotted "$UNIT_ARG")"
  case "$KIND" in
    screen)
      derive_screen_index
      U_PATH="$(derive_screen_by_id "$U_ARG_DOTTED")"
      [ -n "$U_PATH" ] || not_found "$U_ARG_DOTTED" ;;
    *)
      U_PATH="$(domain_path_for "$U_ARG_DOTTED")"
      if [ ! -f "$U_PATH" ]; then
        U_PATH="$(domain_scan "$U_ARG_DOTTED")" || not_found "$U_ARG_DOTTED"
      fi ;;
  esac
fi

if ! kind_holds "$(sdd_scope_norm "$U_PATH")" "$KIND"; then
  if [ -n "$UNIT_FILE" ]; then
    echo "emanate-derive.sh: $U_PATH is not a $KIND artifact" >&2
  else
    echo "emanate-derive.sh: no $KIND carries id '$UNIT_ARG'" >&2
  fi
  [ "$KIND" = "screen" ] && echo "  (a screen deeper than 05_screens/{surface}/{module}/{screen}.md is not reachable by the screen finders)" >&2
  exit "$EXIT_NOT_FOUND"
fi

# One spelling from here on. `sdd_scope_norm` is the same normalizer the rules
# put their scope through, so derive's path and a finding's `target` are
# comparable however the operator spelled either.
U_PATH="$(sdd_scope_norm "$U_PATH")"

# ─────────────────────────────────────────────────────────────────────────────
# Identity
# ─────────────────────────────────────────────────────────────────────────────

U_ID="$(kh_dotted "$(derive_fm_scalar "$U_PATH" id)")"
U_LIFECYCLE="$(derive_fm_scalar "$U_PATH" lifecycle)"
U_MODULE="$(derive_fm_scalar "$U_PATH" module)"
U_ENTITY="$(derive_fm_scalar "$U_PATH" entity)"
U_ACTION="$(derive_fm_scalar "$U_PATH" action)"
U_SCREEN="$(derive_fm_scalar "$U_PATH" screen)"

# An id-less artifact is an old shape, not an unnameable one: it still has to
# appear in the refusal object under a name the operator recognizes, so the
# filename stem stands in — for a screen, positionally, which is exactly the
# identity A12 replaced.
if [ -z "$U_ID" ]; then
  U_ID="$(basename "$U_PATH" .md)"
  [ "$KIND" = "screen" ] && U_ID="$(basename "$(dirname "$U_PATH")").$U_ID"
fi
[ -n "$U_MODULE" ] || U_MODULE="${U_ID%%.*}"
[ "$KIND" = "screen" ] && [ -z "$U_SCREEN" ] && U_SCREEN="${U_ID##*.}"
[ "$KIND" = "action" ] && [ -z "$U_ACTION" ] && U_ACTION="${U_ID##*.}"
if [ -z "$U_ENTITY" ] && [ "$KIND" != "screen" ]; then
  U_ENTITY="${U_ID#*.}"; U_ENTITY="${U_ENTITY%%.*}"
fi
U_ROUTE="/$U_MODULE/$U_SCREEN"

derive_target "$U_PATH" "$U_ID" "$KIND"

# ─────────────────────────────────────────────────────────────────────────────
# Derivation and the sweep run TOGETHER; collect covers whatever directory the
# derivation reached that the first launch did not, then files every class found.
# ─────────────────────────────────────────────────────────────────────────────

# Declared before the branch below because `set -u` makes an unset variable
# fatal and each of these is assigned by one kind's deriver only.
U_PATTERN_ID=""; U_PATTERN_PATH=""; U_OUTPUT_ENTITY=""

derive_sweep_start "$KIND" "$(dirname "$U_PATH")"
case "$KIND" in
  entity) derive_entity "$U_PATH" "$U_ID" ;;
  action) derive_action "$U_PATH" "$U_ID" ;;
  screen) derive_screen "$U_PATH" "$U_ID" ;;
esac
derive_sweep_collect "$KIND"

U_PURPOSE="$(derive_norm "$(sdd_body_prose "$DERIVE_TMP/unit.md" "Purpose")")"

LC_ALL=C sort -u "$DERIVE_TMP/requires.spool" -o "$DERIVE_TMP/requires.spool"
derive_hash_claims

# ─────────────────────────────────────────────────────────────────────────────
# Verdict
# ─────────────────────────────────────────────────────────────────────────────

report_refusals() {
  local class target message remedy last=""
  {
    printf 'REFUSED %s %s (%s)\n' "$KIND" "$U_ID" "$U_PATH"
    while IFS="$DERIVE_FS" read -r class target message remedy; do
      [ -n "$class" ] || continue
      if [ "$class" != "$last" ]; then printf '\n  %s\n' "$class"; last="$class"; fi
      printf '    %s\n' "$target"
      printf '      %s\n' "$message"
      printf '      remedy: %s\n' "$remedy"
    done < "$DERIVE_TMP/refused.spool"
    printf '\n  %s class(es), %s finding(s)\n' \
      "$(cut -d"$DERIVE_FS" -f1 "$DERIVE_TMP/refused.spool" | LC_ALL=C sort -u | grep -c .)" \
      "$(grep -c . "$DERIVE_TMP/refused.spool")"
  } >&2
}

report_derived() {
  {
    printf 'DERIVED %s %s (%s)\n' "$KIND" "$U_ID" "$U_PATH"
    printf '  path      %s\n' "$U_PATH"
    printf '  lifecycle %s\n' "${U_LIFECYCLE:-—}"
    printf '  requires  %s\n' "$(grep -c . "$DERIVE_TMP/requires.spool")"
    printf '  claims    %s (%s store · %s test)\n' \
      "$(grep -c . "$DERIVE_TMP/claims.spool")" \
      "$(cut -d"$DERIVE_FS" -f2 "$DERIVE_TMP/claims.spool" | grep -c '^store$')" \
      "$(cut -d"$DERIVE_FS" -f2 "$DERIVE_TMP/claims.spool" | grep -c '^test$')"
  } >&2
}

if [ -s "$DERIVE_TMP/refused.spool" ]; then
  # Sorted so the report groups by class, deduplicated because one shape stated
  # twice is one defect: two identical findings tell an operator nothing a
  # second time.
  LC_ALL=C sort -u -o "$DERIVE_TMP/refused.spool" "$DERIVE_TMP/refused.spool"
  jq -n --rawfile refused "$DERIVE_TMP/refused.spool" \
    --arg schema "$DERIVE_SCHEMA" --arg kind "$KIND" --arg id "$U_ID" \
    --arg path "$U_PATH" --arg lifecycle "$U_LIFECYCLE" --arg module "$U_MODULE" \
    --arg entity "$U_ENTITY" --arg action "$U_ACTION" --arg screen "$U_SCREEN" \
    "$DERIVE_JQ_PRELUDE"'
      {schema: $schema,
       unit: ({kind: $kind, id: $id, path: $path, lifecycle: $lifecycle,
               module: $module}
              + (if $kind == "entity" then {entity: $entity}
                 elif $kind == "action" then {entity: $entity, action: $action}
                 else {screen: $screen} end)),
       refused: (recs($refused)
                 | map({class: .[0], target: cel(.;1), message: cel(.;2),
                        remedy: cel(.;3)}))}
    '
  report_refusals
  exit "$EXIT_REFUSED"
fi

case "$KIND" in
  entity) derive_entity_json ;;
  action) derive_action_json ;;
  screen) derive_screen_json ;;
esac
report_derived
exit "$EXIT_OK"
