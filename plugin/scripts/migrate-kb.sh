#!/usr/bin/env bash
#
# plugin/scripts/migrate-kb.sh — move a knowledge base from the layered layout
# (01_adr … 05_screens) to the concept layout under 01_spec/ (adr-kb-structure).
#
# The engine behind /inspire:migrate. It asks nothing: every answer the operator
# owes comes in as a flag, and a run that needs one it was not given prints the
# question as an `ask` line and exits 3 without touching anything. The skill asks
# the operator and runs it again.
#
# Usage:
#   migrate-kb.sh [--kb DIR] [--dry-run]
#                 [--face ID]                  face for screens when there is no roster
#                 [--bundle ID]                bundle for every module when there is no roster
#                 [--bundle-package PATH]      that bundle's package
#                 [--bundle-modules ID=m1,m2]  modules a roster's headless surface serves (repeatable)
#                 [--lib ID=bundle|design-system]  what a roster's lib surface becomes (repeatable)
#                 [--shared-face ID]           face that receives 05_screens/shared/
#                 [--skeleton DIR]             the plugin's base/kb/01_spec: seed what is missing
#
# Output (stdout): the plan, one tab-separated line per step —
#   move <old> <new> · write <new> <what> · idmap <old-id> <new-id> ·
#   unplaced <old> <new> · seed <new> · note <text> · ask <key> <question>
# In act mode the same plan is applied and also saved to
# 01_spec/_migration/plan.tsv.
#
# Exit: 0 migrated (or nothing to do) · 1 refused · 2 usage · 3 an answer is missing.
#
# What it never does (adr-kb-structure D10): rename a module, entity or action;
# change any id but a screen's; rewrite a link inside a screen's `## Bindings`;
# extract a shared screen; create a process or an artifact bundle; run git.
#
# bash 3.2 compatible: no associative arrays, everything keyed goes through files.

set -uo pipefail

KB="inspire_kb"
DRY=0
FACE=""
BUNDLE=""
BUNDLE_PACKAGE=""
SHARED_FACE=""
SKELETON=""
BUNDLE_MODULES=""   # newline list of id=m1,m2
LIBS=""             # newline list of id=bundle|design-system

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --kb) KB="${2:?}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --face) FACE="${2:?}"; shift 2 ;;
    --bundle) BUNDLE="${2:?}"; shift 2 ;;
    --bundle-package) BUNDLE_PACKAGE="${2:?}"; shift 2 ;;
    --bundle-modules) BUNDLE_MODULES="$BUNDLE_MODULES${2:?}
"; shift 2 ;;
    --lib) LIBS="$LIBS${2:?}
"; shift 2 ;;
    --shared-face) SHARED_FACE="${2:?}"; shift 2 ;;
    --skeleton) SKELETON="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) printf 'migrate-kb: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

KB="${KB%/}"
SPEC="$KB/01_spec"
[ -d "$KB" ] || { printf 'migrate-kb: no knowledge base at %s\n' "$KB" >&2; exit 1; }

OLD_LAYERS="01_adr 02_modules 03_features 04_domain 05_screens"
has_old=0
for l in $OLD_LAYERS; do [ -d "$KB/$l" ] && has_old=1; done

if [ "$has_old" -eq 0 ]; then
  if [ -d "$SPEC" ]; then
    printf 'note\talready migrated: %s exists and no layered directory is left\n' "$SPEC"
  else
    printf 'note\tnothing to migrate: %s has no layered directory\n' "$KB"
  fi
  exit 0
fi
if [ -d "$SPEC" ]; then
  printf 'migrate-kb: %s exists next to the layered directories — a half-migrated knowledge base. Finish or undo the earlier run first.\n' "$SPEC" >&2
  exit 1
fi

WORK="$(mktemp -d -t inspire-migrate.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
PLAN="$WORK/plan.tsv"; : > "$PLAN"
ASK="$WORK/ask.tsv"; : > "$ASK"
ROSTER="$WORK/roster.tsv"; : > "$ROSTER"     # id kind package profiles shell name
IDMAP="$WORK/idmap.tsv"; : > "$IDMAP"
GEN="$WORK/gen"; mkdir -p "$GEN"               # generated files, written on apply
FMEDIT="$WORK/fmedit.tsv"; : > "$FMEDIT"       # new-path key value(-or-DELETE)

plan() { printf '%s\n' "$(IFS="$(printf '\t')"; echo "$*")" >> "$PLAN"; }
ask()  { printf '%s\t%s\n' "$1" "$2" >> "$ASK"; }

# ── frontmatter ─────────────────────────────────────────────────────────────
fm_get() {  # fm_get <file> <key>
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); sub(/[ \t]+$/, "", v)
      gsub(/^["\047]|["\047]$/, "", v)
      print v; exit
    }
  ' "$1"
}

# fm_apply <file> — apply every queued edit for <file> (keyed by its NEW path).
fm_apply() {
  local file="$1" target="$2" edits
  edits="$(awk -F'\t' -v f="$target" '$1 == f' "$FMEDIT")"
  [ -n "$edits" ] || return 0
  printf '%s\n' "$edits" > "$WORK/edits.one"
  awk -F'\t' -v ed="$WORK/edits.one" '
    BEGIN {
      while ((getline line < ed) > 0) {
        split(line, p, "\t"); n++; key[n] = p[2]; val[n] = p[3]; done[n] = 0
      }
    }
    NR == 1 && $0 != "---" { nofm = 1 }
    NR == 1 && nofm {
      print "---"
      for (i = 1; i <= n; i++) if (val[i] != "DELETE") print key[i] ": " val[i]
      print "---"
      print; next
    }
    NR == 1 { infm = 1; print; next }
    infm && $0 == "---" {
      for (i = 1; i <= n; i++) if (!done[i] && val[i] != "DELETE") print key[i] ": " val[i]
      infm = 0; print; next
    }
    infm {
      for (i = 1; i <= n; i++) {
        if (index($0, key[i] ":") == 1) {
          done[i] = 1
          if (val[i] == "DELETE") next
          print key[i] ": " val[i]; next
        }
      }
    }
    { print }
  ' "$file" > "$file.mig" && mv "$file.mig" "$file"
  # A frontmatter left with no key is dropped rather than kept as two bare fences.
  if [ "$(sed -n '1p' "$file")" = "---" ] && [ "$(sed -n '2p' "$file")" = "---" ]; then
    sed '1,2d' "$file" > "$file.mig" && mv "$file.mig" "$file"
  fi
}

fm_queue() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$FMEDIT"; }

# ── roster ──────────────────────────────────────────────────────────────────
ROSTER_FILE="$KB/00_bootstrap/surfaces.md"
if [ -f "$ROSTER_FILE" ]; then
  awk '
    function flush() { if (id != "") printf "%s\t%s\t%s\t%s\t%s\t%s\n", id, kind, pkg, prof, shell, name }
    /^## / { flush(); id = substr($0, 4); gsub(/[ \t]+$/, "", id); kind = pkg = prof = shell = name = ""; next }
    function val(s) { sub(/^\*\*[A-Za-z]+:\*\*[ \t]*/, "", s); gsub(/[ \t]+$/, "", s); return s }
    /^\*\*Kind:\*\*/     { kind = val($0) }
    /^\*\*Package:\*\*/  { pkg = val($0) }
    /^\*\*Profiles:\*\*/ { prof = val($0) }
    /^\*\*Shell:\*\*/    { shell = val($0) }
    /^\*\*Name:\*\*/     { name = val($0) }
    END { flush() }
  ' "$ROSTER_FILE" > "$ROSTER"
fi
roster_kind() { awk -F'\t' -v i="$1" '$1 == i { print $2; exit }' "$ROSTER"; }
ui_ids()       { awk -F'\t' '$2 == "ui" { print $1 }' "$ROSTER"; }
headless_ids() { awk -F'\t' '$2 == "headless" { print $1 }' "$ROSTER"; }
lib_ids()      { awk -F'\t' '$2 == "lib" { print $1 }' "$ROSTER"; }
lib_choice()   { printf '%s' "$LIBS" | awk -F= -v i="$1" '$1 == i { print $2; exit }'; }
bundle_mods()  { printf '%s' "$BUNDLE_MODULES" | awk -F= -v i="$1" '$1 == i { print $2; exit }'; }

MODULES="$WORK/modules.txt"
{
  [ -d "$KB/02_modules" ] && find "$KB/02_modules" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' ! -name '_*' \
    | sed 's|.*/||; s|\.md$||'
  [ -d "$KB/04_domain" ] && find "$KB/04_domain" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | sed 's|.*/||'
  [ -d "$KB/03_features" ] && find "$KB/03_features" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | sed 's|.*/||'
} | sort -u > "$MODULES"

# ── decide faces and bundles ─────────────────────────────────────────────────
# FACES: id|package|profiles|shell|name ; BUNDLES: id|package|profiles|modules(csv).
# `|`, not a tab: `read` collapses runs of a whitespace IFS, so an empty field would shift the rest.
FACES="$WORK/faces.tsv"; : > "$FACES"
BUNDLES="$WORK/bundles.tsv"; : > "$BUNDLES"
DS_LIBS="$WORK/ds-libs.txt"; : > "$DS_LIBS"

has_screens=0
if [ -d "$KB/05_screens" ]; then
  if find "$KB/05_screens" -type f -name '*.md' | awk -F'/05_screens/' '
      { n = split($2, s, "/"); if (n < 2) next
        if (s[1] == "patterns" || s[1] == "components" || s[1] == "layouts") next
        if (s[n] == "README.md" || s[n] == "_index.md") next
        found = 1; exit }
      END { exit !found }'; then
    has_screens=1
  fi
fi

all_modules_csv="$(paste -sd, "$MODULES")"

if [ -s "$ROSTER" ]; then
  awk -F'\t' '$2 == "ui" { printf "%s|%s|%s|%s|%s\n", $1, $3, $4, $5, $6 }' "$ROSTER" > "$FACES"
  n_headless="$(headless_ids | wc -l | tr -d ' ')"
  for h in $(headless_ids); do
    mods="$(bundle_mods "$h")"
    if [ -z "$mods" ]; then
      if [ "$n_headless" -eq 1 ]; then
        mods="$all_modules_csv"
      else
        ask "bundle-modules:$h" "Which modules does the headless surface '$h' serve? Pass --bundle-modules $h=m1,m2"
        continue
      fi
    fi
    awk -F'\t' -v i="$h" -v m="$mods" '$1 == i { printf "%s|%s|%s|%s\n", $1, $3, $4, m }' "$ROSTER" >> "$BUNDLES"
  done
  for l in $(lib_ids); do
    c="$(lib_choice "$l")"
    case "$c" in
      bundle)
        mods="$(bundle_mods "$l")"
        awk -F'\t' -v i="$l" -v m="$mods" '$1 == i { printf "%s|%s|%s|%s\n", $1, $3, $4, m }' "$ROSTER" >> "$BUNDLES" ;;
      design-system) printf '%s\n' "$l" >> "$DS_LIBS" ;;
      *) ask "lib:$l" "The lib surface '$l' becomes a bundle or part of the design system? Pass --lib $l=bundle or --lib $l=design-system" ;;
    esac
  done
else
  if [ "$has_screens" -eq 1 ]; then
    if [ -z "$FACE" ]; then
      ask "face" "Every screen moves to one face. What is its id? (suggested: the project's name, kebab-case) Pass --face ID"
    else
      printf '%s||||\n' "$FACE" > "$FACES"
    fi
    if [ -s "$MODULES" ]; then
      if [ -z "$BUNDLE" ]; then
        ask "bundle" "Every module is exposed by one bundle. What is its id? (suggested: api) Pass --bundle ID [--bundle-package PATH]"
      else
        printf '%s|%s||%s\n' "$BUNDLE" "$BUNDLE_PACKAGE" "$all_modules_csv" > "$BUNDLES"
      fi
    fi
  fi
fi

# A shared tree needs a home.
if [ -d "$KB/05_screens/shared" ] && [ -z "$SHARED_FACE" ]; then
  ask "shared-face" "05_screens/shared/ holds screens used by more than one face. Which face keeps them? Pass --shared-face ID"
fi

# Reserved: a user-chosen id never starts with `_`.
for id in $(cut -d"|" -f1 "$FACES") $(cut -d"|" -f1 "$BUNDLES") $(cat "$MODULES"); do
  case "$id" in _*) printf 'migrate-kb: id %s starts with `_`, which is reserved for INSPIRE structure. Rename it first.\n' "$id" >&2; exit 1 ;; esac
done

if [ -s "$ASK" ]; then
  awk -F'\t' '{ printf "ask\t%s\t%s\n", $1, $2 }' "$ASK"
  exit 3
fi

face_ids_csv="$(cut -d"|" -f1 "$FACES" | paste -sd, -)"
bundle_ids_csv="$(cut -d"|" -f1 "$BUNDLES" | paste -sd, -)"

# convert_surfaces <value> — prints "faces<TAB>bundles" (bracketed lists, empty when none)
convert_surfaces() {
  local raw="$1" ids f="" b="" id k
  raw="${raw#[}"; raw="${raw%]}"
  ids="$(printf '%s' "$raw" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')"
  for id in $ids; do
    [ "$id" = "all" ] && { printf '\t\n'; return; }
    k="$(roster_kind "$id")"
    case "$k" in
      ui) f="$f${f:+, }$id" ;;
      headless) b="$b${b:+, }$id" ;;
      lib) [ "$(lib_choice "$id")" = "bundle" ] && b="$b${b:+, }$id" ;;
      *) if [ -n "$FACE" ] || grep -qx "$id" <(cut -d"|" -f1 "$FACES"); then f="$f${f:+, }$id"; fi ;;
    esac
  done
  printf '%s\t%s\n' "${f:+[$f]}" "${b:+[$b]}"
}

queue_surfaces() {  # queue_surfaces <old-file> <new-path> [drop]
  local s fb fv bv
  s="$(fm_get "$1" surfaces)"
  [ -n "$s" ] || return 0
  fm_queue "$2" surfaces DELETE
  [ "${3:-}" = "drop" ] && return 0
  fb="$(convert_surfaces "$s")"
  fv="${fb%%	*}"; bv="${fb#*	}"
  [ -n "$fv" ] && fm_queue "$2" faces "$fv"
  [ -n "$bv" ] && fm_queue "$2" bundles "$bv"
  return 0
}

unplaced() { plan unplaced "$1" "$SPEC/_migration/unplaced/${1#$KB/}"; }

# ── 01_adr ───────────────────────────────────────────────────────────────────
if [ -d "$KB/01_adr" ]; then
  while IFS= read -r f; do
    b="${f##*/}"
    case "$b" in
      adr-*.rationale.md) continue ;;   # moved with its decision
      adr-*.md) ;;
      *) unplaced "$f"; continue ;;
    esac
    slug="${b#adr-}"; slug="${slug%.md}"
    dest="$SPEC/_adr"
    s="$(fm_get "$f" surfaces)"
    drop=""
    if [ -n "$s" ]; then
      fb="$(convert_surfaces "$s")"; fv="${fb%%	*}"; bv="${fb#*	}"
      one="${fv#[}"; one="${one%]}"
      if [ -n "$fv" ] && [ -z "$bv" ] && [ "${one#*,}" = "$one" ]; then
        dest="$SPEC/_faces/$one/_adr"; drop=drop
      fi
    fi
    if [ "$dest" = "$SPEC/_adr" ]; then
      mods="$(awk 'index($0, "**Modules affected:**") == 1 { print; exit }' "$f" \
        | grep -oE '\[\[[^]|]+' | sed 's/^\[\[//; s|.*/||' | sort -u)"
      if [ -n "$mods" ] && [ "$(printf '%s\n' "$mods" | wc -l | tr -d ' ')" -eq 1 ] && grep -qx "$mods" "$MODULES"; then
        dest="$SPEC/_modules/$mods/_adr"
      fi
    fi
    plan move "$f" "$dest/$slug.adr.md"
    queue_surfaces "$f" "$dest/$slug.adr.md" $drop
    r="${f%.md}.rationale.md"
    [ -f "$r" ] && plan move "$r" "$dest/$slug.adr.rationale.md"
  done < <(find "$KB/01_adr" -type f ! -name '.gitkeep' | sort)
  # A rationale whose decision is missing is still a rationale: it moves to the global
  # ADRs under its typed name, where sections-present reports the missing decision.
  while IFS= read -r r; do
    [ -f "${r%.rationale.md}.md" ] && continue
    slug="${r##*/adr-}"; slug="${slug%.rationale.md}"
    plan move "$r" "$SPEC/_adr/$slug.adr.rationale.md"
    plan note "$r has no decision beside it; moved to the global ADRs"
  done < <(find "$KB/01_adr" -type f -name 'adr-*.rationale.md' | sort)
fi

# ── 02_modules ───────────────────────────────────────────────────────────────
if [ -d "$KB/02_modules" ]; then
  while IFS= read -r f; do
    b="${f##*/}"
    case "$b" in
      README.md|_*) unplaced "$f" ;;
      *.md) m="${b%.md}"; plan move "$f" "$SPEC/_modules/$m/$m.module.md" ;;
      *) unplaced "$f" ;;
    esac
  done < <(find "$KB/02_modules" -type f ! -name '.gitkeep' | sort)
fi

# ── 03_features ──────────────────────────────────────────────────────────────
if [ -d "$KB/03_features" ]; then
  while IFS= read -r f; do
    rel="${f#$KB/03_features/}"
    b="${f##*/}"
    case "$rel" in
      */*/*) unplaced "$f" ;;
      */README.md|*/_*) unplaced "$f" ;;
      */*.md)
        m="${rel%%/*}"; uc="${b%.md}"
        plan move "$f" "$SPEC/_modules/$m/_features/$uc.feature.md"
        queue_surfaces "$f" "$SPEC/_modules/$m/_features/$uc.feature.md" ;;
      *) unplaced "$f" ;;
    esac
  done < <(find "$KB/03_features" -type f ! -name '.gitkeep' | sort)
fi

# ── 04_domain ────────────────────────────────────────────────────────────────
if [ -d "$KB/04_domain" ]; then
  while IFS= read -r f; do
    rel="${f#$KB/04_domain/}"
    b="${f##*/}"
    case "$rel" in
      */*/*.md)
        m="${rel%%/*}"; rest="${rel#*/}"; e="${rest%%/*}"
        if [ "$rest" != "$e/$b" ]; then unplaced "$f"; continue; fi
        case "$b" in
          "$m.$e.md") plan move "$f" "$SPEC/_modules/$m/_domain/$e/$e.entity.md" ;;
          "$m.$e."*.md)
            a="${b#$m.$e.}"; a="${a%.md}"
            case "$a" in *.*) unplaced "$f" ;; *) plan move "$f" "$SPEC/_modules/$m/_domain/$e/$e.$a.action.md" ;; esac ;;
          *) unplaced "$f" ;;
        esac ;;
      *) unplaced "$f" ;;
    esac
  done < <(find "$KB/04_domain" -type f ! -name '.gitkeep' | sort)
fi

# ── 05_screens ───────────────────────────────────────────────────────────────
SCREENS="$WORK/screens.tsv"; : > "$SCREENS"   # face module slug old-path
NAVS="$WORK/navs.tsv"; : > "$NAVS"            # face module old-index-path
if [ -d "$KB/05_screens" ]; then
  single_face="$(cut -d"|" -f1 "$FACES" | head -1)"
  n_faces="$(wc -l < "$FACES" | tr -d ' ')"
  while IFS= read -r f; do
    rel="${f#$KB/05_screens/}"
    b="${f##*/}"
    top="${rel%%/*}"
    case "$rel" in
      design-system.md) plan move "$f" "$SPEC/_design-system/design-system.md"; continue ;;
      design-tokens.json) plan move "$f" "$SPEC/_design-system/design-system.tokens.json"; continue ;;
      README.md) unplaced "$f"; continue ;;
    esac
    case "$top" in
      patterns|layouts|components)
        kind="${top%s}"
        case "$rel" in
          "$top/_template.md") plan move "$f" "$SPEC/_design-system/$top/$kind.template.md" ;;
          "$top"/README.md|"$top"/_*|"$top"/*/*) unplaced "$f" ;;
          "$top"/*.md)
            n="${b%.md}"
            plan move "$f" "$SPEC/_design-system/$top/$n.$kind.md"
            queue_surfaces "$f" "$SPEC/_design-system/$top/$n.$kind.md" ;;
          *) unplaced "$f" ;;
        esac
        continue ;;
    esac
    # A screen or a module index: flat {m}/{s}.md, or surface-first {surface|shared}/{m}/{s}.md.
    depth="$(printf '%s' "$rel" | awk -F/ '{ print NF }')"
    if [ "$depth" -eq 2 ] && [ "$n_faces" -le 1 ]; then
      face="$single_face"; m="$top"
    elif [ "$depth" -eq 3 ]; then
      if [ "$top" = "shared" ]; then face="$SHARED_FACE"; else face="$top"; fi
      m="$(printf '%s' "$rel" | cut -d/ -f2)"
    else
      unplaced "$f"; continue
    fi
    if [ -z "$face" ]; then unplaced "$f"; continue; fi
    case "$b" in
      _index.md) printf '%s\t%s\t%s\n' "$face" "$m" "$f" >> "$NAVS" ;;
      README.md|_*) unplaced "$f" ;;
      *.md) printf '%s\t%s\t%s\t%s\n' "$face" "$m" "${b%.md}" "$f" >> "$SCREENS" ;;
      *) unplaced "$f" ;;
    esac
  done < <(find "$KB/05_screens" -type f ! -name '.gitkeep' | sort)

  # A slug is unique within a face. Two modules with the same file name in one face
  # keep their module as a prefix — the only case the slug is not the file name.
  awk -F'\t' '{ c[$1 "\t" $3]++ } END { for (k in c) if (c[k] > 1) print k }' "$SCREENS" > "$WORK/clash.tsv"
  while IFS="$(printf '\t')" read -r face m s f; do
    slug="$s"
    if grep -qxF "$(printf '%s\t%s' "$face" "$s")" "$WORK/clash.tsv"; then
      slug="$m-$s"
      plan note "screen slug $s repeats in face $face; $f becomes $m-$s"
    fi
    new="$SPEC/_faces/$face/_screens/$slug.screen.md"
    old_id="$(fm_get "$f" id)"
    [ -n "$old_id" ] || old_id="$m.$s"
    new_id="$face.$slug"
    plan move "$f" "$new"
    fm_queue "$new" id "$new_id"
    fm_m="$(fm_get "$f" module)"; [ -n "$fm_m" ] || fm_queue "$new" module "$m"
    fm_s="$(fm_get "$f" screen)"; [ -n "$fm_s" ] || fm_queue "$new" screen "$s"
    queue_surfaces "$f" "$new" drop
    if [ "$old_id" != "$new_id" ]; then
      printf '%s\t%s\n' "$old_id" "$new_id" >> "$IDMAP"
      plan idmap "$old_id" "$new_id"
    fi
  done < "$SCREENS"

  # The id map is keyed by the old id, which the layered layout already held unique
  # across the project (screen-coherence's duplicate-id check). A repeat means the
  # knowledge base was not valid before the migration, and the map would be ambiguous.
  rep="$(cut -f1 "$IDMAP" | sort | uniq -d | head -1)"
  if [ -n "$rep" ]; then
    printf 'migrate-kb: screen id %s is used by more than one screen. Make it unique (screen-coherence reports it) and run again.\n' "$rep" >&2
    exit 1
  fi

  # One navigation file per face: every module's `## Navigation` prose, in module order.
  for face in $(cut -f1 "$NAVS" | sort -u); do
    out="$GEN/nav-$face.md"
    {
      printf '# %s — navigation\n\n' "$face"
      printf '<!-- Merged by /inspire:migrate from each module'"'"'s _index.md. The screens table is gone: a search for *.screen.md gives it. -->\n'
      sort -t"$(printf '\t')" -k2,2 "$NAVS" | awk -F'\t' -v f="$face" '$1 == f' | while IFS="$(printf '\t')" read -r _ m p; do
        printf '\n## %s\n\n' "$m"
        awk '
          /^## / { on = ($0 ~ /^## Navigation[ \t]*$/); next }
          on { print }
        ' "$p" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
      done
    } > "$out"
    plan write "$SPEC/_faces/$face/_index.md" "navigation of face $face, merged from $(awk -F'\t' -v f="$face" '$1 == f' "$NAVS" | wc -l | tr -d ' ') module index(es)"
    awk -F'\t' -v f="$face" '$1 == f { print $3 }' "$NAVS" | while IFS= read -r p; do
      plan unplaced "$p" "$SPEC/_migration/merged/${p#$KB/}"
    done
  done
fi

# ── 00_bootstrap: theme and roster ───────────────────────────────────────────
for t in theme.md theme.tokens.json; do
  [ -f "$KB/00_bootstrap/$t" ] && plan move "$KB/00_bootstrap/$t" "$SPEC/_design-system/$t"
done
[ -f "$ROSTER_FILE" ] && plan unplaced "$ROSTER_FILE" "$SPEC/_migration/retired/00_bootstrap/surfaces.md"

# ── faces and bundles ────────────────────────────────────────────────────────
yaml_list() { [ -n "$1" ] && printf '[%s]' "$(printf '%s' "$1" | sed 's/,/, /g')"; }

while IFS='|' read -r id pkg prof shell name; do
  [ -n "$id" ] || continue
  out="$GEN/face-$id.md"
  {
    printf -- '---\nid: %s\n' "$id"
    [ -n "$pkg" ] && printf 'package: %s\n' "$pkg"
    [ -n "$prof" ] && printf 'profiles: %s\n' "$prof"
    [ -n "$shell" ] && printf 'shell: %s\n' "$shell"
    [ -n "$bundle_ids_csv" ] && printf 'bundles: %s\n' "$(yaml_list "$bundle_ids_csv")"
    printf -- '---\n\n# Face: %s\n' "${name:-$id}"
    printf '\n<!-- Created by /inspire:migrate. It lists every bundle, since the layered layout did not say which ones this face uses. Narrow the list when you know. -->\n'
  } > "$out"
  plan write "$SPEC/_faces/$id/$id.face.md" "face $id"
done < "$FACES"

while IFS='|' read -r id pkg prof mods; do
  [ -n "$id" ] || continue
  out="$GEN/bundle-$id.md"
  {
    printf -- '---\nid: %s\n' "$id"
    [ -n "$pkg" ] && printf 'package: %s\n' "$pkg"
    [ -n "$prof" ] && printf 'profiles: %s\n' "$prof"
    printf -- '---\n\n# Bundle: %s\n\n## Actions\n\n' "$id"
    if [ -n "$mods" ]; then
      printf '%s\n' "$mods" | tr ',' '\n' | grep -v '^$' | while IFS= read -r m; do
        printf -- '- [[%s]] (whole module)\n' "$m"
      done
    fi
  } > "$out"
  plan write "$SPEC/_bundles/$id.bundle.md" "bundle $id, grouping $(printf '%s' "$mods" | tr ',' '\n' | grep -vc '^$') module(s)"
  [ -n "$pkg" ] || plan note "bundle $id has no package: set package: in its file before the Factory plans it"
done < "$BUNDLES"

for l in $(cat "$DS_LIBS"); do
  plan note "lib surface $l is now part of the design system; its package is no longer declared anywhere"
done

[ -s "$IDMAP" ] && plan write "$SPEC/_migration/id-map.json" "$(wc -l < "$IDMAP" | tr -d ' ') screen id(s)"

# Whatever is left in a layered directory is the operator's and is moved, never dropped.
moved_list="$WORK/moved.txt"
awk -F'\t' '$1 == "move" || $1 == "unplaced" { print $2 }' "$PLAN" | sort -u > "$moved_list"
for l in $OLD_LAYERS; do
  [ -d "$KB/$l" ] || continue
  find "$KB/$l" -type f | sort | while IFS= read -r f; do
    grep -qxF "$f" "$moved_list" || { case "${f##*/}" in .gitkeep) continue ;; esac; unplaced "$f"; }
  done
done

# ── apply ────────────────────────────────────────────────────────────────────
if [ "$DRY" -eq 1 ]; then
  cat "$PLAN"
  printf 'note\tdry run: nothing was written. Commit the moves on their own, before any edit, so git sees them as renames.\n'
  exit 0
fi

# Refuse to overwrite anything: every destination must be free.
dup="$(awk -F'\t' '$1 == "move" || $1 == "unplaced" || $1 == "write" { print ($1 == "write" ? $2 : $3) }' "$PLAN" | sort | uniq -d | head -1)"
if [ -n "$dup" ]; then
  printf 'migrate-kb: two files would land on %s — refusing.\n' "$dup" >&2
  exit 1
fi

while IFS="$(printf '\t')" read -r op a b; do
  case "$op" in
    move|unplaced)
      mkdir -p "$(dirname "$b")"
      mv "$a" "$b"
      [ "$op" = "move" ] && fm_apply "$b" "$b" ;;
  esac
done < "$PLAN"

for g in "$GEN"/face-*.md; do
  [ -f "$g" ] || continue
  id="${g##*/face-}"; id="${id%.md}"
  mkdir -p "$SPEC/_faces/$id"; cp "$g" "$SPEC/_faces/$id/$id.face.md"
done
for g in "$GEN"/bundle-*.md; do
  [ -f "$g" ] || continue
  id="${g##*/bundle-}"; id="${id%.md}"
  mkdir -p "$SPEC/_bundles"; cp "$g" "$SPEC/_bundles/$id.bundle.md"
done
for g in "$GEN"/nav-*.md; do
  [ -f "$g" ] || continue
  id="${g##*/nav-}"; id="${id%.md}"
  mkdir -p "$SPEC/_faces/$id"; cp "$g" "$SPEC/_faces/$id/_index.md"
done

mkdir -p "$SPEC/_migration"
if [ -s "$IDMAP" ]; then
  jq -Rn '[inputs | split("\t") | {(.[0]): .[1]}] | add | {screens: .}' < "$IDMAP" > "$SPEC/_migration/id-map.json"
fi
cp "$PLAN" "$SPEC/_migration/plan.tsv"

# The skeleton the layered layout never had (READMEs, the starter patterns, the
# default theme): added only where nothing is on disk, exactly like seed_kb.
if [ -n "$SKELETON" ] && [ -d "$SKELETON" ]; then
  ( cd "$SKELETON" && find . -type f ) | sed 's|^\./||' | sort | while IFS= read -r rel; do
    [ -e "$SPEC/$rel" ] && continue
    mkdir -p "$(dirname "$SPEC/$rel")"
    cp "$SKELETON/$rel" "$SPEC/$rel"
    printf 'seed\t%s\n' "$SPEC/$rel" >> "$PLAN"
  done
  ds="$SPEC/_design-system"
  if [ ! -f "$ds/design-system.md" ] && [ -f "$ds/theme.md" ]; then
    cp "$ds/theme.md" "$ds/design-system.md"
    printf 'seed\t%s\n' "$ds/design-system.md" >> "$PLAN"
  fi
  if [ ! -f "$ds/design-system.tokens.json" ] && [ -f "$ds/theme.tokens.json" ]; then
    cp "$ds/theme.tokens.json" "$ds/design-system.tokens.json"
    printf 'seed\t%s\n' "$ds/design-system.tokens.json" >> "$PLAN"
  fi
  cp "$PLAN" "$SPEC/_migration/plan.tsv"
fi

# Remove the layered directories once they hold nothing but placeholders.
for l in $OLD_LAYERS; do
  [ -d "$KB/$l" ] || continue
  find "$KB/$l" -type f -name '.gitkeep' -delete
  find "$KB/$l" -depth -type d -empty -delete
done

cat "$PLAN"
exit 0
