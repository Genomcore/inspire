#!/usr/bin/env bash
# plugin/base/bin/test/test-trust.sh — behavioural tests for `trust.sh`
#
# trust.sh is a tool, not a review rule: it emits no findings, so the golden
# fixture runner (run-tests.sh, which discovers fixtures/<rule>/<scenario>/)
# cannot exercise it. This script is wired into run-tests.sh explicitly.
#
# Every test builds its own scratch tree under one mktemp -d root — no fixture
# lives in the repo, because the trees here are cheap and their point is the
# hashes, which must be path-independent.
#
# Usage: bash plugin/base/bin/test/test-trust.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
TRUST="$HERE/../trust.sh"
TODAY="$(date +%Y-%m-%d)"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
ne(){ if [ "$2" != "$3" ]; then ok "$1"; else bad "$1 (both are '$2')"; fi; }
yes(){ if [ -n "$2" ]; then ok "$1"; else bad "$1 (empty)"; fi; }
has(){ if printf '%s\n' "$3" | grep -q -- "$2"; then ok "$1"; else bad "$1 (no match for '$2')"; fi; }
hasnt(){ if printf '%s\n' "$3" | grep -q -- "$2"; then bad "$1 (unexpected match for '$2')"; else ok "$1"; fi; }
filesame(){ if diff -u "$2" "$3" >/dev/null 2>&1; then ok "$1"; else bad "$1 (differs)"; fi; }

if [ ! -x "$TRUST" ]; then
  echo "FAIL trust.sh is not executable at $TRUST" >&2
  echo ""; echo "Passed: 0 · Failed: 1"
  exit 1
fi

ROOT="$(mktemp -d -t inspire-trust-test.XXXXXX)" || exit 1
trap 'rm -rf "$ROOT"' EXIT

# Everything after the frontmatter's closing `---`. Used to prove a stamp never
# disturbs the body.
body_after_fm(){ awk 'BEGIN{n=0}{ if(n<2 && $0=="---"){n++; next} if(n==2) print }' "$1"; }

fm(){ yq --front-matter=extract -r "$2 // \"\"" "$1" 2>/dev/null; }

# Content is unique per skill, and deliberately so: the hash is path-independent,
# so byte-identical skill dirs would all hash the SAME. Every assertion that a
# stamp was compared against the RIGHT owner's directory would then pass whether
# the ownership map was consulted or not — the vacuous-assertion trap this repo
# documents. Unique content is what makes those assertions mean anything.
mkskill(){ mkdir -p "$1"; printf '# skill %s\n\nrules for %s.\n' "${1##*/}" "${1##*/}" > "$1/SKILL.md"; }

# The block of a group in the full report, header excluded. Group headers are
# the only ALL-CAPS lines that start at column 0.
group_block(){
  printf '%s\n' "$2" | awk -v g="$1" '
    $0 ~ "^" g " \\(" { on=1; next }
    on && /^[A-Z]/ { exit }
    on { print }
  '
}
group_count(){ printf '%s\n' "$2" | sed -n "s/^$1 (\([0-9]*\))\$/\1/p"; }

# ═══════════════════════════════════════════════════════════════════════════
# skill-sha
# ═══════════════════════════════════════════════════════════════════════════

D="$ROOT/sha"; mkdir -p "$D/sub/deep"
printf 'alpha\n'  > "$D/a.md"
printf 'beta\n'   > "$D/sub/b.md"
printf 'gamma\n'  > "$D/sub/deep/c.md"

short="$("$TRUST" skill-sha "$D")"
full="$("$TRUST" skill-sha "$D" --full)"

eq  "skill-sha: default is 7 lowercase hex" "$(printf '%s' "$short" | grep -cE '^[0-9a-f]{7}$')" "1"
eq  "skill-sha: --full is 64 lowercase hex" "$(printf '%s' "$full"  | grep -cE '^[0-9a-f]{64}$')" "1"
eq  "skill-sha: short is the prefix of full" "$short" "${full:0:7}"
eq  "skill-sha: deterministic across runs" "$("$TRUST" skill-sha "$D")" "$short"

cp -R "$D" "$ROOT/sha-copy"
eq  "skill-sha: a copy at another path hashes identically" "$("$TRUST" skill-sha "$ROOT/sha-copy")" "$short"

printf 'ALPHA\n' > "$ROOT/sha-copy/a.md"
ne  "skill-sha: a content change moves the hash" "$("$TRUST" skill-sha "$ROOT/sha-copy")" "$short"

cp -R "$D" "$ROOT/sha-ren"; mv "$ROOT/sha-ren/a.md" "$ROOT/sha-ren/z.md"
ne  "skill-sha: a rename moves the hash" "$("$TRUST" skill-sha "$ROOT/sha-ren")" "$short"

cp -R "$D" "$ROOT/sha-hid"
printf 'junk\n' > "$ROOT/sha-hid/.DS_Store"
printf 'junk\n' > "$ROOT/sha-hid/sub/.DS_Store"
mkdir -p "$ROOT/sha-hid/sub/deep/.cache"; printf 'junk\n' > "$ROOT/sha-hid/sub/deep/.cache/x"
eq  "skill-sha: hidden files and dirs excluded at any depth" "$("$TRUST" skill-sha "$ROOT/sha-hid")" "$short"

rc=0; "$TRUST" skill-sha "$D/a.md"  >/dev/null 2>&1 || rc=$?
eq  "skill-sha: a regular file exits 2" "$rc" "2"
rc=0; "$TRUST" skill-sha "$ROOT/absent" >/dev/null 2>&1 || rc=$?
eq  "skill-sha: a missing path exits 2" "$rc" "2"

mkdir -p "$ROOT/sha-empty"
rc=0; empty_sha="$("$TRUST" skill-sha "$ROOT/sha-empty")" || rc=$?
eq  "skill-sha: an empty dir succeeds" "$rc" "0"
yes "skill-sha: an empty dir still yields a hash" "$empty_sha"

# ═══════════════════════════════════════════════════════════════════════════
# stamp
# ═══════════════════════════════════════════════════════════════════════════

P="$ROOT/proj"
mkdir -p "$P/.claude/skills/_references"
for s in adr module feature domain screens bootstrap; do mkskill "$P/.claude/skills/inspire-$s"; done
printf 'surface scoping rules.\n' > "$P/.claude/skills/_references/surface-scope.md"
printf '{"inspire_version":"0.5.0","released":"2026-08-01","template_sha":"deadbee","installed_at":"2026-08-01"}\n' \
  > "$P/.inspire.lock"
git init -q "$P" >/dev/null 2>&1
git -C "$P" config user.email "tester@example.com"

SHA_DOMAIN="$("$TRUST" skill-sha "$P/.claude/skills/inspire-domain")"
SHA_SCREENS="$("$TRUST" skill-sha "$P/.claude/skills/inspire-screens")"
SHA_REFS="$("$TRUST" skill-sha "$P/.claude/skills/_references")"

# ── a file that already has frontmatter, including an endorsement ──────────
WITH="$P/inspire_kb/04_domain/auth/user/auth.user.md"
mkdir -p "$(dirname "$WITH")"
cat > "$WITH" <<'EOF'
---
lifecycle: draft
endorsed:
  by: "@dario"
  at: 2026-09-13
---

# auth::user

Body paragraph with `backticks` and a [[wikilink]].
EOF
cp "$WITH" "$ROOT/orig-with-fm.md"

rc=0; ( cd "$P" && "$TRUST" stamp inspire_kb/04_domain/auth/user/auth.user.md --skill domain ) >/dev/null || rc=$?
eq "stamp: exits 0"                "$rc" "0"
eq "stamp: produced.skill"         "$(fm "$WITH" '.produced.skill')"     "domain"
eq "stamp: produced.skill_sha"     "$(fm "$WITH" '.produced.skill_sha')" "$SHA_DOMAIN"
eq "stamp: produced.refs_sha"      "$(fm "$WITH" '.produced.refs_sha')"  "$SHA_REFS"
eq "stamp: produced.inspire"       "$(fm "$WITH" '.produced.inspire')"   "0.5.0"
eq "stamp: produced.at"            "$(fm "$WITH" '.produced.at')"        "$TODAY"
eq "stamp: leaves other keys be"   "$(fm "$WITH" '.lifecycle')"          "draft"
filesame "stamp: endorsed block byte-for-byte" \
  <(grep -A2 '^endorsed:' "$WITH") <(grep -A2 '^endorsed:' "$ROOT/orig-with-fm.md")
filesame "stamp: body byte-for-byte" \
  <(body_after_fm "$WITH") <(body_after_fm "$ROOT/orig-with-fm.md")

# ── re-stamping overwrites the whole block ────────────────────────────────
yq -i --front-matter=process '.produced.skill_sha = "0000000" | .produced.leftover = "x"' "$WITH"
( cd "$P" && "$TRUST" stamp inspire_kb/04_domain/auth/user/auth.user.md --skill domain ) >/dev/null
eq "re-stamp: exactly one produced block"   "$(grep -c '^produced:' "$WITH")" "1"
eq "re-stamp: sha back to the real one"     "$(fm "$WITH" '.produced.skill_sha')" "$SHA_DOMAIN"
eq "re-stamp: a foreign produced key is gone" "$(fm "$WITH" '.produced.leftover')" ""
eq "re-stamp: endorsement still there"      "$(fm "$WITH" '.endorsed.by')" "@dario"

# ── a file with no frontmatter at all (screens ship this way) ──────────────
NOFM="$P/inspire_kb/05_screens/login.md"
mkdir -p "$(dirname "$NOFM")"
printf '# Login\n\nA screen that ships without frontmatter.\n' > "$NOFM"
cp "$NOFM" "$ROOT/orig-no-fm.md"

( cd "$P" && "$TRUST" stamp inspire_kb/05_screens/login.md --skill screens ) >/dev/null
eq "stamp (no frontmatter): all five keys, in order" \
  "$(yq --front-matter=extract -r '.produced | keys | join(",")' "$NOFM" 2>/dev/null)" \
  "skill,skill_sha,refs_sha,inspire,at"
eq "stamp (no frontmatter): skill_sha is the screens dir" "$(fm "$NOFM" '.produced.skill_sha')" "$SHA_SCREENS"
filesame "stamp (no frontmatter): body byte-for-byte" \
  <(body_after_fm "$NOFM") "$ROOT/orig-no-fm.md"

# ── --skills override, and a missing lock ─────────────────────────────────
ALT="$ROOT/altskills"; mkdir -p "$ALT/_references"; mkskill "$ALT/inspire-adr"
printf 'other refs\n' > "$ALT/_references/r.md"
NOLOCK="$ROOT/nolock"; mkdir -p "$NOLOCK/inspire_kb/01_adr"
printf -- '---\nid: adr-x\n---\n\n# ADR\n' > "$NOLOCK/inspire_kb/01_adr/adr-x.md"
( cd "$NOLOCK" && "$TRUST" stamp inspire_kb/01_adr/adr-x.md --skill adr --skills "$ALT" ) >/dev/null
eq "stamp: --skills root honoured" \
  "$(fm "$NOLOCK/inspire_kb/01_adr/adr-x.md" '.produced.skill_sha')" "$("$TRUST" skill-sha "$ALT/inspire-adr")"
eq "stamp: no .inspire.lock means inspire: unknown" \
  "$(fm "$NOLOCK/inspire_kb/01_adr/adr-x.md" '.produced.inspire')" "unknown"

rc=0; ( cd "$P" && "$TRUST" stamp inspire_kb/05_screens/login.md --skill ghost ) >/dev/null 2>&1 || rc=$?
ne "stamp: an uninstalled skill is an error, not a fake hash" "$rc" "0"

# ═══════════════════════════════════════════════════════════════════════════
# endorse
# ═══════════════════════════════════════════════════════════════════════════

grep -A5 '^produced:' "$NOFM" > "$ROOT/produced-before.txt"
rc=0; ( cd "$P" && "$TRUST" endorse inspire_kb/05_screens/login.md ) >/dev/null || rc=$?
eq "endorse: exits 0"        "$rc" "0"
eq "endorse: by is @ + the local part of git user.email" "$(fm "$NOFM" '.endorsed.by')" "@tester"
eq "endorse: at is today"    "$(fm "$NOFM" '.endorsed.at')" "$TODAY"
filesame "endorse: produced block byte-for-byte" \
  <(grep -A5 '^produced:' "$NOFM") "$ROOT/produced-before.txt"

# endorse must also work on a file that has no frontmatter yet
BARE="$P/inspire_kb/03_features/checkout.md"
mkdir -p "$(dirname "$BARE")"
printf '# Checkout\n\nno frontmatter.\n' > "$BARE"
( cd "$P" && "$TRUST" endorse inspire_kb/03_features/checkout.md ) >/dev/null
eq "endorse (no frontmatter): by written" "$(fm "$BARE" '.endorsed.by')" "@tester"
eq "endorse (no frontmatter): no produced block invented" "$(grep -c '^produced:' "$BARE")" "0"

NOMAIL="$ROOT/nomail"; mkdir -p "$NOMAIL"; git init -q "$NOMAIL" >/dev/null 2>&1
printf -- '---\nid: x\n---\n\n# x\n' > "$NOMAIL/a.md"
rc=0
( cd "$NOMAIL" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$TRUST" endorse a.md ) >/dev/null 2>&1 || rc=$?
ne "endorse: an unset git user.email is a clear error" "$rc" "0"
eq "endorse: nothing written when the email is unset" "$(grep -c '^endorsed:' "$NOMAIL/a.md")" "0"

# ═══════════════════════════════════════════════════════════════════════════
# report — one artifact per group
# ═══════════════════════════════════════════════════════════════════════════

R="$ROOT/rep"
mkdir -p "$R/.claude/skills/_references"
# inspire-feature is deliberately NOT installed — deleting a skill is legitimate
# use, and its artifacts must land in OWNER NOT INSTALLED, never in STALE.
for s in adr module domain screens bootstrap; do mkskill "$R/.claude/skills/inspire-$s"; done
printf 'surface scoping rules.\n' > "$R/.claude/skills/_references/surface-scope.md"
printf '{"inspire_version":"0.6.0","released":"2026-08-11","template_sha":"cafe123","installed_at":"2026-08-11"}\n' \
  > "$R/.inspire.lock"

R_ADR="$("$TRUST" skill-sha "$R/.claude/skills/inspire-adr")"
R_MOD="$("$TRUST" skill-sha "$R/.claude/skills/inspire-module")"
R_DOM="$("$TRUST" skill-sha "$R/.claude/skills/inspire-domain")"
R_SCR="$("$TRUST" skill-sha "$R/.claude/skills/inspire-screens")"
R_BOOT="$("$TRUST" skill-sha "$R/.claude/skills/inspire-bootstrap")"
R_REFS="$("$TRUST" skill-sha "$R/.claude/skills/_references")"

# Guard on the fixture itself: every owner must hash distinctly, or every
# "compared against the right owner" assertion below is vacuous.
eq "fixture: all six skill dirs hash distinctly" \
  "$(printf '%s\n' "$R_ADR" "$R_MOD" "$R_DOM" "$R_SCR" "$R_BOOT" "$R_REFS" | LC_ALL=C sort -u | grep -c .)" "6"

mkdir -p "$R/inspire_kb/00_bootstrap" "$R/inspire_kb/01_adr" "$R/inspire_kb/02_modules" \
         "$R/inspire_kb/03_features" "$R/inspire_kb/04_domain/auth/user" \
         "$R/inspire_kb/05_screens/patterns" "$R/inspire_kb/05_screens/components" \
         "$R/inspire_kb/05_screens/auth"

art(){ # art <path> <endorsed:yes|no> [skill sha refs]
  local path="$R/inspire_kb/$1" e="$2" skill="${3:-}" sha="${4:-}" refs="${5:-}"
  { printf -- '---\n'
    if [ "$e" = yes ]; then printf 'endorsed:\n  by: "@dario"\n  at: 2026-08-01\n'; fi
    if [ -n "$skill" ]; then
      printf 'produced:\n  skill: %s\n  skill_sha: "%s"\n  refs_sha: "%s"\n  inspire: 0.6.0\n  at: 2026-08-01\n' \
        "$skill" "$sha" "$refs"
    fi
    printf -- '---\n\n# %s\n' "$(basename "$1" .md)"
  } > "$path"
}

art 00_bootstrap/project.md   no                                  # UNENDORSED
art 00_bootstrap/stack.md     yes                                 # clean
art 00_bootstrap/theme.md     no                                  # skipped by filename
art 00_bootstrap/surfaces.md  no                                  # never scanned
art 01_adr/README.md          no                                  # skipped by filename
art 01_adr/adr-stale.md       yes adr     0000000   "$R_REFS"      # STALE
art 01_adr/adr-refs.md        yes adr     "$R_ADR"  0000000        # REFS-CHANGED
art 02_modules/_template.md   no                                  # skipped by filename
art 05_screens/auth/_index.md no  screens "$R_SCR"  "$R_REFS"      # produced-checked, never UNENDORSED
art 02_modules/billing.md     yes                                 # PRE-PROVENANCE
art 03_features/checkout.md   yes feature 0000000   "$R_REFS"      # OWNER NOT INSTALLED, not STALE
art 04_domain/auth/user/auth.user.md yes module "$R_DOM" "$R_REFS" # MISROUTED (owner is domain)
art 05_screens/design-system.md yes bootstrap "$R_BOOT" "$R_REFS"  # clean — DS is owned by bootstrap
art 05_screens/login.md       no                                  # UNENDORSED + PRE-PROVENANCE
art 05_screens/patterns/list.md no screens "$R_SCR" "$R_REFS"      # UNENDORSED — patterns/ became endorsable (T12)
art 05_screens/components/button.md yes screens "$R_SCR" "$R_REFS" # clean — endorsed AND fresh, the inverse positive

# An artifact with NO frontmatter whose BODY contains `endorsed:` and `produced:`
# at column 0 — a KB artifact documenting the stamp format is the obvious way to
# write one. yq's --front-matter=extract happily parses such a file as YAML (a
# markdown `# Heading` is a valid YAML comment) and hands back a real `by`, so
# without a frontmatter guard this file is silently counted as human-endorsed and
# machine-stamped. It must land in UNENDORSED and PRE-PROVENANCE.
cat > "$R/inspire_kb/01_adr/adr-stamp-format.md" <<'EOF'
# ADR — the artifact trust stamp format

endorsed:
  by: "@nobody"
  at: 2026-01-01
produced:
  skill: adr
  skill_sha: "deadbee"
  refs_sha: "deadbee"
  inspire: 0.6.0
  at: 2026-01-01
EOF

rc=0; FULL="$(cd "$R" && "$TRUST" report)" || rc=$?
eq "report: exits 0 with findings" "$rc" "0"

eq "report: UNENDORSED count"        "$(group_count UNENDORSED "$FULL")"            "4"
eq "report: STALE count"             "$(group_count STALE "$FULL")"                 "1"
eq "report: REFS-CHANGED count"      "$(group_count REFS-CHANGED "$FULL")"          "1"
eq "report: PRE-PROVENANCE count"    "$(group_count PRE-PROVENANCE "$FULL")"        "3"
eq "report: OWNER NOT INSTALLED count" "$(group_count 'OWNER NOT INSTALLED' "$FULL")" "1"
eq "report: MISROUTED count"         "$(group_count MISROUTED "$FULL")"             "1"

has "report: UNENDORSED lists project.md"  'inspire_kb/00_bootstrap/project.md' "$(group_block UNENDORSED "$FULL")"
has "report: UNENDORSED lists login.md"    'inspire_kb/05_screens/login.md'     "$(group_block UNENDORSED "$FULL")"
hasnt "report: endorsed stack.md is not UNENDORSED" 'stack.md' "$(group_block UNENDORSED "$FULL")"
hasnt "report: _index.md is never UNENDORSED" '_index.md'   "$(group_block UNENDORSED "$FULL")"
hasnt "report: catalog entries are never UNENDORSED" 'patterns/list.md' "$(group_block UNENDORSED "$FULL")"

# A body is not frontmatter: an `endorsed:` line in prose must never be mistaken
# for a human vouch, nor a `produced:` line for a stamp.
has "report: a body 'endorsed:' is not an endorsement" \
  'inspire_kb/01_adr/adr-stamp-format.md' "$(group_block UNENDORSED "$FULL")"
eq  "report: a body 'produced:' is not a stamp" \
  "$(printf '%s\n' "$FULL" | grep -c 'adr-stamp-format.md')" "1"
hasnt "report: the fabricated handle is never read out of a body" '@nobody' "$FULL"
hasnt "report: the fabricated sha is never read out of a body"    'deadbee' "$FULL"

has "report: STALE keyed by owner and stamped sha" \
  "adr stamped 0000000, now $R_ADR (1)" "$(group_block STALE "$FULL")"
has "report: STALE lists the artifact"             'inspire_kb/01_adr/adr-stale.md' "$(group_block STALE "$FULL")"
hasnt "report: an uninstalled owner is not STALE"  'checkout.md' "$(group_block STALE "$FULL")"
# Real only because every skill dir hashes distinctly: design-system.md is stamped
# with inspire-bootstrap's hash, so comparing it against inspire-screens (the
# positional owner) would put it in STALE.
hasnt "report: design-system.md compared against bootstrap, not screens" \
  'design-system.md' "$(group_block STALE "$FULL")"
has "report: STALE names the remedy"               'owning skill' "$FULL"

has "report: REFS-CHANGED names the current refs hash" "$R_REFS" "$(group_block REFS-CHANGED "$FULL")"
eq  "report: REFS-CHANGED is one line" \
  "$(group_block REFS-CHANGED "$FULL" | grep -c .)" "1"

has "report: OWNER NOT INSTALLED names the skill dir" 'inspire-feature' "$(group_block 'OWNER NOT INSTALLED' "$FULL")"
has "report: OWNER NOT INSTALLED lists the artifact"  'inspire_kb/03_features/checkout.md' "$(group_block 'OWNER NOT INSTALLED' "$FULL")"

# The full phrase, not the bare words: `module` and `domain` both already appear
# in the artifact's own path on that same line.
has "report: MISROUTED names the artifact, the stamped skill and the map owner" \
  "inspire_kb/04_domain/auth/user/auth.user.md — stamped skill 'module', the layer's owner is 'domain'" \
  "$(group_block MISROUTED "$FULL")"

hasnt "report: theme.md skipped by filename"     'theme.md'     "$FULL"
hasnt "report: README.md skipped by filename"    'README.md'    "$FULL"
hasnt "report: _template.md skipped by filename" '_template.md' "$FULL"
hasnt "report: 00_bootstrap beyond the two files is never scanned" 'surfaces.md' "$FULL"

# ── --summary: one line, counts matching the groups above ─────────────────
rc=0; SUM="$(cd "$R" && "$TRUST" report --summary)" || rc=$?
eq "report --summary: exits 0" "$rc" "0"
eq "report --summary: exactly one line" "$(printf '%s\n' "$SUM" | grep -c .)" "1"
eq "report --summary: counts match the full report" "$SUM" \
  "trust: 3 unendorsed · 1 stale (inspire-adr) · 1 refs-changed · 3 pre-provenance · 1 owner-missing · 1 misrouted — .inspire/bin/trust.sh report for detail"

# ── stamping the stale artifact clears it ─────────────────────────────────
( cd "$R" && "$TRUST" stamp inspire_kb/01_adr/adr-stale.md --skill adr ) >/dev/null
FRESH="$(cd "$R" && "$TRUST" report)"
eq "report: STALE is gone after a real re-stamp" "$(group_count STALE "$FRESH")" ""
hasnt "report --summary: no stale term after a real re-stamp" \
  'stale' "$(cd "$R" && "$TRUST" report --summary)"

# ── a wholly clean vault ─────────────────────────────────────────────────
C="$ROOT/clean"
mkdir -p "$C/.claude/skills/_references" "$C/inspire_kb/01_adr"
mkskill "$C/.claude/skills/inspire-adr"
printf 'refs\n' > "$C/.claude/skills/_references/r.md"
printf '{"inspire_version":"0.6.0"}\n' > "$C/.inspire.lock"
printf -- '---\nendorsed:\n  by: "@dario"\n  at: 2026-08-01\n---\n\n# ADR\n' > "$C/inspire_kb/01_adr/adr-ok.md"
( cd "$C" && "$TRUST" stamp inspire_kb/01_adr/adr-ok.md --skill adr ) >/dev/null

rc=0; CLEAN_FULL="$(cd "$C" && "$TRUST" report)" || rc=$?
eq "report (clean): exits 0" "$rc" "0"
has "report (clean): all-clear line" 'all stamped artifacts fresh' "$CLEAN_FULL"
hasnt "report (clean): no group headers" '^UNENDORSED' "$CLEAN_FULL"
rc=0; CLEAN_SUM="$(cd "$C" && "$TRUST" report --summary)" || rc=$?
eq "report --summary (clean): exits 0" "$rc" "0"
eq "report --summary (clean): all-fresh wording" "$CLEAN_SUM" "trust: all stamped artifacts fresh"

# ── no KB at all ─────────────────────────────────────────────────────────
E="$ROOT/empty"; mkdir -p "$E"
rc=0; ( cd "$E" && "$TRUST" report ) >/dev/null 2>&1 || rc=$?
eq "report (no inspire_kb): exits 0" "$rc" "0"
rc=0; ( cd "$E" && "$TRUST" report --summary ) >/dev/null 2>&1 || rc=$?
eq "report --summary (no inspire_kb): exits 0" "$rc" "0"

# ── --kb / --skills from an unrelated cwd ────────────────────────────────
OUT="$(cd "$ROOT" && "$TRUST" report --kb "$R/inspire_kb" --skills "$R/.claude/skills" --summary)"
has "report: --kb/--skills work from another cwd" 'unendorsed' "$OUT"

# ── the declared no-jq constraint, enforced ──────────────────────────────
mkdir -p "$ROOT/nojq"
printf '#!/bin/sh\necho "trust.sh must not require jq" >&2\nexit 127\n' > "$ROOT/nojq/jq"
chmod +x "$ROOT/nojq/jq"
NOJQ="$(cd "$R" && PATH="$ROOT/nojq:$PATH" "$TRUST" report --summary 2>/dev/null)"
eq "report: identical output with jq broken" "$NOJQ" "$(cd "$R" && "$TRUST" report --summary)"

# ═══════════════════════════════════════════════════════════════════════════
# Stub-guard — the freshness assertions must be sensitive to real hashing.
#
# The fixture's deliberately-stale stamp is the literal 0000000, so a copy whose
# directory hashing always answers 0000000 must FAIL to see it as stale. If the
# assertion still passes under the stub, it was never testing the comparison.
# ═══════════════════════════════════════════════════════════════════════════

STUB="$ROOT/trust-stubbed.sh"
sed 's/^trust_dir_sha() {$/trust_dir_sha() { echo 0000000; return 0; #/' "$TRUST" > "$STUB"
chmod +x "$STUB"
ne "stub-guard: the stub actually replaced the hasher" \
  "$(diff -q "$STUB" "$TRUST" >/dev/null 2>&1; echo $?)" "0"
eq "stub-guard: stubbed hashing answers 0000000" "$("$STUB" skill-sha "$D")" "0000000"

G="$ROOT/guard"
cp -R "$R" "$G"
# restore the stale stamp cleared above
yq -i --front-matter=process '.produced.skill_sha = "0000000"' "$G/inspire_kb/01_adr/adr-stale.md"
has "stub-guard: the real tool reports the stale artifact" 'adr-stale.md' \
  "$(group_block STALE "$(cd "$G" && "$TRUST" report)")"
hasnt "stub-guard: the stubbed tool cannot — the freshness assertion fails" 'adr-stale.md' \
  "$(group_block STALE "$(cd "$G" && "$STUB" report)")"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
