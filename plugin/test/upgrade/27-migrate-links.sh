#!/usr/bin/env bash
# plugin/test/upgrade/27-migrate-links.sh — wikilinks become relative Markdown links
# (plugin/scripts/migrate-links.sh, adr-markdown-links D6).
#
# What it must hold: each resolution source resolves what only it can, an id resolves
# to the file the id index (scripts/lib/wikilinks.sh) resolves it to, a pre-move name two files had resolves
# nothing, aliases, escaped table pipes and frontmatter convert, code and embeds stay,
# unresolved links are listed and left, a dry run writes nothing, a second run changes
# nothing, git is only read, and a layered KB is refused.
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
move${TAB}inspire_kb/03_features/a/legacy.md${TAB}inspire_kb/01_spec/_modules/a/_features/create.feature.md
move${TAB}inspire_kb/03_features/b/legacy.md${TAB}inspire_kb/01_spec/_modules/b/_features/create.feature.md
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
- shared: [[create]]
- nowhere: [[nowhere]]
- ambiguous old name: [[legacy]]
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

eq "it counts the wikilinks outside code" "$(cd "$P" && bash "$LINKS" --count)" "13"
# path_read <dir> <file> <line> — the file the validators' reader resolves that line's link to.
path_read() { (cd "$1" && . "$PLUGIN_ROOT/base/bin/_lib.sh" && sdd_links "$2" | awk -F'\t' -v l="$3" '$1 == l { print $5 }'); }
# index_read <dir> <target> — the file the converter's id index resolves a wikilink target to.
index_read() {
  (cd "$1" && . "$PLUGIN_ROOT/base/bin/_lib.sh" && . "$PLUGIN_ROOT/scripts/lib/wikilinks.sh" || exit 1
   wikilink_index
   awk -v t="$2" "$WIKILINK_AWK_RESOLVE"'{ wiki_ix_add($0) } END { print wiki_resolve(t) }' "$WIKILINK_INDEX_FILE"
   rm -f "${WIKILINK_INDEX_FILE:-}" "${SDD_ENTITY_INDEX_FILE:-}")
}
shared_before="$(index_read "$P" create)"
premise "the index resolves the key two features share" "[ -n '$shared_before' ]"

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
has "a key two files share converts"                         "$A" "- shared: [create]("
eq  "to the file the index resolves it to" \
    "$(path_read "$P" inspire_kb/01_spec/_modules/a/a.module.md 8)" "$shared_before"
has "a pre-move name two files had resolves nothing"         "$A" "- ambiguous old name: [[legacy]]"
has "a link to nothing stays as written"                     "$A" "- nowhere: [[nowhere]]"
has "an embed converts and keeps its !"                      "$A" "- embed: ![b](../b/b.module.md)"
has "a link in a code span stays"                            "$A" '- code: `[[b]]`'
has "a link in a fenced block stays"                         "$A" '```
[[b]]
```'
check "a frontmatter link converts and stays quoted" \
  "grep -qxF 'requires: [\"[a](../../a/a.module.md)\"]' '$S/_modules/b/_features/create.feature.md'"
check "a link outside 01_spec converts too" "grep -qxF 'Touches [a](../../01_spec/_modules/a/a.module.md).' '$K/99_tracker/tickets/T-1.md'"
has "the run lists each unresolved link with its line" "$out" "unresolved${TAB}inspire_kb/01_spec/_modules/a/a.module.md${TAB}9${TAB}[[nowhere]]"
has "and sums up by source" "$out" "links: 11 converted in 3 file(s) (moved-path 1, path 1, id 8, moved-stem 1), 2 unresolved and left as written, 2 in code left as written"
check "the link plan is saved" "grep -q '^link${TAB}' '$S/_migration/links.tsv' && grep -q '^unresolved${TAB}' '$S/_migration/links.tsv'"
eq "only the unresolved links are left" "$(cd "$P" && bash "$LINKS" --count)" "2"

after="$(tree_hash "$P")"
out="$(cd "$P" && bash "$LINKS" 2>&1)"; rc=$?
eq "a second run exits 0" "$rc" "0"
eq "a second run changes nothing" "$(tree_hash "$P")" "$after"
has "and says it converted nothing" "$out" "links: 0 converted"

# migrate-kb.sh moves files and rewrites no link, so on a concept KB it does nothing.
Q="$W/via-migrate"; mkdir -p "$Q"; cp -R "$W/concept/inspire_kb" "$Q/"
printf '# c\nSee [[b]].\n' | mk "$Q/inspire_kb/01_spec/_modules/a/c.md"
out="$(cd "$Q" && bash "$MIG" 2>&1)"; rc=$?
eq "migrate-kb on a concept KB with wikilinks exits 0" "$rc" "0"
has "it says the layout is migrated" "$out" "already migrated"
check "and leaves the links to migrate-links.sh" "grep -qxF 'See [[b]].' '$Q/inspire_kb/01_spec/_modules/a/c.md'"

# A layered KB is refused: its moves come first, committed on their own.
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
# --since names the commit before the move when the history cannot.
out="$(cd "$G" && bash "$LINKS" --dry-run --since HEAD~1 2>&1)"
has "--since sets the commit the renames are read from" "$out" "move record: git renames since HEAD~1"
has "and a path link follows those renames" "$out" "moved-path${TAB}[[../03_features/a/create]]${TAB}[create](_features/create.feature.md)"
out="$(cd "$G" && bash "$LINKS" 2>&1)"; rc=$?
eq "with no plan.tsv the conversion exits 0" "$rc" "0"
check "a path link follows git's renames" "grep -qxF -- '- [create](_features/create.feature.md)' '$GS/a/a.module.md'"
has "and the plan names git as the move record" "$out" "move record: git renames since"
eq "git is only read: HEAD is where it was" "$(gitq rev-parse HEAD)" "$head_before"
eq "and the only change is the converted file" "$(gitq status --porcelain | tr '\n' ' ')" " M inspire_kb/01_spec/_modules/a/a.module.md ?? inspire_kb/01_spec/_migration/ "

gitq add -A && gitq commit -qm converted

# Moves git has not committed refuse the act run: they would share its commit (D6).
mkdir -p "$GS/c"; gitq mv "$GS/b/_features/create.feature.md" "$GS/c/create.feature.md"
printf '# c\n[[a]]\n' | mk "$GS/c/c.module.md"
before="$(tree_hash "$G")"
out="$(cd "$G" && bash "$LINKS" 2>&1)"; rc=$?
eq "uncommitted moves: refused" "$rc" "1"
has "the refusal names Step 3" "$out" "Step 3"
has "and lists the move" "$out" "c/create.feature.md"
eq "and nothing changed" "$(tree_hash "$G")" "$before"
out="$(cd "$G" && bash "$LINKS" --dry-run 2>&1)"; rc=$?
eq "a dry run still plans" "$rc" "0"
has "and says the act run refuses" "$out" "the act run refuses until the moves are committed"
gitq add -A && gitq commit -qm "moved c"
out="$(cd "$G" && bash "$LINKS" 2>&1)"; rc=$?
eq "once committed, the conversion runs" "$rc" "0"
has "outside git a run proceeds with a note" "$(cd "$P" && bash "$LINKS" --dry-run 2>&1)" "not in a git work tree"

# Git pairs moves it must compare by content only below diff.renameLimit; the run
# lifts the limit, so an edited move is still a rename.
R="$W/renamelimit"; mkdir -p "$R"
gitr() { git -C "$R" -c user.email=t@t -c user.name=t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
gitr init -q; gitr config diff.renameLimit 1
for m in a b c; do printf '# %s\n[[../03_features/%s/list]]\none\ntwo\nthree\n' "$m" "$m" | mk "$R/inspire_kb/02_modules/$m.md"
  printf '# list of %s\none\ntwo\nthree\nfour\n' "$m" | mk "$R/inspire_kb/03_features/$m/list.md"; done
gitr add -A && gitr commit -qm layered
for m in a b c; do mkdir -p "$R/inspire_kb/01_spec/_modules/$m/_features"
  mv "$R/inspire_kb/02_modules/$m.md" "$R/inspire_kb/01_spec/_modules/$m/$m.module.md"
  { cat "$R/inspire_kb/03_features/$m/list.md"; printf 'edited in the move\n'; } > "$R/inspire_kb/01_spec/_modules/$m/_features/list.feature.md"
  rm "$R/inspire_kb/03_features/$m/list.md"; done
rm -rf "$R/inspire_kb/02_modules" "$R/inspire_kb/03_features"
gitr add -A && gitr commit -qm moved
out="$(cd "$R" && bash "$LINKS" --dry-run 2>&1)"
has "an edited move above the rename limit still maps a path link" "$out" "moved-path${TAB}[[../03_features/c/list]]${TAB}[list](_features/list.feature.md)"

# The edge cases: the reader's code rules, frontmatter, anchors, spaces, CRLF, bytes.
E="$W/edge"; EK="$E/inspire_kb/01_spec/_modules"
printf '# b\n' | mk "$EK/b/b.module.md"
printf '# v2\n' | mk "$EK/b/my file (v2).md"
printf -- '---\r\nid: zed.custom\r\n---\r\n# crlf entity\r\n' | mk "$EK/b/crlf.entity.md"
printf -- '---\r\nrequires: [[b]]\r\n---\r\nSee [[b]].\r\n' | mk "$EK/b/crlf-links.md"
printf 'no newline [[b]]' | mk "$EK/b/tail.md"
mk "$EK/a/a.module.md" <<'E'
---
requires: [[b]]
links:
  - [[b]]
deps: [[[b]], [[b|bee]]]
quoted: '[[b]]'
---
# a
~~~
[[b]] tilde
~~~

````
```
[[b]] inner4
````

``x [[b]] dbl``
anchor [[b#context]] and [[b#context|ctx]] and [[#local]]
space [[my file (v2)]] crlf id [[zed.custom]]
E
reader() { (cd "$E" && . "$PLUGIN_ROOT/base/bin/_lib.sh" && sdd_links "$1" wiki); }
wikis_read=0
while IFS= read -r f; do
  wikis_read=$((wikis_read + $(reader "$f" | awk -F'\t' '$2 == "wiki"' | wc -l)))
done < <(cd "$E" && find inspire_kb -name '*.md')
eq "--count counts exactly the wikilinks the reader reads" "$(cd "$E" && bash "$LINKS" --count)" "$wikis_read"
premise "the reader reads the corpus's 13 wikilinks outside code" "[ '$wikis_read' -eq 13 ]"
tail_before="$(shasum -a 256 < "$EK/b/tail.md")"
out="$(cd "$E" && bash "$LINKS" 2>&1)"; rc=$?
eq "the edge KB converts" "$rc" "0"
A="$(cat "$EK/a/a.module.md")"
has "a ~~~ fence is code"                         "$A" '~~~
[[b]] tilde
~~~'
has "a four-backtick fence quoting a three-backtick one is code" "$A" '```
[[b]] inner4
````'
has "a double-backtick span is code"              "$A" '``x [[b]] dbl``'
has "an anchor stays after the path"              "$A" "anchor [b](../b/b.module.md#context) and [ctx](../b/b.module.md#context)"
has "a same-file anchor becomes an in-file link"  "$A" "and [local](#local)"
has "a path holding a space or a parenthesis goes in <>" "$A" "space [my file (v2)](<../b/my file (v2).md>)"
has "a CRLF file's frontmatter id is indexed"     "$A" "crlf id [zed.custom](../b/crlf.entity.md)"
has "an unquoted frontmatter wikilink is quoted"  "$A" 'requires: "[b](../b/b.module.md)"'
has "a list item is quoted"                       "$A" '  - "[b](../b/b.module.md)"'
has "flow sequence items are quoted"              "$A" 'deps: ["[b](../b/b.module.md)", "[bee](../b/b.module.md)"]'
has "a single-quoted link stays in its quotes"    "$A" "quoted: '[b](../b/b.module.md)'"
bad_yaml=0
while IFS= read -r f; do
  head -1 "$f" | grep -q '^---' || continue
  yq --front-matter=extract '.' "$f" >/dev/null 2>&1 || bad_yaml=$((bad_yaml + 1))
done < <(find "$E/inspire_kb" -name '*.md')
eq "yq parses every converted frontmatter" "$bad_yaml" "0"
eq "and reads the quoted link as the value" "$(yq --front-matter=extract '.requires' "$EK/a/a.module.md")" "[b](../b/b.module.md)"
eq "a CRLF file keeps its line ends" "$(tr -cd '\r' < "$EK/b/crlf-links.md" | wc -c | tr -d ' ')" "4"
eq "a CRLF frontmatter link is quoted before its \\r" "$(sed -n 2p "$EK/b/crlf-links.md")" "$(printf 'requires: "[b](b.module.md)"\r')"
hasnt "a file with no last newline converts" "$(shasum -a 256 < "$EK/b/tail.md")" "$tail_before"
eq "and gets no newline" "$(tail -c 1 "$EK/b/tail.md")" ")"
R1="$(reader inspire_kb/01_spec/_modules/a/a.module.md)"
has "the reader resolves the anchored path" "$R1" "../b/b.module.md#context${TAB}ctx${TAB}inspire_kb/01_spec/_modules/b/b.module.md"
has "the reader resolves the path in <>"    "$R1" "my file (v2)${TAB}inspire_kb/01_spec/_modules/b/my file (v2).md"
hasnt "the reader finds no unresolved link" "$(printf '%s\n' "$R1" | awk -F'\t' '$5 == ""')" "md"

# A typed file whose frontmatter declares an id is not named by its file name's id:
# `[[orders]]` never becomes a link to `orders.screen.md`, whose id is portal.orders.
X="$W/screen-name"; XS="$X/inspire_kb/01_spec"
printf -- '---\nid: portal.orders\n---\n# Orders\n' | mk "$XS/_faces/portal/_screens/orders.screen.md"
printf '# Bundle: api\n## Actions\n- [[orders]] (whole module)\n- [[orders.screen]]\n' | mk "$XS/_bundles/api.bundle.md"
eq "the index resolves no module from a screen's file name" "$(index_read "$X" orders)" ""
out="$(cd "$X" && bash "$LINKS" 2>&1)"
B="$(cat "$XS/_bundles/api.bundle.md")"
has "so the converter leaves it as written and lists it" "$out" "unresolved${TAB}inspire_kb/01_spec/_bundles/api.bundle.md${TAB}3${TAB}[[orders]]"
has "and keeps the whole-module line"                    "$B" "- [[orders]] (whole module)"
has "the screen's plain file name still converts"        "$B" "- [orders.screen](../_faces/portal/_screens/orders.screen.md)"
printf '# orders\n' | mk "$XS/_modules/orders/orders.module.md"
out="$(cd "$X" && bash "$LINKS" 2>&1)"
has "once the module exists, the link names it"          "$(cat "$XS/_bundles/api.bundle.md")" "- [orders](../_modules/orders/orders.module.md) (whole module)"
printf 'See [[portal.orders]].\n' | mk "$XS/_modules/orders/see.md"
out="$(cd "$X" && bash "$LINKS" --kb ./inspire_kb/ 2>&1)"
has "a KB spelled ./inspire_kb/ resolves a screen id all the same" "$(cat "$XS/_modules/orders/see.md")" "See [portal.orders](../../_faces/portal/_screens/orders.screen.md)."

# A process's scoped id is its id in either form, and its file name still names it.
Y="$W/process"; YS="$Y/inspire_kb/01_spec"
printf -- '---\nid: billing.nightly-close\n---\n# Nightly close\n' | mk "$YS/_modules/billing/_processes/nightly-close.process.md"
printf '# billing\n- [[nightly-close]]\n- [[billing.nightly-close]]\n- [[billing::nightly-close]]\n' | mk "$YS/_modules/billing/billing.module.md"
out="$(cd "$Y" && bash "$LINKS" 2>&1)"
BM="$(cat "$YS/_modules/billing/billing.module.md")"
has "a process link by file name converts"  "$BM" "- [nightly-close](_processes/nightly-close.process.md)"
has "a process link by dotted id converts"  "$BM" "- [billing.nightly-close](_processes/nightly-close.process.md)"
has "a process link by colon id converts"   "$BM" "- [billing::nightly-close](_processes/nightly-close.process.md)"
hasnt "and none is left unresolved"         "$out" "unresolved${TAB}"

# Markdown links written before the move are rebased through the move record (D7),
# and every Markdown link left broken, anywhere in the KB, is listed.
Z="$W/rebase"; ZK="$Z/inspire_kb"; ZS="$ZK/01_spec"
mk "$ZS/_migration/plan.tsv" <<E
move${TAB}inspire_kb/01_adr/adr-a.md${TAB}inspire_kb/01_spec/_adr/a.adr.md
move${TAB}inspire_kb/02_modules/m.md${TAB}inspire_kb/01_spec/_modules/m/m.module.md
move${TAB}inspire_kb/03_features/m/x.md${TAB}inspire_kb/01_spec/_modules/m/_features/x.feature.md
move${TAB}inspire_kb/03_features/m/y.md${TAB}inspire_kb/01_spec/_modules/m/_features/y.feature.md
E
printf -- '---\nid: adr-a\n---\n# A\n' | mk "$ZS/_adr/a.adr.md"
printf '# x\n' | mk "$ZS/_modules/m/_features/x.feature.md"
printf '# y\nSee [x](x.md).\n' | mk "$ZS/_modules/m/_features/y.feature.md"
mk "$ZS/_modules/m/m.module.md" <<'E'
---
links: ["[A](../01_adr/adr-a.md)"]
---
# m
See [the A decision](../01_adr/adr-a.md#context) and [[adr-a]].
Features: [features](../03_features/m) · stack: [stack](../00_bootstrap/stack.md) · self: [m](m.module.md)
Retired: [roster](../surfaces.md) · code: `[c](../01_adr/adr-a.md)`
E
printf 'Stack. See [adr a](../01_adr/adr-a.md) and [gone](../02_modules/gone.md).\n' | mk "$ZK/00_bootstrap/stack.md"
out="$(cd "$Z" && bash "$LINKS" 2>&1)"; rc=$?
eq "the rebase run exits 0" "$rc" "0"
M="$(cat "$ZS/_modules/m/m.module.md")"
has "a link from a moved file to a moved file follows both"    "$M" "See [the A decision](../../_adr/a.adr.md#context) and [adr-a](../../_adr/a.adr.md)."
has "a frontmatter link is rebased in its quotes"              "$M" 'links: ["[A](../../_adr/a.adr.md)"]'
has "a directory whose files moved together follows them"      "$M" "Features: [features](_features)"
has "a link from a moved file to a file that stayed follows it" "$M" "stack: [stack](../../../00_bootstrap/stack.md)"
has "a link that resolves where it stands is left"             "$M" "self: [m](m.module.md)"
has "a link to a retired file stays as written"                "$M" "Retired: [roster](../surfaces.md)"
has "a link in a code span stays"                              "$M" '`[c](../01_adr/adr-a.md)`'
check "a moved file's link to its moved sibling follows it" "grep -qxF 'See [x](x.feature.md).' '$ZS/_modules/m/_features/y.feature.md'"
check "a file that stayed has its link to a moved file rebased" \
  "grep -qF 'See [adr a](../01_spec/_adr/a.adr.md)' '$ZK/00_bootstrap/stack.md'"
has "the plan lists each rebased link" "$out" "link${TAB}inspire_kb/00_bootstrap/stack.md${TAB}1${TAB}rebased${TAB}[adr a](../01_adr/adr-a.md)${TAB}[adr a](../01_spec/_adr/a.adr.md)"
has "and each broken link, in 01_spec"  "$out" "broken${TAB}inspire_kb/01_spec/_modules/m/m.module.md${TAB}7${TAB}[roster](../surfaces.md)"
has "and outside it"                    "$out" "broken${TAB}inspire_kb/00_bootstrap/stack.md${TAB}1${TAB}[gone](../02_modules/gone.md)"
has "and sums them up" "$out" "Markdown links: 6 rebased through the move record, 2 broken and left as written"
after="$(tree_hash "$Z")"
out="$(cd "$Z" && bash "$LINKS" 2>&1)"
eq "a second rebase run changes nothing" "$(tree_hash "$Z")" "$after"
has "and lists the broken links again" "$out" "Markdown links: 0 rebased through the move record, 2 broken and left as written"

# A link to a layered directory, or to its README, names the concept directory that
# took its contents, or that directory's README; no link is rebased into _migration/ (D7).
Y="$W/layered-dirs"; YK="$Y/inspire_kb"; YD="$YK/01_spec"
mk "$YD/_migration/plan.tsv" <<E
move${TAB}inspire_kb/01_adr/README.md${TAB}inspire_kb/01_spec/_adr/README.md
move${TAB}inspire_kb/01_adr/adr-b.md${TAB}inspire_kb/01_spec/_modules/m/_adr/b.adr.md
move${TAB}inspire_kb/03_features/README.md${TAB}inspire_kb/01_spec/_migration/unplaced/03_features/README.md
unplaced${TAB}inspire_kb/04_domain/notes.md${TAB}inspire_kb/01_spec/_migration/unplaced/04_domain/notes.md
E
printf '# ADRs\n' | mk "$YD/_adr/README.md"
printf '# m\n' | mk "$YD/_modules/m/m.module.md"
printf '# B\n' | mk "$YD/_modules/m/_adr/b.adr.md"
printf '# app\n' | mk "$YD/_faces/app/app.face.md"
printf '# features\n' | mk "$YD/_migration/unplaced/03_features/README.md"
printf '# notes\n' | mk "$YD/_migration/unplaced/04_domain/notes.md"
mk "$YK/06_spikes/README.md" <<'E'
Decisions: [adr](../01_adr) and [its readme](../01_adr/README.md).
Features: [features](../03_features/) and [their readme](../03_features/README.md).
Screens: [screens](../05_screens). Notes: [notes](../04_domain/notes.md).
E
out="$(cd "$Y" && bash "$LINKS" 2>&1)"; rc=$?
eq "the layered-directory run exits 0" "$rc" "0"
R="$(cat "$YK/06_spikes/README.md")"
has "a layered directory link names the concept directory" "$R" "Decisions: [adr](../01_spec/_adr) and"
has "a layered README link names the concept directory's README" "$R" "[its readme](../01_spec/_adr/README.md)."
has "a trailing slash names the directory too" "$R" "Features: [features](../01_spec/_modules) and"
has "a README the concept directory lacks names the directory, not _migration/" "$R" "[their readme](../01_spec/_modules)."
has "every layered directory has its concept directory" "$R" "Screens: [screens](../01_spec/_faces)."
has "a link whose move took its target into _migration/ is left" "$R" "Notes: [notes](../04_domain/notes.md)."
has "and listed as broken" "$out" "broken${TAB}inspire_kb/06_spikes/README.md${TAB}3${TAB}[notes](../04_domain/notes.md)"
hasnt "no link is rebased into _migration/" "$out" "_migration/unplaced"

# A layered KB is counted as it stands, for Step 1.
eq "--count on a layered KB" "$(cd "$L" && bash "$LINKS" --count)" "1"

out="$(cd "$P" && bash "$LINKS" --bogus 2>&1)"; rc=$?
eq "an unknown argument is a usage error" "$rc" "2"
has "and names it" "$out" "unknown argument: --bogus"

summary
