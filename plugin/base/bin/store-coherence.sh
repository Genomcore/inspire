#!/usr/bin/env bash
# .inspire/bin/store-coherence.sh
#
# Rule: a face's store declares its keys in the closed vocabularies, and every
# screen and shell that reads or writes the store names a key it declares
# (adr-face-store D1–D7).
#
#   FACE     — `{face}.store.md` names a face a `*.face.md` declares.
#   KEYS     — every row of `## Server keys` and `## Client keys` is keyed, and no
#              key is declared twice across the two tables.
#   SERVER   — a server key links an action; `Load` is `start-up`, `first read` or
#              ``on change of `k` ``, where `k` is another key of the store and no
#              chain of them loops; `On error` is `—` or an outcome.
#   CLIENT   — a client key has a `Type`; `Persist` is `none`, `session` or `local`.
#   ON ERROR — a `Class` is `unauthenticated`, `forbidden`, `not-found`,
#              `unavailable` or `other`, once each; an outcome is
#              `→ [{screen-id}]({path})`, `keep` or `clear`.
#   READERS  — ``store `k` `` in a data row, ``set store `k` `` and
#              ``refresh store `k` `` in a dispatch outcome, and
#              ``set store `k` from param `p` `` in a navigation `Then` name a key
#              of their face's store; a refresh names a server key and a `Then`
#              a client key. A shell resolves its face through `faces:`, and one
#              that frames several faces binds no store.
#   UNREAD   — a key no reader reads and no `on change of` watches is a warning.
#
# Severity: lifecycle-progressive by the store's `lifecycle:` for its own rows, by
# the screen's for a screen, and by `**State:**` for a shell.
#
# Usage:
#   .inspire/bin/store-coherence.sh
#   .inspire/bin/store-coherence.sh inspire_kb/01_spec/_faces/portal

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_link-reads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="$(sdd_scope_intersect "${1:-}" "$SDD_SPEC_ROOT")"
[ -n "$SCOPE" ] || exit 0
[ -d "$SDD_SPEC_ROOT" ] || exit 0

KEYS="$(mktemp -t sdd-store-keys.XXXXXX)"
READS="$(mktemp -t sdd-store-reads.XXXXXX)"
trap 'rm -f "$KEYS" "$READS"' EXIT

emit() {
  sdd_finding "$1" "store-coherence" "$2" "$3"
  sdd_count_by_severity "$1"
}

in_scope() {
  [ -n "$(sdd_scope_intersect "$1" "$SCOPE")" ]
}

trim() {
  awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }'
}

bare() {
  printf '%s\n' "$1" | tr -d '`' | trim
}

table_rows() {
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /<!--/ { incomment = 1 }
    incomment { if ($0 ~ /-->/) incomment = 0; next }
    /^[ \t]*\|/ {
      line = $0
      gsub(/\\\|/, "\001", line)
      probe = line
      gsub(/[ \t|:-]/, "", probe)
      if (probe == "") next
      if (!hdr) { hdr = 1; next }
      n = split(line, cell, "|")
      out = ""
      for (i = 2; i < n; i++) {
        c = cell[i]
        gsub(/\001/, "|", c)
        out = out (i > 2 ? "\t" : "") trim(c)
      }
      print out
    }
  '
}

binding_rows() {
  sdd_body_subsection "$1" "Bindings" "$2" | table_rows
}

is_outcome() {
  case "$1" in
    keep|clear) return 0 ;;
  esac
  [ -n "$(sdd_link_in_text "$2" "$1")" ]
}

catalog_state_severity() {
  case "$(sdd_catalog_state "$1" 2>/dev/null)" in
    implemented) sdd_progressive_severity stable ;;
    to-extract)  sdd_progressive_severity accepted ;;
    *)           sdd_progressive_severity draft ;;
  esac
}

FACES="$(sdd_find_faces "$SDD_SPEC_ROOT" | while IFS= read -r f; do printf '%s\t%s\n' "$(sdd_artifact_id "$f")" "$f"; done)"

face_file() {
  printf '%s\n' "$FACES" | awk -F'\t' -v k="$1" '$1 == k { print $2; exit }'
}

store_file() {
  sdd_find_stores "$SDD_SPEC_ROOT" | while IFS= read -r s; do
    [ "$(sdd_artifact_id "$s")" = "$1" ] && { printf '%s\n' "$s"; break; }
  done
}

while IFS= read -r store; do
  [ -n "$store" ] || continue
  face="$(sdd_artifact_id "$store")"
  sdd_body_section "$store" "Server keys" | table_rows | while IFS=$'\t' read -r k rest; do
    k="$(bare "$k")"; [ -n "$k" ] && printf '%s\tserver\t%s\n' "$face" "$k"
  done >> "$KEYS"
  sdd_body_section "$store" "Client keys" | table_rows | while IFS=$'\t' read -r k rest; do
    k="$(bare "$k")"; [ -n "$k" ] && printf '%s\tclient\t%s\n' "$face" "$k"
  done >> "$KEYS"
  sdd_body_section "$store" "Server keys" | table_rows | while IFS=$'\t' read -r k a load rest; do
    case "$load" in
      *"on change of"*) printf '%s\t%s\n' "$face" "$(bare "${load##*on change of}")" ;;
    esac
  done >> "$READS"
done < <(sdd_find_stores "$SDD_SPEC_ROOT")

key_kind() {
  awk -F'\t' -v f="$1" -v k="$2" '$1 == f && $3 == k { print $2; exit }' "$KEYS"
}

check_store() {
  local store="$1" face sev links seen="" k action load onerr notes type initial persist cls outcome w seen_cls=""
  face="$(sdd_artifact_id "$store")"
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$store" '.lifecycle')")"
  links="$(sdd_links "$store" wiki)"

  if [ -z "$(face_file "$face")" ]; then
    emit "$sev" "$store" "store names face '$face', which no face declares (no $face.face.md) — the file is {face}.store.md"
  fi

  if [ -z "$(awk -F'\t' -v f="$face" '$1 == f' "$KEYS")" ]; then
    emit "warning" "$store" "store declares no key: a face with no state across screens has no store file"
  fi

  while IFS=$'\t' read -r k; do
    [ -n "$k" ] || continue
    case " $seen " in
      *" $k "*) emit "$sev" "$store" "duplicate store key: '$k' is declared twice across '## Server keys' and '## Client keys'" ;;
      *) seen="$seen $k" ;;
    esac
  done < <(awk -F'\t' -v f="$face" '$1 == f { print $3 }' "$KEYS")

  while IFS=$'\t' read -r k action load onerr notes; do
    k="$(bare "$k")"
    if [ -z "$k" ]; then
      emit "$sev" "$store" "server key row has no key: a row under '## Server keys' declares nothing to key a claim on"
      continue
    fi
    if [ -z "$(sdd_link_in_text "$links" "$action")" ]; then
      emit "$sev" "$store" "server key '$k' links no action: its 'Action' cell is a link to the action that loads it"
    fi
    case "$load" in
      "start-up"|"first read") ;;
      "on change of \`"*"\`")
        w="$(bare "${load##*on change of}")"
        if [ "$w" = "$k" ]; then
          emit "$sev" "$store" "server key '$k' loads on change of itself"
        elif [ -z "$(key_kind "$face" "$w")" ]; then
          emit "$sev" "$store" "server key '$k' loads on change of '$w', which this store does not declare"
        fi ;;
      *) emit "$sev" "$store" "server key '$k' Load is '$load' — one of 'start-up', 'first read' or 'on change of \`{key}\`'" ;;
    esac
    case "$onerr" in
      ""|"-"|"—") ;;
      *) is_outcome "$onerr" "$links" \
           || emit "$sev" "$store" "server key '$k' On error is '$onerr' — '—', 'keep', 'clear' or '→ [{screen-id}]({path})'" ;;
    esac
  done < <(sdd_body_section "$store" "Server keys" | table_rows)

  while IFS=$'\t' read -r k type initial persist notes; do
    k="$(bare "$k")"
    if [ -z "$k" ]; then
      emit "$sev" "$store" "client key row has no key: a row under '## Client keys' declares nothing to key a claim on"
      continue
    fi
    case "$(bare "$type")" in
      ""|"-"|"—") emit "$sev" "$store" "client key '$k' declares no Type" ;;
    esac
    case "$(bare "$persist")" in
      none|session|local) ;;
      *) emit "$sev" "$store" "client key '$k' Persist is '$persist' — one of 'none', 'session' or 'local'" ;;
    esac
  done < <(sdd_body_section "$store" "Client keys" | table_rows)

  while IFS=$'\t' read -r cls outcome; do
    cls="$(bare "$cls")"
    [ -n "$cls" ] || continue
    case "$cls" in
      unauthenticated|forbidden|not-found|unavailable|other) ;;
      *) emit "$sev" "$store" "error class '$cls' is not one of unauthenticated, forbidden, not-found, unavailable, other" ;;
    esac
    case " $seen_cls " in
      *" $cls "*) emit "$sev" "$store" "error class '$cls' has two rows under '## On error'" ;;
      *) seen_cls="$seen_cls $cls" ;;
    esac
    is_outcome "$outcome" "$links" \
      || emit "$sev" "$store" "error class '$cls' outcome is '$outcome' — 'keep', 'clear' or '→ [{screen-id}]({path})'"
  done < <(sdd_body_section "$store" "On error" | table_rows)

  local from to path cycle
  while IFS=$'\t' read -r from to; do
    [ "$from" != "$to" ] || continue
    path=" $from "
    cycle=""
    while [ -n "$to" ]; do
      case "$path" in *" $to "*) cycle="$to"; break ;; esac
      path="$path$to "
      to="$(sdd_body_section "$store" "Server keys" | table_rows \
        | awk -F'\t' -v k="$to" '{ c = $1; gsub(/`/, "", c); gsub(/^[ \t]+|[ \t]+$/, "", c) } c == k && $3 ~ /on change of/ { s = $3; sub(/.*on change of[ \t]*/, "", s); gsub(/`/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s); print s; exit }')"
    done
    if [ "$cycle" = "$from" ]; then
      emit "$sev" "$store" "server key '$from' loads on a chain of 'on change of' that comes back to it"
    fi
  done < <(sdd_body_section "$store" "Server keys" | table_rows \
    | awk -F'\t' '$3 ~ /on change of/ { c = $1; gsub(/`/, "", c); gsub(/^[ \t]+|[ \t]+$/, "", c); s = $3; sub(/.*on change of[ \t]*/, "", s); gsub(/`/, "", s); gsub(/^[ \t]+|[ \t]+$/, "", s); print c "\t" s }')
}

store_tokens() {
  printf '%s\n' "$1" | awk -v form="$2" '{
    s = $0
    while (match(s, form)) {
      t = substr(s, RSTART, RLENGTH)
      sub(/^[^`]*`/, "", t)
      sub(/`.*$/, "", t)
      print t
      s = substr(s, RSTART + RLENGTH)
    }
  }'
}

check_reader() {
  local file="$1" face="$2" sev="$3" report="$4" what="$5"
  local key action rest trig ok oe target trigger then k kind
  local have_store=0
  [ -n "$(store_file "$face")" ] && have_store=1

  need() {
    local k="$1" use="$2" want="$3"
    kind="$(key_kind "$face" "$k")"
    if [ "$have_store" = 0 ]; then
      [ "$report" = 1 ] && emit "$sev" "$file" "$what $use store key '$k', and face '$face' has no store ($face.store.md)"
      return
    fi
    if [ -z "$kind" ]; then
      [ "$report" = 1 ] && emit "$sev" "$file" "$what $use store key '$k', which the store of face '$face' does not declare"
    elif [ -n "$want" ] && [ "$kind" != "$want" ]; then
      [ "$report" = 1 ] && emit "$sev" "$file" "$what $use store key '$k', which is a $kind key — only a $want key can be"
    fi
  }

  while IFS=$'\t' read -r key action rest; do
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      printf '%s\t%s\n' "$face" "$k" >> "$READS"
      need "$k" "reads" ""
    done < <(store_tokens "$action" 'store `[^`]+`')
  done < <(binding_rows "$file" "Data")

  while IFS=$'\t' read -r key action trig ok oe; do
    while IFS= read -r k; do
      [ -n "$k" ] && need "$k" "sets" ""
    done < <(store_tokens "$ok" 'set store `[^`]+`')
    while IFS= read -r k; do
      [ -n "$k" ] && need "$k" "refreshes" "server"
    done < <(store_tokens "$ok" 'refresh store `[^`]+`')
  done < <(binding_rows "$file" "Dispatches")

  while IFS=$'\t' read -r key target trigger then; do
    while IFS= read -r k; do
      [ -n "$k" ] && need "$k" "sets" "client"
    done < <(store_tokens "$then" 'set store `[^`]+`')
  done < <(binding_rows "$file" "Navigation")
}

while IFS= read -r screen; do
  [ -n "$screen" ] || continue
  id="$(sdd_fm_value "$screen" '.id')"
  face="${id%%.*}"
  [ -n "$face" ] && [ "$face" != "$id" ] || continue
  report=0; in_scope "$screen" && report=1
  check_reader "$screen" "$face" "$(sdd_progressive_severity "$(sdd_fm_value "$screen" '.lifecycle')")" "$report" "screen"
done < <(sdd_find_screens "$SDD_SPEC_ROOT")

while IFS= read -r layout; do
  [ -n "$layout" ] || continue
  sdd_has_section "$layout" "Bindings" || continue
  sev="$(catalog_state_severity "$layout")"
  report=0; in_scope "$layout" && report=1
  faces="$(sdd_fm_list "$layout" '.faces')"
  [ -n "$faces" ] || faces="$(printf '%s\n' "$FACES" | cut -f1)"
  if [ "$(printf '%s\n' "$faces" | grep -c .)" != 1 ]; then
    [ "$report" = 1 ] && emit "$sev" "$layout" "shell binds data for several faces: name one face in 'faces:' — each face's shell binds its own store and bundles"
    continue
  fi
  check_reader "$layout" "$faces" "$sev" "$report" "shell"
done < <(sdd_find_catalog "$SDD_SPEC_ROOT" layouts)

while IFS= read -r store; do
  [ -n "$store" ] || continue
  check_store "$store"
  face="$(sdd_artifact_id "$store")"
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$store" '.lifecycle')")"
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    awk -F'\t' -v f="$face" -v k="$k" '$1 == f && $2 == k { found = 1; exit } END { exit !found }' "$READS" && continue
    emit "warning" "$store" "store key '$k' has no reader: no screen or shell of face '$face' reads it, and no key loads on its change"
  done < <(awk -F'\t' -v f="$face" '$1 == f { print $3 }' "$KEYS")
done < <(sdd_find_stores "$SCOPE")

sdd_exit_with_counters
