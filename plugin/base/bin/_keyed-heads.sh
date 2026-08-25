#!/usr/bin/env bash
# .inspire/bin/_keyed-heads.sh
#
# Library — not a review rule, and deliberately absent from `review.sh`'s
# DEFAULT_RULES. It carries the readers for the keyed-entry grammar that the
# domain and feature formats share, so that the three rules built on it
# (`keys-present.sh`, `constraints-mechanics.sh`, `head-referents.sh`)
# cannot drift on what a key, a head or a Constraints line is.
#
# The grammar this file reads is specified once, in
# `.claude/skills/_references/keyed-heads.md`. Two shapes, and only two:
#
#     - `{key}` — {head} — {prose}
#     - `{key}` — {prose}
#
# …and the same pair for a numbered-list section (`1. ` instead of `- `).
#
# Three parsing decisions are load-bearing, and each is the reason a whole class
# of defect is detectable at all:
#
#   THE SEPARATOR IS ` — ` (space, U+2014, space). It is the one the shipped
#   `## Errors` convention already used, so error bullets were conformant before
#   this file existed. Matched byte-wise, which UTF-8 makes safe.
#
#   A HEAD IS RECOGNIZED BY SHAPE, NOT BY POSITION. The first separated segment
#   after the key is a *head attempt* when it is nothing but a lowercase
#   identifier optionally followed by a parenthesized argument list — `unique`,
#   `actor(admin)`, `len(3, 64)`, `pattern(/.+@.+/)` — or by an argument list
#   that opens and never closes, `actor(admin`, which prose does not do either.
#   Prose never has any of those shapes. The consequence that matters: a
#   MISSPELLED head is still a head attempt, so `uniqe(email)` is reported
#   rather than silently demoted to prose, which is what a position-based
#   reader would have done.
#
#   What the shape rule does NOT catch is bounded and stated, rather than
#   claimed away: a head written with the wrong separator (`–`, `-`), or
#   capitalised (`Actor(admin)`), or standing with no prose after it, parses as
#   a prose-only entry. Each is a legal shape on its own terms, so the reader
#   degrades to the weaker claim instead of guessing. `keyed-heads.md`
#   § "What the grammar does not catch" is where that is documented for the
#   author; do not "fix" one of them here without changing it there.
#
#   THE MARKDOWN ORDINAL IS NEVER READ. In `## Behavior` and `## Main flow` the
#   `Bn` key is the step's identity and the `1.` is presentation. Reading the
#   ordinal would re-introduce exactly the positional identity the keys exist to
#   remove: deleting a step would rename its successors.
#
# Sourced after `_lib.sh`, whose readers it composes on.

# ─────────────────────────────────────────────────────────────────────────────
# Vocabularies (closed — see keyed-heads.md; adding a word is a runtime change)
# ─────────────────────────────────────────────────────────────────────────────

# V1 — field and input constraints, as `word:arity`. Arity is the number of
# top-level arguments; `-` means the word takes no parentheses at all.
KH_V1="nonnull:- unique:- immutable:- default:1 enum:1 min:1 max:1 len:2 pattern:1 references:1"
# V2 — invariant heads: V1 restricted to the forms a single field's own line
# cannot express, with an argument list of field names (any arity ≥ 1).
KH_V2="unique:+ nonnull:+ immutable:+ references:1"
# V3 — precondition heads.
KH_V3="actor:1 exists:1 absent:1 state:2"
# V4 — postcondition heads.
KH_V4="created:1 updated:1 deleted:1 unchanged:1 returns:1"
# V5 — error heads: what the error reports the violation of. The words are V1's
# and V3's, but a V1 word's ARGUMENTS MEAN SOMETHING DIFFERENT here: an error
# head names the FIELD it guards (`unique(email)`), not the constraint's own
# value (`len(3, 64)`). The value is already on that field's Constraints line,
# and repeating it in the error would give two spellings of one bound. So every
# field-shaped word takes one or more field names, and the V3 words keep their
# own arity. `default` is absent on purpose: a default cannot fail.
KH_V5="unique:+ nonnull:+ immutable:+ enum:+ min:+ max:+ len:+ pattern:+ references:+ actor:1 exists:1 absent:1 state:2"

# Which oracle asserts a claim carrying this head. Everything not listed here —
# every other head, and every prose-only entry — is a test-oracle claim.
KH_STORE_ORACLE="unique nonnull default references"

# kh_oracle_of <word> — "store" or "test".
kh_oracle_of() {
  local w="$1" s
  for s in $KH_STORE_ORACLE; do
    [ "$w" = "$s" ] && { printf 'store\n'; return 0; }
  done
  printf 'test\n'
}

# ─────────────────────────────────────────────────────────────────────────────
# Severity — the 0.8 grace on the presence classes
# ─────────────────────────────────────────────────────────────────────────────

# The five OLD-SHAPE PRESENCE classes: no `B{n}` on the first `## Behavior`
# step (`OS-A1`), no `## Preconditions` (`OS-A3`) or `## Postconditions`
# (`OS-A4`), no `Constraints:` line on `id` (`OS-E1`), unkeyed or prose
# `## Invariants` (`OS-E3`).
#
# They are FLAT WARNINGS at every lifecycle state in 0.8, the way `W-1` is, and
# the reason is that "new but unkeyed" and "pre-0.8" are the same shape on disk.
# Ramping them with the artifact's own lifecycle would turn every `accepted` or
# `stable` artifact in an upgraded vault red at pre-PR and at `promote` — an
# upgrade that leaves the vault broken, which `/inspire:update` may never do.
# The strict refusal has a home already: `derive` refuses an old-shape artifact
# outright (design D7), which is what the appended note tells the operator the
# warning costs. These five are scheduled to ramp with the lifecycle in the
# release after 0.8, once a touch pass has had a release to run.
#
# Every OTHER old-shape class — the CONTENT of a keyed entry: vocabulary,
# arity, duplicate keys, referents, `unique`+`create`, a misplaced
# `Constraints:` line — is lifecycle-progressive, because that content is
# something the current format's own author got wrong, not something an older
# format left behind.
KH_GRACE_CLASSES="OS-A1 OS-A3 OS-A4 OS-E1 OS-E3"
KH_GRACE_NOTE="— derive refuses old-shape artifacts"

# kh_class_severity <class> <progressive-severity>
#   The severity to report this class at: `warning` for a presence class under
#   the grace, the lifecycle-progressive answer for every other class.
kh_class_severity() {
  local c
  for c in $KH_GRACE_CLASSES; do
    [ "$1" = "$c" ] && { printf 'warning\n'; return 0; }
  done
  printf '%s\n' "$2"
}

# kh_class_note <class>
#   The trailing note a graced class's message ends with (leading space
#   included), or nothing at all for a class that is not under the grace.
kh_class_note() {
  local c
  for c in $KH_GRACE_CLASSES; do
    [ "$1" = "$c" ] && { printf ' %s\n' "$KH_GRACE_NOTE"; return 0; }
  done
  printf '\n'
}

# ─────────────────────────────────────────────────────────────────────────────
# Entry readers
# ─────────────────────────────────────────────────────────────────────────────

# The separator is an em dash, conventionally written with a space on each side.
# Matching is on the DASH ALONE, with surrounding whitespace tolerated, so that
# an author who wrote `- `I1`—prose` is read the same way as one who spaced it.
# `KH_EM` carries the character so no caller re-types it.
KH_EM='—'

# Records emitted by `kh_entries` are separated by U+001F, not by a tab. Tab is
# an IFS whitespace character, which means `IFS=$'\t' read` COLLAPSES runs of
# tabs and strips leading ones — so an entry with no key would shift every
# remaining field one place left and read its prose as its key. A control
# character that is not whitespace preserves empty fields.
KH_FS=$'\037'

# kh_entries <file> <section> <marker>
#   Emits one record per top-level entry in the section, fields separated by
#   $KH_FS:
#       key <FS> head <FS> raw-first-segment <FS> line
#   `marker` is `bullet` (a line starting `- `) or `step` (a line starting
#   `N. `). Anchoring at line start is what makes an indented sub-bullet a
#   continuation rather than a second entry, exactly as the AC-id reader does.
#   `key` is empty when the entry does not open with a backticked token;
#   `head` is empty when the first segment is not a head attempt, and the raw
#   first segment is emitted alongside so a caller can report what it saw.
kh_entries() {
  local file="$1" section="$2" marker="$3"
  sdd_body_section "$file" "$section" \
    | awk -v marker="$marker" -v em="$KH_EM" -v fs="$KH_FS" '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        {
          line = $0
          if (marker == "bullet") {
            if (line !~ /^- /) next
            rest = substr(line, 3)
          } else {
            if (line !~ /^[0-9]+\.[[:space:]]/) next
            p = index(line, ".")
            rest = substr(line, p + 1)
          }
          rest = trim(rest)
          key = ""
          if (substr(rest, 1, 1) == "`") {
            q = index(substr(rest, 2), "`")
            if (q > 0) {
              key = substr(rest, 2, q - 1)
              rest = trim(substr(rest, q + 2))
            }
          }
          # Strip the separator that follows the key, if present.
          if (substr(rest, 1, length(em)) == em) {
            rest = trim(substr(rest, length(em) + 1))
          }
          # First separated segment.
          s = index(rest, em)
          first = (s > 0) ? substr(rest, 1, s - 1) : rest
          first = trim(first)
          head = ""
          if (first ~ /^[a-z][a-z_]*$/ || first ~ /^[a-z][a-z_]*\(.*\)$/) head = first
          # An UNCLOSED argument list is a head attempt too. Prose never opens
          # a parenthesis immediately after a bare lowercase identifier, so
          # `actor(admin` is a mistyped head and not a sentence — and treating
          # it as prose would silently drop the claim, which is the one thing
          # shape-recognition exists to prevent. This is what makes
          # `kh_check_head`s "unclosed argument list" branch reachable.
          else if (first ~ /^[a-z][a-z_]*\(/) head = first
          printf "%s%s%s%s%s%s%s\n", key, fs, head, fs, first, fs, line
        }
      '
}

# kh_section_content_lines <file> <section>
#   The section's content lines — blank lines and comment-only lines dropped,
#   table rows and fences kept. Used to tell "declared none" from "has entries"
#   from "has prose that is neither".
kh_section_content_lines() {
  sdd_body_section "$1" "$2" \
    | awk '
        { gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
        /^$/ { next }
        /^<!--.*-->$/ { next }
        { print }
      '
}

# kh_is_declared_none <file> <section>
#   Exit 0 when the section's whole body is the declared-none one-liner: a
#   single content line beginning with `None` and ending with a period. This is
#   the escape hatch, so it is read permissively — `None.` and the shipped
#   `None beyond Fields constraints.` both qualify.
kh_is_declared_none() {
  local body count first
  body="$(kh_section_content_lines "$1" "$2")"
  count="$(printf '%s' "$body" | grep -c . )"
  [ "$count" = "1" ] || return 1
  first="$(printf '%s\n' "$body" | head -1)"
  case "$first" in
    None|None.|"None "*) ;;
    *) return 1 ;;
  esac
  case "$first" in
    *.) return 0 ;;
    *) return 1 ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Head validation
# ─────────────────────────────────────────────────────────────────────────────

# kh_is_head_shape <string>
#   Exit 0 when the string has the shape a head or a constraint token must have:
#   a lowercase identifier, optionally followed by a parenthesized argument list,
#   and nothing else. This is the single definition of that shape; the readers
#   above and the constraint checks both call it rather than re-typing the regex.
kh_is_head_shape() {
  [[ "$1" =~ ^[a-z][a-z_]*$ ]] && return 0
  [[ "$1" =~ ^[a-z][a-z_]*\(.*\)$ ]] && return 0
  return 1
}

# The W-1 phrase list: constraint words with legitimate prose uses, looked for
# in `Notes` and `Description` cells so that a constraint left behind after its
# machine-readable form moved to a Constraints line is surfaced. Deliberately
# short and closed. Every entry is a heuristic, which is why the finding that
# uses it is a flat warning at every lifecycle and never a refusal.
# Semicolon-separated on ONE line: a value passed through `awk -v` may not
# contain a literal newline on every supported host.
KH_PROSE_CONSTRAINT_PHRASES="unique;immutable;nullable;not null;never updated;write-once;regex;defaults to;at least;at most"

# kh_head_word <head> — the identifier, without arguments.
kh_head_word() {
  printf '%s\n' "${1%%(*}"
}

# kh_head_args <head> — the argument list, or empty when there are no parens.
#   Greedy to the LAST `)` so that a `pattern(/.+)/)` argument survives.
kh_head_args() {
  local h="$1"
  case "$h" in
    *\(*\)) printf '%s\n' "${h#*(}" | sed 's/)$//' ;;
    *) printf '\n' ;;
  esac
}

# kh_split_args <arglist> — one top-level argument per line. Paren-aware, so
#   `len(3, 64)`'s two arguments split while a nested `(a, b)` inside one
#   argument does not. Without this, `len(3,64)` would read as arity 1 and the
#   arity table would be decorative.
#
#   REGEX-AWARE as well, and that is not a nicety. A19 puts no restriction on
#   what `pattern(/…/)` may contain, and the commonest regex forms carry commas
#   and parentheses: `{3,8}`, `[a,b]`, `(x|y)`. Splitting those on the comma
#   would report a correct entity as wrong-arity and, at `accepted`, block its
#   promotion. So a `/…/` span opening where an ARGUMENT opens — at the start
#   of the list, or right after a `(` or a `,` — is one atomic token: commas,
#   parens and `\/` escapes inside it are the regex's, not the grammar's. A `/`
#   anywhere else (`default(2024/01/01)`) is an ordinary character, so a date
#   literal is untouched. An unterminated `/` swallows the rest of the list,
#   which is the conservative reading: one malformed argument, never several.
kh_split_args() {
  printf '%s' "$1" | awk '
    {
      depth = 0; cur = ""; inregex = 0; argstart = 1
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (inregex) {
          cur = cur c
          if (c == "\\" && i < n) { i++; cur = cur substr($0, i, 1); continue }
          if (c == "/") inregex = 0
          continue
        }
        if (c == "/" && argstart) { cur = cur c; inregex = 1; argstart = 0; continue }
        if (c == "(") { depth++; cur = cur c; argstart = 1; continue }
        if (c == ")") { depth--; cur = cur c; argstart = 0; continue }
        if (c == ",") {
          if (depth == 0) { print cur; cur = ""; argstart = 1; continue }
          cur = cur c; argstart = 1; continue
        }
        cur = cur c
        if (c != " " && c != "\t") argstart = 0
      }
      print cur
    }
  ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# kh_check_head <head> <vocabulary>
#   Prints an empty line and exits 0 when the head is well-formed against the
#   vocabulary; otherwise prints the reason and exits 1. Arity spec `-` means
#   "no parentheses at all", `+` means "one or more arguments", a number means
#   exactly that many.
kh_check_head() {
  local head="$1" vocab="$2"
  local word args spec entry n
  word="$(kh_head_word "$head")"
  spec=""
  for entry in $vocab; do
    if [ "${entry%%:*}" = "$word" ]; then spec="${entry##*:}"; break; fi
  done
  if [ -z "$spec" ]; then
    printf 'unknown head `%s` (not in the closed vocabulary)\n' "$word"
    return 1
  fi
  case "$head" in
    *\(*\)) args="$(kh_head_args "$head")" ;;
    *\(*) printf 'head `%s` has an unclosed argument list\n' "$head"; return 1 ;;
    *) args="" ;;
  esac
  if [ "$spec" = "-" ]; then
    case "$head" in
      *\(*) printf 'head `%s` takes no arguments\n' "$word"; return 1 ;;
    esac
    printf '\n'
    return 0
  fi
  case "$head" in
    *\(*\)) ;;
    *) printf 'head `%s` requires an argument list\n' "$word"; return 1 ;;
  esac
  n="$(kh_split_args "$args" | grep -c .)"
  if [ "$spec" = "+" ]; then
    if [ "$n" -lt 1 ]; then
      printf 'head `%s` requires at least one argument\n' "$word"; return 1
    fi
  elif [ "$n" != "$spec" ]; then
    printf 'head `%s` takes %s argument(s), found %s\n' "$word" "$spec" "$n"
    return 1
  fi
  # `pattern` carries a shape obligation beyond arity — but only where its
  # argument IS the regex. In an error head (V5) the same word takes the field
  # it guards instead, which the `+` arity distinguishes from V1's `1`.
  if [ "$word" = "pattern" ] && [ "$spec" = "1" ]; then
    case "$args" in
      /*/) ;;
      *) printf 'head `pattern` expects a /regex/ argument, found `%s`\n' "$args"; return 1 ;;
    esac
  fi
  printf '\n'
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Constraints lines
# ─────────────────────────────────────────────────────────────────────────────

# kh_h3_names <file> <parent_h2>
#   The H3 header names declared inside that H2, in document order. Read the
#   way `sdd_has_section` reads headers: outside frontmatter, outside fences.
kh_h3_names() {
  local file="$1" parent="$2"
  awk -v ph="## $parent" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      $0 == ph { inparent = 1; next }
      /^## / { inparent = 0; next }
      inparent && /^### / {
        h = substr($0, 5)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
        print h
      }
    '"${SDD_AWK_FENCE_FUNCS}" "$file"
}

# kh_constraints_raw_lines <file> <parent_h2> <h3_name>
#   Every `Constraints:`-prefixed line in that H3's body, in document order,
#   each prefixed with a one-character POSITION MARKER: `1` when the line is the
#   H3's first content line, `0` when it sits anywhere later.
#
#   A `Constraints:` line is read WHEREVER it sits, and that is the whole point
#   of this reader. Reading only the first content line meant a line written
#   after a sentence of prose was silently ignored — vocabulary typos, arity
#   errors and all — so a claim the author believed they had made stopped being
#   asserted, which is exactly the failure the closed vocabulary exists to
#   prevent. Placement is still part of the format, so the marker lets the
#   caller report the misplacement (`OS-E8`) *and* validate the line's contents.
#   Content lines are counted the way `kh_section_content_lines` counts them:
#   blank and comment-only lines are not content.
kh_constraints_raw_lines() {
  sdd_body_subsection "$1" "$2" "$3" | awk '
      {
        t = $0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
        if (t == "") next
        if (t ~ /^<!--.*-->$/) next
        seen++
        if ($0 ~ /^Constraints:/) printf "%s%s\n", (seen == 1 ? "1" : "0"), t
      }
    '
}

# kh_constraints_misplaced <file> <parent_h2> <h3_name>
#   Every `Constraints:` line in the H3 body that is NOT its first content
#   line, one per line, marker stripped. Empty when the H3 carries at most one
#   and it is correctly placed — so a second `Constraints:` line is reported
#   too, since at most one line can be the first.
kh_constraints_misplaced() {
  kh_constraints_raw_lines "$1" "$2" "$3" | sed -n 's/^0//p'
}

# kh_constraints_of <file> <parent_h2> <h3_name>
#   Prints the raw constraint list of the FIRST `Constraints:` line anywhere in
#   the H3 body; prints nothing and returns 1 when the H3 carries no such line
#   at all (a legitimate prose-only H3); prints nothing and returns 2 when it
#   DOES carry one but malformed (no single backtick span) — a distinction the
#   callers need, because one is a shape and the other is a defect.
kh_constraints_of() {
  local raw list
  raw="$(kh_constraints_raw_lines "$1" "$2" "$3" | head -1)"
  [ -n "$raw" ] || return 1
  raw="${raw#?}"
  list="$(printf '%s\n' "$raw" \
    | sed -n 's/^Constraints:[[:space:]]*`\(.*\)`[[:space:]]*$/\1/p')"
  [ -n "$list" ] || return 2
  printf '%s\n' "$list"
}

# kh_split_constraints <list> — one constraint token per line, paren-aware, so
#   `nonnull, len(3, 64)` yields two tokens and not three.
kh_split_constraints() {
  kh_split_args "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Table readers the domain rules need and `_lib.sh` does not already carry
# ─────────────────────────────────────────────────────────────────────────────

# kh_first_column <file> <section> — the first column of that section's table,
#   backticks stripped, header and separator rows skipped. Used for `## Inputs`
#   parameters and `## Outputs` fields; a section with no table yields nothing,
#   which is the correct reading of the whole-entity Outputs one-liner.
kh_first_column() {
  sdd_body_section "$1" "$2" \
    | awk '
      /^\|/ {
        gsub(/^\|[[:space:]]*|[[:space:]]*\|$/, "")
        n = split($0, parts, /[[:space:]]*\|[[:space:]]*/)
        if (n < 1) next
        cell = parts[1]
        gsub(/^`|`$/, "", cell)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
        if (cell == "" || cell ~ /^-+$/) next
        if (cell == "Parameter" || cell == "Field" || cell == "Action" || cell == "Key") next
        print cell
      }
    '
}

# kh_dotted <id> — an entity or action id in dotted form, whatever it arrived
#   as. Claim ids and heads are dotted; `## Entities` H3s are colon-form.
kh_dotted() {
  printf '%s\n' "${1//::/.}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Comment stripping
# ─────────────────────────────────────────────────────────────────────────────

# kh_strip_comments <file>
#   The file with every HTML comment blanked out, line structure preserved (a
#   line that was entirely comment becomes empty, never deleted, so nothing
#   above and below it merges). Multi-line comments are tracked across lines.
#   Fenced blocks pass through verbatim: a comment quoted inside a fence is
#   sample text.
#
#   The rules built on this file strip comments in EVERY layer, which is a
#   deliberate divergence from `sections-present.sh` (which strips only outside
#   `04_domain`). The reason is new: the 0.8 action and entity templates carry
#   guidance comments that name the very keys and Constraints lines these rules
#   look for, so a descriptor copied from a template and not yet filled in would
#   otherwise read as though it declared them.
kh_strip_comments() {
  awk '
      !incomment && sdd_fence($0) { print; next }
      !incomment && sdd_in_fence() { print; next }
      {
        out = ""; rest = $0
        while (1) {
          if (incomment) {
            p = index(rest, "-->")
            if (p == 0) { break }
            rest = substr(rest, p + 3); incomment = 0
          } else {
            p = index(rest, "<!--")
            if (p == 0) { out = out rest; break }
            out = out substr(rest, 1, p - 1)
            rest = substr(rest, p + 4); incomment = 1
          }
        }
        print out
      }
    '"${SDD_AWK_FENCE_FUNCS}" "$1"
}
