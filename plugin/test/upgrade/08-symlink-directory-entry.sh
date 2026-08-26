#!/usr/bin/env bash
# A symlink is a directory entry, so both modes must see it.
# Moved from test-upgrade.sh:552-593.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/hop-ops.sh"
. "$HERE/lib/scratch.sh"

# ---- a symlink is a directory entry, so both modes must see it -------------
# `find -type f` excluded it, so both modes computed zero survivors; only act
# mode then discovered via rmdir that the directory was not empty. The two
# modes returned OPPOSITE verdicts on identical input, and neither mentioned
# the symlink at all. `! -type d` fixes both halves at once.
sym="$(mktemp -d)"; hopops_scratch "$sym"
mkdir -p "$sym/proj/pfx/nested"
printf 'x\n' > "$sym/proj/pfx/nested/ours.txt"
jq -n --arg h "$(sha256_of "$sym/proj/pfx/nested/ours.txt")" \
  '{version:"9.9.9",released:"x",commit:"x",layout:"A",
    files:{"pfx/nested/ours.txt":$h}}' > "$sym/mf.json"
ln -s /nonexistent-target-xyz "$sym/proj/pfx/operator-symlink"
eq "the symlink is invisible to -type f but seen by ! -type d" \
  "$(find "$sym/proj/pfx" -type f | wc -l | tr -d ' ')/$(find "$sym/proj/pfx" ! -type d | wc -l | tr -d ' ')" \
  "1/2"

HOP_JOURNAL="$sym/j-act"; hop_ops_init "$sym/proj" "$sym/mf.json" 0
hop_rm_owned pfx
sym_act="$(awk -F'\t' '$2=="pfx/" {print $1}' "$sym/j-act")"
sym_act_link="$(grep -c 'operator-symlink' "$sym/j-act")"

# Rebuild an identical starting tree for record mode.
rm -rf "$sym/proj"
mkdir -p "$sym/proj/pfx/nested"
printf 'x\n' > "$sym/proj/pfx/nested/ours.txt"
ln -s /nonexistent-target-xyz "$sym/proj/pfx/operator-symlink"
HOP_JOURNAL="$sym/j-rec"; hop_ops_init "$sym/proj" "$sym/mf.json" 1
hop_rm_owned pfx
sym_rec="$(awk -F'\t' '$2=="pfx/" {print $1}' "$sym/j-rec")"
sym_rec_link="$(grep -c 'operator-symlink' "$sym/j-rec")"

eq "act and record agree on the directory verdict with a symlink present" \
  "$sym_act" "$sym_rec"
eq "the verdict is keep — a symlink blocks the removal" "$sym_act" "keep"
eq "act mode reports the operator's symlink" "$sym_act_link" "1"
eq "record mode reports the operator's symlink" "$sym_rec_link" "1"
check "the symlink is labelled the operator's, not ours" \
  "grep -q \$'^keep\tpfx/operator-symlink\tyours' '$sym/j-rec'"
check "the operator's symlink was not deleted" \
  "[ -L '$sym/proj/pfx/operator-symlink' ]"
rm -rf "$sym"

summary
