#!/usr/bin/env bash
# The agents payload class - base/agents/ -> .claude/agents/ (0.9).
# Moved from test-upgrade.sh:1961-2153.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/merge.sh"
. "$HERE/lib/upgrade-helpers.sh"

base="$PLUGIN_ROOT/base"
MAP_03="$(layout_map "$PLUGIN_ROOT" 0.3)"
MAP_PRE="$(layout_map "$PLUGIN_ROOT" pre-0.3)"
MZ="$PLUGIN_ROOT/scripts/materialize.sh"

# ---------------------------------------------------------------------------
# The agents payload class — base/agents/ → .claude/agents/ (0.9)
#
# ADDITIVE, so it extends the 0.3 layout row's dest_map instead of minting a
# `0.9` layout id: an additive class moves nothing and changes no tree SHAPE, a
# second id could only reuse 0.3's own markers (undiscriminable by
# verify_layout), and any score tie between the two manifests would then be the
# CROSS-LAYOUT tie detect_version refuses outright rather than the intra-layout
# one it resolves to the higher version. The whole argument lives in
# scripts/hops/layouts.tsv; this block is the coverage it needs.
#
# No 0.9.0 hop exists, and none should: a hop's absence is the no-op (lib/chain.sh).
# ---------------------------------------------------------------------------

# --- the table itself ------------------------------------------------------
# layouts.tsv's header explains what an empty column costs: bash collapses runs
# of tabs in `read`, so dest_map would be read as must_not_exist, layout_map
# would return empty, and an upgrade would classify nothing, move nothing and
# still rewrite the lock — a silent no-op claiming success. `read` cannot see
# that; awk counts fields, so it can.
LT="$PLUGIN_ROOT/scripts/hops/layouts.tsv"
lt_rows="$(awk -F'\t' '!/^#/ && NF' "$LT" | wc -l | tr -d ' ')"
check "layout table: it has rows at all, so the guard below cannot pass vacuously" \
  "[ '$lt_rows' -ge 2 ]"
lt_bad="$(awk -F'\t' '!/^#/ && NF { if (NF != 4 || $1 == "" || $2 == "" || $3 == "" || $4 == "") printf "%s ", $1 }' "$LT")"
eq "layout table: every row has four non-empty columns" "$lt_bad" ""

map03_agents="$(layout_map "$PLUGIN_ROOT" 0.3 | tr ' ' '\n' | grep '^agents:')"
eq "layout table: the 0.3 map carries the agents class" \
   "$map03_agents" "agents:.claude/agents"
mappre_agents="$(layout_map "$PLUGIN_ROOT" pre-0.3 | tr ' ' '\n' | grep -c '^agents:' | tr -d ' ')"
eq "layout table: pre-0.3 has none — that layout never materialized agents" \
   "$mappre_agents" "0"

# THE PROOF OBLIGATION behind reusing the row: a dest added to an existing
# layout may not shadow another dest in either direction, or _middle would start
# translating paths it never translated before — which is precisely how a past
# version's manifest would begin to mean something new.
dest_overlap=""
for _a in $MAP_03; do
  for _b in $MAP_03; do
    [ "$_a" = "$_b" ] && continue
    _da="${_a#*:}"; _db="${_b#*:}"
    case "$_db" in "$_da"/*) dest_overlap="$dest_overlap $_da<$_db" ;; esac
  done
done
eq "layout table: the 0.3 dest roots are pairwise non-overlapping" "$dest_overlap" ""

eq "_middle: a project agents path resolves to its base/ middle" \
   "$(_middle "$MAP_03" ".claude/agents/README.txt")" "agents/README.txt"
eq "_from_middle: and back again" \
   "$(_from_middle "$MAP_03" "agents/README.txt")" ".claude/agents/README.txt"
eq "_middle: no pre-0.3 layout claims an agents path" \
   "$(_middle "$MAP_PRE" ".claude/agents/README.txt"; printf 'rc=%s' "$?")" "rc=1"

# --- the signature is indifferent to the class -----------------------------
# An operator may create or delete .claude/agents/ freely, so neither state may
# ever block an upgrade. This is also why the class could not have become a
# structural marker even if we had wanted one.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.7.0 "$w" "$REPO")"
check "premise: the v0.7.0 fixture has no .claude/agents — the class postdates it" \
  "[ ! -e '$p/.claude/agents' ]"
verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "verify_layout: a 0.3 tree with no .claude/agents verifies" "$?" "0"
mkdir -p "$p/.claude/agents"; printf 'mine\n' > "$p/.claude/agents/mine.md"
verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "verify_layout: and one that already has it verifies too" "$?" "0"

# --- classify: creation, and the operator's own files ----------------------
check "premise: the plugin really ships base/agents/README.txt" \
  "[ -f '$base/agents/README.txt' ]"
agv="$(mktemp)"
classify "$PLUGIN_ROOT/manifests/0.7.0.json" "$p" "$base" "$MAP_03" "$MAP_03" > "$agv"
agv_txt="$(cat "$agv")"
eq "classify: the shipped agent payload is a create on a 0.7 tree" \
   "$(verdict_for "$agv_txt" ".claude/agents/README.txt")" "create"
eq "classify: the operator's own agent file is kept" \
   "$(verdict_for "$agv_txt" ".claude/agents/mine.md")" "keep"
eq "classify: and the reason names them as its author" \
   "$(detail_for "$agv_txt" ".claude/agents/mine.md")" "yours — INSPIRE never shipped this"

# A file of theirs sitting exactly where we ship one asks; it is never a create.
printf 'not ours\n' > "$p/.claude/agents/README.txt"
classify "$PLUGIN_ROOT/manifests/0.7.0.json" "$p" "$base" "$MAP_03" "$MAP_03" > "$agv"
agv_txt="$(cat "$agv")"
eq "classify: a collision at a shipped agent path asks" \
   "$(verdict_for "$agv_txt" ".claude/agents/README.txt")" "ask"
agks="$(mktemp)"; keepset_of "$agv" "$p" > "$agks"
apply_base "$agks" "$PLUGIN_ROOT/manifests/0.7.0.json" "$p" "$base" "$MAP_03" "$MAP_03" 0
eq "apply_base: an unresolved collision leaves their bytes alone" \
   "$(cat "$p/.claude/agents/README.txt")" "not ours"
eq "apply_base: and their unshipped agent file too" \
   "$(cat "$p/.claude/agents/mine.md")" "mine"
rm -f "$agv" "$agks"
fixture_cleanup "$w"

# --- classify: an operator-edited SHIPPED agent file -----------------------
# The never-clobber posture must be the skills' posture exactly. No released
# manifest lists an agents path yet, so the source baseline is synthesized: the
# smallest manifest that claims we shipped this file, with the hash we ship today.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.7.0 "$w" "$REPO")"
mkdir -p "$p/.claude/agents"
cp "$base/agents/README.txt" "$p/.claude/agents/README.txt"
ag_synth="$(mktemp)"
jq -n --arg h "$(sha256_of "$base/agents/README.txt")" \
  '{version:"0.7.9", released:"2026-01-01", commit:"synthetic", layout:"0.3",
    files:{".claude/agents/README.txt": $h}}' > "$ag_synth"
agv="$(mktemp)"
classify "$ag_synth" "$p" "$base" "$MAP_03" "$MAP_03" > "$agv"
eq "classify: an untouched shipped agent file is a noop" \
   "$(verdict_for "$(cat "$agv")" ".claude/agents/README.txt")" "noop"

printf 'MY EDIT\n' >> "$p/.claude/agents/README.txt"
ag_edit="$(sha256_of "$p/.claude/agents/README.txt")"
classify "$ag_synth" "$p" "$base" "$MAP_03" "$MAP_03" > "$agv"
agv_txt="$(cat "$agv")"
eq "classify: an operator-edited shipped agent file is kept, not replaced" \
   "$(verdict_for "$agv_txt" ".claude/agents/README.txt")" "keep"
eq "classify: with the skills' own reason" \
   "$(detail_for "$agv_txt" ".claude/agents/README.txt")" "you changed it, we did not"
agks="$(mktemp)"; keepset_of "$agv" "$p" > "$agks"
apply_base "$agks" "$ag_synth" "$p" "$base" "$MAP_03" "$MAP_03" 0
eq "apply_base: the edit survives the apply" \
   "$(sha256_of "$p/.claude/agents/README.txt")" "$ag_edit"

# Both sides changed it, differently → the one prompt, same as a skill.
ag_synth2="$(mktemp)"
jq -n '{version:"0.7.9", released:"2026-01-01", commit:"synthetic", layout:"0.3",
        files:{".claude/agents/README.txt":
               "0000000000000000000000000000000000000000000000000000000000000000"}}' > "$ag_synth2"
classify "$ag_synth2" "$p" "$base" "$MAP_03" "$MAP_03" > "$agv"
eq "classify: both sides changed a shipped agent file → ask" \
   "$(verdict_for "$(cat "$agv")" ".claude/agents/README.txt")" "ask"
rm -f "$agv" "$agks" "$ag_synth" "$ag_synth2"
fixture_cleanup "$w"

# --- detection, and the tie that must never happen -------------------------
# THE DISCRIMINATOR PARADOX, tested rather than argued: a 0.7 tree and a 0.7
# tree carrying the class have identical structure, so if the class had its own
# layout id, a project matching both manifests equally would be refused outright.
# Under one layout there is nothing to refuse.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.7.0 "$w" "$REPO")"
ag_det_err="$(detect_version "$PLUGIN_ROOT" "$p" "" 2>&1 >/dev/null)"
eq "detection: a v0.7.0 fixture is nominated 0.7.0" \
   "$(detect_version "$PLUGIN_ROOT" "$p" "" 2>/dev/null | cut -f1)" "0.7.0"
check "detection: nothing was refused for spanning layouts" \
  "! printf '%s' \"\$ag_det_err\" | grep -qi 'different layouts'"

mkdir -p "$p/.claude/agents"; printf 'mine\n' > "$p/.claude/agents/mine.md"
eq "detection: an operator's own .claude/agents does not move the verdict" \
   "$(detect_version "$PLUGIN_ROOT" "$p" "" 2>/dev/null | cut -f1)" "0.7.0"

# --mode plan must still write nothing — the new directory included.
ag_plan_f="$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
ag_plan_d="$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"
bash "$MZ" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "plan: a tree with the class in its future exits 0" "$?" "0"
eq "plan: wrote no file" "$ag_plan_f" \
   "$(cd "$p" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "plan: created no directory either" "$ag_plan_d" \
   "$(cd "$p" && find . -type d | LC_ALL=C sort | shasum -a 256)"
check "plan: their .claude/agents holds nothing but their file" \
  "[ \"\$(ls -A '$p/.claude/agents' | tr '\n' ' ')\" = 'mine.md ' ]"

bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "a 0.7 tree with a pre-existing .claude/agents upgrades" "$?" "0"
eq "the operator's agent file is untouched by the upgrade" \
   "$(cat "$p/.claude/agents/mine.md")" "mine"
check "and the class landed beside it" "[ -f '$p/.claude/agents/README.txt' ]"
ag_redet_err="$(detect_version "$PLUGIN_ROOT" "$p" "0.7.0" 2>&1 >/dev/null)"
detect_version "$PLUGIN_ROOT" "$p" "0.7.0" >/dev/null 2>&1
eq "re-detection after the upgrade still resolves to one version" "$?" "0"
check "re-detection refused nothing for spanning layouts" \
  "! printf '%s' \"\$ag_redet_err\" | grep -qi 'different layouts'"
fixture_cleanup "$w"

# --- a pre-0.3 project reaches the class through the TARGET map ------------
# Its own layout has no agents entry; classify's pass 2 and apply_base's pass 1
# both walk the target map, so the class arrives as a plain create across the
# longest chain there is.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.1.0 "$w" "$REPO")"
check "premise: a 0.1.0 fixture has no .claude/agents" "[ ! -e '$p/.claude/agents' ]"
bash "$MZ" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$p" >/dev/null 2>&1
eq "0.1.0 → current still exits 0 with the class in the target map" "$?" "0"
check "the class landed after the longest chain" \
  "[ -f '$p/.claude/agents/README.txt' ]"
eq "and it is byte-identical to what the plugin ships" \
   "$(sha256_of "$p/.claude/agents/README.txt")" "$(sha256_of "$base/agents/README.txt")"
fixture_cleanup "$w"

echo ""; echo "Passed: $pass · Failed: $fail · Skipped: $skip"
[ "$fail" -eq 0 ]

summary
