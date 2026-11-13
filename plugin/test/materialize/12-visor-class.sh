#!/usr/bin/env bash
# The visor payload class (base/visor/ → .inspire/visor/) on init and update, its
# .gitignore entry, and the Quartz install under .quartz/ that update never walks.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

VB="$PLUGIN_ROOT/base/visor"
# visor_landed <project> → 0 when every file the class ships is on disk, byte-identical.
visor_landed() {
  local f n=0
  while IFS= read -r f; do
    cmp -s "$VB/$f" "$1/.inspire/visor/$f" || return 1
    n=$((n+1))
  done < <(cd "$VB" && find . -type f | sed 's|^\./||')
  [ "$n" -gt 0 ]
}
GI_BLOCK="sed -n '/INSPIRE (materialize.sh)/,/end INSPIRE/p'"

# --- init ------------------------------------------------------------------
check "premise: the plugin ships the class's settings and plugin" \
  "[ -f '$VB/visor.yaml' ] && [ -f '$VB/quartz.config.yaml' ] && [ -f '$VB/plugins/inspire/dist/index.js' ]"
ip="$(mktemp -d)/proj"; mkdir -p "$ip"; ( cd "$ip" && git init -q )
"$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$ip" \
  --source-root source --prototype-root prototype >/dev/null 2>&1
eq "init: exits 0" "$?" "0"
check "init: every visor file landed byte-identical" "visor_landed '$ip'"
check "init: nothing under .inspire/visor came out executable" \
  "[ -z \"\$(find '$ip/.inspire/visor' -type f -perm -u+x)\" ]"
check "init: the .gitignore block names the Quartz install" \
  "$GI_BLOCK '$ip/.gitignore' | grep -qxF '.inspire/visor/.quartz/'"
check "init: the install is ignored" \
  "git -C '$ip' check-ignore -q --no-index .inspire/visor/.quartz/node_modules/x/index.js"
check "init: the class root and its shipped files are not" \
  "{ git -C '$ip' check-ignore --no-index .inspire/visor .inspire/visor/visor.yaml .inspire/visor/plugins/inspire/dist/index.js >/dev/null; [ \$? = 1 ]; }"
rm -rf "$(dirname "$ip")"

# --- update ----------------------------------------------------------------
# The released baseline this block detects against — why a v0.6.0 fixture and
# not the current tree is spelled out in 01-init-current-tree.sh.
FIXTURE_WORK="$(mktemp -d)"
# The tag is spelled out: run.sh greps these call sites for what to pre-build.
FIXTURE_BASE="$(fixture_from_tag v0.6.0 "$FIXTURE_WORK" "$REPO")"
# A glob character in the project's path must not reach find's -path pattern.
up="$(mktemp -d)/proj[1]"; mkdir -p "$up" && cp -R "$FIXTURE_BASE/." "$up/"
check "premise: the project path holds a glob character" "case '$up' in *'['*) true ;; *) false ;; esac"
check "premise: the released baseline has no .inspire/visor (the class postdates it)" \
  "[ ! -e '$up/.inspire/visor' ]"
check "premise: its .gitignore block has no Quartz line" \
  "[ -f '$up/.gitignore' ] && ! grep -qF '.quartz' '$up/.gitignore'"

# A populated install, as the visor leaves it, and one file of the operator's
# beside it: the operator's keep line proves the walk reached .inspire/visor.
Q="$up/.inspire/visor/.quartz"
mkdir -p "$Q/node_modules/preact" "$Q/node_modules/a/node_modules/b" "$Q/public" \
         "$up/.inspire/visor/plugins/mine"
printf '{}\n' > "$Q/package.json"
printf '{}\n' > "$Q/node_modules/preact/package.json"
printf 'x\n'  > "$Q/node_modules/a/node_modules/b/index.js"
printf '<p>\n' > "$Q/public/index.html"
printf 'mine\n' > "$up/.inspire/visor/plugins/mine/index.js"
q_hash() { (cd "$Q" && find . -type f | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256); }
q_before="$(q_hash)"
# A verdict line names a path below .quartz/; the .gitignore line names only the dir.
Q_PATH='\.inspire/visor/\.quartz/[^ ]'

plan_err="$(mktemp)"
"$SCRIPT" --mode plan --plugin-root "$PLUGIN_ROOT" --project-root "$up" >/dev/null 2>"$plan_err"
eq "plan: exits 0 over a populated install" "$?" "0"
check "plan: the operator's own visor plugin is reported as theirs (the walk ran)" \
  "grep -q 'keep .*\.inspire/visor/plugins/mine/index\.js' '$plan_err'"
check "plan: no line names a path inside .quartz/" "! grep -q '$Q_PATH' '$plan_err'"

up_err="$(mktemp)"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$up" >/dev/null 2>"$up_err"
eq "update: exits 0 over a populated install" "$?" "0"
check "update: every visor file landed byte-identical" "visor_landed '$up'"
check "update: the report announces the class as a creation" \
  "grep -q 'create .*\.inspire/visor/visor\.yaml' '$up_err'"
check "update: the operator's own visor plugin is kept" \
  "grep -q 'keep .*\.inspire/visor/plugins/mine/index\.js' '$up_err' && [ \"\$(cat '$up/.inspire/visor/plugins/mine/index.js')\" = mine ]"
check "update: no report line names a path inside .quartz/" "! grep -q '$Q_PATH' '$up_err'"
check "update: nor does the saved report" \
  "[ -f '$up/.inspire/last-upgrade.log' ] && ! grep -q '$Q_PATH' '$up/.inspire/last-upgrade.log'"
eq "update: the install is untouched" "$(q_hash)" "$q_before"
check "update: the .gitignore block gained the Quartz install" \
  "$GI_BLOCK '$up/.gitignore' | grep -qxF '.inspire/visor/.quartz/'"
check "update: still exactly one INSPIRE block" \
  "[ \"\$(grep -c 'INSPIRE (materialize.sh)' '$up/.gitignore')\" = 1 ]"

rm -f "$plan_err" "$up_err"; rm -rf "$(dirname "$up")"
fixture_cleanup "$FIXTURE_WORK"
summary
