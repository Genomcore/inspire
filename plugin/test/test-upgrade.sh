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

echo ""; echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
