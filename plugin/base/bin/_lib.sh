#!/usr/bin/env bash
# .inspire/bin/_lib.sh — shared helpers for the SDD validation library
#
# Source this file from other scripts: `source "$(dirname "$0")/_lib.sh"`.
# Do NOT execute directly.

set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

# The KB root, and the specification root inside it (adr-kb-structure D2). Every
# specification artifact — module, feature, entity, action, ADR, bundle, face,
# screen, process, design-system entry — lives somewhere under SDD_SPEC_ROOT, and a
# finder selects it by its typed extension, never by the directory it sits in (D4).
SDD_KB_ROOT="${SDD_KB_ROOT:-inspire_kb}"
SDD_SPEC_ROOT="${SDD_SPEC_ROOT:-$SDD_KB_ROOT/01_spec}"

# The parent of the spec root, computed once: the foundation layer is its sibling.
# `_SDD_PARENT` assigns rather than prints, because a `$(...)` around a helper is a
# fork, and derive spawns rules per unit while plan spawns a derive per unit.
#
# It answers exactly what `dirname` answered: a trailing slash is stripped
# first, a path with no slash left has parent `.`, and a path whose only slash
# is the leading one has parent `/`.
_SDD_PARENT="$SDD_SPEC_ROOT"
while :; do
  case "$_SDD_PARENT" in
    /) break ;;
    */) _SDD_PARENT="${_SDD_PARENT%/}" ;;
    *) break ;;
  esac
done
case "$_SDD_PARENT" in
  */*) _SDD_PARENT="${_SDD_PARENT%/*}"; [ -n "$_SDD_PARENT" ] || _SDD_PARENT="/" ;;
  *)   _SDD_PARENT="." ;;
esac

# ...and the foundation layer, where the stack declares which profiles are resolved.
SDD_BOOTSTRAP_ROOT="${SDD_BOOTSTRAP_ROOT:-$_SDD_PARENT/00_bootstrap}"

# Where the product's code lives. Resolution order: the env var, then the project's own
# declaration (`source_root:` in stack.md's frontmatter — a brownfield install sets it
# to "." there, and nothing else would ever tell these rules about it), then the
# greenfield default. Without the stack.md step, every source-reading gate on a
# brownfield project would look for a `source/` that does not exist, see zero test
# files, and quietly pass — enforced-looking and inert.
_sdd_stack_source_root() {
  local stack="$_SDD_PARENT/00_bootstrap/stack.md"
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

# Where the skills live. Part of the runtime rather than the KB, so NOT derived from the
# spec root — a fixture redirecting SDD_SPEC_ROOT must still be able to point at its own
# skill tree.
SDD_SKILLS_ROOT="${SDD_SKILLS_ROOT:-.claude/skills}"

# sdd_stack_skills <id> → every $SDD_SKILLS_ROOT/*/SKILL.md whose frontmatter `stack:`
# is <id>, one per line in glob order. The skill's own name never matters, and a stack
# id no skill declares prints nothing: that is a legal stack, not a missing file. One
# awk over every skill rather than a yq per skill, because the planner calls this once
# per resolved id.
sdd_stack_skills() {
  local files=( "$SDD_SKILLS_ROOT"/*/SKILL.md )
  [ -f "${files[0]}" ] || return 0
  awk -v id="$1" '
    FNR == 1 { fm = ($0 == "---"); next }
    fm && $0 == "---" { fm = 0; next }
    fm && /^stack:/ {
      v = $0
      sub(/^stack:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v)
      gsub(/^["\047]|["\047]$/, "", v)
      if (v == id) print FILENAME
    }
  ' "${files[@]}"
}

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

# Strip [[ and ]] wrappers and read the LINK TARGET — the left of `|`.
# Prints the target to stdout. No-op on already-bare strings.
#
# The counterpart of sdd_unwrap_wikilink above, and the contrast is the whole
# point: that one answers "what id does this link DECLARE?", which the V3
# convention writes on the right; this one answers "what file does this link
# POINT AT?", which is always the left — `[[adr-x|the audit decision]]` points
# at `adr-x`. Reading the right side for a target reports every aliased prose
# link as dangling, which is the defect this pair exists to keep apart.
#
# A pipe escaped for a markdown table cell (`[[a.b\|a::b]]`) leaves its
# backslash at the end of the target, so it is stripped.
sdd_wikilink_target() {
  local s="$1"
  s="${s#\[\[}"
  s="${s%\]\]}"
  if [[ "$s" == *"|"* ]]; then
    s="${s%%|*}"
    s="${s%\\}"
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
#   trailing `/` dropped. `./inspire_kb//01_spec/` and `inspire_kb/01_spec`
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
#   Prints the path a rule should scan for that layer, or nothing at all
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

  if [ -e "$scope" ] && [ -d "$root" ]; then
    local pscope proot
    if [ -d "$scope" ]; then
      pscope="$(cd "$scope" 2>/dev/null && pwd -P)" || return 0
    else
      pscope="$(cd "$(dirname "$scope")" 2>/dev/null && pwd -P)/${scope##*/}" || return 0
    fi
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
# Artifact discovery (adr-kb-structure D3, D4)
#
# Every artifact type has a typed extension, and every finder is one recursive
# search under $SDD_SPEC_ROOT for that extension. The directory a file sits in is
# for people; no finder reads it. Scoping a finder to a module or a face is the
# scope argument — a path filter — never a different shape.
#
# A template carries its own extension (`entity.template.md`), so no finder can
# mistake one for a unit and none has to skip `_`-prefixed names.
# ─────────────────────────────────────────────────────────────────────────────

# sdd_find_typed <scope> <type> — every `*.<type>.md` in scope ∩ $SDD_SPEC_ROOT.
#   A scope disjoint from the spec root yields nothing: that is the scope contract
#   (a rule checks `$1 ∩ its own layers`), and it is what keeps a run scoped to
#   00_bootstrap or 06_spikes silent.
sdd_find_typed() {
  local scope
  scope="$(sdd_scope_intersect "${1:-$SDD_SPEC_ROOT}" "$SDD_SPEC_ROOT")"
  [ -n "$scope" ] || return 0
  [ -e "$scope" ] || return 0
  find "$scope" -type f -name "*.$2.md" 2>/dev/null | sort
}

sdd_find_actions()    { sdd_find_typed "${1:-}" action; }
sdd_find_entities()   { sdd_find_typed "${1:-}" entity; }
sdd_find_features()   { sdd_find_typed "${1:-}" feature; }
sdd_find_modules()    { sdd_find_typed "${1:-}" module; }
sdd_find_bundles()    { sdd_find_typed "${1:-}" bundle; }
sdd_find_faces()      { sdd_find_typed "${1:-}" face; }
sdd_find_screens()    { sdd_find_typed "${1:-}" screen; }
sdd_find_processes()  { sdd_find_typed "${1:-}" process; }
sdd_find_adr_rationales() { sdd_find_typed "${1:-}" adr.rationale; }
# `*.adr.md` never matches `*.adr.rationale.md`: the rationale ends in `.rationale.md`.
sdd_find_adrs()       { sdd_find_typed "${1:-}" adr; }

# Design-system CATALOG entries: `{name}.pattern.md`, `{name}.layout.md`,
# `{name}.component.md`. The second argument keeps the plural directory name the
# callers have always passed (`patterns`, `layouts`, `components`); it selects the
# extension, not a directory.
sdd_find_catalog() {
  local scope="$1" dir="$2"
  sdd_find_typed "$scope" "${dir%s}"
}

# sdd_resolve_catalog <kind> <name> — the `{name}.{kind}.md` entry for a catalog id
#   (`pattern`, `layout`, `component`; a plural is accepted), by name anywhere under
#   the spec root. A name with a path keeps only its last segment, and a typed
#   extension already on it is dropped: the id never carries one. Prints nothing
#   when no entry has that name.
sdd_resolve_catalog() {
  local kind="${1%s}" name="${2##*/}"
  name="${name%.md}"; name="${name%.$kind}"
  [ -n "$name" ] || return 0
  [ -d "$SDD_SPEC_ROOT" ] || return 0
  find "$SDD_SPEC_ROOT" -type f -name "$name.$kind.md" 2>/dev/null | sort | head -1
}

# sdd_artifact_id <file> — the id an artifact is linked by (D3).
#   The frontmatter `id:` wins where it exists. Otherwise the id is the file name
#   without its typed extension — `list.pattern.md` is `list`, never `list.pattern`
#   — and an ADR adds back its `adr-` prefix: `foo.adr.md` is `adr-foo`, and
#   `foo.adr.rationale.md` is `adr-foo.rationale`.
sdd_artifact_id() {
  local file="$1" id base
  id="$(sdd_fm_value "$file" '.id' 2>/dev/null)"
  if [ -n "$id" ] && [ "$id" != "null" ]; then printf '%s\n' "$id"; return 0; fi
  base="${file##*/}"
  case "$base" in
    *.adr.rationale.md) printf 'adr-%s.rationale\n' "${base%.adr.rationale.md}" ;;
    *.adr.md)           printf 'adr-%s\n' "${base%.adr.md}" ;;
    *.template.md)      printf '%s\n' "${base%.md}" ;;
    *.*.md)             base="${base%.md}"; printf '%s\n' "${base%.*}" ;;
    *.md)               printf '%s\n' "${base%.md}" ;;
    *)                  printf '%s\n' "$base" ;;
  esac
}

# sdd_typed_kind <file> — the artifact type its extension declares, or nothing.
sdd_typed_kind() {
  case "${1##*/}" in
    *.template.md)      ;;
    *.adr.rationale.md) printf 'adr-rationale\n' ;;
    *.adr.md)           printf 'adr\n' ;;
    *.module.md)        printf 'module\n' ;;
    *.feature.md)       printf 'feature\n' ;;
    *.entity.md)        printf 'entity\n' ;;
    *.action.md)        printf 'action\n' ;;
    *.bundle.md)        printf 'bundle\n' ;;
    *.face.md)          printf 'face\n' ;;
    *.screen.md)        printf 'screen\n' ;;
    *.process.md)       printf 'process\n' ;;
    *.component.md)     printf 'component\n' ;;
    *.layout.md)        printf 'layout\n' ;;
    *.pattern.md)       printf 'pattern\n' ;;
  esac
}

# The entity index — `{id}<TAB>{path}` for every entity, keyed by the dotted form.
# Built on first use and kept for the life of the calling script: rules resolve
# entity ids per action, and one search per lookup would multiply finds by actions.
SDD_ENTITY_INDEX_FILE=""
_sdd_entity_index() {
  [ -n "$SDD_ENTITY_INDEX_FILE" ] && [ -f "$SDD_ENTITY_INDEX_FILE" ] && return 0
  SDD_ENTITY_INDEX_FILE="$(mktemp -t sdd-entity-index.XXXXXX)"
  local f id
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    id="$(sdd_fm_value "$f" '.id' 2>/dev/null)"
    [ -n "$id" ] && [ "$id" != "null" ] || continue
    printf '%s\t%s\n' "${id//::/.}" "$f" >> "$SDD_ENTITY_INDEX_FILE"
  done < <(sdd_find_entities "$SDD_SPEC_ROOT")
}

# Resolve an entity id (colon form "auth::user" or dotted "auth.user") to its
# entity document, by its `id:` — never by building a path (D4). Prints the path,
# or nothing and a non-zero exit when no entity carries that id.
#
# The usual home of `{module}::{entity}` is tried first, and accepted only when the
# file's own `id:` says so — a hint, verified, never the answer by itself. It reads
# the frontmatter in bash, with no process: rules call this inside `$(...)` once per
# touched entity, and a subshell cannot keep the index, so without the hint every call
# would rebuild it. Anything elsewhere falls back to the index.
_sdd_fm_id_is() {  # _sdd_fm_id_is <file> <dotted-id>
  local line n=0 v
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if [ "$n" -eq 1 ]; then [ "$line" = "---" ] || return 1; continue; fi
    [ "$line" = "---" ] && return 1
    case "$line" in
      id:*)
        v="${line#id:}"; v="${v%%#*}"
        v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
        v="${v#[\"\']}"; v="${v%[\"\']}"
        [ "${v//::/.}" = "$2" ]; return ;;
    esac
  done < "$1"
  return 1
}

sdd_resolve_entity_id() {
  local rid="${1//::/.}" path module entity
  module="${rid%%.*}"; entity="${rid#*.}"
  path="$SDD_SPEC_ROOT/_modules/$module/_domain/$entity/$entity.entity.md"
  if [ "$module" != "$rid" ] && [ -f "$path" ] && _sdd_fm_id_is "$path" "$rid"; then
    printf '%s\n' "$path"
    return 0
  fi
  _sdd_entity_index
  path="$(awk -F'\t' -v id="$rid" '$1 == id { print $2; exit }' "$SDD_ENTITY_INDEX_FILE")"
  [ -n "$path" ] || return 1
  printf '%s\n' "$path"
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

# The screen id map the migration wrote (adr-kb-structure D10): old id → new id.
# A link written before the migration keeps its text — a screen's `## Bindings` is
# never rewritten — so a resolver reads an old screen id through this map.
# sdd_screen_id_alias <id> prints the new id, or nothing.
sdd_screen_id_alias() {
  local map="$SDD_SPEC_ROOT/_migration/id-map.json"
  [ -f "$map" ] || return 0
  jq -r --arg id "$1" '.screens[$id] // empty' "$map" 2>/dev/null
}

# sdd_catalog_state <file> — the `**State:**` header line of a catalog entry,
# or empty when it declares none.
sdd_catalog_state() {
  awk '
    index($0, "**State:**") == 1 {
      s = $0
      sub(/^\*\*State:\*\*[ \t]*/, "", s)
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      print s
      exit
    }
  ' "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# KB links (adr-markdown-links)
#
# A link is a relative Markdown link, `[text](path)`, resolved by joining its
# path to the linking file's directory (D2). A wikilink, `[[target|text]]`, is the
# form before 0.16.1 and still resolves by id (D5). A link inside a code span or a
# fenced block is an example and is never read (D4). The id of a resolved file is
# `sdd_artifact_id`.
# ─────────────────────────────────────────────────────────────────────────────

# sdd_link_index — builds the wikilink index once, KB-wide whatever the scope:
#   `{kind}<TAB>{key}<TAB>{path}`, kind A action id · E entity id (dotted) ·
#   S screen id · M old screen id (path holds the new one) · N file name id.
#   Call it in the calling script's own shell, which removes
#   `$SDD_LINK_INDEX_FILE` and `$SDD_ENTITY_INDEX_FILE` on exit.
SDD_LINK_INDEX_FILE=""
sdd_link_index() {
  [ -n "$SDD_LINK_INDEX_FILE" ] && [ -f "$SDD_LINK_INDEX_FILE" ] && return 0
  SDD_LINK_INDEX_FILE="$(mktemp -t sdd-link-index.XXXXXX)"
  local f id map="$SDD_SPEC_ROOT/_migration/id-map.json"
  {
    while IFS= read -r f; do
      id="$(sdd_fm_value "$f" '.id')"
      [ -n "$id" ] && printf 'A\t%s\t%s\n' "$id" "$f"
    done < <(sdd_find_actions "$SDD_SPEC_ROOT")
    _sdd_entity_index
    awk '{ print "E\t" $0 }' "$SDD_ENTITY_INDEX_FILE"
    while IFS= read -r f; do
      id="$(sdd_fm_value "$f" '.id')"
      [ -n "$id" ] && printf 'S\t%s\t%s\n' "$id" "$f"
    done < <(sdd_find_screens "$SDD_SPEC_ROOT")
    [ -f "$map" ] && jq -r '.screens // {} | to_entries[] | "M\t\(.key)\t\(.value)"' "$map" 2>/dev/null
    # A file is named both by its plain name and by the id its typed name gives.
    find "$SDD_KB_ROOT" .claude/skills -type f -name '*.md' ! -path '*/node_modules/*' 2>/dev/null \
      | awk '
          {
            n = split($0, seg, "/"); base = seg[n]; sub(/\.md$/, "", base)
            print "N\t" base "\t" $0
            if (base ~ /\.adr\.rationale$/) { sub(/\.adr\.rationale$/, "", base); print "N\tadr-" base ".rationale\t" $0 }
            else if (base ~ /\.adr$/) { sub(/\.adr$/, "", base); print "N\tadr-" base "\t" $0 }
            else if (base ~ /\.(module|feature|entity|action|bundle|face|screen|process|component|layout|pattern)$/) {
              sub(/\.[a-z]+$/, "", base); print "N\t" base "\t" $0
            }
          }'
  } > "$SDD_LINK_INDEX_FILE"
}

# sdd_links <file> — every link in the file, frontmatter included, one per line:
#   `{line}<TAB>{md|wiki}<TAB>{target as written}<TAB>{text}<TAB>{resolved path}`.
#   The path is empty when the link resolves to no file. Text and target are never
#   empty, so `IFS=$'\t' read` keeps the five fields apart: a link that shows no
#   text reports its target as text. Images and external URLs are not links here.
sdd_links() {
  local file="$1" dir ln form target text path
  sdd_link_index
  case "$file" in */*) dir="${file%/*}" ;; *) dir="." ;; esac
  awk -v idx="$SDD_LINK_INDEX_FILE" -v dir="$dir" "$SDD_AWK_LINKS$SDD_AWK_FENCE_FUNCS" \
    "$SDD_LINK_INDEX_FILE" "$file" \
  | while IFS=$'\t' read -r ln form target text path; do
      [ -n "$path" ] && [ -f "$path" ] || path=""
      printf '%s\t%s\t%s\t%s\t%s\n' "$ln" "$form" "$target" "$text" "$path"
    done
}

# The reader's awk program. The index file is read first; every later line is the
# linking file. A wikilink resolves through the routes it always took (D5), in
# order; a Markdown path is joined and normalized here and tested for existence by
# the caller.
SDD_AWK_LINKS='
  FILENAME == idx {
    if ($0 !~ /\t/) next
    split($0, r, "\t")
    if (!((r[1], r[2]) in ix)) ix[r[1], r[2]] = r[3]
    next
  }
  FNR == 1 && $0 == "---" { fm = 1; next }
  fm { if ($0 == "---") fm = 0; else sdd_scan(sdd_unspan($0), FNR); next }
  sdd_fence($0) { next }
  sdd_in_fence() { next }
  { sdd_scan(sdd_unspan($0), FNR) }

  # A code span is a run of n backticks closed by the next run of exactly n.
  function sdd_unspan(s,   out, i, n, run, rest, pos, k, m, found) {
    out = ""
    while ((i = index(s, "`")) > 0) {
      n = 0; while (substr(s, i + n, 1) == "`") n++
      run = substr(s, i, n); rest = substr(s, i + n); pos = 1; found = 0
      while ((k = index(substr(rest, pos), run)) > 0) {
        k += pos - 1; m = 0
        while (substr(rest, k + m, 1) == "`") m++
        if (m == n) { found = k; break }
        pos = k + m
      }
      if (found) { out = out substr(s, 1, i - 1) " "; s = substr(rest, found + n) }
      else { out = out substr(s, 1, i + n - 1); s = rest }
    }
    return out s
  }

  function sdd_scan(s, ln,   w, ws, wl, ms, ml, tok) {
    while (1) {
      w = match(s, /\[\[[^]]+\]\]/); ws = RSTART; wl = RLENGTH
      ms = match(s, /!?\[[^]]*\]\([^)]*\)/); ml = RLENGTH
      if (!w && !ms) return
      if (w && (!ms || ws <= ms)) {
        sdd_wiki(substr(s, ws + 2, wl - 4), ln); s = substr(s, ws + wl)
      } else {
        tok = substr(s, ms, ml); s = substr(s, ms + ml)
        if (substr(tok, 1, 1) != "!") sdd_md(tok, ln)
      }
    }
  }

  function sdd_emit(ln, form, target, text, path) {
    gsub(/\t/, " ", target); gsub(/\t/, " ", text)
    if (text == "") text = target
    print ln "\t" form "\t" target "\t" text "\t" path
  }

  # `[[target|text]]`: the target is the left half, and a pipe escaped for a
  # table cell leaves its backslash on it.
  function sdd_wiki(inner, ln,   p, t, text) {
    p = index(inner, "|")
    if (p) { t = substr(inner, 1, p - 1); sub(/\\$/, "", t); text = substr(inner, p + 1) }
    else { t = inner; text = inner }
    if (t == "") return
    sdd_emit(ln, "wiki", t, text, sdd_wres(t))
  }

  function sdd_wres(t,   c) {
    sub(/#.*/, "", t)
    if (t == "") return ""
    # A path-shaped target means its last segment (adr-kb-structure D4).
    if (index(t, "/")) { sub(/.*\//, "", t); sub(/\.md$/, "", t); if (t == "") return "" }
    if (index(t, "::")) {
      if (("A", t) in ix) return ix["A", t]
      c = t; gsub(/::/, ".", c)
      if (("E", c) in ix) return ix["E", c]
    } else if (index(t, ".")) {
      c = t; gsub(/\./, "::", c)
      if (("A", c) in ix) return ix["A", c]
      if (("E", t) in ix) return ix["E", t]
      if (("N", t) in ix) return ix["N", t]
    }
    if (("S", t) in ix) return ix["S", t]
    if ((("M", t) in ix) && (("S", ix["M", t]) in ix)) return ix["S", ix["M", t]]
    if (("N", t) in ix) return ix["N", t]
    return ""
  }

  function sdd_md(tok, ln,   p, text, dest, path) {
    p = index(tok, "](")
    text = substr(tok, 2, p - 2); gsub(/\\\|/, "|", text)
    dest = substr(tok, p + 2, length(tok) - p - 2)
    gsub(/^[ ]+|[ ]+$/, "", dest)
    if (substr(dest, 1, 1) == "<") { sub(/^</, "", dest); sub(/>.*$/, "", dest) }
    else sub(/[ ].*$/, "", dest)
    if (dest == "" || dest ~ /^#/ || dest ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\// || dest ~ /^(mailto|tel|data):/) return
    path = dest; sub(/[#?].*$/, "", path)
    sdd_emit(ln, "md", dest, text, sdd_join(dir, sdd_unescape(path)))
  }

  # Percent-decoding of printable ASCII; any other `%` stays as written.
  function sdd_unescape(s,   out, i, hi, lo) {
    out = ""
    while ((i = index(s, "%")) > 0) {
      hi = index("0123456789abcdef", tolower(substr(s, i + 1, 1)))
      lo = index("0123456789abcdef", tolower(substr(s, i + 2, 1)))
      if (hi < 3 || hi > 8 || lo == 0) { out = out substr(s, 1, i); s = substr(s, i + 1); continue }
      out = out substr(s, 1, i - 1) sprintf("%c", (hi - 1) * 16 + lo - 1); s = substr(s, i + 3)
    }
    return out s
  }

  # Lexical join: `.` dropped, `..` pops a segment, leading `..` kept.
  function sdd_join(d, p,   abs, n, seg, i, st, k, out) {
    abs = (substr(p, 1, 1) == "/")
    n = split((abs ? "" : d "/") p, seg, "/")
    if (substr(d, 1, 1) == "/") abs = 1
    k = 0
    for (i = 1; i <= n; i++) {
      if (seg[i] == "" || seg[i] == ".") continue
      if (seg[i] == ".." && k > 0 && st[k] != "..") { k--; continue }
      if (seg[i] == ".." && abs) continue
      st[++k] = seg[i]
    }
    out = ""
    for (i = 1; i <= k; i++) out = out (i > 1 ? "/" : "") st[i]
    return (abs ? "/" : "") out
  }
'

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
#   sections-present (its order check) and prose-style (its four
#   non-heuristic checks).
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
# Extracts the content under a markdown H2 header, found by its section name
# (see sdd_heading_name), up to the next H2 or EOF. Frontmatter and prose above the
# first H2 are ignored.
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

SDD_SECTION_IDS='entity	ENT1	Purpose	
entity	ENT2	Rationale	
entity	ENT3	Invariants	
entity	ENT4	Fields	
entity	ENT5	Touched by	
action	ACT1	Purpose	
action	ACT2	Inputs	
action	ACT3	Outputs	
action	ACT4	Entities	
action	ACT5	Preconditions	
action	ACT6	Behavior	
action	ACT7	Postconditions	
action	ACT8	Errors	
feature	UC1	Actor	
feature	UC2	Preconditions	
feature	UC3	Main flow	
feature	UC4	Alternative flows	
feature	UC5	Error flows	
feature	UC6	Postconditions	
feature	UC7	Acceptance criteria	
adr	ADR1	Context	
adr	ADR2	Decision	
adr	ADR3	Consequences	
adr	ADR4	Breaking changes	Consequences
adr	ADR5	Alternatives considered	
adr	ADR6	Related ADRs	
screen	SCR1	Purpose	
screen	SCR2	Bindings	
screen	SCR3	Parameters	Bindings
screen	SCR4	Data	Bindings
screen	SCR5	Dispatches	Bindings
screen	SCR6	Navigation	Bindings
screen	SCR7	States	Bindings
screen	SCR8	Render	
screen	SCR9	Module-specific deviations	
screen	SCR10	Current prototype	
screen	SCR11	Notes	
pattern	PAT1	Structure	
pattern	PAT2	Regions	
pattern	PAT3	Variants	
pattern	PAT4	Notes	
component	CMP1	Structure	
component	CMP2	API / Slots	
component	CMP3	States	
component	CMP4	Variants	
component	CMP5	Instances	
layout	LAY1	Frame	
layout	LAY2	Geometry	
layout	LAY3	Breakpoints	
layout	LAY4	Composition	
layout	LAY5	Variants	
layout	LAY6	Adopters	
layout	LAY7	Notes	
module	MOD1	Overview	
module	MOD2	Relationships	
module	MOD3	Use cases	
module	MOD4	Screens	
module	MOD5	Domain	
module	MOD6	Module ADRs	
spike	SPK1	Question	
spike	SPK2	Scope	
spike	SPK3	Learnings	
spike	SPK4	Outcome	'
export SDD_SECTION_IDS

SDD_AWK_HEADING_FUNCS='
  function sdd_heading_key(line, prefix,   h) {
    if (index(line, prefix) != 1) return ""
    h = substr(line, length(prefix) + 1)
    sub(/:[[:space:]].*$/, "", h)
    sub(/:$/, "", h)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
    return h
  }
  function sdd_heading_name(line, prefix,   k, n, i, rows, f) {
    if (!sdd_ids_loaded) {
      n = split(ENVIRON["SDD_SECTION_IDS"], rows, "\n")
      for (i = 1; i <= n; i++) { split(rows[i], f, "\t"); sdd_name_of[f[2]] = f[3] }
      sdd_ids_loaded = 1
    }
    k = sdd_heading_key(line, prefix)
    return (k in sdd_name_of) ? sdd_name_of[k] : k
  }
'

# sdd_body_section <file> <header_name>
#   Prints the body section content to stdout, verbatim (fenced blocks and
#   tables included). Empty if not found.
sdd_body_section() {
  local file="$1"
  local header="$2"
  awk -v header="$header" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_KEEP}"'
      sdd_heading_name($0, "## ") == header { capture = 1; next }
      /^## / && capture { exit }
      capture { print }
    '"${SDD_AWK_FENCE_FUNCS}${SDD_AWK_HEADING_FUNCS}" "$file"
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
  awk -v pfx="$prefix" -v hdr="$header" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      sdd_heading_name($0, pfx) == hdr { found = 1; exit }
      END { exit !found }
    '"${SDD_AWK_FENCE_FUNCS}${SDD_AWK_HEADING_FUNCS}" "$file"
}

# sdd_has_subsection <file> <parent_h2> <header_h3>
#   Exit 0 if the file declares `### header_h3` *within* the `## parent_h2`
#   section. This is the "sits under" form: an H3 that has drifted to another
#   H2 does not satisfy it.
sdd_has_subsection() {
  local file="$1"
  local parent="$2"
  local header="$3"
  awk -v ph="$parent" -v sh="$header" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      sdd_heading_name($0, "## ") == ph { inparent = 1; next }
      /^## / { inparent = 0; next }
      inparent && sdd_heading_name($0, "### ") == sh { found = 1; exit }
      END { exit !found }
    '"${SDD_AWK_FENCE_FUNCS}${SDD_AWK_HEADING_FUNCS}" "$file"
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
  awk -v ph="$parent" -v sh="$header" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_KEEP}"'
      !capture && sdd_heading_name($0, "## ") == ph { inparent = 1; next }
      /^## / { if (capture) exit; inparent = 0; next }
      inparent && sdd_heading_name($0, "### ") == sh { capture = 1; next }
      /^### / && capture { exit }
      capture { print }
    '"${SDD_AWK_FENCE_FUNCS}${SDD_AWK_HEADING_FUNCS}" "$file"
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
      !/^\|/ { tab = 0 }
      /^\|/ && !tab { tab = 1; next }
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
        if (field ~ /^-+$/) next
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
      !/^\|/ { tab = 0 }
      /^\|/ && !tab { tab = 1; next }
      /^\|[[:space:]]*`?[A-Za-z_][A-Za-z0-9_]*`?[[:space:]]*\|/ {
        gsub(/^\|[[:space:]]*|[[:space:]]*\|$/, "")
        n = split($0, parts, /[[:space:]]*\|[[:space:]]*/)
        if (n < 1) next
        field = parts[1]
        gsub(/^`|`$/, "", field)
        if (field ~ /^-+$/) next
        print field
      }
    '
}
