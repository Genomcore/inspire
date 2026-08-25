#!/usr/bin/env bash
# .inspire/bin/_keyed-heads.sh
#
# Library — not a review rule, and deliberately absent from `review.sh`'s
# DEFAULT_RULES. It carries the readers for the keyed-entry grammar that the
# domain and feature formats share, so that the three rules built on it
# (`keys-present.sh`, `constraints-mechanics.sh`, `unique-conflict-error.sh`)
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
#   `actor(admin)`, `len(3, 64)`, `pattern(/.+@.+/)`. Prose never has that
#   shape. The consequence that matters: a MISSPELLED head is still a head
#   attempt, so `uniqe(email)` is reported rather than silently demoted to
#   prose, which is what a position-based reader would have done.
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
kh_split_args() {
  printf '%s' "$1" | awk '
    {
      depth = 0; cur = ""
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "(") depth++
        else if (c == ")") depth--
        if (c == "," && depth == 0) { print cur; cur = ""; continue }
        cur = cur c
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

# kh_constraints_of <file> <parent_h2> <h3_name>
#   Prints the raw constraint list when the H3's FIRST content line is a
#   well-formed `Constraints:` line; prints nothing and returns 1 when the H3's
#   first line is something else (a legitimate prose-only H3); prints nothing
#   and returns 2 when it IS a Constraints line but malformed (no single
#   backtick span) — a distinction the callers need, because one is a shape and
#   the other is a defect.
kh_constraints_of() {
  local file="$1" parent="$2" h3="$3" first list
  first="$(sdd_body_subsection "$file" "$parent" "$h3" | awk 'NF { print; exit }')"
  case "$first" in
    Constraints:*) ;;
    *) return 1 ;;
  esac
  list="$(printf '%s\n' "$first" \
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
