#!/usr/bin/env bash
# The three-way classifier, including pass-2 collisions and staleness.
# Moved from test-upgrade.sh:652-797.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$HERE/lib/upgrade-helpers.sh"

# ---- the three-way classifier -------------------------------------------
. "$PLUGIN_ROOT/scripts/lib/merge.sh"
MAP_03="$(layout_map "$PLUGIN_ROOT" 0.3)"
MAP_PRE="$(layout_map "$PLUGIN_ROOT" pre-0.3)"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
mf="$PLUGIN_ROOT/manifests/0.3.1.json"
base="$PLUGIN_ROOT/base"


# Row: they didn't change it, we didn't change it → noop.
# Row: they changed it, we didn't → keep.
printf '\nMY EDIT\n' >> "$p/.inspire/bin/no-todos.sh"
# Row: they deleted an owned file → restore.
rm -f "$p/.inspire/bin/acyclic-deps.sh"
# Row: project-authored file inside an owned dir → keep. THE rm -rf REGRESSION.
printf 'go rules\n' > "$p/.claude/skills/inspire-code/references/go-best-practices.md"
# Row: project-authored files whose NAMES CONTAIN A TAB. Pass 3 is the one pass
# that walks the operator's own file names, and the classifier's row files are
# tab-separated: the first shape of the batched pass 3 wrote `<rel>\t<flag>` and
# read `$1`, which cut such a name at its tab, read the remainder as the exclusion
# flag — a remainder of exactly `1` DROPPED the keep row — and collapsed the
# truncated duplicates through the seen set. Two names, one whose tail is `1` and
# one whose tail is not, so both halves of that failure are covered.
tab_a=".claude/skills/$(printf 'tab\t1')"
tab_b=".claude/skills/$(printf 'tab\t1.md')"
printf 'operator, tab-named\n' > "$p/$tab_a"
printf 'operator, tab-named\n' > "$p/$tab_b"

# ---- pass 2 collision: base ships a target the SOURCE manifest never listed
# (merge.sh:161-184). Eligibility mirrors the no-op-row selection below, but
# against pass 2's own test — a base/-shipped, non-excluded file whose target
# path is absent from mf's `files` map — rather than pass 1's already-shipped
# set. Picked at runtime: hardcoding one path goes stale the moment an
# intervening manifest ships it, a fact about releases, not the classifier.
collision_candidates=""
for pair in $MAP_03; do
  cname="${pair%%:*}"; cdest="${pair#*:}"
  [ -d "$base/$cname" ] || continue
  while IFS= read -r cabs; do
    crel="${cabs#"$base/$cname"/}"
    _base_excluded "$cname" "$crel" && continue
    ctgt="$cdest/$crel"
    jq -e --arg t "$ctgt" '.files | has($t)' "$mf" >/dev/null 2>&1 && continue
    [ -e "$p/$ctgt" ] && continue
    collision_candidates="$collision_candidates
$ctgt"
  done < <(find "$base/$cname" -type f)
done
collision_candidates="$(printf '%s\n' "$collision_candidates" | awk 'NF' | LC_ALL=C sort -u)"
check "at least two pass-2 collision candidates exist (base ships a target 0.3.1 never listed)" \
   "[ \"\$(printf '%s\n' \"\$collision_candidates\" | awk 'NF' | wc -l | tr -d ' ')\" -ge 2 ]"
ask_path="$(printf '%s\n' "$collision_candidates" | sed -n '1p')"
noop2_path="$(printf '%s\n' "$collision_candidates" | sed -n '2p')"

# Row: base ships it, 0.3.1 never did, operator already has a DIFFERENT file
# there → ask (merge.sh:178), with its exact wording.
mkdir -p "$(dirname "$p/$ask_path")"
printf 'operator content, deliberately different from base\n' > "$p/$ask_path"
# Row: same shape, but the operator's copy is byte-identical to base's → noop
# (merge.sh:176).
noop2_src="$(_base_src "$base" "$MAP_03" "$noop2_path")"
mkdir -p "$(dirname "$p/$noop2_path")"
cp "$noop2_src" "$p/$noop2_path"

before="$(tree_print "$p")"
out="$(classify "$mf" "$p" "$base" "$MAP_03" "$MAP_03")"
after="$(tree_print "$p")"

# The no-op row needs a file that is pristine on all three sides at once: the
# project's copy matches the manifest AND base/ still ships it byte-identical.
# Naming one goes red the moment a release edits that particular file — a true
# statement about the release, reported as a false statement about the
# classifier. So the file is picked at run time, and the run says loudly when no
# candidate is left rather than asserting on nothing.
noop_path=""
while IFS="$(printf '\t')" read -r cand mhash; do
  [ -n "$cand" ] && [ -n "$mhash" ] || continue
  [ -f "$p/$cand" ] || continue
  csrc="$(_base_src "$base" "$MAP_03" "$cand")" || continue
  [ -n "$csrc" ] || continue
  [ "$(sha256_of "$p/$cand")" = "$mhash" ] || continue
  [ "$(sha256_of "$csrc")" = "$mhash" ] || continue
  noop_path="$cand"
  break
done < <(jq -r '.files | to_entries[] | "\(.key)\t\(.value)"' "$mf")
check "the no-op row found a manifest-pristine file to assert on" \
   "[ -n '$noop_path' ]"
eq "unmodified file is a no-op" \
   "$(verdict_for "$out" "$noop_path")" "noop"
eq "operator edit is kept" \
   "$(verdict_for "$out" .inspire/bin/no-todos.sh)" "keep"
eq "operator deletion is restored" \
   "$(verdict_for "$out" .inspire/bin/acyclic-deps.sh)" "restore"
eq "project-authored file is kept" \
   "$(verdict_for "$out" .claude/skills/inspire-code/references/go-best-practices.md)" "keep"
# Full-line match, not verdict_for: that helper compares $2, which is itself only
# the first tab-separated segment of a tab-named path. The whole row must be
# present, once per file, carrying the complete name.
tab_row_a="$(printf 'keep\t%s\tyours — INSPIRE never shipped this' "$tab_a")"
tab_row_b="$(printf 'keep\t%s\tyours — INSPIRE never shipped this' "$tab_b")"
check "a TAB in an operator file's name survives pass 3 whole, one row each" \
   "[ \"\$(printf '%s\n' \"\$out\" | grep -Fxc \"\$tab_row_a\")\" = 1 ] \
    && [ \"\$(printf '%s\n' \"\$out\" | grep -Fxc \"\$tab_row_b\")\" = 1 ]"
eq "pass-2 collision: a different operator file at an unshipped-in-source target asks" \
   "$(verdict_for "$out" "$ask_path")" "ask"
eq "pass-2 collision: ask detail matches merge.sh's exact wording" \
   "$(detail_for "$out" "$ask_path")" "new in this release, and you already have a different file here"
eq "pass-2 collision: a byte-identical operator file at a second unshipped target is a no-op" \
   "$(verdict_for "$out" "$noop2_path")" "noop"
check "classify wrote nothing" "[ -f '$p/.inspire/bin/no-todos.sh' ]"
check "classify did not restore anything itself" \
   "[ ! -e '$p/.inspire/bin/acyclic-deps.sh' ]"
eq "classify left the whole tree byte-identical" "$before" "$after"

# keepset_of: hashes, not paths — every keep plus every unresolved ask.
vf="$w/verdicts.tsv"; printf '%s\n' "$out" > "$vf"
ks="$(keepset_of "$vf" "$p")"
check "keepset carries the operator's edited validator" \
   "printf '%s\n' \"\$ks\" | grep -Fxq \"\$(sha256_of '$p/.inspire/bin/no-todos.sh')\""
check "keepset carries the project-authored file" \
   "printf '%s\n' \"\$ks\" | grep -Fxq \"\$(sha256_of '$p/.claude/skills/inspire-code/references/go-best-practices.md')\""
check "keepset does not carry a shipped file the operator did not touch" \
   "! printf '%s\n' \"\$ks\" | grep -Fxq \"\$(sha256_of '$p/.inspire/bin/review.sh')\""
check "keepset carries the operator's differing file from the pass-2 collision (ask defaults to keep)" \
   "printf '%s\n' \"\$ks\" | grep -Fxq \"\$(sha256_of '$p/$ask_path')\""
check "keepset is deduplicated and hash-shaped" \
   "[ -z \"\$(printf '%s\n' \"\$ks\" | grep -vE '^[0-9a-f]{64}\$')\" ]"
fixture_cleanup "$w"

# --- staleness and conflict, on a PRE-0.3 source -------------------------
# NOTE: do not use a 0.3.0 fixture for staleness. plugin/base/ is byte-identical
# between 0.3.0 and 0.3.1 (the hotfix touched only materialize.sh, the skills
# and the tests), so a 0.3.0 project has NOTHING stale and the assertion would
# fail for a reason unrelated to the code. 0.2.1's base genuinely differs.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
mf21="$PLUGIN_ROOT/manifests/0.2.1.json"
out="$(classify "$mf21" "$p" "$base" "$MAP_PRE" "$MAP_03")"

check "a pre-0.3 source finds its base counterparts (nothing wholesale-deleted)" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"delete\" && \$2 !~ /^\.claude\/bin\/test\//' | wc -l | tr -d ' ')\" -lt 20 ]"
check "the validator set is NOT mass-classified as delete" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"delete\" && \$2 ~ /^\.claude\/bin\/[^\/]*\$/' | wc -l | tr -d ' ')\" = 0 ]"
check "at least one untouched-but-stale file is replaced" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"replace\"' | wc -l | tr -d ' ')\" -ge 1 ]"
check "the dropped bin/test fixtures are recognised as ours to delete" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"delete\" && \$2 ~ /^\.claude\/bin\/test\//' | wc -l | tr -d ' ')\" = 114 ]"
check "a file that only MOVED is not reported as a creation" \
   "[ \"\$(printf '%s' \"\$out\" | awk -F'\t' '\$1==\"create\" && \$2==\".inspire/bin/review.sh\"' | wc -l | tr -d ' ')\" = 0 ]"

# A genuine conflict: they edited a file that also changed upstream.
stale="$(printf '%s' "$out" | awk -F'\t' '$1=="replace"{print $2; exit}')"
check "a stale path was found to conflict on" "[ -n '$stale' ]"
printf '\nMY EDIT\n' >> "$p/$stale"
out2="$(classify "$mf21" "$p" "$base" "$MAP_PRE" "$MAP_03")"
eq "both-changed is a conflict" "$(verdict_for "$out2" "$stale")" "ask"
fixture_cleanup "$w"

summary
