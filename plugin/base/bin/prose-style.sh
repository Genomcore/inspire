#!/usr/bin/env bash
# .inspire/bin/prose-style.sh
#
# Rule: the mechanical subset of the writing contract
# (`.claude/skills/_references/writing-style.md`). The contract is the whole
# rule and the authoring skills carry it as judgment; this file is the part of
# it a script can grep, and it says so rather than implying more.
#
# ─── Language gate ───────────────────────────────────────────────────────────
#
# The checks below are English morphology (R1, R3, the R6 token list) keyed on
# English H2 names (the binding table). A compliant non-`en` fork translates its
# headers — headers are prose, not machine-read tokens — so even the
# language-independent rules would have no section kind to bind to. When
# `$SDD_KB_ROOT/00_bootstrap/project.md` declares an `output_language` other
# than English, this script emits ONE info-level note and exits 0. Absent or
# empty `output_language` reads as `en`, exactly as `session-start.sh` reads it.
#
# The field is authored by a human and project.md invites a code OR a plain name,
# so English is recognised case-insensitively as `en`, `en-*`/`en_*` (`en-US`,
# `en_GB`) or `english`. Reading only the byte string `en` would silently skip
# checking on every one of those spellings, and a checker that quietly checks
# nothing is worse than one that says out loud it cannot.
#
# ─── The checks ──────────────────────────────────────────────────────────────
#
#   R2  sentence cap        — at most 25 words per sentence   (contract §R2)
#   R4  glossary synonyms   — a rejected synonym from `00_bootstrap/glossary.md`
#   R5  paragraph length    — at most 6 sentences per paragraph
#   R6  historical language — the CLOSED token list: `previously`, `used to`,
#                             `migrated from`, `~~strikethrough~~`. `replaces`
#                             and `removed` are deliberately NOT checked: both
#                             have legitimate present-tense uses in this vault,
#                             and a check that flagged them would train
#                             operators to ignore it. `used to` is narrowed the
#                             same way — it fires on the historical construction
#                             ("the caller used to send a cookie") and not on the
#                             passive-purpose one ("the salt is used to derive
#                             the key"), which a be-verb immediately before the
#                             phrase distinguishes.
#   R1  passive voice       — be-verb + past participle, heuristic
#   R3  noun clusters       — 4+ consecutive content nouns, heuristic
#
# Severity. R2, R4, R5 and R6 are lifecycle-progressive where a `lifecycle:`
# field exists (the `04_domain` layer, via `sdd_progressive_severity`: draft →
# warning, accepted/stable → error, superseded → warning) and flat warnings
# everywhere else, because features, ADRs and screens carry no lifecycle at all.
# R1 and R3 are heuristics: they are warnings at EVERY lifecycle and never ramp,
# in either layer. A guess does not get to block a commit.
#
# ─── What binds where (the contract's binding table, keyed per layer) ────────
#
#   kind        | checks               | sections
#   ------------|----------------------|------------------------------------
#   normative   | R1 R2 R3 R4 R5 R6    | everything not named below
#   ac          | R1 R2 R3 R4 R6       | feature `## Acceptance criteria`
#   tabular     | R3 R4 R6             | action `## Inputs` `## Outputs`
#               |                      | `## Entities` `## Errors`; entity
#               |                      | `## Fields` `## Touched by`; ADR
#               |                      | `## Related ADRs` (R6-exempt)
#
# An H2 the map does not name reads as normative prose — the permissive
# direction, since a table-only section yields no prose lines to check anyway.
#
# ─── What 0.7 mechanically reaches, and what it does not ─────────────────────
#
# Every check reads `sdd_body_prose` (_lib.sh), which is `sdd_body_section`
# minus fenced blocks, minus table rows, minus bare `---` thematic breaks, with
# wikilinks unwrapped to their display text. That reader draws the boundary, and
# the boundary is narrower than the contract:
#
#   - TABLE CELLS ARE NEVER READ. The prose reader drops table rows, so R3, R4
#     and R6 reach only the prose that SURROUNDS a table in a tabular section,
#     never the cells themselves. The contract binds the cells; 0.7 does not
#     check them. A column header is exactly where a noun cluster hides best,
#     and that hiding place is left to judgment for now.
#   - PROSE ABOVE THE FIRST H2 IS NEVER READ. The classification is keyed on H2
#     names, so a feature's one-line description, a screen's `**Features:**` /
#     `**Pattern:**` preamble and an ADR's `**Status:**` block sit outside every
#     section and are unchecked.
#   - PER-FIELD `### {field}` PROSE INSIDE `## Fields` READS AS TABULAR. An
#     entity's per-field H3 notes are normative prose, but H2-level
#     classification cannot see them: they inherit their parent's kind and get
#     R3/R4/R6 only. Recorded, not solved, in 0.7.
#   - R1 AND R3 ARE HEURISTICS, and R2's sentence splitter is one too. They
#     mis-read some sentences in both directions. That is why they never ramp.
#   - R4 MATCHES WHOLE WORDS ONLY. Boundary matching misses inflections: a
#     glossary rejecting `organization` does not catch `organizations`. Exact
#     word, or nothing — judgment owns the rest.
#   - A THEMATIC BREAK ARRIVES ALREADY STRIPPED, AND ONLY THE `---` SHAPE.
#     `sdd_body_prose` drops a bare `---`; the other two thematic breaks
#     CommonMark allows, `***` and `___`, reach this script as prose lines and
#     are measured as words. A `---` written with blank lines around it — the
#     normal shape — still separates two paragraphs, and R5 measures them
#     separately. Written with NO blank line above and below, the two paragraphs
#     merge into one measurement unit and R5 counts them as one; that shape is a
#     setext H2 underline in markdown rather than a break, so it is left as is.
#   - INLINE CODE IS NOT PROSE for R1, R3, R4 and R6: their line is read with
#     `` `code spans` `` blanked out, so a token quoted as a token is not a claim
#     about the system. R2 keeps them — a code span is still a word the reader
#     reads, and dropping it would under-count the sentence.
#   - A NON-ENGLISH PROJECT IS NOT CHECKED AT ALL (see the language gate above).
#
# ─── R6 exemptions (contract § Historical language) ─────────────────────────
#
#   - an ADR's `### Breaking changes` content — naming what breaks IS its job;
#   - an ADR's `## Related ADRs` section;
#   - a `**Status:**` line, including `superseded by [[…]]`;
#   - a `Supersedes: [[…]]` header line.
#
# The last two are checked line-wise wherever they appear, not only in the
# preamble the reader never sees, so the exemption holds if such a line is
# written inside a section body.
#
# The exemptions are R6's alone. An exempt line is ordinary prose for R1, R2, R3
# and R5 — it still carries a sentence, and it still belongs to the paragraph it
# sits in. Widening them to every rule would silently un-check whole lines on the
# strength of a rule about history.
#
# ─── R4, in one pass ─────────────────────────────────────────────────────────
#
# The synonym scan runs on the PR gate, so it never spawns a process per file
# per glossary row. Every prose line of every checked file is appended to ONE
# stream (inline-code spans and wikilink-remnant ids removed), with a parallel
# index carrying `file / section / layer / original line`. One `grep -inE -f`
# over that stream finds the hits; one awk attributes each hit to its file and
# to the approved term. `00_bootstrap/glossary.md` is not in any checked layer,
# so the glossary never matches itself. No glossary, or a glossary with zero
# data rows, disables R4 entirely — an empty term list binds nothing.
#
# Scope: the rule receives one `$1` and checks `$1 ∩ each of its layers` — see
# `bin/README.md` §Scope, resolved through the same `sdd_scope_intersect` every
# other rule uses. Absent `$1`, every layer scans its own full root.
#
# Usage:
#   .inspire/bin/prose-style.sh                              # every layer
#   .inspire/bin/prose-style.sh inspire_kb                   # every layer
#   .inspire/bin/prose-style.sh inspire_kb/04_domain/auth    # domain only
#   .inspire/bin/prose-style.sh inspire_kb/01_adr            # ADRs only

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

# The contract's own numbers (writing-style.md §R2, §R5). Encoded once.
R2_MAX_WORDS=25
R5_MAX_SENTENCES=6

# ─────────────────────────────────────────────────────────────────────────────
# Language gate — first, before anything is read
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_FILE="$SDD_KB_ROOT/00_bootstrap/project.md"
OUTPUT_LANGUAGE=""
if [ -f "$PROJECT_FILE" ]; then
  OUTPUT_LANGUAGE="$(sdd_fm_value "$PROJECT_FILE" '.output_language')"
fi
[ -n "$OUTPUT_LANGUAGE" ] && [ "$OUTPUT_LANGUAGE" != "null" ] || OUTPUT_LANGUAGE="en"

# `output_language` is authored by a human, and project.md's own comment invites
# a plain name as much as a code. `EN`, `en-US`, `en_GB` and `English` all
# declare English, and reading only the byte string `en` would silently skip
# every one of them — a checker that quietly checks nothing is worse than one
# that says it cannot. Anything else is another language and stops the run.
PS_LANG="$(printf '%s' "$OUTPUT_LANGUAGE" | tr '[:upper:]' '[:lower:]')"
case "$PS_LANG" in
  en|en-*|en_*|english) ;;
  *)
    sdd_finding "info" "prose-style" "$PROJECT_FILE" \
      "output_language: $OUTPUT_LANGUAGE — prose-style mechanical checks are en-only in 0.7; the writing contract still binds as authoring judgment"
    exit 0
    ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# Scratch files — one set for the whole run, removed by the EXIT trap
# ─────────────────────────────────────────────────────────────────────────────

PS_TMP=""        # comment-stripped copy of the file being read
PS_FLAT=""       # the same copy with wikilinks unwrapped — the locator's source
R4_STREAM=""     # concatenated prose, cleaned, one line per collected line
R4_INDEX=""      # parallel index: file<TAB>section<TAB>layer<TAB>original line

ps_cleanup() {
  local rc=$?
  [ -n "$PS_TMP" ] && rm -f "$PS_TMP"
  [ -n "$PS_FLAT" ] && rm -f "$PS_FLAT"
  [ -n "$R4_STREAM" ] && rm -f "$R4_STREAM"
  [ -n "$R4_INDEX" ] && rm -f "$R4_INDEX"
  [ -n "${R4_TERMS:-}" ] && rm -f "$R4_TERMS"
  [ -n "${R4_PATTERNS:-}" ] && rm -f "$R4_PATTERNS"
  [ -n "${R4_HITS:-}" ] && rm -f "$R4_HITS"
  return $rc
}
trap ps_cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────────
# Readers
# ─────────────────────────────────────────────────────────────────────────────

# strip_html_comments <file>
#   The file with every HTML comment blanked out, line structure preserved (a
#   line that was entirely comment becomes an empty line, never a deleted one),
#   so line numbers still name the same lines in the original. Multi-line
#   comments are tracked across lines; fenced blocks pass through verbatim,
#   using the shared fence reader.
#
#   Every layer is read this way, not only the three whose templates carry
#   guidance comments: a comment is authoring guidance in any file, and prose
#   style is not a property of guidance. `sections-present.sh` reads its own
#   copy the same way for the same reason — the fence functions are shared
#   (`_lib.sh`), the six lines of comment tracking are not.
strip_html_comments() {
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

# h2_list <file>
#   The file's H2 header names in document order, deduplicated, read outside
#   frontmatter and outside fences. A repeated H2 is listed once: the body
#   reader answers with the first occurrence either way, so scanning it twice
#   would only double every finding it makes.
h2_list() {
  awk \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      /^## / {
        h = substr($0, 4)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
        if (h != "" && !(h in seen)) { seen[h] = 1; print h }
      }
    '"${SDD_AWK_FENCE_FUNCS}" "$1"
}

# section_kind <layer> <header> — normative | ac | tabular
section_kind() {
  case "$1" in
    action)
      case "$2" in
        Inputs|Outputs|Entities|Errors) printf 'tabular\n' ;;
        *) printf 'normative\n' ;;
      esac ;;
    entity)
      case "$2" in
        Fields|"Touched by") printf 'tabular\n' ;;
        *) printf 'normative\n' ;;
      esac ;;
    feature)
      case "$2" in
        "Acceptance criteria") printf 'ac\n' ;;
        *) printf 'normative\n' ;;
      esac ;;
    adr)
      case "$2" in
        "Related ADRs") printf 'tabular\n' ;;
        *) printf 'normative\n' ;;
      esac ;;
    *) printf 'normative\n' ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# The scanner
#
# One awk pass per section runs every line-based check and, when R4 is armed,
# writes that section's contribution to the shared stream. It prints one record
# per finding: check<TAB>anchor line<TAB>detail.
# ─────────────────────────────────────────────────────────────────────────────

# Words that never count as a noun in a cluster: articles, determiners,
# prepositions, conjunctions, pronouns, auxiliaries and the handful of adverbs
# that bind clauses. A run of four content words with none of these between them
# and no punctuation is the shape R3 names.
PS_STOPWORDS="a an the this that these those its his her their our your my \
each every any some no all both one two three first second next last other \
another same such which what who whose whom when where why how there here \
of in on at to for with by from as and or but nor so than then if unless \
until while because since after before during per via into onto over under \
between across against about without within above below out off near upon \
toward towards through throughout along around among besides despite except \
it they them we us you he she i one \
is are was were be been being am has have had do does did done \
can could may might must shall should will would not never always only also \
still already yet more most less least very too just even rather again once \
ever much many few own such same way ways thing things"

# The participles a be-verb turns passive that do not end in `ed`. The `ed`
# ending is matched by pattern; these are the irregulars worth naming.
PS_IRREGULARS="written|shown|done|made|given|taken|seen|known|kept|held|sent|built|found|drawn|thrown|chosen|driven|hidden|broken|frozen|lost|left|met|paid|read|set|put|cut|run|begun|rewritten|overwritten|undone|withheld"

# prose_scan <kind> <skip_breaking_changes> <r6_exempt_section> <index_record>
#   Reads prose on stdin. Emits finding records on stdout.
prose_scan() {
  local kind="$1" skipbc="$2" exempt6="$3" idxrec="$4"
  local do_r1=0 do_r2=0 do_r3=0 do_r5=0 do_r6=0
  case "$kind" in
    normative) do_r1=1; do_r2=1; do_r3=1; do_r5=1; do_r6=1 ;;
    ac)        do_r1=1; do_r2=1; do_r3=1; do_r6=1 ;;
    tabular)   do_r3=1; do_r6=1 ;;
  esac
  [ "$exempt6" = "1" ] && do_r6=0

  awk -v do_r1="$do_r1" -v do_r2="$do_r2" -v do_r3="$do_r3" \
      -v do_r5="$do_r5" -v do_r6="$do_r6" -v skipbc="$skipbc" \
      -v maxwords="$R2_MAX_WORDS" -v maxsent="$R5_MAX_SENTENCES" \
      -v stopwords="$PS_STOPWORDS" -v irregulars="$PS_IRREGULARS" \
      -v r4stream="${R4_STREAM_ARMED:-}" -v r4index="${R4_INDEX_ARMED:-}" \
      -v idxrec="$idxrec" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }

    function emit(c, a, d) {
      gsub(/\t/, " ", a); gsub(/\t/, " ", d)
      printf "%s\t%s\t%s\n", c, a, d
    }

    function wordcount(s,   n, a, i, c) {
      n = split(s, a, /[[:space:]]+/); c = 0
      for (i = 1; i <= n; i++) if (a[i] ~ /[A-Za-z0-9]/) c++
      return c
    }

    function excerpt(s,   n, a, i, o) {
      n = split(trim(s), a, /[[:space:]]+/); o = ""
      for (i = 1; i <= n && i <= 8; i++) o = o (i > 1 ? " " : "") a[i]
      if (n > 8) o = o " ..."
      return o
    }

    # An abbreviation-final period does not end a sentence. The list is the
    # handful that occur in specification prose; a one-letter token is an
    # initial and is treated the same way.
    function is_abbrev(s, i,   j, w) {
      j = i
      while (j > 1 && substr(s, j - 1, 1) != " ") j--
      w = tolower(substr(s, j, i - j))
      if (length(w) <= 1) return 1
      return (w ~ /^(e\.g|i\.e|etc|vs|cf|fig|no|nos|mr|ms|mrs|dr|prof|approx|resp|al|ca|st)$/)
    }

    # Index of the character that closes the first complete sentence in s, or 0.
    # A terminator counts only when a space or the end of the accumulated text
    # follows it (so `200.5` and `auth.user` never split), and closing quotes or
    # brackets ride along with it.
    function find_terminator(s,   i, ch, j, nxt, L) {
      L = length(s)
      for (i = 1; i <= L; i++) {
        ch = substr(s, i, 1)
        if (ch != "." && ch != "!" && ch != "?") continue
        j = i
        while (j < L && index("\")]}", substr(s, j + 1, 1)) > 0) j++
        nxt = (j >= L) ? "" : substr(s, j + 1, 1)
        if (nxt != "" && nxt != " " && nxt != "\t") continue
        if (ch == "." && is_abbrev(s, i)) continue
        return j
      }
      return 0
    }

    function sent_flush(   cnt) {
      if (trim(cur) == "") { cur = ""; return }
      usent++
      if (do_r2) {
        cnt = wordcount(cur)
        if (cnt > maxwords)
          emit("R2", curanchor, cnt "|" excerpt(cur))
      }
      cur = ""
    }

    function unit_end() {
      if (trim(cur) != "") sent_flush()
      if (do_r5 && usent > maxsent) emit("R5", uanchor, usent)
      usent = 0; uanchor = ""; cur = ""; curanchor = ""
    }

    function check_r3(s,   n, a, i, w, clean, run, runtext) {
      gsub(/`[^`]*`/, " x ", s)
      n = split(s, a, /[[:space:]]+/)
      run = 0; runtext = ""
      for (i = 1; i <= n; i++) {
        w = a[i]
        clean = w
        gsub(/^[^A-Za-z]+/, "", clean); gsub(/[^A-Za-z]+$/, "", clean)
        if (clean == "" || length(clean) < 3 || clean ~ /[^A-Za-z]/ \
            || tolower(clean) in STOP || tolower(clean) ~ /(ly|ing|ed)$/) {
          run = 0; runtext = ""
        } else {
          run++
          runtext = runtext (runtext == "" ? "" : " ") clean
          if (run >= 4) { emit("R3", raw, runtext); return }
        }
        # Punctuation closing the token closes the run behind it.
        if (w ~ /[,;:.!?()\[\]{}"]$/) { run = 0; runtext = "" }
      }
    }

    BEGIN {
      n = split(stopwords, sw, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (sw[i] != "") STOP[sw[i]] = 1
      passive_ed = "(^|[^A-Za-z])(is|are|was|were|be|been|being|am)[ \t]+[A-Za-z]+ed([^A-Za-z]|$)"
      passive_irr = "(^|[^A-Za-z])(is|are|was|were|be|been|being|am)[ \t]+(" irregulars ")([^A-Za-z]|$)"
      usent = 0
    }

    {
      raw = $0
      gsub(/\t/, " ", raw)

      # R4 collection — every prose line, whatever its kind, minus inline-code
      # spans and minus the id-shaped remnants a wikilink leaves behind once
      # `sdd_body_prose` has unwrapped it (`auth::user`, `auth.user.create`,
      # `adr-some-slug`). Those are machine-read tokens, which the contract
      # exempts; matching a synonym inside one would be a finding about a link.
      # Known limit of the id stripper: a glossary synonym that itself contains a
      # dot or a `::` can never match, because the id shapes are eaten first. A
      # rejected synonym is a word the team says out loud, so this costs nothing
      # in practice — but it is a silent miss, not a decision.
      if (r4stream != "") {
        c = tolower(raw)
        gsub(/`[^`]*`/, " ", c)
        gsub(/[a-z0-9_]+(::[a-z0-9_]+)+/, " ", c)
        gsub(/[a-z0-9_]+(\.[a-z0-9_]+)+/, " ", c)
        gsub(/adr-[a-z0-9_-]+/, " ", c)
        print c >> r4stream
        print idxrec "\t" raw >> r4index
      }

      line = raw

      # `### Breaking changes` runs until the next H3 or the end of the section.
      if (skipbc == "1") {
        if (line ~ /^[[:space:]]*###[[:space:]]+Breaking changes[[:space:]]*$/) { bc = 1 }
        else if (line ~ /^[[:space:]]*#{1,6}[[:space:]]/) { bc = 0 }
      }

      if (trim(line) == "") { unit_end(); next }
      if (line ~ /^[[:space:]]*#{1,6}[[:space:]]/) { unit_end(); next }

      # A list is not a paragraph: each item is measured on its own, so a marker
      # closes the previous unit and opens a new one. (writing-style.md §R5)
      body = line
      if (line ~ /^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+/) {
        unit_end()
        sub(/^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+/, "", body)
        # An acceptance criterion opens with a checkbox. It is structure, not
        # words, so it is not counted as words.
        sub(/^\[[ xX]\][[:space:]]+/, "", body)
      }

      # The contract scopes these exemptions to R6 and to nothing else
      # (writing-style.md § Historical language). A `**Status:**` line is still
      # prose for every other rule, and it still belongs to the paragraph it
      # sits in.
      exempt_r6 = (bc == 1) \
        || line ~ /^[[:space:]]*\*\*Status:\*\*/ \
        || line ~ /^[[:space:]]*(\*\*)?Supersedes:/

      # Inline code is not prose. R1 and R6 measure the line with its code spans
      # blanked, so a `previously` quoted as a token — or a wikilink that
      # unwrapped into one — is not read as a claim about the system. R3 blanks
      # them itself, with a placeholder that also breaks the noun run. R2 keeps
      # them: a code span is still a word the reader reads.
      nocode = line
      gsub(/`[^`]*`/, " ", nocode)

      if (do_r1) {
        if (match(nocode, passive_ed) || match(nocode, passive_irr))
          emit("R1", raw, trim(substr(nocode, RSTART, RLENGTH)))
      }

      if (do_r3) check_r3(line)

      if (do_r6 && !exempt_r6) {
        lc = tolower(nocode)
        if (match(lc, /(^|[^a-z])previously([^a-z]|$)/)) emit("R6", raw, "previously")
        # `used to` is history only in the historical construction. "The caller
        # used to send a cookie" narrates the past; "the salt is used to derive
        # the key" states present behavior, and a be-verb immediately before the
        # phrase is what separates them. The narrowing is deliberate: flagging
        # the passive-purpose form would train operators to ignore the rule, the
        # same reasoning that keeps `replaces` and `removed` off the token list.
        # A line carrying both constructions reads as the passive one and is not
        # flagged — under-reporting is the safe direction for a closed list.
        if (match(lc, /(^|[^a-z])used to([^a-z]|$)/) \
            && !match(lc, /(^|[^a-z])(is|are|was|were|be|been|being|am)[[:space:]]+used to([^a-z]|$)/))
          emit("R6", raw, "used to")
        if (match(lc, /(^|[^a-z])migrated from([^a-z]|$)/)) emit("R6", raw, "migrated from")
        if (nocode ~ /~~[^~]+~~/) emit("R6", raw, "~~strikethrough~~")
      }

      if (uanchor == "") uanchor = raw
      if (cur == "") curanchor = raw
      cur = cur (cur == "" ? "" : " ") body

      while (1) {
        p = find_terminator(cur)
        if (p == 0) break
        rest = substr(cur, p + 1)
        cur = substr(cur, 1, p)
        sent_flush()
        cur = trim(rest)
        curanchor = raw
      }
    }

    END { unit_end() }
  '
}

# ─────────────────────────────────────────────────────────────────────────────
# Emission
# ─────────────────────────────────────────────────────────────────────────────

CUR_FILE=""      # the artifact a finding names
CUR_READ=""      # the comment-stripped copy actually parsed
CUR_LAYER=""
CUR_SECTION=""
RAMP_SEV=""

# ramp_sev — sets RAMP_SEV for the current file. The lifecycle is read at most
# once per file, and only when a ramping finding is about to be emitted: a clean
# file never pays for a yq call.
ramp_sev() {
  [ -n "$RAMP_SEV" ] && return 0
  case "$CUR_LAYER" in
    action|entity)
      RAMP_SEV="$(sdd_progressive_severity "$(sdd_fm_value "$CUR_FILE" '.lifecycle')")" ;;
    *) RAMP_SEV="warning" ;;
  esac
}

# flatten_copy <file> <dest>
#   The locator's source: the file with HTML comments blanked and wikilinks
#   unwrapped exactly the way `sdd_body_prose` unwraps them. Both passes are
#   line-preserving — comments become blank lines, the unwrap is a per-line
#   substitution — so line N of this copy is line N of the artifact.
#
#   It exists because the anchor a finding carries has ALREADY been unwrapped:
#   looking `auth::user` up in a file that says `[[auth.user|auth::user]]` fails
#   on every wikilink-bearing line, which in a back-sourced KB is most of the
#   normative prose. Without this the common case silently degraded to the
#   section header's line number.
flatten_copy() {
  strip_html_comments "$1" \
    | sed -E 's/\[\[([^]|]*)\|([^]]*)\]\]/\2/g; s/\[\[([^]]*)\]\]/\1/g' > "$2"
}

# locate_line <read_file> <section> <anchor text>
#   The line the finding points at, looked up verbatim in the flattened copy.
#   The fallback is the section header's own line, which always resolves: an
#   anchor can still miss when the prose reader changed the text some other way
#   (a table row folded out from between two prose lines, say).
locate_line() {
  local read_file="$1" section="$2" anchor="$3" n=""
  if [ -n "$anchor" ]; then
    n="$(grep -nF -m1 -e "$anchor" "$read_file" 2>/dev/null | head -1 | cut -d: -f1)"
  fi
  if [ -z "$n" ]; then
    n="$(grep -nF -m1 -e "## $section" "$read_file" 2>/dev/null | head -1 | cut -d: -f1)"
  fi
  [ -n "$n" ] || n=0
  printf '%s\n' "$n"
}

emit_finding() {
  local check="$1" anchor="$2" detail="$3"
  local sev line msg
  case "$check" in
    R1|R3) sev="warning" ;;
    *) ramp_sev; sev="$RAMP_SEV" ;;
  esac
  line="$(locate_line "$CUR_READ" "$CUR_SECTION" "$anchor")"
  case "$check" in
    R1)
      msg="R1 passive voice: '$detail' in '## $CUR_SECTION' (line $line) — name the actor" ;;
    R2)
      msg="R2 sentence cap: sentence of ${detail%%|*} words exceeds $R2_MAX_WORDS in '## $CUR_SECTION' (line $line): ${detail#*|}" ;;
    R3)
      msg="R3 noun cluster: stacked nouns '$detail' in '## $CUR_SECTION' (line $line) — a preposition removes the ambiguity" ;;
    R5)
      msg="R5 paragraph length: paragraph of $detail sentences exceeds $R5_MAX_SENTENCES in '## $CUR_SECTION' (line $line)" ;;
    R6)
      msg="R6 historical language: '$detail' in '## $CUR_SECTION' (line $line) — state the present, git carries the history" ;;
    *) return 0 ;;
  esac
  sdd_finding "$sev" "prose-style" "$CUR_FILE" "$msg"
  sdd_count_by_severity "$sev"
}

# ─────────────────────────────────────────────────────────────────────────────
# R4 — the glossary term list
# ─────────────────────────────────────────────────────────────────────────────

R4_TERMS=""
R4_PATTERNS=""
R4_HITS=""
R4_STREAM_ARMED=""
R4_INDEX_ARMED=""

# build_glossary — reads `$SDD_KB_ROOT/00_bootstrap/glossary.md` into the two
# files R4 needs, and arms the collection when there is at least one term to
# look for. The table is `| Term | Rejected synonyms | Definition |`; the
# synonyms cell is a comma-separated list. Header and separator rows are
# skipped, and a row with no rejected synonyms contributes nothing.
build_glossary() {
  local glossary="$SDD_KB_ROOT/00_bootstrap/glossary.md"
  [ -f "$glossary" ] || return 0

  R4_TERMS="$(mktemp -t sdd-prose-terms.XXXXXX)" || return 0
  R4_PATTERNS="$(mktemp -t sdd-prose-pat.XXXXXX)" || return 0

  awk -F'[[:space:]]*\\|[[:space:]]*' '
    function esc(s) { gsub(/[][\\.^$*+?(){}|]/, "\\\\&", s); return s }
    /^[[:space:]]*\|/ {
      term = $2; syns = $3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", term)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", syns)
      gsub(/`/, "", term); gsub(/`/, "", syns)
      if (term == "" || syns == "") next
      if (tolower(term) == "term" || term ~ /^-+$/) next
      n = split(syns, parts, /[[:space:]]*,[[:space:]]*/)
      for (i = 1; i <= n; i++) {
        s = parts[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        if (s == "" || s == "—" || s == "-" || tolower(s) == "none") continue
        print tolower(esc(s)) "\t" term "\t" s
      }
    }
  ' "$glossary" | sort -u > "$R4_TERMS"

  if [ ! -s "$R4_TERMS" ]; then
    # No glossary rows, or none with rejected synonyms: an empty term list binds
    # nothing, so R4 stays disarmed rather than scanning for the empty pattern.
    return 0
  fi

  # `\b` is not portable across BSD and GNU grep; an explicit non-word class on
  # both sides is, and says the same thing.
  awk -F'\t' '{ print "(^|[^a-z0-9_])" $1 "([^a-z0-9_]|$)" }' "$R4_TERMS" > "$R4_PATTERNS"

  R4_STREAM="$(mktemp -t sdd-prose-stream.XXXXXX)" || return 0
  R4_INDEX="$(mktemp -t sdd-prose-index.XXXXXX)" || return 0
  R4_STREAM_ARMED="$R4_STREAM"
  R4_INDEX_ARMED="$R4_INDEX"
}

# run_r4 — the one pass. One grep over the whole concatenated stream, one awk to
# attribute each hit back to its file, section and approved term.
run_r4() {
  [ -n "$R4_STREAM_ARMED" ] || return 0
  [ -s "$R4_STREAM" ] || return 0

  R4_HITS="$(mktemp -t sdd-prose-hits.XXXXXX)" || return 0
  grep -inE -f "$R4_PATTERNS" "$R4_STREAM" > "$R4_HITS" 2>/dev/null
  [ -s "$R4_HITS" ] || return 0

  local file section layer anchor syn term sev line msg
  while IFS=$'\t' read -r file section layer anchor syn term; do
    [ -z "$file" ] && continue
    if [ "$file" != "$CUR_FILE" ]; then
      CUR_FILE="$file"
      CUR_LAYER="$layer"
      RAMP_SEV=""
      # The walk's flattened copy is long gone by now — R4 runs after every file
      # — so it is rebuilt here, once per file that actually has a hit.
      CUR_READ="$file"
      if [ -n "$PS_FLAT" ] && flatten_copy "$file" "$PS_FLAT"; then
        CUR_READ="$PS_FLAT"
      fi
    fi
    CUR_LAYER="$layer"
    CUR_SECTION="$section"
    ramp_sev
    sev="$RAMP_SEV"
    line="$(locate_line "$CUR_READ" "$section" "$anchor")"
    msg="R4 glossary synonym: '$syn' in '## $section' (line $line) — the glossary's approved term is '$term'"
    sdd_finding "$sev" "prose-style" "$file" "$msg"
    sdd_count_by_severity "$sev"
  done < <(awk -F'\t' -v tf="$R4_TERMS" -v xf="$R4_INDEX" '
      FILENAME == tf { pat[++ns] = $1; app[ns] = $2; disp[ns] = $3; next }
      FILENAME == xf { f[FNR] = $1; s[FNR] = $2; l[FNR] = $3; o[FNR] = $4; next }
      {
        p = index($0, ":")
        if (p == 0) next
        n = substr($0, 1, p - 1) + 0
        t = tolower(substr($0, p + 1))
        if (!(n in f)) next
        for (i = 1; i <= ns; i++) {
          if (match(t, "(^|[^a-z0-9_])" pat[i] "([^a-z0-9_]|$)"))
            printf "%s\t%s\t%s\t%s\t%s\t%s\n", f[n], s[n], l[n], o[n], disp[i], app[i]
        }
      }
    ' "$R4_TERMS" "$R4_INDEX" "$R4_HITS")
}

# ─────────────────────────────────────────────────────────────────────────────
# Per-file walk
# ─────────────────────────────────────────────────────────────────────────────

check_file() {
  local file="$1" layer="$2"
  CUR_FILE="$file"
  CUR_LAYER="$layer"
  RAMP_SEV=""

  if [ -z "$PS_TMP" ]; then
    PS_TMP="$(mktemp -t sdd-prose.XXXXXX)" || return 0
  fi
  if [ -z "$PS_FLAT" ]; then
    PS_FLAT="$(mktemp -t sdd-prose-flat.XXXXXX)" || return 0
  fi
  strip_html_comments "$file" > "$PS_TMP" || return 0
  # The parsed copy keeps its wikilinks (the body readers unwrap their own); the
  # locator's copy does not. Same line numbering, two different jobs.
  flatten_copy "$file" "$PS_FLAT" || return 0
  CUR_READ="$PS_FLAT"

  local header kind skipbc exempt6 prose check anchor detail
  while IFS= read -r header; do
    [ -z "$header" ] && continue
    CUR_SECTION="$header"
    kind="$(section_kind "$layer" "$header")"

    skipbc=0
    exempt6=0
    if [ "$layer" = "adr" ]; then
      [ "$header" = "Consequences" ] && skipbc=1
      [ "$header" = "Related ADRs" ] && exempt6=1
    fi

    prose="$(sdd_body_prose "$PS_TMP" "$header")"
    [ -z "$prose" ] && continue

    while IFS=$'\t' read -r check anchor detail; do
      [ -z "$check" ] && continue
      emit_finding "$check" "$anchor" "$detail"
    done < <(printf '%s\n' "$prose" \
      | prose_scan "$kind" "$skipbc" "$exempt6" \
          "$(printf '%s\t%s\t%s' "$file" "$header" "$layer")")
  done < <(h2_list "$PS_TMP")
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch — one pass per layer, each over its own slice of the scope
# ─────────────────────────────────────────────────────────────────────────────

build_glossary

DOMAIN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_SPEC_ROOT")"
FEATURE_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_KB_ROOT/03_features")"
ADR_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_KB_ROOT/01_adr")"
SCREEN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_KB_ROOT/05_screens")"

if [ -n "$DOMAIN_SCOPE" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    check_file "$f" "action"
  done < <(sdd_find_actions "$DOMAIN_SCOPE")

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    check_file "$f" "entity"
  done < <(sdd_find_entities "$DOMAIN_SCOPE")
fi

if [ -n "$FEATURE_SCOPE" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    check_file "$f" "feature"
  done < <(sdd_find_features "$FEATURE_SCOPE")
fi

if [ -n "$ADR_SCOPE" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    check_file "$f" "adr"
  done < <(sdd_find_adrs "$ADR_SCOPE")
fi

if [ -n "$SCREEN_SCOPE" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    check_file "$f" "screen"
  done < <(sdd_find_screens "$SCREEN_SCOPE")
fi

run_r4

sdd_exit_with_counters
