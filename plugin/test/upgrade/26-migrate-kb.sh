#!/usr/bin/env bash
# plugin/test/upgrade/26-migrate-kb.sh — the layered KB → 01_spec migration
# (plugin/scripts/migrate-kb.sh, adr-kb-structure D10).
#
# What it must hold: it asks rather than guesses, a dry run writes nothing, every
# file lands where D10's table says, no id changes but a screen's (and every one
# that does is in the id map), nothing of the operator's is dropped, a second run
# is a no-op, and a KB that was valid before is valid after.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"

MIG="$PLUGIN_ROOT/scripts/migrate-kb.sh"
W="$(mktemp -d -t inspire-migrate-test.XXXXXX)"
trap 'rm -rf "$W"' EXIT

# ── a layered KB with a roster: two UI surfaces, one headless, one lib ─────────
mk() { mkdir -p "$(dirname "$1")"; cat > "$1"; }
old_kb() {
  local K="$1/inspire_kb"
  mk "$K/00_bootstrap/surfaces.md" <<'E'
---
kind: bootstrap-surfaces
surfaces: [portal, admin, api, kit]
---
# Surfaces
## portal
**Kind:** ui
**Name:** Customer portal
**Profiles:** [react]
**Package:** apps/portal
**Shell:** /portal

## admin
**Kind:** ui
**Name:** Admin
**Package:** apps/admin
**Shell:** /admin

## api
**Kind:** headless
**Name:** API
**Profiles:** [nestjs]
**Package:** apps/api

## kit
**Kind:** lib
**Name:** Kit
**Package:** packages/kit
E
  printf '# theme\n' | mk "$K/00_bootstrap/theme.md"
  printf -- '---\nsurfaces: [admin]\n---\n# Admin rule\n**Modules affected:** [[auth]], [[billing]]\n' | mk "$K/01_adr/adr-admin-rule.md"
  printf '# why\n' | mk "$K/01_adr/adr-admin-rule.rationale.md"
  printf -- '---\nsurfaces: all\n---\n# Global\n**Modules affected:** [[auth]], [[billing]]\n' | mk "$K/01_adr/adr-global.md"
  printf '# Auth only\n**Modules affected:** [[auth]]\n' | mk "$K/01_adr/adr-auth-local.md"
  printf '# hub\n' | mk "$K/02_modules/auth.md"
  printf -- '---\nsurfaces: [portal, api]\n---\n# login\nSee [[../../02_modules/auth]].\n' | mk "$K/03_features/auth/login.md"
  printf -- '---\nid: auth::user\n---\n# user\n' | mk "$K/04_domain/auth/user/auth.user.md"
  printf -- '---\nid: auth::user::create\n---\n# create\n' | mk "$K/04_domain/auth/user/auth.user.create.md"
  printf -- '---\nid: auth.list\nmodule: auth\nscreen: list\n---\n# list\n## Bindings\n- nav: [[auth.detail]]\n' | mk "$K/05_screens/portal/auth/list.md"
  printf -- '---\nid: auth.detail\nmodule: auth\nscreen: detail\n---\n# d\n' | mk "$K/05_screens/portal/auth/detail.md"
  printf -- '---\nid: admin.auth.list\nmodule: auth\nscreen: list\n---\n# admin list\n' | mk "$K/05_screens/admin/auth/list.md"
  printf '# auth\n## Screens\n| a |\n## Navigation\nList goes to detail.\n\n## Other\nx\n' | mk "$K/05_screens/portal/auth/_index.md"
  printf '# list pattern\n**State:** implemented\n' | mk "$K/05_screens/patterns/list.md"
  printf '# ds\n' | mk "$K/05_screens/design-system.md"
  printf '{}\n' | mk "$K/05_screens/design-tokens.json"
  printf 'my own notes\n' | mk "$K/04_domain/auth/NOTES.txt"
  printf '# mail hub, no actions\n' | mk "$K/02_modules/mail.md"
}

P="$W/roster"; old_kb "$P"
mkdir -p "$P/.inspire"
printf '{ "kb_root": "inspire_kb", "spec_root": "inspire_kb/04_domain", "concurrency": 2 }\n' > "$P/.inspire/emanate.json"
printf 'image:\n  name: node:24\nfactory:\n  kb_root: inspire_kb\n  spec_root: inspire_kb/04_domain\n  concurrency: 2\n' > "$P/.inspire/emanate.yml"
before="$(cd "$P" && find inspire_kb -type f | LC_ALL=C sort | xargs shasum -a 256)"

out="$(cd "$P" && bash "$MIG" 2>&1)"; rc=$?
eq "a lib surface with no answer: exit 3"      "$rc" "3"
has "it asks what the lib surface becomes"     "$out" "ask	lib:kit"
eq "asking writes nothing" "$(cd "$P" && find inspire_kb -type f | LC_ALL=C sort | xargs shasum -a 256)" "$before"

out="$(cd "$P" && bash "$MIG" --dry-run --lib kit=design-system 2>&1)"; rc=$?
eq "a dry run with every answer: exit 0"       "$rc" "0"
has "the dry run prints the plan"              "$out" "move	inspire_kb/04_domain/auth/user/auth.user.md	inspire_kb/01_spec/_modules/auth/_domain/user/user.entity.md"
eq "a dry run writes nothing" "$(cd "$P" && find inspire_kb -type f | LC_ALL=C sort | xargs shasum -a 256)" "$before"

out="$(cd "$P" && bash "$MIG" --lib kit=design-system --skeleton "$PLUGIN_ROOT/base/kb/01_spec" 2>&1)"; rc=$?
eq "the migration exits 0" "$rc" "0"
S="$P/inspire_kb/01_spec"
check "no layered directory is left" \
  "[ ! -e '$P/inspire_kb/01_adr' ] && [ ! -e '$P/inspire_kb/02_modules' ] && [ ! -e '$P/inspire_kb/03_features' ] && [ ! -e '$P/inspire_kb/04_domain' ] && [ ! -e '$P/inspire_kb/05_screens' ]"
check "module hub"                 "[ -f '$S/_modules/auth/auth.module.md' ]"
check "feature"                    "[ -f '$S/_modules/auth/_features/login.feature.md' ]"
check "entity"                     "[ -f '$S/_modules/auth/_domain/user/user.entity.md' ]"
check "action keeps its entity"    "[ -f '$S/_modules/auth/_domain/user/user.create.action.md' ]"
check "global ADR"                 "[ -f '$S/_adr/global.adr.md' ]"
check "a one-face ADR goes to that face, with its rationale" \
  "[ -f '$S/_faces/admin/_adr/admin-rule.adr.md' ] && [ -f '$S/_faces/admin/_adr/admin-rule.adr.rationale.md' ]"
check "a one-module ADR goes to that module" "[ -f '$S/_modules/auth/_adr/auth-local.adr.md' ]"
check "screens go to their face"   "[ -f '$S/_faces/portal/_screens/list.screen.md' ] && [ -f '$S/_faces/admin/_screens/list.screen.md' ]"
check "catalog entries get their extension" "[ -f '$S/_design-system/patterns/list.pattern.md' ]"
check "the design system and its tokens move" \
  "[ -f '$S/_design-system/design-system.md' ] && [ -f '$S/_design-system/design-system.tokens.json' ]"
check "theme moves out of 00_bootstrap" "[ -f '$S/_design-system/theme.md' ] && [ ! -e '$P/inspire_kb/00_bootstrap/theme.md' ]"
check "a ui surface becomes a face file, with its packaging" \
  "grep -q '^package: apps/portal' '$S/_faces/portal/portal.face.md' && grep -q '^shell: /portal' '$S/_faces/portal/portal.face.md'"
check "a headless surface becomes a bundle of every module" \
  "grep -q '^package: apps/api' '$S/_bundles/api.bundle.md' && grep -qF -- '- [auth](../_modules/auth/auth.module.md) (whole module)' '$S/_bundles/api.bundle.md'"
check "a module with no action is not in the bundle" "! grep -q 'mail' '$S/_bundles/api.bundle.md'"
check "the lib chosen as design system makes no bundle" "[ ! -e '$S/_bundles/kit.bundle.md' ]"
check "the roster is retired, not deleted" "[ -f '$S/_migration/retired/00_bootstrap/surfaces.md' ] && [ ! -e '$P/inspire_kb/00_bootstrap/surfaces.md' ]"
check "a file it cannot place is kept under _migration/unplaced" "[ -f '$S/_migration/unplaced/04_domain/auth/NOTES.txt' ]"
N2="$W/ds-no-tokens"; mkdir -p "$N2/inspire_kb/05_screens"; printf '# our ds\n' > "$N2/inspire_kb/05_screens/design-system.md"
( cd "$N2" && bash "$MIG" --skeleton "$PLUGIN_ROOT/base/kb/01_spec" ) >/dev/null 2>&1
check "no default tokens beside a design system the project already has" \
  "[ ! -e '$N2/inspire_kb/01_spec/_design-system/design-system.tokens.json' ] && grep -q 'our ds' '$N2/inspire_kb/01_spec/_design-system/design-system.md'"
check "the skeleton is seeded around it" "[ -f '$S/README.md' ] && [ -f '$S/_processes/README.md' ]"

eq "a Factory spec_root pinned to a layer follows the KB" "$(jq -r .spec_root "$P/.inspire/emanate.json")" "inspire_kb/01_spec"
eq "and the rest of the Factory settings stay" "$(jq -r .concurrency "$P/.inspire/emanate.json")" "2"
eq "a factory.spec_root in emanate.yml pinned to a layer follows the KB" "$(yq -r .factory.spec_root "$P/.inspire/emanate.yml")" "inspire_kb/01_spec"
eq "and the rest of emanate.yml stays" "$(yq -r '.factory.concurrency + "/" + .image.name' "$P/.inspire/emanate.yml")" "2/node:24"

# Ids: nothing but a screen's changes, and every screen change is in the map.
eq "the entity id is unchanged" "$(yq --front-matter=extract '.id' "$S/_modules/auth/_domain/user/user.entity.md")" "auth::user"
eq "the action id is unchanged" "$(yq --front-matter=extract '.id' "$S/_modules/auth/_domain/user/user.create.action.md")" "auth::user::create"
eq "a screen id becomes {face}.{slug}" "$(yq --front-matter=extract '.id' "$S/_faces/portal/_screens/list.screen.md")" "portal.list"
eq "module: and screen: stay, so the route does not change" \
  "$(yq --front-matter=extract '.module + "/" + .screen' "$S/_faces/portal/_screens/list.screen.md")" "auth/list"
eq "the id map lists every screen id that changed" \
  "$(jq -c '.screens' "$S/_migration/id-map.json")" '{"admin.auth.list":"admin.list","auth.detail":"portal.detail","auth.list":"portal.list"}'
check "a link inside ## Bindings is not rewritten" "grep -q -- '- nav: \[\[auth.detail\]\]' '$S/_faces/portal/_screens/list.screen.md'"
check "the moves rewrite no link" "grep -qF 'See [[../../02_modules/auth]].' '$S/_modules/auth/_features/login.feature.md'"

# surfaces: becomes faces: / bundles:, and goes where placement already says it.
eq "a feature's surfaces: splits by kind" \
  "$(yq --front-matter=extract '(.faces | join(",")) + "|" + (.bundles | join(","))' "$S/_modules/auth/_features/login.feature.md")" "portal|api"
check "surfaces: all goes away" "! grep -q '^surfaces:' '$S/_adr/global.adr.md' && ! grep -q '^---' '$S/_adr/global.adr.md'"
check "a face-scoped ADR drops the field" "! grep -q 'surfaces:\|faces:' '$S/_faces/admin/_adr/admin-rule.adr.md'"

# The face's navigation keeps each module's prose and drops the screens table.
check "navigation prose is kept" "grep -q 'List goes to detail.' '$S/_faces/portal/_index.md'"
check "the screens table is dropped" "! grep -q '| a |' '$S/_faces/portal/_index.md'"

# Nothing of the operator's is lost: every original body is still somewhere.
lost=0
while IFS= read -r line; do
  grep -rqF -- "$line" "$S" || lost=$((lost + 1))
done < <(printf '%s\n' 'Admin rule' 'Auth only' '# hub' '# login' '# user' '# create' '# admin list' '# list pattern' '# ds' 'my own notes' '# why')
eq "every original body survives somewhere under 01_spec" "$lost" "0"

out="$(cd "$P" && bash "$MIG" --lib kit=design-system 2>&1)"; rc=$?
eq "a second run is a no-op" "$rc" "0"
has "and says so" "$out" "already migrated"

# Once the moves are committed, migrate-links.sh converts the links from the saved
# move plan (adr-markdown-links D6).
out="$(cd "$P" && bash "$PLUGIN_ROOT/scripts/migrate-links.sh" 2>&1)"
check "a path link follows its target through the move plan" \
  "grep -qF 'See [auth](../auth.module.md).' '$S/_modules/auth/_features/login.feature.md'"
check "an id link becomes a path from the linking file" \
  "grep -qF '**Modules affected:** [auth](../auth.module.md)' '$S/_modules/auth/_adr/auth-local.adr.md'"
check "a link inside ## Bindings keeps the old screen id as its text and points at the screen" \
  "grep -q -- '- nav: \[auth.detail\](detail.screen.md)' '$S/_faces/portal/_screens/list.screen.md'"
check "a link to nothing stays as written" "grep -qF '[[billing]]' '$S/_adr/global.adr.md'"
has "and the run lists it" "$out" "unresolved	inspire_kb/01_spec/_adr/global.adr.md"
check "the link plan is saved beside the move plan" "grep -q '^link	' '$S/_migration/links.tsv'"

# A half-migrated KB is refused, never merged into.
H="$W/half"; old_kb "$H"; mkdir -p "$H/inspire_kb/01_spec"
out="$(cd "$H" && bash "$MIG" --lib kit=design-system 2>&1)"; rc=$?
eq "01_spec beside layered directories: refused" "$rc" "1"
has "the refusal names it" "$out" "half-migrated"

# A screen id used twice cannot be mapped: refused.
D="$W/dup"; old_kb "$D"
sed -i.bak 's/^id: admin.auth.list$/id: auth.list/' "$D/inspire_kb/05_screens/admin/auth/list.md" && rm -f "$D/inspire_kb/05_screens/admin/auth/list.md.bak"
out="$(cd "$D" && bash "$MIG" --lib kit=design-system 2>&1)"; rc=$?
eq "a repeated screen id: refused" "$rc" "1"
check "and nothing moved" "[ -d '$D/inspire_kb/05_screens' ] && [ ! -e '$D/inspire_kb/01_spec' ]"

# No roster: one face for every screen and one bundle for every module, both asked.
N="$W/noroster"
mkdir -p "$N/inspire_kb/04_domain/shop/order" "$N/inspire_kb/05_screens/shop"
printf -- '---\nid: shop::order\n---\n# o\n' > "$N/inspire_kb/04_domain/shop/order/shop.order.md"
printf -- '---\nid: shop::order::place\n---\n# p\n' > "$N/inspire_kb/04_domain/shop/order/shop.order.place.md"
printf -- '---\nid: shop.cart\nmodule: shop\nscreen: cart\n---\n# c\n' > "$N/inspire_kb/05_screens/shop/cart.md"
out="$(cd "$N" && bash "$MIG" 2>&1)"; rc=$?
eq "no roster: exit 3 until the face and bundle are named" "$rc" "3"
has "it asks for the face" "$out" "ask	face"
has "it asks for the bundle" "$out" "ask	bundle"
( cd "$N" && bash "$MIG" --face shop-web --bundle api --bundle-package apps/api ) >/dev/null 2>&1
check "the one face holds the screen" "[ -f '$N/inspire_kb/01_spec/_faces/shop-web/_screens/cart.screen.md' ]"
eq "its id names the face" "$(yq --front-matter=extract '.id' "$N/inspire_kb/01_spec/_faces/shop-web/_screens/cart.screen.md")" "shop-web.cart"
check "the one bundle groups every module, with its package" \
  "grep -q '^package: apps/api' '$N/inspire_kb/01_spec/_bundles/api.bundle.md' && grep -qF '[shop](../_modules/shop/shop.module.md)' '$N/inspire_kb/01_spec/_bundles/api.bundle.md'"
check "the face uses the bundle" "grep -q '^bundles: \[api\]' '$N/inspire_kb/01_spec/_faces/shop-web/shop-web.face.md'"

# No screens, no roster: modules and domain only — no face, no bundle.
M="$W/domainonly"
mkdir -p "$M/inspire_kb/04_domain/shop/order"
printf -- '---\nid: shop::order\n---\n# o\n' > "$M/inspire_kb/04_domain/shop/order/shop.order.md"
( cd "$M" && bash "$MIG" ) >/dev/null 2>&1; rc=$?
eq "domain only: nothing to ask" "$rc" "0"
check "no face and no bundle are invented" "[ ! -e '$M/inspire_kb/01_spec/_faces' ] && [ ! -e '$M/inspire_kb/01_spec/_bundles' ]"

# A KB that was valid before the migration is valid after: the released golden
# fixtures, in their layered form, through the migration and the validators.
V="$W/valid"; mkdir -p "$V/old"
if git -C "$REPO" rev-parse -q --verify 'origin/release/0.15.0^{commit}' >/dev/null 2>&1; then
  git -C "$REPO" archive origin/release/0.15.0 plugin/base/bin/test/fixtures/entity-coherence/coherent \
    plugin/base/bin/test/fixtures/screen-coherence/clean | tar -x -C "$V/old"
  FX="$V/old/plugin/base/bin/test/fixtures"
  for case in entity-coherence/coherent screen-coherence/clean; do
    d="$V/${case%%/*}"; mkdir -p "$d/inspire_kb"
    [ -d "$FX/$case/spec/kb" ] && cp -R "$FX/$case/spec/kb/." "$d/inspire_kb/"
    [ -d "$FX/$case/spec/sdd" ] && { mkdir -p "$d/inspire_kb/04_domain"; cp -R "$FX/$case/spec/sdd/." "$d/inspire_kb/04_domain/"; }
    ( cd "$d" && bash "$MIG" --face app --bundle api ) >/dev/null 2>&1
    rule="${case%%/*}"
    ( cd "$d" && "$PLUGIN_ROOT/base/bin/$rule.sh" ) >/dev/null 2>"$d/findings"; rc=$?
    eq "$case: valid before the migration, valid after" "$rc" "0"
  done
else
  skipped 2 "origin/release/0.15.0 is not fetched: no layered golden fixtures to migrate"
fi

summary
