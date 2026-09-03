#!/usr/bin/env bash
# Scratch trees that spend part of their life read-only — chmod 555 or 500, so that
# a deletion or a move fails the way it would on a read-only mount. `rm -rf` cannot
# unlink out of a directory it may not write to, so an abort between the chmod and
# the inline restore would strand an undeletable tree in $TMPDIR forever (the old
# fixed /tmp paths at least got a `rm -rf` attempt from the next run; a private
# mktemp tree gets none). Register them here and the EXIT trap restores the mode
# before removing. The trap runs no `exit`, so the suite's own status stands, and
# its `[ -d ]` guard means a tree already cleaned up inline costs nothing.
HOPOPS_SCRATCH=()
hopops_scratch(){ HOPOPS_SCRATCH=( ${HOPOPS_SCRATCH+"${HOPOPS_SCRATCH[@]}"} "$1" ); }
hopops_scratch_cleanup(){
  local d
  for d in ${HOPOPS_SCRATCH+"${HOPOPS_SCRATCH[@]}"}; do
    [ -d "$d" ] || continue
    chmod -R u+rwX "$d" 2>/dev/null
    rm -rf "$d"
  done
}
trap hopops_scratch_cleanup EXIT
