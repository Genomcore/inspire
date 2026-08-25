#!/usr/bin/env bash
# .inspire/bin/trust.sh
#
# Artifact trust — the mechanical half of provenance and endorsement.
#
# Two additive frontmatter blocks answer two different questions:
#
#   produced:   what machine wrote this? — the owning skill, the exact bytes of
#               the deployed skill directory, the shared references, and the
#               runtime version. Machine-owned, overwritten wholesale on every
#               KB write.
#   endorsed:   who is the last human that put their name on this? — a name and
#               a date. Attestation, not content-pinning: git history is the
#               byte-level audit trail.
#
# Staleness is ecosystem divergence, never age. There are no clocks in any
# check here: `at` fields are informational, and so is `inspire`.
#
# This tool is not a review rule. It emits no findings, `review.sh` does not
# enumerate it, and `report` exits 0 no matter what it finds — a signal, never
# a gate.
#
# Skills never author stamp YAML and never compute hashes; they call this.
#
# Usage:
#   .inspire/bin/trust.sh skill-sha <dir> [--full]
#   .inspire/bin/trust.sh stamp <file> --skill <name> [--skills <root>]
#   .inspire/bin/trust.sh endorse <file>
#   .inspire/bin/trust.sh report [--kb <dir>] [--skills <root>] [--summary]
#
# Paths are read relative to the current working directory, which must be the
# project root. Requires `yq` only — deliberately not `jq`, so the pre-PR hook
# can call it in a project that has never installed one.

set -uo pipefail

SKILLS_ROOT_DEFAULT=".claude/skills"
KB_ROOT_DEFAULT="inspire_kb"
LOCK_FILE=".inspire.lock"

die() { echo "trust.sh: $*" >&2; exit 2; }

# The header block's own Usage section, through to the first line of code.
usage() {
  sed -n '/^# Usage:/,/^[^#]/p' "$0" | sed -e '/^[^#]/d' -e 's/^# \{0,1\}//'
}

require_yq() {
  command -v yq >/dev/null 2>&1 && return 0
  echo "trust.sh: missing required tool: yq" >&2
  echo "          install via: brew install yq" >&2
  exit 127
}

# ─────────────────────────────────────────────────────────────────────────────
# Hashing
#
# One algorithm everywhere: sha256, per the repo convention. An LLM
# hand-writing a hash is not a trust primitive, so nothing outside this file
# ever produces one.
# ─────────────────────────────────────────────────────────────────────────────

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# trust_dir_sha <dir>
#   The composite hash of a directory, as 64 hex. For every regular file, one
#   `relpath␠␠sha256` line; hidden files and hidden directories are excluded at
#   any depth (.DS_Store is a fact of this platform, and a stamp that moved
#   because the Finder walked past would be worthless); the lines are LC_ALL=C
#   sorted and digested with sha256.
#
#   Relative paths are what make the hash path-independent: the same skill
#   directory hashes identically in every project that installs it. Returns 2
#   when the argument is not a directory. Symlinks are out of scope repo-wide.
trust_dir_sha() {
  local dir="$1"
  [ -d "$dir" ] || return 2
  local manifest sha rel
  manifest="$(mktemp -t inspire-trust.XXXXXX)" || return 1
  ( cd "$dir" && find . -name '.?*' -prune -o -type f -print ) 2>/dev/null \
    | while IFS= read -r rel; do
        rel="${rel#./}"
        printf '%s  %s\n' "$rel" "$(sha256_of "$dir/$rel")"
      done \
    | LC_ALL=C sort > "$manifest"
  sha="$(sha256_of "$manifest")"
  rm -f "$manifest"
  printf '%s\n' "$sha"
}

# The 7-hex short form that goes into a stamp.
trust_dir_sha_short() {
  local sha
  sha="$(trust_dir_sha "$1")" || return $?
  printf '%s\n' "${sha:0:7}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Frontmatter
#
# Every read and write goes through yq. The one thing yq cannot do is tell a
# file that has no frontmatter from one that has an empty block, so presence is
# detected here and an empty block created before yq is handed the file.
# ─────────────────────────────────────────────────────────────────────────────

# Whether a file opens with a frontmatter block at all. Every read below is
# guarded on this, because `yq --front-matter=extract` does NOT fail on a file
# that has none — it parses the whole document as YAML, and a markdown `# Title`
# is a valid YAML comment. So a body with `endorsed:` at column 0 (a KB artifact
# documenting the stamp format, say) reads back as a real endorsement with a real
# `by`. A fabricated endorsement is the one error class this whole feature exists
# to prevent, so the guard is load-bearing rather than defensive.
has_frontmatter() {
  local first
  IFS= read -r first < "$1" 2>/dev/null || return 1
  [ "$first" = "---" ] || return 1
  awk 'NR==1 { next } $0 == "---" { found = 1; exit } END { exit !found }' "$1"
}

fm_value() {
  has_frontmatter "$1" || return 0
  yq --front-matter=extract -r "$2 // \"\"" "$1" 2>/dev/null || true
}

# fm_has_block <file> <key> — true only when the file has frontmatter AND the key
# exists in it as a mapping.
fm_has_block() {
  local tag
  has_frontmatter "$1" || return 1
  tag="$(yq --front-matter=extract -r ".$2 | tag" "$1" 2>/dev/null || true)"
  [ "$tag" = "!!map" ]
}

# Screens ship without frontmatter deliberately, and most ADRs and features do
# in practice. Give such a file an empty block so yq can edit it; the body is
# left byte-for-byte intact, and the file keeps its inode and mode.
ensure_frontmatter() {
  local file="$1" tmp
  has_frontmatter "$file" && return 0
  tmp="$(mktemp -t inspire-trust.XXXXXX)" || die "cannot create a temp file"
  { printf -- '---\n---\n'; cat "$file"; } > "$tmp" \
    && cat "$tmp" > "$file" \
    && rm -f "$tmp"
}

# The runtime version, for the stamp's `inspire` field. `.inspire.lock` is JSON;
# yq reads it, so this tool still needs no jq. `unknown` is the honest answer
# with no lock (the template repo itself, for one) and is never a trigger for
# anything: the field is a human label at grep scale and a retrieval key.
lock_version() {
  local v
  [ -f "$LOCK_FILE" ] || { printf 'unknown\n'; return 0; }
  v="$(yq -p json -o yaml -r '.inspire_version // ""' "$LOCK_FILE" 2>/dev/null || true)"
  case "$v" in ''|null) v="unknown" ;; esac
  printf '%s\n' "$v"
}

# ─────────────────────────────────────────────────────────────────────────────
# The structural ownership map
#
# Which skill owns a KB path. INSPIRE-owned code, and therefore repairable: a
# release that renames or splits a skill fixes the map in the same commit,
# whereas a name frozen into a stamp could never be repaired — KB content is
# not INSPIRE's to rewrite. The stamp's own `skill` is kept as evidence, and
# when it disagrees with the map that disagreement is a reported finding.
#
# Two entries are corrections of the positional rule: `design-system.md` is the
# one artifact inspire-bootstrap owns outside 00_bootstrap, and `surfaces.md` is
# inspire-surface's roster.
# ─────────────────────────────────────────────────────────────────────────────

owner_for() {
  case "$1" in
    05_screens/design-system.md) printf 'bootstrap\n' ;;
    00_bootstrap/surfaces.md)    printf 'surface\n' ;;
    01_adr/*)                    printf 'adr\n' ;;
    02_modules/*)                printf 'module\n' ;;
    03_features/*)               printf 'feature\n' ;;
    04_domain/*)                 printf 'domain\n' ;;
    05_screens/*)                printf 'screens\n' ;;
    *)                           printf '\n' ;;
  esac
}

# Skeleton and template files carry no stamps. The test is by path and filename
# ONLY: the live design-system.md inherits `status: template` from the byte-copy
# of theme.md at materialize time, so any frontmatter predicate would silently
# excuse a project's real design system from every check here.
skip_artifact() {
  case "${1##*/}" in
    README.md|_template.md|theme.md) return 0 ;;
  esac
  return 1
}

# Screens `_index.md` files are rebuilt nav content: endorsing them is drift by
# construction. They still carry provenance. Pattern/component catalog entries
# are NOT in this exemption: since T2 an entry is an authored layout contract
# (its regions, what each accepts) rather than rebuilt output, so a human can
# vouch for it like any other 01_adr–05_screens artifact.
endorsement_checked() {
  case "$1" in
    _index.md|*/_index.md) return 1 ;;
  esac
  return 0
}

# `00_bootstrap/{project,stack}.md` are generated by the operator interview, not
# by a skill run, so a provenance stamp there would be unactionable noise.
produced_checked() {
  case "$1" in
    00_bootstrap/*) return 1 ;;
  esac
  return 0
}

# Every artifact the report considers, KB-relative and stably ordered. The two
# bootstrap files are named explicitly — the rest of 00_bootstrap is not walked,
# and neither are the meta layers 06_spikes, 98_lessons and 99_tracker.
scan_paths() {
  local kb="$1" rel layer
  {
    for rel in 00_bootstrap/project.md 00_bootstrap/stack.md; do
      [ -f "$kb/$rel" ] && printf '%s\n' "$rel"
    done
    for layer in 01_adr 02_modules 03_features 04_domain 05_screens; do
      [ -d "$kb/$layer" ] || continue
      ( cd "$kb" && find "$layer" -name '.?*' -prune -o -type f -name '*.md' -print )
    done
  } 2>/dev/null | LC_ALL=C sort
}

# ─────────────────────────────────────────────────────────────────────────────
# skill-sha
# ─────────────────────────────────────────────────────────────────────────────

cmd_skill_sha() {
  local dir="" want_full=0 sha
  while [ $# -gt 0 ]; do
    case "$1" in
      --full) want_full=1 ;;
      -h|--help) usage; exit 0 ;;
      -*) die "unknown option for skill-sha: $1" ;;
      *) [ -z "$dir" ] || die "skill-sha takes one directory"; dir="$1" ;;
    esac
    shift
  done
  [ -n "$dir" ] || die "usage: trust.sh skill-sha <dir> [--full]"
  [ -d "$dir" ] || die "not a directory: $dir"
  sha="$(trust_dir_sha "$dir")" || die "cannot hash: $dir"
  if [ "$want_full" = 1 ]; then
    printf '%s\n' "$sha"
  else
    printf '%s\n' "${sha:0:7}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# stamp — machine-owned, overwritten wholesale
# ─────────────────────────────────────────────────────────────────────────────

cmd_stamp() {
  local file="" skill="" skills_root="$SKILLS_ROOT_DEFAULT"
  local skill_dir refs_dir skill_sha refs_sha
  while [ $# -gt 0 ]; do
    case "$1" in
      --skill)  shift; skill="${1:-}" ;;
      --skills) shift; skills_root="${1:-}" ;;
      -h|--help) usage; exit 0 ;;
      -*) die "unknown option for stamp: $1" ;;
      *) [ -z "$file" ] || die "stamp takes one file"; file="$1" ;;
    esac
    shift
  done
  [ -n "$file" ] && [ -n "$skill" ] \
    || die "usage: trust.sh stamp <file> --skill <name> [--skills <root>]"
  [ -f "$file" ] || die "not a file: $file"

  # A stamp naming bytes that are not on disk would be worse than no stamp, so
  # an uninstalled skill is an error rather than a placeholder hash.
  skill_dir="$skills_root/inspire-$skill"
  refs_dir="$skills_root/_references"
  [ -d "$skill_dir" ] || die "skill not installed: $skill_dir"
  [ -d "$refs_dir" ]  || die "shared references not installed: $refs_dir"

  skill_sha="$(trust_dir_sha_short "$skill_dir")" || die "cannot hash: $skill_dir"
  refs_sha="$(trust_dir_sha_short "$refs_dir")"   || die "cannot hash: $refs_dir"

  ensure_frontmatter "$file"

  # Wholesale assignment, so a key some earlier version wrote cannot survive.
  # Every value goes in as a string: a short hash of hex digits alone (1234567)
  # would otherwise be read back as a number.
  TRUST_SKILL="$skill" \
  TRUST_SKILL_SHA="$skill_sha" \
  TRUST_REFS_SHA="$refs_sha" \
  TRUST_INSPIRE="$(lock_version)" \
  TRUST_AT="$(date +%Y-%m-%d)" \
  yq -i --front-matter=process '.produced = {
      "skill":     strenv(TRUST_SKILL),
      "skill_sha": strenv(TRUST_SKILL_SHA),
      "refs_sha":  strenv(TRUST_REFS_SHA),
      "inspire":   strenv(TRUST_INSPIRE),
      "at":        strenv(TRUST_AT)
    }' "$file" || die "yq could not write the produced block into $file"
}

# ─────────────────────────────────────────────────────────────────────────────
# endorse — human-owned; run only after an explicit operator yes
#
# That last part is a discipline the prose demands, not a property this script
# can prove. Nothing here checks that anyone was asked.
# ─────────────────────────────────────────────────────────────────────────────

cmd_endorse() {
  local file="" email handle
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -*) die "unknown option for endorse: $1" ;;
      *) [ -z "$file" ] || die "endorse takes one file"; file="$1" ;;
    esac
    shift
  done
  [ -n "$file" ] || die "usage: trust.sh endorse <file>"
  [ -f "$file" ] || die "not a file: $file"

  email="$(git config user.email 2>/dev/null || true)"
  [ -n "$email" ] \
    || die "git config user.email is unset — an endorsement needs a name to carry"
  handle="@${email%%@*}"
  [ "$handle" != "@" ] || die "git config user.email has no local part: $email"

  ensure_frontmatter "$file"
  TRUST_BY="$handle" TRUST_AT="$(date +%Y-%m-%d)" \
  yq -i --front-matter=process \
    '.endorsed = {"by": strenv(TRUST_BY), "at": strenv(TRUST_AT)}' "$file" \
    || die "yq could not write the endorsed block into $file"
}

# ─────────────────────────────────────────────────────────────────────────────
# report — read-only, stateless, exit 0
#
# Everything is recomputed on every run: no ack ledger, no persisted state,
# nothing to rebaseline. The guarantee is only ever "nothing is stale without
# the report saying so *when run*" — which is why the pre-PR hook runs
# `--summary` unconditionally.
# ─────────────────────────────────────────────────────────────────────────────

nlines() {
  if [ -s "$1" ]; then LC_ALL=C grep -c . "$1"; else echo 0; fi
}

# The current composite hash of an owner's deployed skill directory, memoised
# for the run. `MISSING` when the directory is absent — deleting a skill is
# legitimate use, so that is its own verdict and never staleness.
owner_sha() {
  local owner="$1" skills_root="$2" cached dir sha
  cached="$(awk -F'\t' -v o="$owner" '$1 == o { print $2; exit }' "$OWNER_CACHE")"
  if [ -n "$cached" ]; then printf '%s\n' "$cached"; return 0; fi
  dir="$skills_root/inspire-$owner"
  if [ -d "$dir" ]; then sha="$(trust_dir_sha_short "$dir")"; else sha="MISSING"; fi
  printf '%s\t%s\n' "$owner" "$sha" >> "$OWNER_CACHE"
  printf '%s\n' "$sha"
}

cmd_report() {
  local kb="$KB_ROOT_DEFAULT" skills_root="$SKILLS_ROOT_DEFAULT" summary=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --kb)      shift; kb="${1:-}" ;;
      --skills)  shift; skills_root="${1:-}" ;;
      --summary) summary=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument for report: $1" ;;
    esac
    shift
  done
  kb="${kb%/}"
  skills_root="${skills_root%/}"

  # The scratch dir is a global, not a local: the EXIT trap runs after the
  # function has returned and its locals are gone.
  REPORT_WORK="$(mktemp -d -t inspire-trust-report.XXXXXX)" || die "cannot create a temp dir"
  trap 'rm -rf "${REPORT_WORK:-}"' EXIT
  local work="$REPORT_WORK"
  OWNER_CACHE="$work/owners"; : > "$OWNER_CACHE"
  local g_unend="$work/unendorsed"   ; : > "$g_unend"
  local g_stale="$work/stale"         ; : > "$g_stale"
  local g_refs="$work/refs"           ; : > "$g_refs"
  local g_prep="$work/preprovenance"  ; : > "$g_prep"
  local g_noown="$work/noowner"       ; : > "$g_noown"
  local g_misr="$work/misrouted"      ; : > "$g_misr"

  # One vault-wide comparand for the shared rules. Absent `_references/` leaves
  # no honest comparand, so the check is skipped rather than guessed at.
  local refs_now=""
  [ -d "$skills_root/_references" ] && refs_now="$(trust_dir_sha_short "$skills_root/_references")"

  local rel file disp owner st_skill st_sha st_refs cur endorsed produced
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    skip_artifact "$rel" && continue
    file="$kb/$rel"
    disp="$kb/$rel"
    owner="$(owner_for "$rel")"

    # A file with no frontmatter carries no blocks, full stop — decided once here
    # rather than trusting yq, which would read a body line as a stamp. Screens
    # ship this way by design and most ADRs and features do in practice, so this
    # is the common case, not the edge one.
    endorsed=0; produced=0
    if has_frontmatter "$file"; then
      fm_has_block "$file" endorsed && endorsed=1
      fm_has_block "$file" produced && produced=1
    fi

    if endorsement_checked "$rel" && [ "$endorsed" = 0 ]; then
      printf '%s\n' "$disp" >> "$g_unend"
    fi

    produced_checked "$rel" || continue

    if [ "$produced" = 0 ]; then
      printf '%s\n' "$disp" >> "$g_prep"
      continue
    fi

    st_skill="$(fm_value "$file" '.produced.skill')"
    st_sha="$(fm_value "$file" '.produced.skill_sha')"
    st_refs="$(fm_value "$file" '.produced.refs_sha')"

    if [ -n "$refs_now" ] && [ "$st_refs" != "$refs_now" ]; then
      printf '%s\n' "$disp" >> "$g_refs"
    fi

    [ -n "$owner" ] || continue

    if [ -n "$st_skill" ] && [ "$st_skill" != "$owner" ]; then
      printf '%s\t%s\t%s\n' "$disp" "$st_skill" "$owner" >> "$g_misr"
    fi

    cur="$(owner_sha "$owner" "$skills_root")"
    if [ "$cur" = "MISSING" ]; then
      printf '%s\t%s\n' "$owner" "$disp" >> "$g_noown"
    elif [ "$st_sha" != "$cur" ]; then
      printf '%s\t%s\t%s\t%s\n' "$owner" "$st_sha" "$cur" "$disp" >> "$g_stale"
    fi
  done < <(scan_paths "$kb")

  local n_unend n_stale n_refs n_prep n_noown n_misr stale_owners
  n_unend="$(nlines "$g_unend")"
  n_stale="$(nlines "$g_stale")"
  n_refs="$(nlines "$g_refs")"
  n_prep="$(nlines "$g_prep")"
  n_noown="$(nlines "$g_noown")"
  n_misr="$(nlines "$g_misr")"
  stale_owners="$(awk -F'\t' '{ print "inspire-" $1 }' "$g_stale" \
    | LC_ALL=C sort -u | paste -sd, - | sed 's/,/, /g')"

  local clean=0
  [ "$n_unend" -eq 0 ] && [ "$n_stale" -eq 0 ] && [ "$n_refs" -eq 0 ] \
    && [ "$n_prep" -eq 0 ] && [ "$n_noown" -eq 0 ] && [ "$n_misr" -eq 0 ] && clean=1

  if [ "$summary" = 1 ]; then
    # Counts, never lists. A full report at every PR would be the same wall of
    # true-but-unchanged lines each time; a count that jumped since the last PR
    # is the part worth an unconditional line.
    if [ "$clean" = 1 ]; then
      printf 'trust: all stamped artifacts fresh\n'
    else
      local parts=""
      [ "$n_unend" -gt 0 ] && parts="$parts · $n_unend unendorsed"
      [ "$n_stale" -gt 0 ] && parts="$parts · $n_stale stale ($stale_owners)"
      [ "$n_refs"  -gt 0 ] && parts="$parts · $n_refs refs-changed"
      [ "$n_prep"  -gt 0 ] && parts="$parts · $n_prep pre-provenance"
      [ "$n_noown" -gt 0 ] && parts="$parts · $n_noown owner-missing"
      [ "$n_misr"  -gt 0 ] && parts="$parts · $n_misr misrouted"
      printf 'trust: %s — .inspire/bin/trust.sh report for detail\n' "${parts# · }"
    fi
    return 0
  fi

  printf 'INSPIRE artifact trust — %s (read-only signal, never a gate)\n' "$kb"

  if [ "$clean" = 1 ]; then
    printf '\ntrust: all stamped artifacts fresh\n'
    return 0
  fi

  local owner st cur n p sk ow
  if [ "$n_unend" -gt 0 ]; then
    printf '\nUNENDORSED (%s)\n' "$n_unend"
    sed 's/^/  /' "$g_unend"
    printf '  no human has put a name on these; an owning skill proposes at its promote moments.\n'
  fi

  if [ "$n_stale" -gt 0 ]; then
    printf '\nSTALE (%s)\n' "$n_stale"
    # Grouped by producer transition: "23 artifacts under a different
    # inspire-feature" is one judgment, not 23.
    awk -F'\t' '{ print $1 "\t" $2 "\t" $3 }' "$g_stale" | LC_ALL=C sort -u \
      | while IFS=$'\t' read -r owner st cur; do
          n="$(awk -F'\t' -v o="$owner" -v s="$st" '$1 == o && $2 == s { c++ } END { print c+0 }' "$g_stale")"
          printf '  %s stamped %s, now %s (%s)\n' "$owner" "$st" "$cur" "$n"
          awk -F'\t' -v o="$owner" -v s="$st" '$1 == o && $2 == s { print "    " $4 }' "$g_stale"
        done
    printf '  fix: invoke the owning skill on the artifact — its update or review flow.\n'
  fi

  if [ "$n_refs" -gt 0 ]; then
    printf '\nREFS-CHANGED (%s)\n' "$n_refs"
    printf '  the shared rules are now %s; %s stamped artifacts anchor a different version of them.\n' \
      "$refs_now" "$n_refs"
  fi

  if [ "$n_prep" -gt 0 ]; then
    printf '\nPRE-PROVENANCE (%s)\n' "$n_prep"
    printf '  no produced: block — a shrinking cohort, never backfilled; stamps accrue as artifacts are touched.\n'
  fi

  if [ "$n_noown" -gt 0 ]; then
    printf '\nOWNER NOT INSTALLED (%s)\n' "$n_noown"
    awk -F'\t' '{ print $1 }' "$g_noown" | LC_ALL=C sort -u \
      | while IFS= read -r owner; do
          n="$(awk -F'\t' -v o="$owner" '$1 == o { c++ } END { print c+0 }' "$g_noown")"
          printf '  %s — %s/inspire-%s is absent, so provenance is unresolvable, never stale (%s)\n' \
            "$owner" "$skills_root" "$owner" "$n"
          awk -F'\t' -v o="$owner" '$1 == o { print "    " $2 }' "$g_noown"
        done
  fi

  if [ "$n_misr" -gt 0 ]; then
    printf '\nMISROUTED (%s)\n' "$n_misr"
    while IFS=$'\t' read -r p sk ow; do
      printf "  %s — stamped skill '%s', the layer's owner is '%s'\n" "$p" "$sk" "$ow"
    done < "$g_misr"
    printf '  fix: a skill writing outside its owned layer is misbehaviour — route the write to the owner.\n'
  fi

  return 0
}

# ─────────────────────────────────────────────────────────────────────────────

require_yq

verb="${1:-}"
[ $# -gt 0 ] && shift
case "$verb" in
  skill-sha) cmd_skill_sha "$@" ;;
  stamp)     cmd_stamp "$@" ;;
  endorse)   cmd_endorse "$@" ;;
  report)    cmd_report "$@"; exit 0 ;;
  -h|--help|help) usage ;;
  '')        usage >&2; exit 2 ;;
  *)         echo "trust.sh: unknown verb: $verb" >&2; usage >&2; exit 2 ;;
esac
