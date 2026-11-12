#!/usr/bin/env bash
# plugin/test/upgrade/27-migrate-links.sh — wikilinks become relative Markdown links
# (plugin/scripts/migrate-links.sh, adr-markdown-links D6).
#
# What it must hold: each resolution source resolves what only it can, an ambiguous
# key resolves nothing, aliases, escaped table pipes and frontmatter convert, code and
# embeds stay, unresolved links are listed and left, a dry run writes nothing, a
# second run changes nothing, git is only read, and a layered KB is refused.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"

LINKS="$PLUGIN_ROOT/scripts/migrate-links.sh"
MIG="$PLUGIN_ROOT/scripts/migrate-kb.sh"
W="$(mktemp -d -t inspire-links-test.XXXXXX)"
trap 'rm -rf "$W"' EXIT

mk() { mkdir -p "$(dirname "$1")"; cat > "$1"; }
tree_hash() { (cd "$1" && find inspire_kb -type f | LC_ALL=C sort | xargs shasum -a 256); }
TAB="$(printf '\t')"

# ── a migrated KB: its move plan, its id map, and links of every kind ──────────
P="$W/concept"; K="$P/inspire_kb"; S="$K/01_spec"
mk "$S/_migration/plan.tsv" <<E
move${TAB}inspire_kb/02_modules/a.md${TAB}inspire_kb/01_spec/_modules/a/a.module.md
move${TAB}inspire_kb/02_modules/b.md${TAB}inspire_kb/01_spec/_modules/b/b.module.md
move${TAB}inspire_kb/03_features/a/create.md${TAB}inspire_kb/01_spec/_modules/a/_features/create.feature.md
move${TAB}inspire_kb/03_features/b/create.md${TAB}inspire_kb/01_spec/_modules/b/_features/create.feature.md
move${TAB}inspire_kb/04_domain/a/order/a.order.md${TAB}inspire_kb/01_spec/_modules/a/_domain/order/order.entity.md
idmap${TAB}a.detail${TAB}portal.detail
E
printf '{"screens":{"a.detail":"portal.detail"}}\n' | mk "$S/_migration/id-map.json"
mk "$S/_modules/a/a.module.md" <<'E'
# a
- moved path: [[../03_features/a/create]]
- current path: [[../b/b.module]]
- id: [[b]]
- moved stem: [[a.order]]
- id map: [[a.detail]]
- alias: [[a.detail|the detail screen]]
- ambiguous: [[create]]
- nowhere: [[nowhere]]
- embed: ![[b]]
- code: `[[b]]`

| col | link |
|---|---|
| x | [[b\|module b]] |

```
[[b]]
```
E
printf '# b\n' | mk "$S/_modules/b/b.module.md"
printf '# create in a\n' | mk "$S/_modules/a/_features/create.feature.md"
printf -- '---\nrequires: ["[[a]]"]\n---\n# create in b\n' | mk "$S/_modules/b/_features/create.feature.md"
printf '# order, with no id: in its frontmatter\n' | mk "$S/_modules/a/_domain/order/order.entity.md"
printf -- '---\nid: portal.detail\n---\n# detail\n' | mk "$S/_faces/portal/_screens/detail.screen.md"
printf '# T-1\nTouches [[a]].\n' | mk "$K/99_tracker/tickets/T-1.md"

eq "it counts the wikilinks outside code" "$(cd "$P" && bash "$LINKS" --count)" "11"

before="$(tree_hash "$P")"
out="$(cd "$P" && bash "$LINKS" --dry-run 2>&1)"; rc=$?
eq "a dry run exits 0" "$rc" "0"
has "the dry run prints the plan" "$out" "link${TAB}inspire_kb/01_spec/_modules/a/a.module.md${TAB}2${TAB}moved-path${TAB}[[../03_features/a/create]]${TAB}[create](_features/create.feature.md)"
eq "a dry run writes nothing" "$(tree_hash "$P")" "$before"

out="$(cd "$P" && bash "$LINKS" 2>&1)"; rc=$?
eq "the conversion exits 0" "$rc" "0"
A="$(cat "$S/_modules/a/a.module.md")"
has "a path link follows its target through the move plan"   "$A" "- moved path: [create](_features/create.feature.md)"
has "a path link to a file where it stands keeps its path"   "$A" "- current path: [b.module](../b/b.module.md)"
has "an id resolves through the index"                       "$A" "- id: [b](../b/b.module.md)"
has "a pre-move file name resolves through the move plan"    "$A" "- moved stem: [a.order](_domain/order/order.entity.md)"
has "an old screen id resolves through the id map"           "$A" "- id map: [a.detail](../../_faces/portal/_screens/detail.screen.md)"
has "an alias becomes the text"                              "$A" "- alias: [the detail screen](../../_faces/portal/_screens/detail.screen.md)"
has "an escaped table pipe splits target from alias"         "$A" "| x | [module b](../b/b.module.md) |"
has "an ambiguous key resolves nothing"                      "$A" "- ambiguous: [[create]]"
has "a link to nothing stays as written"                     "$A" "- nowhere: [[nowhere]]"
has "an embed stays"                                         "$A" "- embed: ![[b]]"
has "a link in a code span stays"                            "$A" '- code: `[[b]]`'
has "a link in a fenced block stays"                         "$A" '```
[[b]]
```'
check "a frontmatter link converts and stays quoted" \
  "grep -qxF 'requires: [\"[a](../../a/a.module.md)\"]' '$S/_modules/b/_features/create.feature.md'"
check "a link outside 01_spec converts too" "grep -qxF 'Touches [a](../../01_spec/_modules/a/a.module.md).' '$K/99_tracker/tickets/T-1.md'"
has "the run lists each unresolved link with its line" "$out" "unresolved${TAB}inspire_kb/01_spec/_modules/a/a.module.md${TAB}8${TAB}[[create]]"
has "and sums up by source" "$out" "links: 9 converted in 3 file(s) (moved-path 1, path 1, id 4, moved-stem 1, id-map 2), 2 unresolved and left as written, 2 in code left as written"
check "the link plan is saved" "grep -q '^link${TAB}' '$S/_migration/links.tsv' && grep -q '^unresolved${TAB}' '$S/_migration/links.tsv'"
eq "only the unresolved links are left" "$(cd "$P" && bash "$LINKS" --count)" "2"

after="$(tree_hash "$P")"
out="$(cd "$P" && bash "$LINKS" 2>&1)"; rc=$?
eq "a second run exits 0" "$rc" "0"
eq "a second run changes nothing" "$(tree_hash "$P")" "$after"
has "and says it converted nothing" "$out" "links: 0 converted"

# migrate-kb.sh on a concept KB that still holds wikilinks is a conversion-only run.
Q="$W/via-migrate"; mkdir -p "$Q"; cp -R "$W/concept/inspire_kb" "$Q/"
( cd "$Q" && bash "$LINKS" ) >/dev/null 2>&1
printf '# c\nSee [[b]].\n' | mk "$Q/inspire_kb/01_spec/_modules/a/c.md"
out="$(cd "$Q" && bash "$MIG" 2>&1)"; rc=$?
eq "migrate-kb on a concept KB with wikilinks exits 0" "$rc" "0"
has "it says the layout is migrated" "$out" "already migrated"
check "and converts the links" "grep -qxF 'See [b](../b/b.module.md).' '$Q/inspire_kb/01_spec/_modules/a/c.md'"

# A layered KB is refused: migrate-kb.sh moves it and converts its links in one run.
L="$W/layered"; printf '# a\n[[b]]\n' | mk "$L/inspire_kb/02_modules/a.md"
out="$(cd "$L" && bash "$LINKS" 2>&1)"; rc=$?
eq "a layered KB: refused" "$rc" "1"
has "the refusal names migrate-kb.sh" "$out" "migrate-kb.sh"
eq "and nothing changed" "$(cat "$L/inspire_kb/02_modules/a.md")" "$(printf '# a\n[[b]]')"

# No plan.tsv: the move record is git's rename history, read and never written.
G="$W/git"; mkdir -p "$G"
gitq() { git -C "$G" -c user.email=t@t -c user.name=t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
gitq init -q
printf '# a\n- [[../03_features/a/create]]\n' | mk "$G/inspire_kb/02_modules/a.md"
printf '# create in a, the first module of the two\n' | mk "$G/inspire_kb/03_features/a/create.md"
printf '# create in b, the second module of the two\n' | mk "$G/inspire_kb/03_features/b/create.md"
gitq add -A && gitq commit -qm layered
GS="$G/inspire_kb/01_spec/_modules"
mkdir -p "$GS/a/_features" "$GS/b/_features"
mv "$G/inspire_kb/02_modules/a.md" "$GS/a/a.module.md"
mv "$G/inspire_kb/03_features/a/create.md" "$GS/a/_features/create.feature.md"
mv "$G/inspire_kb/03_features/b/create.md" "$GS/b/_features/create.feature.md"
rm -rf "$G/inspire_kb/02_modules" "$G/inspire_kb/03_features"
gitq add -A && gitq commit -qm moved
head_before="$(gitq rev-parse HEAD)"
out="$(cd "$G" && bash "$LINKS" 2>&1)"; rc=$?
eq "with no plan.tsv the conversion exits 0" "$rc" "0"
check "a path link follows git's renames" "grep -qxF -- '- [create](_features/create.feature.md)' '$GS/a/a.module.md'"
has "and the plan names git as the move record" "$out" "move record: git renames since"
eq "git is only read: HEAD is where it was" "$(gitq rev-parse HEAD)" "$head_before"
eq "and the only change is the converted file" "$(gitq status --porcelain | tr '\n' ' ')" " M inspire_kb/01_spec/_modules/a/a.module.md ?? inspire_kb/01_spec/_migration/ "

summary
