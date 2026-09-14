#!/usr/bin/env bash
# .inspire/bin/emanate-harvest.sh
#
# harvest — worktree diff -> integration-branch commit. Pure git; writes git
# only (D8). One of the emanation loop's five independent bin scripts
# (derive, plan, gate, results, harvest); this one has no lib/ dependency —
# see "In-package decision: lib/" below.
#
# The envelope (D4): prepare shapes a phase worktree, work happens inside it
# with full freedom (commits, staged/unstaged/untracked edits, even editing
# tests to debug). Harvest is the only step that decides what LEAVES the
# sandbox: the whole worktree is present and writable, but only the phase's
# OWNED paths exit. The test freeze IS this filter, structurally — a tester
# that edited source, or an implementer that edited tests/**, is silently
# DROPPED, never blocked, and the drop is reported so the orchestrator can
# treat it as a signal.
#
# Mechanics — never a checkout of the integration branch, never a mutation of
# either worktree's real index:
#   1. cut  = merge-base(worktree HEAD, integration branch) — where the phase
#      forked. Comparing against the cut, never against "the tip right now",
#      is what keeps the filter correct after the tip has moved.
#   2. A private temporary index (GIT_INDEX_FILE) is seeded from the cut and
#      then `add -A`'d inside the phase worktree, snapshotting its CURRENT
#      ON-DISK state as one tree object, honouring .gitignore. `add -A`
#      reads the FILESYSTEM, not the worktree's own index — that index is
#      never consulted and never touched. A file staged then deleted from
#      disk is NOT harvested; a staged deletion left on disk (`git rm
#      --cached`) IS harvested with its on-disk content, exactly like an
#      ordinary unstaged edit. Working-tree state is authoritative, full
#      stop.
#   3. git diff --no-renames --name-only, restricted to the owned pathspec vs.
#      unrestricted, gives the harvested and dropped path sets (a rename
#      decomposes into a delete + an add with renames off, which the
#      path-by-path overlay in step 5 handles correctly with no special
#      case). Every path list in this script is produced with `-c
#      core.quotePath=false … -z` and consumed NUL-terminated: a non-ASCII
#      byte, or a literal '"' or '\' in a filename, is never trusted to
#      git's human-readable (and lossy, C-quoted) rendering of it — that
#      rendering is not a valid pathname on its own, and treating it as one
#      silently drops the real file (it matches nothing on a later lookup).
#   4. The same diff between the cut and the integration branch's CURRENT tip
#      gives the set of paths the branch changed independently since the cut
#      (other harvests, other commits). If that set intersects the owned
#      set AND the intersecting path's content actually differs between the
#      worktree snapshot and the tip, this is a conflict: refuse, touch
#      nothing. An intersecting path whose content is byte-identical on both
#      sides is NOT a conflict — it means this exact change already landed
#      (a repeat harvest, or the same content arrived some other way) — see
#      exit 6. Otherwise disjoint means the harvest applies cleanly on top
#      of whatever the tip is now.
#   5. A second temporary index, seeded from the tip, is overlaid path by
#      path with the worktree snapshot's content for every owned changed
#      path: present => `update-index --cacheinfo`, but ONLY once the tree
#      entry's mode is confirmed to be an actual blob/symlink/gitlink
#      (100644/100755/120000/160000) — anything else means the path became a
#      tree (a file replaced by a same-named directory, or vice versa), and
#      the harvest refuses rather than fabricate a corrupt entry (exit 8);
#      absent => `--force-remove`. The result is written to a new tree and
#      committed with the tip as its one parent.
#   6. `git update-ref refs/heads/<branch> <new> <old-tip>` — itself a
#      compare-and-swap — lands the commit. A concurrent mover of the branch
#      (a real race, not just a stale read) fails this exactly like the
#      path-level conflict above.
#
# Usage:
#   emanate-harvest.sh <worktree> <branch> --label <label> [--discard]
#                      [--mode plan | --dry-run] -- <pathspec>...
#
#   <worktree>   path to the phase worktree. Must be a git worktree of the
#                SAME repository this script is invoked from — its
#                --git-common-dir must resolve to the same place. This
#                script's own CWD must therefore be inside that repository
#                (any of its worktrees), same convention as the rest of
#                base/bin/: "scripts read from the current working directory
#                as the repo root".
#   <branch>     the integration branch — a local ref (refs/heads/<branch>,
#                the "refs/heads/" prefix optional on input). Never checked
#                out and never read from a working tree: read and written
#                purely as git objects, so it may be checked out in another
#                worktree, or nowhere at all.
#   --label      short phase label (e.g. "t07-implementer"), required.
#                Recorded in the commit message; git is the turn's audit
#                trail (D4).
#   --discard    after a successful commit, `git worktree remove --force`
#                the phase worktree and delete the branch that was checked
#                out in it. Refused — commit kept, worktree and branch left
#                exactly in place, a warning printed, discarded:false — if
#                that branch IS <branch> itself: removing it would delete
#                the integration branch this run just committed to. Default
#                (no --discard): keep both. Inert under --mode plan /
#                --dry-run (nothing was committed, so there is nothing whose
#                success gates a removal).
#   --mode plan  read-only preview: performs every check and reports the same
#                verdict an act-mode run would reach, but writes NOTHING to
#                any real ref, reflog or index. (Loose blob/tree objects used
#                internally to compute the diff may land in the shared
#                object database; they are unreachable from any ref, ordinary
#                git garbage, not the state this flag promises not to touch.)
#                Mirrors materialize.sh's --mode vocabulary.
#   --dry-run    alias for --mode plan.
#   --           everything after this is one or more git pathspecs: the
#                phase's OWNED set. ':(exclude)' magic composes normally, so
#                "source minus tests" is one pathspec list passed straight to
#                git — never a second flag INSPIRE would have to invent.
#
# Exit codes — distinct and documented, never a generic catch-all:
#   0   success — a commit was made (or, under --mode plan, would have been).
#   1   an unexpected git failure at a step earlier validation should have
#       ruled out (defensive; not expected to fire in practice).
#   2   usage error — bad flags, missing --label, a malformed owned pathspec
#       (bad ':()' magic — the one input entirely in the caller's hands, so
#       a typo here is USAGE, not an internal failure), or (rare) the
#       worktree's branch shares no history with the integration branch at
#       all.
#   3   the worktree path does not exist, is not a git worktree of THIS
#       repository, or this script's own CWD is not inside any git
#       repository at all.
#   4   the integration branch does not exist as a local ref.
#   5   no owned pathspec was given after --.
#   6   nothing to harvest — either the owned diff is empty, or every owned
#       change is already present on the integration branch byte-for-byte
#       (re-running an already-landed harvest is idempotent, not a
#       conflict). A NORMAL outcome, not a failure: the orchestrator
#       branches on it. No commit is made, no ref is touched.
#   7   conflict — the owned diff does not apply cleanly onto the
#       integration branch's CURRENT tip: it moved since the cut and touched
#       a path this harvest also owns with DIFFERENT content, or the final
#       update-ref compare-and-swap lost a race. Every ref is left exactly
#       as found.
#   8   an owned path is a blob/symlink/gitlink on one side and a tree
#       (directory) on the other, between the cut/tip and the current
#       worktree snapshot — e.g. `foo.txt` replaced by a `foo.txt/`
#       directory, or vice versa. Refused before writing anything rather
#       than fabricate a corrupt tree entry; every ref is left exactly as
#       found.
#   127 a required tool (jq) is missing.
#
# Report: a grouped human report to stderr (harvested paths — each with its
# A/M/D... status — dropped paths, the commit sha) and a one-line JSON
# summary to stdout:
#   {"commit": <sha-or-null>, "branch": <name>, "harvested": [...],
#    "harvested_status": {<path>: "A"|"M"|"D"|...}, "dropped": [...],
#    "discarded": <bool>}
#
# In-package decision: lib/. D8 and the Defaults call for shared bin logic to
# live in plugin/base/bin/lib/ (materializing to .inspire/bin/lib/, deployed
# alongside the flat *.sh entries). Confirmed before writing a single line
# here: plugin/scripts/lib/merge.sh's apply_base resolves EVERY path under
# base/<name>/ generically through _middle/_from_middle — there is no
# top-level-file-only special case — so plugin/base/bin/lib/*.sh would
# materialize to .inspire/bin/lib/*.sh, and materialize.sh's
# chmod_executables() walks base/bin/ recursively (excluding only bin/test/),
# so it would be chmod +x'd too. A lib/ unit is therefore viable without
# touching materialize.sh at all (which this package does not own — T8 does).
# It is not used: harvest is the only bin script this package ships, there is
# nothing yet to share it with (derive/plan/gate are separate packages), and
# introducing a lib/ file for a single caller would be a speculative
# indirection. This script is fully self-contained.

set -uo pipefail

EXIT_OK=0
EXIT_INTERNAL=1
EXIT_USAGE=2
EXIT_NO_WORKTREE=3
EXIT_NO_REF=4
EXIT_NO_PATHSPEC=5
EXIT_EMPTY=6
EXIT_CONFLICT=7
EXIT_TYPE_CONFLICT=8
EXIT_MISSING_TOOL=127

# The header block's own Usage/Exit-codes/Report sections, through to (but
# not including) "In-package decision" — the internal design rationale is
# not operator-facing help.
usage() {
  sed -n '/^# Usage:/,/^# In-package decision/p' "$0" \
    | sed -e '/^# In-package decision/d' -e '/^[^#]/d' -e 's/^# \{0,1\}//'
}

die_code() {
  local code="$1"; shift
  echo "emanate-harvest.sh: $*" >&2
  exit "$code"
}

require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  echo "emanate-harvest.sh: missing required tool: jq" >&2
  echo "                    install via: brew install jq" >&2
  exit "$EXIT_MISSING_TOOL"
}

nlines() {
  if [ -s "$1" ]; then LC_ALL=C grep -c . "$1"; else echo 0; fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

WORKTREE=""
BRANCH=""
LABEL=""
DISCARD=0
MODE="act"
PATHSPECS=()
positional=()

while [ $# -gt 0 ]; do
  case "$1" in
    --label)
      shift; LABEL="${1:-}" ;;
    --discard)
      DISCARD=1 ;;
    --mode)
      shift
      case "${1:-}" in
        plan) MODE="plan" ;;
        act)  MODE="act" ;;
        *) die_code "$EXIT_USAGE" "unknown --mode: '${1:-}' (want plan|act)" ;;
      esac
      ;;
    --dry-run)
      MODE="plan" ;;
    -h|--help)
      usage; exit "$EXIT_OK" ;;
    --)
      shift
      PATHSPECS=("$@")
      break
      ;;
    -*)
      die_code "$EXIT_USAGE" "unknown option: $1" ;;
    *)
      positional+=("$1") ;;
  esac
  shift
done

if [ "${#positional[@]}" -lt 2 ]; then
  usage >&2
  die_code "$EXIT_USAGE" "usage: emanate-harvest.sh <worktree> <branch> --label <label> [--discard] [--mode plan|--dry-run] -- <pathspec>..."
fi
[ "${#positional[@]}" -le 2 ] || die_code "$EXIT_USAGE" "too many positional arguments: ${positional[*]}"

WORKTREE="${positional[0]}"
BRANCH="${positional[1]#refs/heads/}"

[ -n "$LABEL" ] || die_code "$EXIT_USAGE" "--label is required"
[ "${#PATHSPECS[@]}" -gt 0 ] || die_code "$EXIT_NO_PATHSPEC" "no owned pathspec given after --"

if [ "$DISCARD" = 1 ] && [ "$MODE" = "plan" ]; then
  echo "emanate-harvest.sh: note: --discard is inert under --mode plan/--dry-run (nothing is committed)" >&2
fi

require_jq

# ─────────────────────────────────────────────────────────────────────────────
# Validate the worktree: exists, is a git worktree, and shares this repo's
# object database (its --git-common-dir resolves to the same place as the
# repo this script is invoked from).
# ─────────────────────────────────────────────────────────────────────────────

[ -d "$WORKTREE" ] || die_code "$EXIT_NO_WORKTREE" "not a directory: $WORKTREE"

iwt="$(git -C "$WORKTREE" rev-parse --is-inside-work-tree 2>/dev/null)" || iwt="false"
[ "$iwt" = "true" ] || die_code "$EXIT_NO_WORKTREE" "not a git worktree: $WORKTREE"

wt_common_rel="$(cd "$WORKTREE" && git rev-parse --git-common-dir 2>/dev/null)" \
  || die_code "$EXIT_NO_WORKTREE" "cannot resolve git-common-dir for $WORKTREE"
wt_common_abs="$(cd "$WORKTREE" && cd "$wt_common_rel" && pwd -P)" \
  || die_code "$EXIT_NO_WORKTREE" "cannot resolve git-common-dir for $WORKTREE"

repo_common_rel="$(git rev-parse --git-common-dir 2>/dev/null)" \
  || die_code "$EXIT_NO_WORKTREE" "this script must be run with its CWD inside the target repository"
repo_common_abs="$(cd "$repo_common_rel" && pwd -P)" \
  || die_code "$EXIT_NO_WORKTREE" "cannot resolve this repository's git-common-dir"

[ "$wt_common_abs" = "$repo_common_abs" ] \
  || die_code "$EXIT_NO_WORKTREE" "$WORKTREE is not a worktree of this repository"

# ─────────────────────────────────────────────────────────────────────────────
# Validate the integration branch: a local ref, resolved without ever
# checking it out.
# ─────────────────────────────────────────────────────────────────────────────

git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null \
  || die_code "$EXIT_NO_REF" "no such local branch: $BRANCH"

old_tip="$(git rev-parse "refs/heads/$BRANCH")"
wt_head="$(git -C "$WORKTREE" rev-parse HEAD 2>/dev/null)" \
  || die_code "$EXIT_NO_WORKTREE" "cannot resolve HEAD in $WORKTREE"
wt_branch="$(git -C "$WORKTREE" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"

cut_sha="$(git merge-base "$wt_head" "$old_tip" 2>/dev/null)" \
  || die_code "$EXIT_USAGE" "no common history between $WORKTREE (HEAD $wt_head) and $BRANCH — was the worktree cut from this branch?"

# ─────────────────────────────────────────────────────────────────────────────
# Scratch space: one private mktemp dir for every temp index / list this run
# needs, removed on exit however it ends. Never in-tree, never a fixed path.
# ─────────────────────────────────────────────────────────────────────────────

WORK="$(mktemp -d -t emanate-harvest.XXXXXX)" || die_code "$EXIT_INTERNAL" "cannot create a scratch directory"
trap 'rm -rf "${WORK:-}"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
# Snapshot the phase worktree's CURRENT on-disk state (never its own index —
# see step 2 above) as one tree object, via a private index that never
# touches the worktree's own .git/index.
# ─────────────────────────────────────────────────────────────────────────────

wt_idx="$WORK/wt.index"
GIT_INDEX_FILE="$wt_idx" git -C "$WORKTREE" read-tree "$cut_sha" \
  || die_code "$EXIT_INTERNAL" "cannot seed the snapshot index from the cut point"
GIT_INDEX_FILE="$wt_idx" git -C "$WORKTREE" add -A \
  || die_code "$EXIT_INTERNAL" "cannot snapshot the worktree's current state"
worktree_tree="$(GIT_INDEX_FILE="$wt_idx" git -C "$WORKTREE" write-tree)" \
  || die_code "$EXIT_INTERNAL" "cannot write the worktree snapshot tree"

# ─────────────────────────────────────────────────────────────────────────────
# tree_entry <tree> <path> — prints "<mode>\t<type>\t<sha>" for the tree
# entry at EXACTLY <path> in <tree> (`:(literal)` pathspec magic: a filename
# that happens to contain '*'/'?'/'[' is never treated as a glob), or
# nothing at all (and fails) if no such entry exists. NUL-terminated read of
# `ls-tree -z`, never trusting a quoted/munged rendering of the path (B1);
# the caller decides whether the mode is one it is willing to write (B2) —
# this helper only reports what is actually there.
#
# status_for <path> — the A/M/D... status `--name-status` recorded for an
# owned changed path (empty if, for some reason, absent).
# ─────────────────────────────────────────────────────────────────────────────

tree_entry() {
  local raw
  raw="$(git ls-tree -z "$1" -- ":(literal)$2" 2>/dev/null | tr '\0' '\n' | head -n 1)"
  [ -n "$raw" ] || return 1
  printf '%s\n' "$raw" | awk '{print $1"\t"$2"\t"$3}'
}

status_for() {
  awk -F '\t' -v p="$1" '$2 == p { print $1; exit }' "$owned_status_raw"
}

# ─────────────────────────────────────────────────────────────────────────────
# Path sets. --no-renames throughout: this tool's behaviour must not depend
# on the caller's diff.renames config, and a rename decomposing into a
# delete + an add is exactly what the path-by-path overlay below wants — no
# separate rename handling needed. Every list here is produced with `-c
# core.quotePath=false … -z` and immediately normalised to one real,
# unmunged path per line (B1) — filenames cannot contain NUL, so this is
# lossless for every path this tool is asked to support (a literal newline
# INSIDE a filename is the one byte this representation cannot carry; it is
# out of scope, exactly as for the rest of base/bin/'s line-oriented tools).
# ─────────────────────────────────────────────────────────────────────────────

all_changed="$WORK/all_changed"
owned_status_raw="$WORK/owned_status.raw"
owned_changed="$WORK/owned_changed"
dropped_changed="$WORK/dropped_changed"
tip_changed="$WORK/tip_changed"
overlap="$WORK/overlap"
overlap_conflict="$WORK/overlap_conflict"

git -c core.quotePath=false diff --no-renames --name-only -z "$cut_sha" "$worktree_tree" \
  | tr '\0' '\n' > "$all_changed" \
  || die_code "$EXIT_INTERNAL" "cannot diff the worktree snapshot against the cut point"

# The owned diff carries an A/M/D... status per path (N4: a destructive
# harvest — e.g. a rename whose destination fell outside the owned pathspec —
# must read as one, not as an ordinary modify). A pathspec syntax error (a
# bad ':()' magic token) is the one failure shape here that is entirely the
# caller's doing, so it maps to USAGE (2), not an internal failure.
owned_err="$WORK/owned.err"
if ! git -c core.quotePath=false diff --no-renames --name-status -z "$cut_sha" "$worktree_tree" \
       -- "${PATHSPECS[@]}" 2>"$owned_err" \
     | tr '\0' '\n' | paste -d '\t' - - > "$owned_status_raw"; then
  cat "$owned_err" >&2
  if grep -qi pathspec "$owned_err" 2>/dev/null; then
    die_code "$EXIT_USAGE" "malformed owned pathspec"
  else
    die_code "$EXIT_INTERNAL" "cannot diff the worktree snapshot against the cut point (owned pathspec)"
  fi
fi

awk -F '\t' 'NF >= 2 { print $2 }' "$owned_status_raw" | LC_ALL=C sort -u > "$owned_changed"
LC_ALL=C sort -u "$all_changed" -o "$all_changed"
comm -23 "$all_changed" "$owned_changed" > "$dropped_changed"

# ─────────────────────────────────────────────────────────────────────────────
# Report + JSON emitters
# ─────────────────────────────────────────────────────────────────────────────

print_report() {
  local commit_sha="$1" discarded_flag="$2" verdict="$3"
  local n_harvested n_dropped

  n_harvested="$(nlines "$owned_changed")"
  n_dropped="$(nlines "$dropped_changed")"

  {
    printf 'INSPIRE harvest — %s -> %s (%s)\n' "$WORKTREE" "$BRANCH" "$verdict"

    printf '\nHARVESTED (%s)\n' "$n_harvested"
    if [ "$n_harvested" -gt 0 ]; then
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        printf '  %s %s\n' "$(status_for "$p")" "$p"
      done < "$owned_changed"
    else
      printf '  (none)\n'
    fi

    printf '\nDROPPED (%s)\n' "$n_dropped"
    if [ "$n_dropped" -gt 0 ]; then
      sed 's/^/  /' "$dropped_changed"
      printf '  outside the owned pathspec — never staged, never committed.\n'
    else
      printf '  (none)\n'
    fi

    if [ -n "$commit_sha" ]; then
      printf '\nCOMMIT  %s onto %s\n' "$commit_sha" "$BRANCH"
    else
      printf '\nCOMMIT  none\n'
    fi
    if [ "$discarded_flag" = true ]; then
      if [ -n "$wt_branch" ]; then
        printf 'DISCARD worktree + branch removed\n'
      else
        printf 'DISCARD worktree removed (detached HEAD — no branch to remove)\n'
      fi
    fi
  } >&2
}

emit_json() {
  local commit_sha="$1" discarded_flag="$2"
  local commit_json harvested_json dropped_json harvested_status_json
  if [ -n "$commit_sha" ]; then commit_json="\"$commit_sha\""; else commit_json="null"; fi
  harvested_json="$(jq -R -s 'split("\n") | map(select(length > 0))' "$owned_changed")"
  dropped_json="$(jq -R -s 'split("\n") | map(select(length > 0))' "$dropped_changed")"
  harvested_status_json="$(jq -R -s '
      split("\n") | map(select(length > 0)) | map(split("\t"))
      | map({(.[1]): .[0]}) | add // {}
    ' "$owned_status_raw")"
  jq -n \
    --argjson commit "$commit_json" \
    --arg branch "$BRANCH" \
    --argjson harvested "$harvested_json" \
    --argjson harvested_status "$harvested_status_json" \
    --argjson dropped "$dropped_json" \
    --argjson discarded "$discarded_flag" \
    '{commit: $commit, branch: $branch, harvested: $harvested, harvested_status: $harvested_status, dropped: $dropped, discarded: $discarded}'
}

# ─────────────────────────────────────────────────────────────────────────────
# Nothing to harvest (empty diff) — a normal outcome, not a failure.
# Reported regardless: the dropped list on an empty owned diff is itself the
# signal (a tester phase that touched zero tests but touched source, say).
# ─────────────────────────────────────────────────────────────────────────────

if [ ! -s "$owned_changed" ]; then
  print_report "" false "nothing to harvest"
  emit_json "" false
  exit "$EXIT_EMPTY"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Atomicity: has the integration branch itself touched any owned path since
# the cut? An intersecting path is only a REAL conflict if its content
# actually differs between the worktree snapshot and the tip — if the exact
# same content is already on the tip (a previous harvest of this same
# change, or the same content landing some other way), re-harvesting it is
# idempotent, not a conflict (N3). Refs are untouched up to this point
# either way.
# ─────────────────────────────────────────────────────────────────────────────

git -c core.quotePath=false diff --no-renames --name-only -z "$cut_sha" "$old_tip" \
  | tr '\0' '\n' > "$tip_changed" \
  || die_code "$EXIT_INTERNAL" "cannot diff the integration branch against the cut point"
LC_ALL=C sort -u "$tip_changed" -o "$tip_changed"

comm -12 "$owned_changed" "$tip_changed" > "$overlap"

: > "$overlap_conflict"
if [ -s "$overlap" ]; then
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    wt_entry="$(tree_entry "$worktree_tree" "$path")" || wt_entry=""
    tip_entry="$(tree_entry "$old_tip" "$path")" || tip_entry=""
    [ "$wt_entry" = "$tip_entry" ] || printf '%s\n' "$path" >> "$overlap_conflict"
  done < "$overlap"
fi

if [ -s "$overlap_conflict" ]; then
  {
    printf 'INSPIRE harvest — %s -> %s (conflict)\n' "$WORKTREE" "$BRANCH"
    printf '\n%s has moved since the cut and independently touched:\n' "$BRANCH"
    sed 's/^/  /' "$overlap_conflict"
    printf '  refusing — every ref is left exactly as found.\n'
  } >&2
  exit "$EXIT_CONFLICT"
fi

# Every owned change already present on the tip, byte for byte: nothing to
# do, and NOT an error — same exit code as the plain empty-diff case (N3).
n_owned="$(nlines "$owned_changed")"
n_overlap="$(nlines "$overlap")"
if [ "$n_overlap" -gt 0 ] && [ "$n_overlap" -eq "$n_owned" ]; then
  print_report "" false "nothing to harvest — already on $BRANCH"
  emit_json "" false
  exit "$EXIT_EMPTY"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Plan mode stops here: every check above already ran, so the verdict is the
# same one act mode would reach. Nothing further is written.
# ─────────────────────────────────────────────────────────────────────────────

if [ "$MODE" = "plan" ]; then
  print_report "" false "plan — would apply cleanly, nothing written"
  emit_json "" false
  exit "$EXIT_OK"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Act mode: overlay the owned changed paths from the worktree snapshot onto
# the integration branch's current tip, in a private index, then commit.
# ─────────────────────────────────────────────────────────────────────────────

tip_idx="$WORK/tip.index"
GIT_INDEX_FILE="$tip_idx" git read-tree "$old_tip" \
  || die_code "$EXIT_INTERNAL" "cannot seed the new-commit index from $BRANCH"

while IFS= read -r path; do
  [ -n "$path" ] || continue
  if entry="$(tree_entry "$worktree_tree" "$path")"; then
    mode_bits="${entry%%$'\t'*}"
    rest="${entry#*$'\t'}"
    blob_sha="${rest#*$'\t'}"
    case "$mode_bits" in
      100644|100755|120000|160000) ;;
      *)
        die_code "$EXIT_TYPE_CONFLICT" "owned path changed kind in the worktree snapshot: $path is now tree-mode $mode_bits, not a blob/symlink/gitlink (a file replaced by a same-named directory, or vice versa) — refusing to fabricate a tree entry; every ref is left exactly as found" ;;
    esac
    GIT_INDEX_FILE="$tip_idx" git update-index --add --cacheinfo "$mode_bits,$blob_sha,$path" \
      || die_code "$EXIT_INTERNAL" "cannot stage $path"
  else
    GIT_INDEX_FILE="$tip_idx" git update-index --force-remove "$path" >/dev/null 2>&1 || true
  fi
done < "$owned_changed"

new_tree="$(GIT_INDEX_FILE="$tip_idx" git write-tree)" \
  || die_code "$EXIT_INTERNAL" "cannot write the new tree"

src_desc="${wt_branch:-<detached@${wt_head}>}"
commit_msg="$(cat <<EOF
emanate: harvest ${LABEL}

phase:    ${LABEL}
source:   ${src_desc}@${wt_head} (worktree: ${WORKTREE})
onto:     ${BRANCH}@${old_tip}
pathspec: ${PATHSPECS[*]}
EOF
)"

new_commit="$(git commit-tree "$new_tree" -p "$old_tip" -m "$commit_msg")" \
  || die_code "$EXIT_INTERNAL" "cannot create the harvest commit object"

git update-ref "refs/heads/$BRANCH" "$new_commit" "$old_tip" \
  || die_code "$EXIT_CONFLICT" "refs/heads/$BRANCH moved concurrently — refusing (compare-and-swap failed); every ref is left exactly as found"

discarded=false
if [ "$DISCARD" = 1 ]; then
  if [ -n "$wt_branch" ] && [ "$wt_branch" = "$BRANCH" ]; then
    echo "emanate-harvest.sh: warning: commit $new_commit landed, but --discard was refused — $WORKTREE holds $BRANCH itself (the integration branch just committed to); removing it would delete that branch. Worktree and branch left in place." >&2
  elif git worktree remove --force "$WORKTREE" 2>/dev/null; then
    [ -z "$wt_branch" ] || git branch -D "$wt_branch" >/dev/null 2>&1
    discarded=true
  else
    echo "emanate-harvest.sh: warning: commit $new_commit landed, but the worktree/branch removal failed — left in place" >&2
  fi
fi

print_report "$new_commit" "$discarded" "harvested"
emit_json "$new_commit" "$discarded"
exit "$EXIT_OK"
