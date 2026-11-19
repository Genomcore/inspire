#!/usr/bin/env bash
# The seeds payload class (base/seeds/ → .inspire/seeds/) and scaffold.sh, the tool
# that lays a seed's starter project in a repository with no code.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
project() { mkdir -p "$WORK/$1" && ( cd "$WORK/$1" && git init -q ) && printf '%s\n' "$WORK/$1"; }
init() { local p="$1"; shift; "$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$p" "$@" 2>/dev/null; }
scaffold() { ( cd "$1" && shift && bash .inspire/bin/scaffold.sh "$@" 2>&1 ); }
count() { find "$1" -type f | wc -l | tr -d ' '; }

SEED="$PLUGIN_ROOT/base/seeds/web"
N="$(count "$SEED/files")"
premise "the web seed ships a starter" "[ '$N' -gt 20 ]"

# --- the class materializes, and init without --seed lays nothing --------------
p="$(project plain)"
out="$(init "$p" --source-root source --prototype-root prototype)"
eq    "class: every starter file is installed" "$(count "$p/.inspire/seeds/web/files")" "$N"
check "class: a dotfile of the starter is installed too" "[ -f '$p/.inspire/seeds/web/files/.oxlintrc.json' ]"
check "class: seed.json is installed" "[ -f '$p/.inspire/seeds/web/seed.json' ]"
check "class: the tool is executable" "[ -x '$p/.inspire/bin/scaffold.sh' ]"
eq    "init without --seed: the source root holds only its README" "$(ls -A "$p/source")" "README.md"
eq    "the tool lists the seeds" "$(scaffold "$p" --list)" "web"

# --- a dry run writes nothing --------------------------------------------------
dry="$(scaffold "$p" --dry-run web)"
has   "dry run: names what it would create" "$dry" "create source/package.json"
eq    "dry run: writes nothing" "$(ls -A "$p/source")" "README.md"

# --- laying the starter --------------------------------------------------------
out="$(scaffold "$p" web)"; rc=$?
eq    "scaffold: exits 0" "$rc" "0"
eq    "scaffold: every starter file but the README is created, plus the lint plugin" \
      "$(printf '%s\n' "$out" | grep -c '^create ')" "$N"
has   "scaffold: INSPIRE's own README stub gives way to the starter's" "$out" "replace source/README.md"
eq    "scaffold: the README is the starter's" \
      "$(shasum < "$p/source/README.md")" "$(shasum < "$SEED/files/README.md")"
eq    "scaffold: a starter file is the seed's, byte for byte" \
      "$(shasum < "$p/source/package.json")" "$(shasum < "$SEED/files/package.json")"
eq    "scaffold: the lint plugin is the typescript skill's" \
      "$(shasum < "$p/source/oxlint-escape-hatches.mjs")" \
      "$(shasum < "$PLUGIN_ROOT/base/skills/inspire-code-typescript/references/oxlint-escape-hatches.mjs")"
check "scaffold: installs no dependency" "[ ! -e '$p/source/node_modules' ]"
# Every gate the resolved stack skills declare is in the starter's configuration.
eq    "scaffold: no declared gate is missing from the starter" \
      "$(cd "$p" && bash .inspire/bin/profile-gates-installed.sh 2>&1 | jq -rs '[.[] | select(.severity == "error")] | length')" "0"

# A README the project wrote is the project's: it stays, and nothing else is refused.
o="$(project own-readme)"
init "$o" --source-root source --prototype-root none >/dev/null
printf '# Our product\n' > "$o/source/README.md"
out="$(scaffold "$o" web)"
has   "an own README: kept" "$out" "keep source/README.md"
eq    "an own README: byte-identical" "$(cat "$o/source/README.md")" "# Our product"
check "an own README: the starter is laid around it" "[ -f '$o/source/package.json' ]"

# --- a project with code is never scaffolded -----------------------------------
before="$(count "$p/source")"
out="$(scaffold "$p" web)"; rc=$?
eq    "code present: refuses" "$rc" "1"
has   "code present: says why" "$out" "already holds code"
eq    "code present: writes nothing" "$(count "$p/source")" "$before"

q="$(project brownfield)"
init "$q" --source-root . --prototype-root none >/dev/null
out="$(scaffold "$q" web)"; rc=$?
eq    "source_root '.': refuses" "$rc" "1"
has   "source_root '.': says why" "$out" "the repository root is the code"
check "source_root '.': writes nothing" "[ ! -e '$q/package.json' ]"

out="$(scaffold "$q" nope)"; rc=$?
eq    "an unknown seed: refuses" "$rc" "1"
has   "an unknown seed: names the ones that exist" "$out" "seeds: web"

# A seed that needs a runtime file the project removed refuses before the first write.
r="$(project no-skill)"
init "$r" --source-root source --prototype-root none >/dev/null
rm "$r/.claude/skills/inspire-code-typescript/references/oxlint-escape-hatches.mjs"
out="$(scaffold "$r" web)"; rc=$?
eq    "a missing runtime file: refuses" "$rc" "1"
eq    "a missing runtime file: writes nothing" "$(ls -A "$r/source")" "README.md"

# --- materialize.sh --seed -----------------------------------------------------
s="$(project seeded)"
dry="$(init "$s" --source-root source --prototype-root prototype --seed web --dry-run)"
has   "--seed dry run: plans the starter" "$(printf '%s' "$dry" | jq -r '.created[]')" "seed's starter project"
check "--seed dry run: writes nothing" "[ ! -e '$s/source' ]"
out="$(init "$s" --source-root source --prototype-root prototype --seed web)"
check "--seed: the starter is laid at init" "[ -f '$s/source/src/main.ts' ] && [ -f '$s/source/web/src/App.tsx' ]"
has   "--seed: the run reports it" "$(printf '%s' "$out" | jq -r '.created[]')" "the 'web' seed's starter project ($N files)"
eq    "--seed: no warning" "$(printf '%s' "$out" | jq -r '.warnings | length')" "0"

b="$(project seeded-brownfield)"
out="$(init "$b" --source-root . --prototype-root none --seed web)"; rc=$?
eq    "--seed on a brownfield root: the install still succeeds" "$rc" "0"
has   "--seed on a brownfield root: a warning says no starter was laid" \
      "$(printf '%s' "$out" | jq -r '.warnings[]')" "starter project was not laid"
check "--seed on a brownfield root: writes no starter" "[ ! -e '$b/package.json' ]"

"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$s" --seed web >/dev/null 2>&1
eq    "--seed with --mode update is refused" "$?" "1"

# --- an update keeps an edited seed and a project's own ------------------------
printf '\n# ours\n' >> "$s/.inspire/seeds/web/files/README.md"
mkdir -p "$s/.inspire/seeds/ours/files" && printf 'x\n' > "$s/.inspire/seeds/ours/files/a.txt"
edit="$(shasum < "$s/.inspire/seeds/web/files/README.md")"
"$SCRIPT" --mode update --plugin-root "$PLUGIN_ROOT" --project-root "$s" >/dev/null 2>&1
eq    "update: an edited starter file is kept" "$(shasum < "$s/.inspire/seeds/web/files/README.md")" "$edit"
eq    "update: a seed of the project's own is kept" "$(cat "$s/.inspire/seeds/ours/files/a.txt")" "x"
eq    "and the tool lists it" "$(scaffold "$s" --list | paste -sd' ' -)" "ours web"

# --- the released manifest lists the class --------------------------------------
M="$PLUGIN_ROOT/manifests/$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json").json"
check "the manifest lists the seed" "jq -e '.files | has(\".inspire/seeds/web/seed.json\")' '$M' >/dev/null"
check "and the tool" "jq -e '.files | has(\".inspire/bin/scaffold.sh\")' '$M' >/dev/null"

# --- the starter installs and passes its own checks ----------------------------
# Needs npm and its registry, so it is skipped without them, like the visor builds.
if command -v npm >/dev/null 2>&1 && npm ping >/dev/null 2>&1; then
  ( cd "$p/source" && npm ci >/dev/null 2>&1 ); eq "starter: installs from its lockfile" "$?" "0"
  for c in test test:e2e typecheck lint build; do
    ( cd "$p/source" && npm run -s "$c" >/dev/null 2>&1 ); eq "starter: npm run $c passes" "$?" "0"
  done
  ( cd "$p/source" && npx oxfmt --check . >/dev/null 2>&1 ); eq "starter: is formatted" "$?" "0"
  printf '// oxlint-disable-next-line typescript/no-explicit-any\nexport const a: any = 1 as unknown as string;\n' > "$p/source/src/hatch.ts"
  hits="$(cd "$p/source" && npx oxlint src/hatch.ts 2>&1 | grep -o 'escape-hatches([a-z-]*)' | sort -u | paste -sd' ' -)"
  eq "starter: the three escape-hatch rules fire" "$hits" \
     "escape-hatches(no-double-cast) escape-hatches(no-restricted-disable) escape-hatches(require-reason)"
else
  skipped 8 "the starter's install and checks need npm and its registry"
fi

summary
