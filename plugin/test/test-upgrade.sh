#!/usr/bin/env bash
# Tests the upgrade path: detection, layout signatures, hop ops, the chain,
# the three-way merge, and end-to-end chains.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# ---- detection ----------------------------------------------------------
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"

eq "detect 0.2.1 from a clean fixture" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

rm -f "$p/.inspire.lock"
eq "detect 0.2.1 with no lock at all" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

jq -n '{inspire_version:"0.3.1",released:"x",template_sha:"x",installed_at:"x"}' \
  > "$p/.inspire.lock"
eq "detect ignores a lying lock" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"

# Local edits must not change the nomination.
printf '\nLOCAL EDIT\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
rm -f "$p/.claude/bin/no-todos.sh"
eq "detect survives operator edits and deletions" \
   "$(detect_version "$PLUGIN_ROOT" "$p" 2>/dev/null | cut -f1)" "0.2.1"
fixture_cleanup "$w"

# A tree with nothing of ours in it cannot be nominated.
empty="$(mktemp -d)"; ( cd "$empty" && git init -q )
detect_version "$PLUGIN_ROOT" "$empty" >/dev/null 2>&1; rc=$?
eq "detect refuses an unrecognisable tree" "$rc" "1"
rm -rf "$empty"

# ---- N-way tie bookkeeping (Task 5 review findings) ---------------------
# A single min/max pair can only ever remember one runner-up, so a 3+-way tie
# would silently drop all but one contender. Build synthetic manifests in a
# scratch plugin_root — plugin/manifests/ is never touched.
tie_w="$(mktemp -d)"
tie_plugin="$tie_w/plugin"; mkdir -p "$tie_plugin/manifests"
tie_proj="$tie_w/proj"; mkdir -p "$tie_proj"
printf 'shared\n' > "$tie_proj/shared.txt"
tie_h="$(sha256_of "$tie_proj/shared.txt")"

# Three candidates, all scoring 100%, spanning two DIFFERENT layouts (A, A, B).
jq -n --arg h "$tie_h" '{version:"1.0.0",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.0.0.json"
jq -n --arg h "$tie_h" '{version:"1.0.1",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.0.1.json"
jq -n --arg h "$tie_h" '{version:"2.0.0",released:"x",commit:"x",layout:"B",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/2.0.0.json"

tie_err="$(detect_version "$tie_plugin" "$tie_proj" 2>&1 >/dev/null)"; tie_rc=$?
eq "N-way cross-layout tie is refused (rc)" "$tie_rc" "1"
check "N-way cross-layout tie mentions all three candidates" \
  "printf '%s' \"\$tie_err\" | grep -q '1.0.0' && printf '%s' \"\$tie_err\" | grep -q '1.0.1' && printf '%s' \"\$tie_err\" | grep -q '2.0.0'"

# Same three-candidate shape, but all SAME layout: must still resolve, to the
# highest version — a same-layout tie is the normal, safe case.
rm -f "$tie_plugin/manifests/2.0.0.json"
jq -n --arg h "$tie_h" '{version:"1.5.0",released:"x",commit:"x",layout:"A",files:{"shared.txt":$h}}' \
  > "$tie_plugin/manifests/1.5.0.json"
eq "N-way same-layout tie resolves to the highest version" \
  "$(detect_version "$tie_plugin" "$tie_proj" 2>/dev/null | cut -f1)" "1.5.0"
fixture_cleanup "$tie_w"

# ---- empty-array expansion under bash 3.2 + set -u -----------------------
# manifest_versions yielding nothing (no manifests present, no lock hint)
# must not crash the calling script with an unbound-variable error — it must
# return the documented rc=1.
noman_w="$(mktemp -d)"
noman_plugin="$noman_w/plugin"; mkdir -p "$noman_plugin/manifests"
noman_proj="$noman_w/proj"; mkdir -p "$noman_proj"
noman_err="$(detect_version "$noman_plugin" "$noman_proj" 2>&1 >/dev/null)"; noman_rc=$?
eq "empty manifests dir returns rc=1, not a crash" "$noman_rc" "1"
check "empty manifests dir does not raise an unbound-variable error" \
  "! printf '%s' \"\$noman_err\" | grep -qi 'unbound variable'"
fixture_cleanup "$noman_w"

# ---- layout signatures --------------------------------------------------
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "0.2.1 tree satisfies the pre-0.3 signature" "$?" "0"

verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.2.1 tree fails the 0.3 signature" "$?" "1"

# Half-migrated by hand: both KB roots present. We cannot tell which is live.
mkdir -p "$p/inspire_kb"
out="$(verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 2>&1)"; rc=$?
eq "half-migrated tree is refused" "$rc" "1"
check "refusal explains the ambiguity" \
  "printf '%s' \"\$out\" | grep -qi 'inspire_kb'"
fixture_cleanup "$w"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.3.1 tree satisfies the 0.3 signature" "$?" "0"
fixture_cleanup "$w"

verify_layout "$PLUGIN_ROOT" "$p" no-such-layout >/dev/null 2>&1
eq "unknown layout id is refused" "$?" "1"

eq "layout_map for pre-0.3 puts bin under .claude" \
   "$(layout_map "$PLUGIN_ROOT" pre-0.3)" \
   "bin:.claude/bin hooks:.claude/hooks skills:.claude/skills"
eq "layout_map for 0.3 puts bin under .inspire" \
   "$(layout_map "$PLUGIN_ROOT" 0.3)" \
   "bin:.inspire/bin hooks:.claude/inspire/hooks skills:.claude/skills"
layout_map "$PLUGIN_ROOT" no-such-layout >/dev/null 2>&1
eq "layout_map refuses an unknown layout" "$?" "1"

# ---- fix round 1: .claude/bin & .claude/hooks are not INSPIRE-exclusive ---
# `.claude/bin`/`.claude/hooks` are ordinary Claude Code locations an operator
# may legitimately keep their own content in — including, after an INSPIRE-
# performed 0.3.0 hop, leftover foreign entries the hop deliberately never
# touches (it only ever removes entries IT owns). Neither may appear in a
# signature's must_not_exist list; the KB root plus the INSPIRE-exclusive
# .claude/inspire/hooks namespace are the only safe discriminators. This
# section is permanent regression coverage for that finding.

# Direction: a 0.3 fixture must also FAIL the pre-0.3 signature.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.3.1 "$w" "$REPO")"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "0.3.1 tree fails the pre-0.3 signature" "$?" "1"

# The regression itself: operator-owned content under .claude/bin and
# .claude/hooks on an otherwise-clean 0.3 tree must not flip the outcome.
mkdir -p "$p/.claude/hooks" "$p/.claude/bin"
printf '#!/usr/bin/env bash\necho mine\n' > "$p/.claude/hooks/my-own-hook.sh"
printf '#!/usr/bin/env bash\necho mine\n' > "$p/.claude/bin/my-tool.sh"
verify_layout "$PLUGIN_ROOT" "$p" 0.3 >/dev/null 2>&1
eq "0.3 tree with operator's own .claude/hooks and .claude/bin still passes 0.3" "$?" "0"

# Half-migrated the other direction: both KB roots present, checked against
# the 0.3 signature this time — must also be refused as ambiguous, naming
# the offending path.
mkdir -p "$p/.inspire_kb"
out="$(verify_layout "$PLUGIN_ROOT" "$p" 0.3 2>&1)"; rc=$?
eq "half-migrated tree is refused against the 0.3 signature too" "$rc" "1"
check "0.3-side refusal explains the ambiguity" \
  "printf '%s' \"\$out\" | grep -qi 'inspire_kb'"
fixture_cleanup "$w"

# Structure-not-content, as a permanent assertion rather than a one-off
# manual demonstration: a deleted validator, an edited skill file, and an
# entire removed skill directory must never affect the outcome.
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
rm -f "$p/.claude/bin/no-todos.sh"
printf '\nOPERATOR CUSTOMIZATION\n' >> "$p/.claude/skills/inspire-domain/SKILL.md"
rm -rf "$p/.claude/skills/inspire-spike"
verify_layout "$PLUGIN_ROOT" "$p" pre-0.3 >/dev/null 2>&1
eq "deleted validator, edited skill, removed skill dir still pass pre-0.3" "$?" "0"
fixture_cleanup "$w"

# ---- hop ops ------------------------------------------------------------
. "$PLUGIN_ROOT/scripts/lib/hop-ops.sh"

w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
mf="$PLUGIN_ROOT/manifests/0.2.1.json"

# --- act mode ---
hop_ops_init "$p" "$mf" 0
mkdir -p "$p/.inspire/bin"
hop_mv .claude/bin/review.sh .inspire/bin/review.sh
check "hop_mv moved the file"        "[ -f '$p/.inspire/bin/review.sh' ]"
check "hop_mv left no source behind" "[ ! -e '$p/.claude/bin/review.sh' ]"

# The check above is vacuous on its own: a pre-0.3 project legitimately retains
# .inspire/bin/review.sh — the staged source install.sh copied FROM — so the
# destination already existed (verified: it passes even with hop_mv undefined).
# Only "left no source behind" fails without hop_mv. Prove a real transfer, and
# the destination-dir creation, against a path nothing could have pre-created.
printf 'CANARY\n' > "$p/.claude/bin/hop-canary.txt"
hop_mv .claude/bin/hop-canary.txt .inspire/fresh/hop-canary.txt
check "hop_mv creates the missing destination directory" "[ -d '$p/.inspire/fresh' ]"
eq "hop_mv transferred the content intact" \
  "$(cat "$p/.inspire/fresh/hop-canary.txt" 2>/dev/null)" "CANARY"
check "hop_mv journalled move with both paths" \
  "grep -q \$'^move\t.claude/bin/hop-canary.txt\t.inspire/fresh/hop-canary.txt$' '$HOP_JOURNAL'"

hop_mv .claude/bin/definitely-absent.sh .inspire/bin/definitely-absent.sh
eq "hop_mv on a missing source is a silent no-op" "$?" "0"
check "hop_mv created nothing from nothing" "[ ! -e '$p/.inspire/bin/definitely-absent.sh' ]"

# hop_rm_owned deletes only what the manifest says we shipped.
printf 'mine\n' > "$p/.claude/bin/test/my-fixture.sh"
owned_before="$(jq -r '[.files|keys[]|select(startswith(".claude/bin/test/"))]|length' "$mf")"
eq "manifest lists the shipped fixtures" "$owned_before" "114"
# A file we shipped that the operator EDITED must also survive. Pick the target
# deterministically from the manifest — not `find | head -1`, whose result
# depends on filesystem order.
edited_rel="$(manifest_paths "$mf" | cut -f1 | grep '^\.claude/bin/test/' \
              | LC_ALL=C sort | head -1)"
check "picked a shipped fixture deterministically" "[ -n '$edited_rel' ]"
printf '\nMY EDIT\n' >> "$p/$edited_rel"
edited_hash="$(shasum -a 256 "$p/$edited_rel" | awk '{print $1}')"

hop_rm_owned .claude/bin/test
check "hop_rm_owned kept the operator's fixture" "[ -f '$p/.claude/bin/test/my-fixture.sh' ]"
check "hop_rm_owned removed a file we shipped" \
  "[ ! -e '$p/.claude/bin/test/run-tests.sh' ]"
check "hop_rm_owned reported the survivor" \
  "grep -q 'my-fixture.sh' '$HOP_JOURNAL'"
check "hop_rm_owned never deletes a file we shipped but they edited" \
  "[ -f '$p/$edited_rel' ]"
eq "the edited shipped file is byte-identical" \
  "$(shasum -a 256 "$p/$edited_rel" 2>/dev/null | awk '{print $1}')" "$edited_hash"

hop_report 'a note for the operator'
check "hop_report journals the note" "grep -q 'a note for the operator' '$HOP_JOURNAL'"
hop_unregister_hook '.claude/hooks/'
check "hop_unregister_hook journals the substring" \
  "grep -q \$'unregister\t.claude/hooks/' '$HOP_JOURNAL'"
fixture_cleanup "$w"

# --- record mode writes nothing ---
w="$(mktemp -d)"; p="$(fixture_from_tag v0.2.1 "$w" "$REPO")"
before="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
hop_ops_init "$p" "$mf" 1
hop_mv .claude/bin/review.sh .inspire/bin/review.sh
hop_rm_owned .claude/bin/test
hop_rm .inspire/install.sh
after="$(find "$p" -type f | LC_ALL=C sort | xargs shasum -a 256 2>/dev/null | shasum -a 256)"
eq "record mode wrote nothing" "$before" "$after"
check "record mode journalled the move" \
  "grep -q \$'move\t.claude/bin/review.sh' '$HOP_JOURNAL'"
check "record mode journalled 114 deletions" \
  "[ \"\$(grep -c \$'^delete\t.claude/bin/test/' '$HOP_JOURNAL')\" = 114 ]"
fixture_cleanup "$w"

echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
