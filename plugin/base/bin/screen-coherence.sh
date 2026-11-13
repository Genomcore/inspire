#!/usr/bin/env bash
# .inspire/bin/screen-coherence.sh
#
# Rule: a screen file's identity, its keyed bindings, and its join with the
# layout it names all hold. Three groups of checks, one pass over every
# `*.screen.md`:
#
#   IDENTITY — the frontmatter block `id` · `module` · `screen` · `lifecycle`:
#     present; `lifecycle` enum-valid; `id` shaped `{face}.{slug}` (adr-kb-structure
#     D5), its face one a `*.face.md` declares; a `superseded` screen pointing at
#     the screen id that replaced it. The face comes from the id, never from the
#     directory the file sits in (D4). Plus the two contradictions that cannot
#     fire on a pre-0.9 file and are therefore errors at every state: two screens
#     declaring one `id`, and two screens deriving one route in one face.
#
#   BINDINGS — `## Bindings` carries the screen's own semantics, in five
#     subsections and no others (`Parameters` · `Data` · `Dispatches` ·
#     `Navigation` · `States`). Every row is keyed, keys are unique per
#     subsection, every dispatch outcome names a declared state key, a declared
#     data key or a screen id, and every state's `When` references something
#     declared. A parameter travels in `path` or `query`, and a path one is
#     required; every `param \`key\`` a data row relies on is declared here, and
#     every one a transition passes is declared by its target screen.
#
#   JOIN — where `**Pattern:**` names a layout, each of that layout's REQUIRED
#     regions accepting a binding kind finds one: a `list` layout with no data
#     binding is a finding. A `**Components:**` entry still at
#     `**State:** to-extract` blocks a `stable` screen.
#
# Ownership, deliberately: this rule checks the FORM of an outward reference and
# never its existence — `links-resolve.sh` owns resolution, for screens as
# for domain objects. Two rules reporting one dangling link would double every
# finding.
#
# Severity: lifecycle-progressive by the screen's own `lifecycle:` (draft →
# warning, accepted / stable → error, superseded → warning), except where the
# check list above says otherwise. A screen with no frontmatter at all — every
# screen written before the identity block existed — reads as draft, so nothing
# authored before 0.9 starts blocking a commit.
#
# Scope: the rule receives one `$1` and checks the screens in `$1 ∩ 01_spec` — see
# `bin/README.md` §Scope. The duplicate-id and route-collision indexes are built
# vault-wide whatever the scope, because a collision is not local; findings are
# still only ever emitted on in-scope files.
#
# Usage:
#   .inspire/bin/screen-coherence.sh                       # every screen
#   .inspire/bin/screen-coherence.sh inspire_kb/01_spec/_faces/portal  # one face

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_link-reads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

SC_INDEX="$(mktemp -t sdd-screen-index.XXXXXX)"
SC_ROWS="$(mktemp -t sdd-screen-rows.XXXXXX)"
SC_SEEN="$(mktemp -t sdd-screen-seen.XXXXXX)"
SC_LINK_ROWS=""   # `sdd_links` of the screen being checked
trap 'rm -f "$SC_INDEX" "$SC_ROWS" "$SC_SEEN"' EXIT

BINDING_SUBSECTIONS="Parameters Data Dispatches Navigation States"
LIFECYCLE_STATES="draft accepted stable superseded"

# ─────────────────────────────────────────────────────────────────────────────
# Readers
# ─────────────────────────────────────────────────────────────────────────────

# The declared faces, one id per line: every `*.face.md`, by its id.
SC_FACES="$(sdd_find_faces "$SDD_SPEC_ROOT" | while IFS= read -r f; do sdd_artifact_id "$f"; done)"

# sc_h1_route <file> — prints the code span of the H1 title when it looks like a
# path (`# Users — `/users``). Heuristic, and reported as a flat warning.
sc_h1_route() {
  awk "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      /^# / {
        if (match($0, /`\/[^`]*`/)) print substr($0, RSTART+1, RLENGTH-2)
        exit
      }
    '"${SDD_AWK_FENCE_FUNCS}" "$1"
}

# sc_header_links <file> <marker> — the file each link on a `**Marker:**` body line
# resolves to, one per line (a broken one is links-resolve's finding, not listed here).
sc_header_links() {
  local ln form target text path
  ln="$(awk -v pfx="$2" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      index($0, pfx) == 1 { print NR; exit }
    '"${SDD_AWK_FENCE_FUNCS}" "$1")"
  [ -n "$ln" ] || return 0
  sdd_line_links "$1" "$ln" "$ln" | while IFS=$'\t' read -r ln form target text path; do
    [ -f "$path" ] && printf '%s\n' "$path"
  done
}

# sc_parse_bindings <file> — normalizes `## Bindings` into TSV on stdout:
#   SUB<TAB>{subsection}                 one per H3, in document order
#   ROW<TAB>{subsection}<TAB>{cell}...   one per data row, cells trimmed
#   NOSUB                                a table sits under no H3 at all
# A pipe escaped for a table cell (`\|`) is protected before the split and
# restored after, so a link whose text holds a pipe does not end its cell. HTML comments
# are dropped whole-line: the templates carry guidance comments, and no binding
# row ever carries one.
sc_parse_bindings() {
  sdd_body_section "$1" "Bindings" | awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /<!--/ { incomment = 1 }
    incomment { if ($0 ~ /-->/) incomment = 0; next }
    /^###[ \t]/ {
      h = $0
      sub(/^###[ \t]+/, "### ", h)
      sect = sdd_heading_name(h, "### ")
      print "SUB\t" sect
      hdr = 1
      next
    }
    /^[ \t]*\|/ {
      if (sect == "") { nosub = 1; next }
      line = $0
      gsub(/\\\|/, "\001", line)
      probe = line
      gsub(/[ \t|:-]/, "", probe)
      if (probe == "") next          # the |---|---| separator row
      if (hdr) { hdr = 0; next }     # the column-header row
      n = split(line, cell, "|")
      out = "ROW\t" sect
      for (i = 2; i <= n; i++) {
        c = cell[i]
        gsub(/\001/, "|", c)
        out = out "\t" trim(c)
      }
      print out
      next
    }
    END { if (nosub) print "NOSUB" }
  '"${SDD_AWK_HEADING_FUNCS}"
}

# sc_bare <text> — a table cell reduced to its key: backticks and spaces gone.
sc_bare() {
  printf '%s\n' "$1" | tr -d '`' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }'
}

# sc_linked <cell> — `link` when the cell carries a link, `wiki` when that link is a
# wikilink, which only links-resolve reports (D5).
sc_linked() {
  local row
  row="$(sdd_link_in_text "$SC_LINK_ROWS" "$1")"
  case "$row" in "") ;; *$'\t'wiki$'\t'*) printf 'wiki\n' ;; *) printf 'link\n' ;; esac
}

# sc_link_target <cell> — the canonical target of the first link in a table cell,
# or nothing when the cell carries none: the id of the file it names, or, for a
# broken link that is not a file path (`/users`), the path as written, so its route
# shape can be judged. Existence is
# `links-resolve.sh`'s question; this reader serves the FORM check, this rule's half.
sc_link_target() {
  local row ln form target text path
  row="$(sdd_link_in_text "$SC_LINK_ROWS" "$1")"
  [ -n "$row" ] || return 0
  IFS=$'\t' read -r ln form target text path <<< "$row"
  if [ "$form" = wiki ]; then return 0
  elif [ -f "$path" ]; then
    sdd_artifact_id "$path"
  else
    case "${target%%#*}" in *.md) ;; *) printf '%s\n' "${target%%#*}" ;; esac
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# The vault-wide identity index: path \t id \t module \t screen \t face
# ─────────────────────────────────────────────────────────────────────────────

# Read FIELD BY FIELD through `sdd_fm_value`, never off the extracted block:
# `yq '.'` round-trips an inline `# comment` into the value it prints, while
# `yq '.id'` gives the scalar YAML actually means. The shipped canonical screen
# carries such a comment, so the block reader failed its own format's example —
# and it fed `id`, `module` and `screen`, hence the duplicate-id and
# route-collision indexes too.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$f" \
    "$(sdd_fm_value "$f" '.id')" \
    "$(sdd_fm_value "$f" '.module')" \
    "$(sdd_fm_value "$f" '.screen')" \
    "$(id="$(sdd_fm_value "$f" '.id')"; printf '%s' "${id%%.*}")" >> "$SC_INDEX"
done < <(sdd_find_screens "$SDD_SPEC_ROOT")

# sc_screen_file <id> — the screen file declaring <id>.
sc_screen_file() {
  awk -F'\t' -v k="$1" '$2 == k { print $1; exit }' "$SC_INDEX"
}

# ─────────────────────────────────────────────────────────────────────────────
# Checks
# ─────────────────────────────────────────────────────────────────────────────

emit() {
  sdd_finding "$1" "screen-coherence" "$2" "$3"
  sdd_count_by_severity "$1"
}

check_identity() {
  local file="$1" sev="$2" id="$3" module="$4" screen="$5" lifecycle="$6"
  local missing="" other face

  [ -n "$id" ]        || missing="${missing:+$missing,}id"
  [ -n "$module" ]    || missing="${missing:+$missing,}module"
  [ -n "$screen" ]    || missing="${missing:+$missing,}screen"
  [ -n "$lifecycle" ] || missing="${missing:+$missing,}lifecycle"
  if [ -n "$missing" ]; then
    emit "$sev" "$file" "screen missing frontmatter field(s): $missing"
  fi

  # A declared-but-broken enum value is mechanical, like the domain layer's
  # `lifecycle-valid`: error at every state. It cannot fire on a pre-0.9 file —
  # a file with no lifecycle at all takes the missing-field path above — and
  # every OTHER check reads the broken value as draft, so the file gets one
  # blocking finding rather than a cascade.
  if [ -n "$lifecycle" ]; then
    case " $LIFECYCLE_STATES " in
      *" $lifecycle "*) ;;
      *) emit "error" "$file" \
           "invalid screen lifecycle value: '$lifecycle' (expected one of: $LIFECYCLE_STATES)" ;;
    esac
  fi

  if [ -n "$id" ]; then
    case "$id" in
      *.*.*|.*|*.) emit "$sev" "$file" \
             "screen id shape: '$id' is not '{face}.{slug}' — two segments, the face and the screen's slug" ;;
      *.*)
        face="${id%%.*}"
        if ! printf '%s\n' "$SC_FACES" | grep -qxF "$face"; then
          emit "$sev" "$file" \
            "screen id names face '$face', which no face declares (no {face}.face.md has that id)"
        fi ;;
      *) emit "$sev" "$file" \
           "screen id shape: '$id' is not '{face}.{slug}' — two segments, the face and the screen's slug" ;;
    esac
  fi

  if [ "$lifecycle" = "superseded" ]; then
    local sb_form sb_written sb sb_path
    IFS=$'\t' read -r sb_form sb_written sb sb_path < <(sdd_fm_link_refs "$file" superseded_by)
    if [ "$sb_form" = wiki ]; then :
    elif [ -z "$sb_form" ]; then
      emit "$sev" "$file" \
        "screen superseded without superseded_by: name the screen id that replaced it"
    elif [ -z "$sb" ] || [ -z "$(sc_screen_file "$sb")" ]; then
      emit "$sev" "$file" \
        "superseded_by target does not resolve to a screen id: '${sb:-$sb_written}'"
    fi
  fi

  local route
  route="$(sc_h1_route "$file")"
  if [ -n "$route" ]; then
    # Flat warning at every state: the reading is a heuristic, and a heuristic
    # never blocks a commit.
    emit "warning" "$file" \
      "screen carries an authored route: '$route' in the H1 — routes derive from module + screen"
  fi

  # Two screens, one id. Both sides need declared frontmatter, so this can never
  # fire on a pre-0.9 file: error at every state.
  if [ -n "$id" ]; then
    other="$(awk -F'\t' -v k="$id" -v self="$file" '$2 == k && $1 != self { print $1; exit }' "$SC_INDEX")"
    if [ -n "$other" ]; then
      emit "error" "$file" "duplicate screen id: '$id' is also declared by $other"
    fi
  fi

  # Two screens, one derived route in one face: the face is the shell.
  if [ -n "$module" ] && [ -n "$screen" ]; then
    other="$(awk -F'\t' -v m="$module" -v s="$screen" -v face="${id%%.*}" -v self="$file" '
        $1 != self && $3 == m && $4 == s && $5 == face { print $1; exit }' "$SC_INDEX")"
    if [ -n "$other" ]; then
      emit "error" "$file" \
        "route collision: '$module/$screen' is derived by this screen and by $other in the same face"
    fi
  fi
}

check_bindings() {
  local file="$1" sev="$2"
  sc_parse_bindings "$file" > "$SC_ROWS"

  if awk '$1 == "NOSUB" { f=1; exit } END { exit !f }' "$SC_ROWS"; then
    emit "$sev" "$file" \
      "binding rows sit under no subsection: every row belongs to ### Data, ### Dispatches, ### Navigation or ### States"
  fi

  local sub
  while IFS= read -r sub; do
    [ -z "$sub" ] && continue
    case " $BINDING_SUBSECTIONS " in
      *" $sub "*) ;;
      *) emit "$sev" "$file" \
           "unknown bindings subsection: '### $sub' (the set is closed: $BINDING_SUBSECTIONS)" ;;
    esac
  done < <(awk -F'\t' '$1 == "SUB" { print $2 }' "$SC_ROWS")

  # Keys, per subsection: present and unique.
  : > "$SC_SEEN"
  local line rowsub key
  while IFS= read -r line; do
    rowsub="$(printf '%s\n' "$line" | cut -f2)"
    key="$(sc_bare "$(printf '%s\n' "$line" | cut -f3)")"
    if [ -z "$key" ]; then
      emit "$sev" "$file" \
        "binding row has no key: a row under '### $rowsub' declares nothing to key a claim on"
      continue
    fi
    if awk -F'\t' -v s="$rowsub" -v k="$key" '$1 == s && $2 == k { f=1; exit } END { exit !f }' "$SC_SEEN"; then
      emit "$sev" "$file" \
        "duplicate binding key: '$key' is used twice under '### $rowsub'"
    else
      printf '%s\t%s\n' "$rowsub" "$key" >> "$SC_SEEN"
    fi
  done < <(awk -F'\t' '$1 == "ROW" { print }' "$SC_ROWS")

  # Dispatch outcomes: a declared state key, a declared data key, or a screen id.
  local outcome col navtarget
  while IFS= read -r line; do
    for col in 6 7; do
      outcome="$(printf '%s\n' "$line" | cut -f$col)"
      outcome="$(printf '%s\n' "$outcome" | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')"
      case "$outcome" in
        ""|"-"|"—"|"n/a"|"none") continue ;;
      esac
      case "$(sc_linked "$outcome"):$outcome" in
        link:*)                                        # navigate: a screen id
          # …and a screen id has no slash in it. Wrapping a route in a link
          # satisfies the grammar's shape and none of its meaning, so it is
          # caught here rather than left to `links-resolve` to report as a
          # generic dangling target.
          navtarget="$(sc_link_target "$outcome")"
          case "$navtarget" in
            */*) emit "$sev" "$file" \
                   "navigate outcome is route-shaped: '$navtarget' — an outcome names a screen id, never a route" ;;
          esac
          continue ;;
        wiki:*) continue ;;
        *:"state "*|*:"→ state "*)
          key="$(sc_bare "${outcome##*state }")"
          if ! awk -F'\t' -v k="$key" '$1 == "States" && $2 == k { f=1; exit } END { exit !f }' "$SC_SEEN"; then
            emit "$sev" "$file" \
              "unresolved outcome: state '$key' is not declared under '### States'"
          fi
          ;;
        *:"refresh "*|*:"→ refresh "*)
          key="$(sc_bare "${outcome##*refresh }")"
          if ! awk -F'\t' -v k="$key" '$1 == "Data" && $2 == k { f=1; exit } END { exit !f }' "$SC_SEEN"; then
            emit "$sev" "$file" \
              "unresolved outcome: data key '$key' is not declared under '### Data'"
          fi
          ;;
        *)
          emit "$sev" "$file" \
            "unresolved outcome: '$outcome' is none of '→ [{screen-id}]({path})', 'state \`{key}\`' or 'refresh \`{key}\`'"
          ;;
      esac
    done
  done < <(awk -F'\t' '$1 == "ROW" && $2 == "Dispatches" { print }' "$SC_ROWS")

  # Navigation targets are screen ids, written as links. A link alone is not enough:
  # a screen id is `{face}.{slug}` and carries no slash, so a route survives the link
  # test and fails this one — otherwise the check would accept what its own message
  # forbids.
  while IFS= read -r line; do
    key="$(printf '%s\n' "$line" | cut -f4)"
    case "$(sc_linked "$key")" in
      link)
        navtarget="$(sc_link_target "$key")"
        case "$navtarget" in
          */*) emit "$sev" "$file" \
                 "navigation target is route-shaped: '$navtarget' — targets are linked screen ids, never routes" ;;
        esac
        ;;
      wiki) ;;
      *) emit "$sev" "$file" \
           "navigation target is not a screen id: '$key' — targets are linked ids, never routes" ;;
    esac
  done < <(awk -F'\t' '$1 == "ROW" && $2 == "Navigation" { print }' "$SC_ROWS")

  # A state observes something declared: a data key, a dispatch key, or a
  # deviation.
  local when anchored tok
  while IFS= read -r line; do
    key="$(sc_bare "$(printf '%s\n' "$line" | cut -f3)")"
    when="$(printf '%s\n' "$line" | cut -f4)"
    anchored=0
    case "$when" in
      *deviation*|*Deviation*) anchored=1 ;;
    esac
    if [ "$anchored" = 0 ]; then
      while IFS= read -r tok; do
        [ -z "$tok" ] && continue
        if awk -F'\t' -v k="$tok" '($1 == "Data" || $1 == "Dispatches" || $1 == "Parameters") && $2 == k { f=1; exit } END { exit !f }' "$SC_SEEN"; then
          anchored=1
          break
        fi
      done < <(printf '%s\n' "$when" | awk '{
          s = $0
          while (match(s, /`[^`]+`/)) {
            print substr(s, RSTART+1, RLENGTH-2)
            s = substr(s, RSTART + RLENGTH)
          }
        }')
    fi
    if [ "$anchored" = 0 ]; then
      emit "$sev" "$file" \
        "state not anchored: '$key' names no declared data key, dispatch key, parameter or deviation in its When"
    fi
  done < <(awk -F'\t' '$1 == "ROW" && $2 == "States" { print }' "$SC_ROWS")
}

sc_param_refs() {
  printf '%s\n' "$1" | awk '{
    s = $0
    while (match(s, /param[ \t]+`[^`]+`/)) {
      t = substr(s, RSTART, RLENGTH)
      sub(/^param[ \t]+`/, "", t)
      sub(/`$/, "", t)
      print t
      s = substr(s, RSTART + RLENGTH)
    }
  }'
}

sc_declared_params() {
  sc_parse_bindings "$1" | awk -F'\t' '$1 == "ROW" && $2 == "Parameters" { gsub(/`/, "", $3); print $3 }'
}

check_param_refs_target() {
  local file="$1" sev="$2" cell="$3" where="$4" target target_file declared ref
  target="$(sc_link_target "$cell")"
  [ -n "$target" ] || return 0
  target_file="$(sc_screen_file "$target")"
  [ -n "$target_file" ] || return 0
  declared=" $(sc_declared_params "$target_file" | tr '\n' ' ') "
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    case "$declared" in
      *" $ref "*) ;;
      *) emit "$sev" "$file" \
           "undeclared parameter: $where passes param '$ref', which $target does not declare under '### Parameters'" ;;
    esac
  done < <(sc_param_refs "$cell")
}

check_parameters() {
  local file="$1" sev="$2" line key placement required ref col cell

  while IFS= read -r line; do
    key="$(sc_bare "$(printf '%s\n' "$line" | cut -f3)")"
    [ -n "$key" ] || continue
    placement="$(sc_bare "$(printf '%s\n' "$line" | cut -f4)")"
    required="$(sc_bare "$(printf '%s\n' "$line" | cut -f6)" | tr '[:upper:]' '[:lower:]')"
    case "$placement" in
      path|query) ;;
      *) emit "$sev" "$file" \
           "parameter placement: '$key' is in '$placement' — a parameter travels in 'path' or 'query'" ;;
    esac
    case "$required" in
      yes|no) ;;
      *) emit "$sev" "$file" \
           "parameter required value: '$key' says '$required' — required is 'yes' or 'no'" ;;
    esac
    if [ "$placement" = "path" ] && [ "$required" = "no" ]; then
      emit "$sev" "$file" \
        "parameter optional in path: '$key' is a path segment, and a path segment cannot be absent — make it required or move it to the query"
    fi
  done < <(awk -F'\t' '$1 == "ROW" && $2 == "Parameters" { print }' "$SC_ROWS")

  while IFS= read -r line; do
    key="$(sc_bare "$(printf '%s\n' "$line" | cut -f3)")"
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      if ! awk -F'\t' -v k="$ref" '$1 == "Parameters" && $2 == k { f=1; exit } END { exit !f }' "$SC_SEEN"; then
        emit "$sev" "$file" \
          "undeclared parameter: data row '$key' relies on param '$ref', which this screen does not declare under '### Parameters'"
      fi
    done < <(sc_param_refs "$(printf '%s\n' "$line" | cut -f4-)")
  done < <(awk -F'\t' '$1 == "ROW" && $2 == "Data" { print }' "$SC_ROWS")

  while IFS= read -r line; do
    key="$(sc_bare "$(printf '%s\n' "$line" | cut -f3)")"
    check_param_refs_target "$file" "$sev" "$(printf '%s\n' "$line" | cut -f4)" "navigation '$key'"
  done < <(awk -F'\t' '$1 == "ROW" && $2 == "Navigation" { print }' "$SC_ROWS")

  while IFS= read -r line; do
    key="$(sc_bare "$(printf '%s\n' "$line" | cut -f3)")"
    for col in 6 7; do
      cell="$(printf '%s\n' "$line" | cut -f$col)"
      [ "$(sc_linked "$cell")" != link ] || check_param_refs_target "$file" "$sev" "$cell" "dispatch '$key'"
    done
  done < <(awk -F'\t' '$1 == "ROW" && $2 == "Dispatches" { print }' "$SC_ROWS")
}

# sc_reported_patterns — one line per pattern file already reported for a
# missing `## Regions` table, so a shared old-shape pattern is named once
# rather than once per adopting screen.
SC_PATTERNS_REPORTED=""

# sc_pattern_regions <pattern_file> — the entry's `## Regions` table as TSV,
# one row per region: region \t fill \t accepts, backticks gone and the two
# vocabulary columns lowercased. Both readers below share it, so the join and
# the vocabulary check can never disagree about what a row says.
sc_pattern_regions() {
  sdd_body_section "$1" "Regions" | awk '
      function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      /<!--/ { incomment = 1 }
      incomment { if ($0 ~ /-->/) incomment = 0; next }
      /^[ \t]*\|/ {
        probe = $0
        gsub(/[ \t|:-]/, "", probe)
        if (probe == "") next
        if (!hdr) { hdr = 1; next }
        n = split($0, cell, "|")
        if (n < 4) next
        r = trim(cell[2]); gsub(/`/, "", r)
        f = trim(cell[3]); gsub(/`/, "", f)
        a = trim(cell[4]); gsub(/`/, "", a)
        printf "%s\t%s\t%s\n", r, tolower(f), tolower(a)
      }
    '
}

# The two region vocabularies are closed — `Fill` is required|optional and
# `Accepts` is one or more of data|dispatch|nav|static, per format-screen.md and
# `templates/pattern.template.md`. Closed, and until now enforced nowhere:
# the join simply dropped a token it did not recognize, so `| body | required |
# records |` bought the pattern silence instead of a finding, and a region that
# should have demanded a data binding demanded nothing.
#
# Warning, on the PATTERN file, deduped once per pattern — the same three
# reasons as the no-`## Regions` warning it sits beside: that is the file to
# change, an adopting screen did nothing wrong, and a shared entry must not be
# named once per adopter.
SC_PATTERNS_VOCAB_CHECKED=""

check_pattern_vocab() {
  local pattern_file="$1"
  case " $SC_PATTERNS_VOCAB_CHECKED " in
    *" $pattern_file "*) return 0 ;;
  esac
  SC_PATTERNS_VOCAB_CHECKED="$SC_PATTERNS_VOCAB_CHECKED $pattern_file"

  local region fill accepts tok bad="" seen=""
  while IFS=$'\t' read -r region fill accepts; do
    [ -z "$region" ] && continue
    case "$fill" in
      required|optional|""|"-"|"—") ;;
      *)
        case " $seen " in
          *" fill:$fill "*) ;;
          *) seen="$seen fill:$fill"; bad="${bad:+$bad, }Fill '$fill'" ;;
        esac
        ;;
    esac
    for tok in $(printf '%s\n' "$accepts" | tr ',|' '  '); do
      case "$tok" in
        data|dispatch|nav|static|"-"|"—") continue ;;
      esac
      case " $seen " in
        *" accepts:$tok "*) ;;
        *) seen="$seen accepts:$tok"; bad="${bad:+$bad, }Accepts '$tok'" ;;
      esac
    done
  done < <(sc_pattern_regions "$pattern_file")

  [ -n "$bad" ] || return 0
  emit "warning" "$pattern_file" \
    "pattern region value outside the closed vocabulary: $bad — 'Fill' is required|optional, 'Accepts' is one or more of data|dispatch|nav|static"
}

#   Reads $SC_ROWS, which check_bindings wrote for this same file: the join asks
#   which binding kinds the screen declares, and that is exactly what the
#   normalized rows already say. The dispatch below keeps the order.
check_join() {
  local file="$1" sev="$2" lifecycle="$3"
  local pattern_file kinds have region fill accepts tok

  # An old-shape screen has no `## Bindings` at all. sections-present already
  # says so; joining a layout against a section that is not there would only
  # repeat it in a second voice.
  sdd_has_section "$file" "Bindings" || return 0

  # Which binding kinds this screen declares at all.
  have=""
  awk -F'\t' '$1 == "ROW" && $2 == "Data" { f=1 } END { exit !f }' "$SC_ROWS" && have="$have data"
  awk -F'\t' '$1 == "ROW" && $2 == "Dispatches" { f=1 } END { exit !f }' "$SC_ROWS" && have="$have dispatch"
  awk -F'\t' '$1 == "ROW" && $2 == "Navigation" { f=1 } END { exit !f }' "$SC_ROWS" && have="$have nav"

  pattern_file="$(sc_header_links "$file" '**Pattern:**' | head -n 1)"
  if [ -n "$pattern_file" ]; then
    if ! sdd_has_section "$pattern_file" "Regions"; then
      case " $SC_PATTERNS_REPORTED " in
        *" $pattern_file "*) ;;
        *)
          SC_PATTERNS_REPORTED="$SC_PATTERNS_REPORTED $pattern_file"
          # Reported on the pattern, because that is the file to change: an
          # entry with no `## Regions` cannot be joined to anything.
          emit "warning" "$pattern_file" \
            "pattern entry declares no '## Regions' table: the screen-to-layout join cannot be checked"
          ;;
      esac
    else
      check_pattern_vocab "$pattern_file"
      while IFS=$'\t' read -r region fill accepts; do
        [ -z "$region" ] && continue
        [ "$fill" = "required" ] || continue
        kinds=""
        for tok in $(printf '%s\n' "$accepts" | tr ',|' '  '); do
          case "$tok" in
            data|dispatch|nav) kinds="$kinds $tok" ;;
          esac
        done
        [ -n "$kinds" ] || continue
        for tok in $kinds; do
          case " $have " in
            *" $tok "*) kinds="SATISFIED"; break ;;
          esac
        done
        if [ "$kinds" != "SATISFIED" ]; then
          emit "$sev" "$file" \
            "pattern join: required region '$region' of $(sdd_artifact_id "$pattern_file") accepts$(printf '%s' "$kinds") and this screen declares no such binding"
        fi
      done < <(sc_pattern_regions "$pattern_file")
    fi
  fi

  # A component still to extract is a promise, not a dependency: it blocks
  # `stable` and nothing else.
  [ "$lifecycle" = "stable" ] || return 0
  local comp_file state
  while IFS= read -r comp_file; do
    [ -n "$comp_file" ] || continue
    state="$(awk 'index($0, "**State:**") == 1 { s = $0; sub(/^\*\*State:\*\*[ \t]*/, "", s); gsub(/[ \t]+$/, "", s); print s; exit }' "$comp_file")"
    if [ "$state" = "to-extract" ]; then
      emit "error" "$file" \
        "stable screen declares a to-extract component: $(sdd_artifact_id "$comp_file") is not implemented yet"
    fi
  done < <(sc_header_links "$file" '**Components:**')
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────────────────────────────────────

SCREEN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_SPEC_ROOT")"

if [ -n "$SCREEN_SCOPE" ]; then
  while IFS= read -r screen_file; do
    [ -z "$screen_file" ] && continue
    row="$(awk -F'\t' -v f="$screen_file" '$1 == f { print; exit }' "$SC_INDEX")"
    s_id="$(printf '%s\n' "$row" | cut -f2)"
    s_module="$(printf '%s\n' "$row" | cut -f3)"
    s_screen="$(printf '%s\n' "$row" | cut -f4)"
    s_lifecycle="$(sdd_fm_value "$screen_file" '.lifecycle')"
    s_sev="$(sdd_progressive_severity "$s_lifecycle")"
    SC_LINK_ROWS="$(sdd_links "$screen_file" wiki)"

    check_identity "$screen_file" "$s_sev" "$s_id" "$s_module" "$s_screen" "$s_lifecycle"
    check_bindings "$screen_file" "$s_sev"
    check_parameters "$screen_file" "$s_sev"
    check_join "$screen_file" "$s_sev" "$s_lifecycle"
  done < <(sdd_find_screens "$SCREEN_SCOPE")
fi

sdd_exit_with_counters
