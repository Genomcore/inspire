#!/usr/bin/env bash
# The journal must never claim a mutation that failed.
# Moved from test-upgrade.sh:460-551.
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

# ---- the journal must never claim a mutation that failed -------------------
# The journal IS the operator's report, and nothing downstream cross-checks it
# against disk, so a line written BEFORE the mutation is a claim we cannot
# support. chmod 555 on the parent makes rm/mv fail while the paths survive —
# the same shape as a read-only mount, an immutable flag, or a full disk.
#
# The scratch tree is `mktemp -d`, not a fixed path: this block and the symlink
# block below used to name /tmp/inspire-hopops-{perm,link} literally, so two runs
# of this suite at once — two worktrees of the same repo, say — deleted each
# other's trees mid-assertion and reported phantom failures. A private tree per
# run makes the suite safe to run concurrently. It registers with hopops_scratch
# because part of its life is chmod 555, which `rm -rf` cannot empty; the mode is
# restored before the inline cleanup either way.
perm="$(mktemp -d)"; hopops_scratch "$perm"
mkdir -p "$perm/locked"
printf 'a\n' > "$perm/locked/a.txt"
printf 'b\n' > "$perm/locked/b.txt"
printf 'victim\n' > "$perm/locked/victim.txt"
jq -n --arg a "$(sha256_of "$perm/locked/a.txt")" --arg b "$(sha256_of "$perm/locked/b.txt")" \
  '{version:"9.9.9",released:"x",commit:"x",layout:"A",
    files:{"locked/a.txt":$a,"locked/b.txt":$b}}' > "$perm/mf.json"
chmod 555 "$perm/locked"
# `touch`, not `: >` — a redirection failure is reported by the shell itself and
# cannot be silenced with 2>/dev/null on the command.
if touch "$perm/locked/probe" 2>/dev/null; then
  rm -f "$perm/locked/probe"
  skipped 19 "permission-failure journalling — writable despite chmod 555 (running as root?)"
else
  HOP_JOURNAL="$perm/j1"; hop_ops_init "$perm" "$perm/mf.json" 0
  perm_err="$(hop_rm locked/victim.txt 2>&1 >/dev/null)"; perm_rc=$?
  eq "a failed hop_rm returns non-zero" "$perm_rc" "1"
  check "a failed hop_rm journals NO delete line" "! grep -q \$'^delete\t' '$perm/j1'"
  check "a failed hop_rm journals keep with the reason" \
    "grep -q \$'^keep\tlocked/victim.txt\tcould not be removed' '$perm/j1'"
  check "a failed hop_rm leaks no raw rm error" \
    "! printf '%s' \"\$perm_err\" | grep -q '^rm:'"
  check "a failed hop_rm explains itself as INSPIRE" \
    "printf '%s' \"\$perm_err\" | grep -q 'INSPIRE: could not delete'"
  check "the file hop_rm failed on is still on disk" "[ -f '$perm/locked/victim.txt' ]"

  # The severe case: the per-file rm had no error check at all, so this
  # returned 0 and journalled two deletes while removing nothing.
  HOP_JOURNAL="$perm/j2"; hop_ops_init "$perm" "$perm/mf.json" 0
  hop_rm_owned locked 2>/dev/null; perm_rc2=$?
  eq "hop_rm_owned propagates a failed file deletion" "$perm_rc2" "1"
  check "hop_rm_owned journals NO delete it did not perform" \
    "! grep -q \$'^delete\t' '$perm/j2'"
  eq "hop_rm_owned journals a keep-with-reason per failed file" \
    "$(awk -F'\t' '$3 ~ /^could not be removed/' "$perm/j2" | wc -l | tr -d ' ')" "2"
  check "both shipped files hop_rm_owned failed on are still on disk" \
    "[ -f '$perm/locked/a.txt' ] && [ -f '$perm/locked/b.txt' ]"

  HOP_JOURNAL="$perm/j3"; hop_ops_init "$perm" "$perm/mf.json" 0
  hop_mv locked/a.txt moved/a.txt 2>/dev/null
  eq "a failed hop_mv returns non-zero" "$?" "1"
  check "a failed hop_mv journals NO move line" "! grep -q \$'^move\t' '$perm/j3'"
  check "a failed hop_mv journals keep with the reason" \
    "grep -q \$'^keep\tlocked/a.txt\tcould not be moved' '$perm/j3'"

  # Act vs record where the deletion WILL fail. `failed_n` is act-mode-only and
  # structurally unpredictable — knowing whether rm succeeds needs a write, and
  # record mode writes nothing. So record mode is allowed to be optimistic, but
  # it must word its verdict as a FORECAST and must never assert completion.
  # A prefix holding only manifest-listed files, so nothing else blocks removal.
  mkdir -p "$perm/only"
  printf 'a\n' > "$perm/only/a.txt"
  printf 'b\n' > "$perm/only/b.txt"
  jq -n --arg a "$(sha256_of "$perm/only/a.txt")" --arg b "$(sha256_of "$perm/only/b.txt")" \
    '{version:"9.9.9",released:"x",commit:"x",layout:"A",
      files:{"only/a.txt":$a,"only/b.txt":$b}}' > "$perm/mf-only.json"
  chmod 555 "$perm/only"

  HOP_JOURNAL="$perm/j-rec"; hop_ops_init "$perm" "$perm/mf-only.json" 1
  hop_rm_owned only 2>/dev/null; only_rec_rc=$?
  HOP_JOURNAL="$perm/j-act"; hop_ops_init "$perm" "$perm/mf-only.json" 0
  hop_rm_owned only 2>/dev/null; only_act_rc=$?

  eq "record mode returns 0 where it cannot foresee the failure" "$only_rec_rc" "0"
  eq "act mode returns non-zero when the deletion really fails" "$only_act_rc" "1"
  check "record mode's optimistic verdict is worded as a forecast" \
    "grep -q \$'^delete\tonly/\tdirectory would be emptied and removed$' '$perm/j-rec'"
  check "record mode never asserts a removal it cannot guarantee" \
    "! grep -q \$'\tdirectory emptied and removed$' '$perm/j-rec'"
  check "act mode reports the truth: the directory stayed" \
    "grep -q \$'^keep\tonly/\tdirectory left in place — files in it could not be removed$' '$perm/j-act'"
  check "act mode journals no directory deletion it did not perform" \
    "! grep -q \$'^delete\tonly/' '$perm/j-act'"
  chmod 755 "$perm/only"
fi
chmod 755 "$perm/locked"
rm -rf "$perm"

summary
