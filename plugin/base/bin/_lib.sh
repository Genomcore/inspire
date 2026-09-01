#!/usr/bin/env bash
# .inspire/bin/_lib.sh — shared helpers for the SDD validation library
#
# Source this file from other scripts: `source "$(dirname "$0")/_lib.sh"`.
# Do NOT execute directly.

set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

# The domain root — the scope of the nine domain-shaped rules. Its meaning is
# exactly what it has always been: the root of the `04_domain` tree.
SDD_SPEC_ROOT="${SDD_SPEC_ROOT:-inspire_kb/04_domain}"

# The features layer sits beside the spec layer in the same knowledge base, so it is
# derived rather than configured twice — a fixture that redirects SDD_SPEC_ROOT gets
# the matching features root for free. Override explicitly when they are not siblings.
SDD_FEATURES_ROOT="${SDD_FEATURES_ROOT:-$(dirname "$SDD_SPEC_ROOT")/03_features}"

# Same derivation, same reason: the decision layer is a sibling of the spec layer.
SDD_ADR_ROOT="${SDD_ADR_ROOT:-$(dirname "$SDD_SPEC_ROOT")/01_adr}"

# ...and the foundation layer, where the stack declares which profiles are resolved.
SDD_BOOTSTRAP_ROOT="${SDD_BOOTSTRAP_ROOT:-$(dirname "$SDD_SPEC_ROOT")/00_bootstrap}"

# Where the product's code lives. Resolution order: the env var, then the project's own
# declaration (`source_root:` in stack.md's frontmatter — a brownfield install sets it
# to "." there, and nothing else would ever tell these rules about it), then the
# greenfield default. Without the stack.md step, every source-reading gate on a
# brownfield project would look for a `source/` that does not exist, see zero test
# files, and quietly pass — enforced-looking and inert.
_sdd_stack_source_root() {
  local stack="$(dirname "$SDD_SPEC_ROOT")/00_bootstrap/stack.md"
  [ -f "$stack" ] || return 0
  awk '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    /^source_root:/ {
      sub(/^source_root:[[:space:]]*/, "")
      sub(/[[:space:]]*#.*$/, "")
      gsub(/^[[:space:]"]+|[[:space:]"]+$/, "")
      print
      exit
    }
  ' "$stack"
}
if [ -z "${SDD_SOURCE_ROOT:-}" ]; then
  SDD_SOURCE_ROOT="$(_sdd_stack_source_root)"
fi
SDD_SOURCE_ROOT="${SDD_SOURCE_ROOT:-source}"

# Where the stack profiles live. Part of the runtime rather than the KB, so NOT derived
# from the spec root — a fixture redirecting SDD_SPEC_ROOT must still be able to point
# at its own profile tree.
SDD_PROFILES_ROOT="${SDD_PROFILES_ROOT:-.claude/skills/inspire-code/profiles}"

# Where the product's tests live, and what a test file is called. Shared by every rule
# that checks a KB claim against the tests, so the two cannot drift apart. The scope is
# derived from the source root — tests live in the product code — so a project that moves
# its source root moves this with it; override explicitly when the tests live elsewhere.
#
# The hyphen forms are NOT redundant: `*.spec.*` does not match `create.e2e-spec.ts`,
# the NestJS e2e convention. Omitting them makes a rule silently see zero test files and
# report everything as untested.
SDD_TEST_SCOPE="${SDD_TEST_SCOPE:-$SDD_SOURCE_ROOT}"
SDD_TEST_GLOBS="${SDD_TEST_GLOBS:-*.spec.* *-spec.* *.test.* *-test.* *_test.* test_*.*}"

# The KB root — the scope of the KB-wide rules (the ones that check features,
# ADRs and screens as well as domain files). Kept separate from
# SDD_SPEC_ROOT so that a domain-scoped run stays domain-scoped.
SDD_KB_ROOT="${SDD_KB_ROOT:-inspire_kb}"

# ─────────────────────────────────────────────────────────────────────────────
# Dependency checks
# ─────────────────────────────────────────────────────────────────────────────

sdd_require_tools() {
  local missing=()
  command -v yq >/dev/null 2>&1 || missing+=("yq")
  command -v jq >/dev/null 2>&1 || missing+=("jq")
  if [ ${#missing[@]} -gt 0 ]; then
    echo "error: missing required tools: ${missing[*]}" >&2
    echo "       install via: brew install ${missing[*]}" >&2
    return 127
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Test-file discovery
#
# Prints one test file path per line, or nothing when the scope does not exist.
# node_modules / dist are excluded — a vendored fixture must never satisfy a gate.
# ─────────────────────────────────────────────────────────────────────────────

sdd_find_test_files() {
  local scope="${1:-$SDD_TEST_SCOPE}"
  [ -d "$scope" ] || return 0
  local globs=() g
  read -r -a globs <<< "$SDD_TEST_GLOBS"
  local args=()
  for g in "${globs[@]}"; do
    [ -z "$g" ] && continue
    [ ${#args[@]} -gt 0 ] && args+=(-o)
    args+=(-name "$g")
  done
  [ ${#args[@]} -eq 0 ] && return 0
  find "$scope" -type f \( "${args[@]}" \) 2>/dev/null \
    | grep -v '/node_modules/' | grep -v '/dist/' | sort
}

# sdd_literal_in_tests <needle> <test-file-list-path>
#   True when the needle appears verbatim in any listed test file. Deliberately a
#   literal match: the conventions require a test to assert the exact code / id, so
#   the only way to satisfy this is to put it there.
sdd_literal_in_tests() {
  local needle="$1" list="$2"
  [ -s "$list" ] || return 1
  tr '\n' '\0' < "$list" | xargs -0 grep -qlF -- "$needle" 2>/dev/null
}

# sdd_covers_in_tests <id> <test-file-list-path>
#   True when a test file carries an `@covers` annotation naming this id.
#
#   Two things a plain substring search gets wrong, both of which matter:
#   - **Boundary, on BOTH sides.** `ANL-02/AC-1` is a substring of `ANL-02/AC-10`, so a
#     feature with ten criteria would report criterion 1 as covered by criterion 10's
#     test; and `user/AC-1` is a suffix of `admin-user/AC-1`, so a feature whose stem is
#     a suffix of another's would be covered by the other's test. The id must be
#     preceded AND followed by a non-id character (or end of line) — a space always
#     follows `@covers`, so the left boundary always has a character to match.
#   - **Intent.** A bare id loose in a comment, or copied in a fixture, would satisfy a
#     substring match. Requiring `@covers` makes the annotation deliberate and
#     self-describing — the reason it can live in a comment instead of the test name.
sdd_covers_in_tests() {
  local id="$1" list="$2"
  [ -s "$list" ] || return 1
  # `.` is the only regex metacharacter an id may contain — an id is a feature-file
  # stem plus `/AC-n`, and stems stay within `[A-Za-z0-9._-]`; escape it. A stem
  # outside that set would corrupt this ERE, which is a stated assumption, not
  # handled input.
  local pattern="${id//./\\.}"
  tr '\n' '\0' < "$list" \
    | xargs -0 grep -qlE -- "@covers.*[^A-Za-z0-9._-]${pattern}([^A-Za-z0-9._-]|$)" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Frontmatter extraction
#
# Reads YAML frontmatter from a .md file using yq. Outputs the frontmatter as
# YAML on stdout. Empty output (and exit 0) if the file has no frontmatter.
# ─────────────────────────────────────────────────────────────────────────────

sdd_frontmatter() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "error: file not found: $file" >&2
    return 1
  fi
  yq --front-matter=extract '.' "$file" 2>/dev/null || true
}

# Extract a single frontmatter value by path expression (e.g. ".status" or
# ".surfaces.http"). Prints the value (or empty if missing) to stdout.
sdd_fm_value() {
  local file="$1"
  local path="$2"
  yq --front-matter=extract "$path // \"\"" "$file" 2>/dev/null || true
}

# Strip [[ and ]] wikilink wrappers and unwrap pipe-syntax to the canonical id.
# Prints the unwrapped id (colon::form) to stdout. No-op on already-bare strings.
#
# Pipe-syntax wikilinks (V3 convention) carry the dotted on-disk name on the
# left of `|` and the colon-form canonical id on the right:
#   "[[auth.password.hash|auth::password::hash]]" → "auth::password::hash"
# Bare wikilinks (no pipe) are returned as-is after stripping the brackets:
#   "[[auth::user::create]]" → "auth::user::create"
sdd_unwrap_wikilink() {
  local s="$1"
  s="${s#\[\[}"
  s="${s%\]\]}"
  # If there's a `|`, the right-hand side is the canonical id.
  if [[ "$s" == *"|"* ]]; then
    s="${s#*|}"
  fi
  printf '%s\n' "$s"
}

# Extract a frontmatter list value by path expression (e.g. ".depends_on").
# Prints one item per line on stdout. Empty output if the list is missing or
# the value isn't a list. The trailing "?" suppresses errors on missing keys.
sdd_fm_list() {
  local file="$1"
  local path="$2"
  yq --front-matter=extract "${path}[]?" "$file" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# ID resolution
#
# Build an index mapping artifact id → file path by reading the .id
# frontmatter of every SDD source file. The index is cached in a temp file
# for the lifetime of the calling script.
# ─────────────────────────────────────────────────────────────────────────────

SDD_ID_INDEX_FILE=""

sdd_build_id_index() {
  local scope="${1:-$SDD_SPEC_ROOT}"
  SDD_ID_INDEX_FILE="$(mktemp -t sdd-id-index.XXXXXX)"
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local id
    id="$(sdd_fm_value "$file" '.id')"
    if [ -n "$id" ]; then
      printf '%s\t%s\n' "$id" "$file" >> "$SDD_ID_INDEX_FILE"
    fi
  done < <(sdd_find_actions "$scope")
}

# Resolve an artifact id to its file path. Prints the path (or empty) to
# stdout. Requires sdd_build_id_index to have been called first.
sdd_resolve_id() {
  local id="$1"
  if [ -z "$SDD_ID_INDEX_FILE" ] || [ ! -f "$SDD_ID_INDEX_FILE" ]; then
    return 1
  fi
  awk -F'\t' -v id="$id" '$1 == id { print $2; exit }' "$SDD_ID_INDEX_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Scope intersection
#
# The scope contract, in one place: a rule receives one `$1` and checks exactly
# `$1 ∩ its own layers`. Every layer — the domain tree and the three KB layers
# below — resolves its slice of the scope through this one helper, because two
# implementations of "does this scope reach that layer" would eventually answer
# differently and one of them would be a gate.
# ─────────────────────────────────────────────────────────────────────────────

# sdd_scope_norm <path>
#   Lexical normalization: repeated leading `./` removed, runs of `/` squeezed,
#   trailing `/` dropped. `./inspire_kb//04_domain/` and `inspire_kb/04_domain`
#   name the same directory and must compare equal, or a scope spelled the
#   second way silently checks nothing.
sdd_scope_norm() {
  local p="$1"
  # The separators come from variables: written inline, the replacement half of
  # `${p//…/…}` keeps the backslash of an escaped `/` and the "normalization"
  # would corrupt the path it was meant to clean.
  local dbl='//' one='/'
  while [ "$p" != "${p//$dbl/$one}" ]; do p="${p//$dbl/$one}"; done
  while [ "${p#./}" != "$p" ]; do p="${p#./}"; done
  while [ "$p" != "/" ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
  printf '%s\n' "$p"
}

# sdd_scope_intersect <scope> <layer_root>
#   Prints the directory a rule should scan for that layer, or nothing at all
#   when the scope and the layer are disjoint. The cases:
#     - empty scope         → the whole layer
#     - scope inside layer  → the scope
#     - layer inside scope  → the whole layer
#     - otherwise           → nothing (skip the layer)
#   Comparison is lexical first, then physical: when both sides exist on disk,
#   an absolute and a relative spelling of the same directory must intersect,
#   and only `pwd -P` can tell. A scope that does not exist keeps the
#   silent-skip semantics — there is nothing there to check either way.
sdd_scope_intersect() {
  local scope="$1"
  local root
  root="$(sdd_scope_norm "$2")"

  if [ -z "$scope" ]; then
    printf '%s\n' "$root"
    return 0
  fi
  scope="$(sdd_scope_norm "$scope")"

  case "$scope" in
    "$root" | "$root"/*) printf '%s\n' "$scope"; return 0 ;;
  esac
  case "$root" in
    "$scope"/*) printf '%s\n' "$root"; return 0 ;;
  esac

  if [ -d "$scope" ] && [ -d "$root" ]; then
    local pscope proot
    pscope="$(cd "$scope" 2>/dev/null && pwd -P)" || return 0
    proot="$(cd "$root" 2>/dev/null && pwd -P)" || return 0
    case "$pscope" in
      "$proot" | "$proot"/*) printf '%s\n' "$scope"; return 0 ;;
    esac
    case "$proot" in
      "$pscope"/*) printf '%s\n' "$root"; return 0 ;;
    esac
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Artifact discovery
#
# Layout: inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md
#         (full-id leaf filename — 3 dotted segments).
# Per-entity documents sit alongside actions at the same path with one
# fewer segment: inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md (2
# dotted segments). Action discovery uses segment count to distinguish them.
#
# Both finders intersect their scope with $SDD_SPEC_ROOT first. The dotted-leaf
# filename shape is a discriminator WITHIN the domain tree, never a claim about
# the rest of the KB: a screen at `05_screens/auth/user.profile.md` carries the
# same shape and is not a domain object. Without the intersection, a KB-wide
# scope would hand that file to every domain rule and its lifecycle-valid error
# would block the PR — a gate firing on an artifact whose format it does not
# own.
# ─────────────────────────────────────────────────────────────────────────────

# All action descriptor files under inspire_kb/04_domain/. Actions have 3-segment dotted
# leaf filenames ({module}.{entity}.{action}.md); entity documents
# ({module}.{entity}.md) have 2 segments and are excluded.
sdd_find_actions() {
  local scope
  scope="$(sdd_scope_intersect "${1:-$SDD_SPEC_ROOT}" "$SDD_SPEC_ROOT")"
  [ -n "$scope" ] || return 0
  [ -d "$scope" ] || return 0
  find "$scope" -type f -name "*.md" 2>/dev/null \
    | grep -E '/[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.md$' \
    | sort
}

# All entity document files under inspire_kb/04_domain/. Entity documents have
# 2-segment dotted leaf filenames ({module}.{entity}.md); action
# descriptors ({module}.{entity}.{action}.md) have 3 segments and are
# excluded.
sdd_find_entities() {
  local scope
  scope="$(sdd_scope_intersect "${1:-$SDD_SPEC_ROOT}" "$SDD_SPEC_ROOT")"
  [ -n "$scope" ] || return 0
  [ -d "$scope" ] || return 0
  find "$scope" -type f -name "*.md" 2>/dev/null \
    | grep -E '/[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.md$' \
    | grep -vE '/[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.md$' \
    | sort
}

# Resolve an entity id (canonical colon form, e.g. "auth::user") to its
# entity document file path under $SDD_SPEC_ROOT, by mapping
# {module}::{entity} → inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md.
# Prints the path if the file exists; empty string + non-zero exit otherwise.
sdd_resolve_entity_id() {
  local rid="$1"
  # Accept both colon form ("auth::user") and dotted form ("auth.user").
  local module entity
  if [[ "$rid" == *"::"* ]]; then
    module="${rid%%::*}"
    entity="${rid##*::}"
  else
    module="${rid%%.*}"
    entity="${rid##*.}"
  fi
  local path="${SDD_SPEC_ROOT}/${module}/${entity}/${module}.${entity}.md"
  if [ -f "$path" ]; then
    printf '%s\n' "$path"
    return 0
  fi
  return 1
}

# Read an entity document's `lifecycle:` frontmatter field, given its
# canonical id (colon or dotted form). Prints the lifecycle value (e.g.
# "draft", "accepted", "stable", "superseded") to stdout, or empty string
# if the entity file does not exist or has no lifecycle field.
sdd_entity_lifecycle() {
  local rid="$1"
  local file
  file="$(sdd_resolve_entity_id "$rid")" || return 0
  sdd_fm_value "$file" '.lifecycle'
}

# Read an entity document's `population:` frontmatter field, given its
# canonical id (colon or dotted form). Prints the population value
# ("external" or "internal"), defaulting to "internal" when the field is
# absent or the entity file does not exist.
sdd_entity_population() {
  local rid="$1"
  local file
  file="$(sdd_resolve_entity_id "$rid")" || { printf 'internal\n'; return 0; }
  local val
  val="$(sdd_fm_value "$file" '.population')"
  if [ -z "$val" ] || [ "$val" = "null" ]; then
    printf 'internal\n'
  else
    printf '%s\n' "$val"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# KB layer discovery
#
# Every helper below takes a scope and returns the files that lie in both the
# scope and its own layer — the scope contract from bin/README.md §Scope: a
# rule receives one `$1` and checks only `$1 ∩ its layers`. Matching is on the
# layer directory name anywhere in the path, so all three of
# `inspire_kb`, `inspire_kb/03_features` and `inspire_kb/03_features/auth`
# behave as expected, and a domain-scoped run (`inspire_kb/04_domain`) yields
# nothing at all from these helpers.
# ─────────────────────────────────────────────────────────────────────────────

# Use-case files under 03_features/: 03_features/{module}/{use-case}.md.
# Layer READMEs and any `_index.md` are excluded — they are navigation, not
# use cases.
sdd_find_features() {
  local scope="${1:-$SDD_KB_ROOT}"
  [ -d "$scope" ] || return 0
  find "$scope" -type f -name "*.md" 2>/dev/null \
    | awk -F'(^|/)03_features/' '
        NF > 1 {
          n = split($NF, seg, "/")
          if (n != 2) next
          if (seg[n] == "_index.md" || seg[n] == "README.md") next
          print
        }
      ' \
    | sort
}

# ADR files under 01_adr/: one `adr-{slug}.md` per decision. The `adr-` prefix
# is the discriminator, so READMEs and index files never match.
sdd_find_adrs() {
  local scope="${1:-$SDD_KB_ROOT}"
  [ -d "$scope" ] || return 0
  find "$scope" -type f -name "adr-*.md" 2>/dev/null \
    | grep -E '(^|/)01_adr/' \
    | sort
}

# Screen files under 05_screens/. Discovery is POSITIVE — the two accepted
# shapes are 05_screens/{module}/{screen}.md (flat / suite-of-one) and
# 05_screens/{surface}/{module}/{screen}.md (surface-first). `patterns/` and
# `components/` are excluded by top-level path prefix (they never move: they
# sit beside the surface trees in both shapes), and `_index.md` / `README.md`
# basenames are excluded everywhere. Top-level files (`design-system.md`) fall
# outside both shapes and are therefore not screens.
sdd_find_screens() {
  local scope="${1:-$SDD_KB_ROOT}"
  [ -d "$scope" ] || return 0
  find "$scope" -type f -name "*.md" 2>/dev/null \
    | awk -F'(^|/)05_screens/' '
        NF > 1 {
          n = split($NF, seg, "/")
          if (n < 2 || n > 3) next
          if (seg[1] == "patterns" || seg[1] == "components") next
          if (seg[n] == "_index.md" || seg[n] == "README.md") next
          print
        }
      ' \
    | sort
}

# ─────────────────────────────────────────────────────────────────────────────
# Finding emission
#
# Findings are JSON lines on stderr. Stdout is reserved for human summaries.
# ─────────────────────────────────────────────────────────────────────────────

# sdd_finding <severity> <rule> <target> <message>
#   severity: "error" | "warning" | "info" (a note about the run, not an artifact)
#   rule:     short rule id (e.g. "entity-coherence")
#   target:   path or id the finding applies to
#   message:  human-readable description
sdd_finding() {
  local severity="$1"
  local rule="$2"
  local target="$3"
  local message="$4"
  jq -nc \
    --arg severity "$severity" \
    --arg rule     "$rule" \
    --arg target   "$target" \
    --arg message  "$message" \
    '{severity: $severity, rule: $rule, target: $target, message: $message}' >&2
}

# Counters for the calling script to track errors / warnings.
# Usage:
#   sdd_init_counters
#   ... emit findings ...
#   sdd_exit_with_counters     # exits 1 if errors > 0, else 0
sdd_init_counters() {
  SDD_ERRORS=0
  SDD_WARNINGS=0
}

sdd_count_error() {
  SDD_ERRORS=$((${SDD_ERRORS:-0} + 1))
}

sdd_count_warning() {
  SDD_WARNINGS=$((${SDD_WARNINGS:-0} + 1))
}

sdd_exit_with_counters() {
  local errors="${SDD_ERRORS:-0}"
  local warnings="${SDD_WARNINGS:-0}"
  if [ "$errors" -gt 0 ]; then
    return 1
  fi
  return 0
}

# sdd_progressive_severity <lifecycle>
#   Maps an object's lifecycle to the severity tier for lifecycle-
#   progressive rules. Used by field-coverage, rationale-wikilink,
#   wikilinks-resolve, sections-present (its order check) and prose-style
#   (its four non-heuristic checks).
#     draft (and empty / unknown) → warning
#     accepted, stable            → error
#     superseded                  → warning
#   `superseded` is terminal: the object is history, kept for the pointer to
#   what replaced it, and no longer worth blocking a commit over. It therefore
#   de-escalates rather than staying at the tier it retired from.
sdd_progressive_severity() {
  case "$1" in
    accepted|stable) printf 'error\n' ;;
    *) printf 'warning\n' ;;
  esac
}

# sdd_count_by_severity <severity>
#   Bumps the appropriate counter for a severity tier. Convenience wrapper
#   for lifecycle-progressive rules that compute severity dynamically.
sdd_count_by_severity() {
  case "$1" in
    error)   sdd_count_error ;;
    warning) sdd_count_warning ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Markdown body section extraction
#
# Extracts the content under a markdown H2 header (## SectionName) up to the
# next H2 or EOF. Frontmatter and prose above the first H2 are ignored.
#
# Two structures are read the same way by every helper below, because getting
# either wrong silently erases the rest of a file from a check:
#
#   Frontmatter is a real block, not a toggle. It exists only when line 1 is
#   `---`, it closes at the next `---`, and it never reopens. A `---` used as a
#   thematic break in the body is body content, and a file written without
#   frontmatter (screens, by design) is read in full. Known limitation: a file
#   whose line 1 opens frontmatter that is never closed reads as frontmatter to
#   EOF, so every helper sees an empty body. That is the one shape where a
#   malformed file goes quiet rather than loud, and it is left as is — the file
#   is broken YAML that `sdd_frontmatter` cannot parse either.
#
#   A header inside a fenced code block is not a header. Fences are tracked the
#   way CommonMark defines them, not as a boolean toggle: the opening marker's
#   character (` or ~) and run length are recorded, and only a line that is
#   nothing but a run of the SAME character, at least as long, closes it. A
#   boolean toggle gets three common shapes wrong — a four-backtick fence
#   quoting a three-backtick one, a fence quoting the other marker character,
#   and any fence containing an odd number of inner fence-looking lines (which
#   leaves the flag stuck on and erases the rest of the file). All three appear
#   in documentation about markdown, which is exactly what a KB contains.
# ─────────────────────────────────────────────────────────────────────────────

# The two readers above, as awk source. Every helper in this section composes
# its program from these fragments so that there is exactly one implementation
# of each rule: a prologue (frontmatter + fences), the helper's own rules, and
# the fence functions. Two fence prologues exist because a helper either drops
# fenced lines or passes them through to a caller that wants them verbatim.
SDD_AWK_FM_READER='
  NR == 1 && $0 == "---" { fm = 1; next }
  fm { if ($0 == "---") fm = 0; next }
'

SDD_AWK_FENCE_SKIP='
  sdd_fence($0) { next }
  sdd_in_fence() { next }
'

SDD_AWK_FENCE_KEEP='
  sdd_fence($0) { if (capture) print; next }
  sdd_in_fence() { if (capture) print; next }
'

# sdd_fence(line) — returns 1 when the line is a fence delimiter (opening or
# closing) and updates the tracked state; 0 otherwise. sdd_in_fence() reports
# whether the reader is currently inside a fenced block. Interval expressions
# and capture groups are avoided: BSD awk is a supported host.
SDD_AWK_FENCE_FUNCS='
  function sdd_fence(line,   indent, s, ch, n, rest) {
    indent = 0
    while (substr(line, indent + 1, 1) == " ") indent++
    if (indent > 3) return 0          # 4+ spaces is an indented code block
    s = substr(line, indent + 1)
    ch = substr(s, 1, 1)
    if (ch != "`" && ch != "~") return 0
    n = 0
    while (substr(s, n + 1, 1) == ch) n++
    if (n < 3) return 0
    rest = substr(s, n + 1)
    if (sdd_fence_ch == "") {
      # Opening fence. A backtick fence may not carry a backtick in its info
      # string, so such a line is not a fence at all.
      if (ch == "`" && index(rest, "`") > 0) return 0
      sdd_fence_ch = ch
      sdd_fence_len = n
      return 1
    }
    # Closing fence: same character, run at least as long as the opener, and
    # nothing but that run on the line.
    if (ch == sdd_fence_ch && n >= sdd_fence_len && rest ~ /^[[:space:]]*$/) {
      sdd_fence_ch = ""
      sdd_fence_len = 0
      return 1
    }
    return 0
  }
  function sdd_in_fence() { return sdd_fence_ch != "" }
'

# sdd_body_section <file> <header_name>
#   Prints the body section content to stdout, verbatim (fenced blocks and
#   tables included). Empty if not found.
sdd_body_section() {
  local file="$1"
  local header="$2"
  awk -v header="## $header" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_KEEP}"'
      $0 == header { capture = 1; next }
      /^## / && capture { exit }
      capture { print }
    '"${SDD_AWK_FENCE_FUNCS}" "$file"
}

# sdd_body_prose <file> <header_name>
#   sdd_body_section reduced to prose: fenced code blocks, table rows and bare
#   thematic breaks are dropped, and wikilinks are unwrapped to their display
#   text (the same right-of-the-pipe reading sdd_unwrap_wikilink applies, so
#   `[[auth.user|auth::user]]` reads as `auth::user` and `[[adr-x]]` as
#   `adr-x`). What is left is the text a human reads, which is what the
#   prose-style checks measure.
sdd_body_prose() {
  local file="$1"
  local header="$2"
  # No frontmatter reader here: the input is a section body, so a leading `---`
  # is a thematic break, never a frontmatter opener — and a thematic break is
  # structure, not prose, so it is dropped rather than counted as content.
  # (Three-or-more `-` written without an interval expression: BSD awk is a
  # supported host.) Only the `---` spelling is dropped: CommonMark's other two
  # thematic breaks, `***` and `___`, pass through as prose lines.
  sdd_body_section "$file" "$header" \
    | awk "${SDD_AWK_FENCE_SKIP}"'
        /^[[:space:]]*\|/ { next }
        /^[[:space:]]*---+[[:space:]]*$/ { next }
        { print }
      '"${SDD_AWK_FENCE_FUNCS}" \
    | sed -E 's/\[\[([^]|]*)\|([^]]*)\]\]/\2/g; s/\[\[([^]]*)\]\]/\1/g'
}

# sdd_has_section <file> <header_name> [level]
#   Exit 0 if the file declares that header outside frontmatter and outside
#   every fenced block. `level` is 2 (default, `## Header`) or 3
#   (`### Header`); any other value is a usage error.
sdd_has_section() {
  local file="$1"
  local header="$2"
  local level="${3:-2}"
  local prefix
  case "$level" in
    2) prefix="## " ;;
    3) prefix="### " ;;
    *) echo "error: sdd_has_section: unsupported header level: $level" >&2; return 2 ;;
  esac
  awk -v hdr="${prefix}${header}" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      $0 == hdr { found = 1; exit }
      END { exit !found }
    '"${SDD_AWK_FENCE_FUNCS}" "$file"
}

# sdd_has_subsection <file> <parent_h2> <header_h3>
#   Exit 0 if the file declares `### header_h3` *within* the `## parent_h2`
#   section. This is the "sits under" form: an H3 that has drifted to another
#   H2 does not satisfy it.
sdd_has_subsection() {
  local file="$1"
  local parent="$2"
  local header="$3"
  awk -v ph="## $parent" -v sh="### $header" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      $0 == ph { inparent = 1; next }
      /^## / { inparent = 0; next }
      inparent && $0 == sh { found = 1; exit }
      END { exit !found }
    '"${SDD_AWK_FENCE_FUNCS}" "$file"
}

# sdd_body_subsection <file> <parent_h2> <header_h3>
#   Prints the content under `### header_h3` inside `## parent_h2`, up to the
#   next H3, the next H2, or EOF. Empty if the subsection is not there. The
#   FIRST match wins: the parent rule is gated on `!capture` so that a repeated
#   `## parent` later in the file cannot re-arm the scan and concatenate two
#   subsection bodies into one answer.
sdd_body_subsection() {
  local file="$1"
  local parent="$2"
  local header="$3"
  awk -v ph="## $parent" -v sh="### $header" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_KEEP}"'
      !capture && $0 == ph { inparent = 1; next }
      /^## / { if (capture) exit; inparent = 0; next }
      inparent && $0 == sh { capture = 1; next }
      /^### / && capture { exit }
      capture { print }
    '"${SDD_AWK_FENCE_FUNCS}" "$file"
}

# sdd_entities_touched <file>
#   Parses the `## Entities` body section's per-entity h3 sub-sections.
#   Each sub-section has a metadata line and a per-field table with 5 cols:
#     Field | Touch | Type | Mapping | Notes
#   The H3 header uses pipe-syntax wikilinks:
#     ### [[module.entity|module::entity]]
#   The Field column may wrap names in backticks (`field_name`); the parser
#   strips them so callers see bare field names.
#   Outputs TSV:
#     entity_id<TAB>field<TAB>touch<TAB>type<TAB>mapping<TAB>notes<TAB>as_input<TAB>effect
#   one row per declared field. `as_input` and `effect` are repeated on every
#   row of the same entity (denormalized for downstream awk-friendliness).
sdd_entities_touched() {
  local file="$1"
  sdd_body_section "$file" "Entities" \
    | awk '
      # Entity header: ### [[module.entity|module::entity]] (V3)
      # or:            ### [[module::entity]]                 (bare)
      /^###[[:space:]]+\[\[/ {
        match($0, /\[\[[^\]]+\]\]/)
        rid = substr($0, RSTART+2, RLENGTH-4)
        # If pipe-syntax, take the canonical id (right of the `|`).
        pipe = index(rid, "|")
        if (pipe > 0) rid = substr(rid, pipe + 1)
        as_input = ""; effect = ""
        next
      }
      # Metadata line: **As input:** X · **Effect:** Y
      # BSD awk has 2-arg match() only (no capture-group array form),
      # so we extract via sub() on copies of the line.
      /^\*\*As input:\*\*/ {
        as_input = $0
        sub(/^\*\*As input:\*\*[[:space:]]*/, "", as_input)
        sub(/[[:space:]]*·.*$/, "", as_input)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", as_input)
        if (index($0, "**Effect:**") > 0) {
          effect = $0
          sub(/^.*\*\*Effect:\*\*[[:space:]]*/, "", effect)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", effect)
        } else {
          effect = ""
        }
        next
      }
      # Standalone **Effect:** Y (no preceding As input).
      /^\*\*Effect:\*\*/ {
        effect = $0
        sub(/^\*\*Effect:\*\*[[:space:]]*/, "", effect)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", effect)
        next
      }
      # Field-table data row. Allows optional backticks around the field name:
      #   | `id` | written | uuid | ... |
      # or the bare form for back-compat:
      #   | id | written | uuid | ... |
      /^\|[[:space:]]*`?[A-Za-z_][A-Za-z0-9_]*`?[[:space:]]*\|/ {
        if (rid == "") next
        gsub(/^\|[[:space:]]*|[[:space:]]*\|$/, "")
        n = split($0, parts, /[[:space:]]*\|[[:space:]]*/)
        if (n < 3) next
        field   = parts[1]
        touch   = parts[2]
        type    = parts[3]
        mapping = (n >= 4) ? parts[4] : ""
        notes   = (n >= 5) ? parts[5] : ""
        # Strip surrounding backticks from cells (preserve mid-cell ticks).
        gsub(/^`|`$/, "", field)
        gsub(/^`|`$/, "", type)
        # Skip header / separator rows
        if (field == "Field" || field ~ /^-+$/) next
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", rid, field, touch, type, mapping, notes, as_input, effect
      }
    '
}

# sdd_entities_touched_meta <file>
#   Convenience: outputs only the per-entity metadata, deduplicated.
#   TSV: entity_id<TAB>as_input<TAB>effect (one row per touched entity).
sdd_entities_touched_meta() {
  sdd_entities_touched "$1" \
    | awk -F'\t' '{ print $1 "\t" $7 "\t" $8 }' \
    | sort -u
}

# sdd_expand_whole_reads
#   Pipeline filter. Reads touch rows on stdin in the 8-column TSV format
#   emitted by sdd_entities_touched:
#     entity_id<TAB>field<TAB>touch<TAB>type<TAB>mapping<TAB>notes<TAB>as_input<TAB>effect
#   For each row whose effect is "read-whole", resolves the entity doc and
#   enumerates its ## Fields, emitting one synthetic `read` row per declared
#   field. The synthetic rows carry an empty Type/Mapping and a sentinel
#   Notes value of "<synthetic:read-whole>" so consumers can filter if
#   needed. Originals pass through unchanged.
sdd_expand_whole_reads() {
  local input
  input="$(mktemp -t sdd-expand.XXXXXX)"
  cat > "$input"
  # 1. Emit originals verbatim.
  cat "$input"
  # 2. For each unique (entity_id) appearing with effect=read-whole, emit
  #    synthetic per-field reads. Repeated invocations on the same entity
  #    inside one action stream collapse to one set of synthetic rows.
  local rid entity_file field as_input
  awk -F'\t' '$8 == "read-whole" { print $1 "\t" $7 }' "$input" \
    | sort -u \
    | while IFS=$'\t' read -r rid as_input; do
        [ -z "$rid" ] && continue
        entity_file="$(sdd_resolve_entity_id "$rid")" || continue
        while IFS= read -r field; do
          [ -z "$field" ] && continue
          printf '%s\t%s\tread\t\t\t<synthetic:read-whole>\t%s\tread-whole\n' \
            "$rid" "$field" "$as_input"
        done < <(sdd_entity_fields "$entity_file")
      done
  rm -f "$input"
}

# sdd_entity_fields <file>
#   Parses the `## Fields` body section of an entity document and emits one
#   field name per line. The table layout is:
#     | Field | Type | Notes |
#   Field names may be wrapped in backticks (`field_name`); the parser strips
#   them. Header and separator rows are skipped. Empty output if the section
#   is missing or contains no rows.
sdd_entity_fields() {
  local file="$1"
  sdd_body_section "$file" "Fields" \
    | awk '
      /^\|[[:space:]]*`?[A-Za-z_][A-Za-z0-9_]*`?[[:space:]]*\|/ {
        gsub(/^\|[[:space:]]*|[[:space:]]*\|$/, "")
        n = split($0, parts, /[[:space:]]*\|[[:space:]]*/)
        if (n < 1) next
        field = parts[1]
        gsub(/^`|`$/, "", field)
        if (field == "Field" || field ~ /^-+$/) next
        print field
      }
    '
}
