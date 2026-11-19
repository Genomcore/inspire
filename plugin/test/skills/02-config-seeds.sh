#!/usr/bin/env bash
# Every shipped seed names its profiles and a pinned image, the stack.md INSPIRE
# ships is one of them, and /inspire-bootstrap has a successor everywhere.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
BASE="$HERE/../base"
. "$HERE/lib/assert.sh"

SEEDS="$BASE/skills/inspire-config/references/seeds.md"
STACK="$BASE/kb/00_bootstrap/stack.md"
premise "the seeds reference exists" "[ -f '$SEEDS' ]"

# The rows of the `## Seeds` table: id, profiles, image, description.
rows="$(awk -F'|' '
  /^## / { on = ($0 == "## Seeds") }
  on && /^\| `/ { gsub(/[` ]/, "", $2); gsub(/[` ]/, "", $3); gsub(/[` ]/, "", $4); gsub(/^ +| +$/, "", $5); print $2 "\t" $3 "\t" $4 "\t" $5 }
' "$SEEDS")"
check "at least one seed ships" "[ -n '$rows' ]"

while IFS="$(printf '\t')" read -r id profiles image desc; do
  [ -n "$id" ] || continue
  check "seed $id: names its profiles" "[ -n '$profiles' ]"
  # A full version on the official Debian image: no floating tag, no slim, no alpine.
  check "seed $id: its image is a pinned tag ($image)" \
    "printf '%s' '$image' | grep -E >/dev/null '^[a-z0-9./-]+:[0-9]+\.[0-9]+\.[0-9]+-[a-z]+$'"
  check "seed $id: its image is neither slim nor alpine" \
    "! printf '%s' '$image' | grep -E >/dev/null 'slim|alpine|latest'"
  check "seed $id: describes its image" "[ \${#desc} -gt 20 ]"
  # seed.json is what the tools read; the table repeats it for the operator.
  J="$BASE/seeds/$id/seed.json"
  check "seed $id: ships its seed.json and a starter" "[ -f '$J' ] && [ -f '$BASE/seeds/$id/files/README.md' ]"
  eq "seed $id: the table's profiles are seed.json's" "$profiles" "$(jq -r '.profiles | join(",")' "$J")"
  eq "seed $id: the table's image is seed.json's" "$image" "$(jq -r .image.name "$J")"
  eq "seed $id: the table's description is seed.json's" "$desc" "\`$(jq -r .image.description "$J")\`"
  for prof in $(printf '%s' "$profiles" | tr ',' ' '); do
    check "seed $id: a shipped skill serves '$prof'" \
      "grep -l >/dev/null '^stack: $prof\$' '$BASE'/skills/*/SKILL.md"
  done
done <<EOF2
$rows
EOF2

# Every target row names a seed that exists, or none.
targets="$(awk -F'|' '/^## / { on = ($0 == "## Targets") } on && /^\| `/ { gsub(/[` ]/, "", $2); gsub(/[` ]/, "", $4); print $2 "=" $4 }' "$SEEDS")"
eq "the six targets, in the order the wizard offers them" \
  "$(printf '%s' "$targets" | cut -d= -f1 | paste -sd' ' -)" \
  "desktop-web responsive-web pwa native-mobile binary other"
for t in $targets; do
  seed="${t#*=}"
  [ "$seed" = "none" ] && continue
  check "target ${t%%=*}: its seed '$seed' is in the table" \
    "printf '%s\n' \"\$rows\" | cut -f1 | grep -x >/dev/null '$seed'"
done

# The shipped stack.md is one of the seeds, with that seed's profiles.
seed="$(yq --front-matter=extract '.seed' "$STACK")"
want="$(printf '%s\n' "$rows" | awk -F'\t' -v s="$seed" '$1 == s { print $2 }')"
check "the shipped stack.md names a shipped seed ($seed)" "[ -n '$want' ]"
eq "and carries that seed's profiles" "$(yq --front-matter=extract '.profiles | join(",")' "$STACK")" "$want"

# No shipped default names a product, and the retired skill is named only where
# an upgrade explains it.
hasnt "no shipped file names OpenBIMS" "$(grep -rIl 'OpenBIMS' "$BASE" | grep -v '/bin/test/')" "/"
check "the retired skill is not shipped" "[ ! -e '$BASE/skills/inspire-bootstrap' ]"
eq "inspire-bootstrap is named only as a placeholder an older install left" \
  "$(grep -rIl 'inspire-bootstrap' "$BASE" | grep -v '/bin/test/' | sed "s#$BASE/##" | paste -sd' ' -)" \
  "skills/inspire-config/references/foundation-review.md"

# Every question the wizard asks is marked, and every technical one can keep its default.
W="$BASE/skills/inspire-config/references/wizard.md"
unmarked="$(grep -E '^\| [PT][0-9]+ \|' "$W" | grep -vcE '^\| P[0-9]+ \| `\[product\]`|^\| T[0-9]+ \| `\[technical\]`')"
eq "wizard: every question is marked product or technical" "$unmarked" "0"
has "wizard: a technical question can keep the default" "$(cat "$W")" "I don't know — keep the default"
first="$(grep -nE '^\| P3 \|' "$W" | cut -d: -f1)"; stack="$(grep -nE '^\| T1 \|' "$W" | cut -d: -f1)"
check "wizard: the target is asked before the stack" "[ '$first' -lt '$stack' ]"

summary
