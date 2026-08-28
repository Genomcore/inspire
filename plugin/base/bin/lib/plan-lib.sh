#!/usr/bin/env bash
# .inspire/bin/lib/plan-lib.sh
#
# Library — the primitives `emanate-plan.sh` and its sibling `plan-*` units
# share: the scratch directory, the record spools every list is accumulated in,
# the lexical path normalizer, the owning-skill map and the jq prelude.
#
# The spool encoding is `derive`'s, deliberately — one separator-delimited
# record per line, rendered by a single `jq -n --rawfile` program per list,
# because a `jq` process per object costs ~8 ms and a plan holds hundreds. The
# CODE is not derive's: plan composes on `emanate-derive.sh`'s STDOUT and on
# nothing else, so `lib/derive-*.sh` is never sourced here and derive's
# internals can move without moving plan.
#
#   PLAN_FS  U+001F  between the fields of one record
#   PLAN_LS  U+001E  between the items of a list inside one field
#
# Both separators reach jq as `--arg fs` / `--arg ls` rather than as escapes
# inside the prelude: the program text then holds no control byte, which is the
# difference between a source line a reviewer can read and one they cannot.
#
# Sourced after `_lib.sh`. Safe to source on its own.

PLAN_FS=$'\037'
PLAN_LS=$'\036'

# plan_scratch — creates $PLAN_TMP once and prints it. The caller owns the EXIT
# trap that removes it: this is the only thing a plan run writes anywhere.
plan_scratch() {
  if [ -z "${PLAN_TMP:-}" ]; then
    PLAN_TMP="$(mktemp -d -t inspire-plan.XXXXXX)" || return 1
    mkdir -p "$PLAN_TMP/c" "$PLAN_TMP/prof"
  fi
  printf '%s\n' "$PLAN_TMP"
}

# plan_init_spools <name>... — create every spool this run will render, empty.
# `--rawfile` fails on a missing path, and "the plan found none" must not read
# as a broken run.
plan_init_spools() {
  local name
  for name in "$@"; do : > "$PLAN_TMP/$name.spool"; done
}

# plan_row <name> <field>... — append one record to a spool. Read back with
# `IFS="$PLAN_FS" read -r …` and never by word-splitting an unquoted expansion:
# a message containing `*` would otherwise become a directory listing.
plan_row() {
  local name="$1" out="" f
  shift
  for f in "$@"; do out="${out:+$out$PLAN_FS}$f"; done
  printf '%s\n' "$out" >> "$PLAN_TMP/$name.spool"
}

# plan_norm <text> — whitespace collapsed to single spaces and trimmed. A
# message reaching the report or the JSON is one line, whatever the artifact
# spelled it across.
plan_norm() {
  local s="$1"
  s="${s//$'\n'/ }"; s="${s//$'\t'/ }"; s="${s//$'\r'/ }"
  while [ "$s" != "${s//  / }" ]; do s="${s//  / }"; done
  while [ "${s# }" != "$s" ]; do s="${s# }"; done
  while [ "${s% }" != "$s" ]; do s="${s% }"; done
  printf '%s' "$s"
}

# plan_path_norm <path> — `sdd_scope_norm` plus lexical `..` collapse. Derive
# emits a screen's pattern path as `…/users/../patterns/list.md`; two spellings
# of one file would report as two targets and read as two defects.
plan_path_norm() {
  local p out="" lead="" seg
  p="$(sdd_scope_norm "$1")"
  case "$p" in /*) lead="/" ;; esac
  local IFS=/
  for seg in $p; do
    case "$seg" in
      ""|.) continue ;;
      ..) case "$out" in */*) out="${out%/*}" ;; *) out="" ;; esac ;;
      *)  out="${out:+$out/}$seg" ;;
    esac
  done
  printf '%s\n' "$lead$out"
}

# plan_under <path> <root> — exit 0 when <path> lies in <root>'s subtree. Both
# sides are already normalized by their producers, so this is lexical only.
plan_under() {
  local p="$1" root="$2"
  [ -n "$root" ] || return 1
  case "$p" in "$root"|"$root"/*) return 0 ;; esac
  return 1
}

# plan_owner <target-path> — the skill that owns the artifact a finding names,
# read off the ROOT it sits under rather than a hardcoded `04_domain/`: the
# roots are configurable everywhere else in base/bin/, and a fixture's domain
# tree is not called `04_domain` at all.
plan_owner() {
  local p
  p="$(plan_path_norm "$1")"
  if plan_under "$p" "$(sdd_scope_norm "$SDD_SPEC_ROOT")"; then printf 'inspire-domain'
  elif plan_under "$p" "$(sdd_scope_norm "$SDD_KB_ROOT/05_screens")"; then printf 'inspire-screens'
  elif plan_under "$p" "$(sdd_scope_norm "$SDD_KB_ROOT/00_bootstrap")"; then printf 'inspire-bootstrap'
  else printf 'inspire-code'
  fi
}

PLAN_JQ_PRELUDE='
  def recs($s): $s | split("\n") | map(select(length > 0)) | map(split($fs));
  def cel($r; $i): ($r[$i] // "");
  def nul($v): if $v == "" then null else $v end;
'
