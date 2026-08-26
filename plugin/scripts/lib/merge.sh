#!/usr/bin/env bash
# The three-way content merge. Sourced, never executed. bash 3.2 compatible.
#
# Two questions decide everything:
#   did THEY change it?  disk vs manifest(source)          — B vs A
#   did WE change it?    plugin base vs manifest(source)    — C vs A
#
#   they  we    → action
#   no    no      noop
#   no    yes     replace   (untouched but stale)
#   yes   no      keep      (their edit is the only change)
#   yes   yes, and theirs already equals ours   noop
#   yes   yes, differently  ask                 ← the ONLY prompt
#
# Presence cases:
#   not in A, in C                → create
#   not in A, on disk, not in C   → keep     (project-authored; THE rm -rf fix)
#   in A, absent on disk          → restore  (+ reported; never prompts)
#   in A, on disk, not in C, edited   → keep (+ reported; never delete an edit)
#   in A, on disk, not in C, untouched → delete
#
# classify writes NOTHING to the project. It only emits verdicts on stdout.
#
# Limitations, declared rather than handled:
#   · symlinks are unsupported (spec-level decision). A symlink whose target is
#     a regular file is hashed through; a dangling one reads as absent.
#   · a manifest path that is a directory on disk is reported `keep` and left
#     strictly alone — never silently replaced.

# _base_excluded <name> <rel> → 0 when base/<name>/<rel> is present in the
# plugin but is NEVER materialized into a project.
#
# THE SINGLE DEFINITION OF THE RULE, and it must stay that way: _base_src (the
# classifier), apply_base (the applier), classify's pass 3 and
# scripts/gen-manifest.sh (which decides what a released manifest even lists)
# all call it. The generator carried a re-expressed copy of the rule until the
# final whole-branch review; a second copy is the only place a rule can drift.
#
# This filter is why a "does the target ship it?" question is not just
# `[ -f base/<middle> ]`, and it is load-bearing in BOTH directions:
#   · pass 1 — .claude/bin/test/ was shipped by 0.1–0.2 (114 files in the 0.2.1
#     manifest) and is deliberately dropped from 0.3 onward. plugin/base/bin/test/
#     still exists here (the template's own golden fixtures), so without this
#     filter every one of those files would find a base counterpart, be scored
#     as unchanged, and come out `noop` — the upgrade would then leave a dead
#     harness in the project forever instead of deleting it.
#   · pass 2 — without it, the same 114 files plus any template-maintenance
#     script would be announced as brand-new creations.
_base_excluded() {
  local name="$1" rel="$2" top="${2%%/*}"
  # bin/test/ is never materialized — neither fixtures nor harness.
  [ "$name" = "bin" ] && [ "$top" = "test" ] && return 0
  # A template-maintenance script never leaks into a project.
  case "$top" in template-*.sh) return 0 ;; esac
  return 1
}

# _middle <dest_map> <path> → the base-relative middle (e.g. bin/review.sh),
# or empty when the path is not under any of the map's destinations.
# THE `_var` VARIANTS ARE THE SAME FUNCTIONS WITHOUT THE COMMAND SUBSTITUTION:
# they assign a global instead of printing, because the batched walkers below
# call them once per file and a `$(...)` there is a fork per file — the same
# per-file tax the hashing had, in cheaper clothes. The printing form is that
# variant plus a printf, so the path arithmetic exists in exactly one place.
_middle_var() {
  local map="$1" path="$2" pair name dest
  _MIDDLE=""
  for pair in $map; do
    name="${pair%%:*}"; dest="${pair#*:}"
    case "$path" in
      "$dest"/*) _MIDDLE="$name/${path#"$dest"/}"; return 0 ;;
    esac
  done
  return 1
}
_middle() {
  _middle_var "$1" "$2" || return 1
  printf '%s\n' "$_MIDDLE"
}

# _from_middle <dest_map> <middle> → the path that map materializes it at
_from_middle_var() {
  local map="$1" mid="$2" pair name dest
  _FROM_MIDDLE=""
  for pair in $map; do
    name="${pair%%:*}"; dest="${pair#*:}"
    case "$mid" in
      "$name"/*) _FROM_MIDDLE="$dest/${mid#"$name"/}"; return 0 ;;
    esac
  done
  return 1
}
_from_middle() {
  _from_middle_var "$1" "$2" || return 1
  printf '%s\n' "$_FROM_MIDDLE"
}

# _base_src <base_dir> <dest_map> <path> → absolute path in base/ of the file
# the target version would materialize at <path>, or empty (rc 1) when the
# target ships nothing there.
#
# NOTE the caller must pass the map matching the SPACE <path> lives in. Pass 1
# feeds it source-space paths and therefore the SOURCE map: on a 0.2 project
# `.claude/bin/review.sh` only resolves to `base/bin/review.sh` through
# `bin:.claude/bin`. Handing it the target map instead resolves nothing, every
# pre-0.3 file reads as dropped upstream, and the whole validator set is marked
# for deletion.
# _base_mid_var is the same question answered as a MIDDLE rather than a path,
# assigned to _BASE_MID (empty when the target ships nothing there). The batched
# classifier needs the middle: it is the key of the base-side hash table, and the
# absolute path would have to be turned back into one. _base_src is that plus the
# base/ prefix.
_base_mid_var() {
  local base="$1" map="$2" path="$3" name rel
  _BASE_MID=""
  _middle_var "$map" "$path" || return 1
  [ -n "$_MIDDLE" ] || return 1
  name="${_MIDDLE%%/*}"; rel="${_MIDDLE#*/}"
  _base_excluded "$name" "$rel" && return 1
  [ -f "$base/$_MIDDLE" ] || return 1
  _BASE_MID="$_MIDDLE"
}
_base_src() {
  _base_mid_var "$1" "$2" "$3" || return 1
  printf '%s\n' "$1/$_BASE_MID"
}

# classify <source_manifest> <project_root> <base_dir> <src_map> <tgt_map>
#   → lines `<verdict>\t<path>\t<detail>` on stdout.
#
# EVERY PASS IS NOW TWO HALVES. A bash walk decides everything a file test can
# answer — does the path exist, is it a regular file, does the target ship it, is
# it excluded — and writes one row per candidate; then exactly the files that pass
# needed to hash are hashed in ONE process each side; then one awk turns the rows
# and the tables into the verdict lines. The branch tree in that awk is this
# function's old branch tree, in the same order, so the verdict stream is
# byte-identical. Safe by construction: classify writes nothing to the project, so
# no hash it takes can be stale by the time it is used.
#
# `seen` was a file consulted with one `grep -Fxq` PER CANDIDATE — over 900 spawns
# on a pre-0.3 project, where pass 3 walks every file under every INSPIRE-owned
# root. It is an awk set now, filled in the same order and consulted at the same
# points, including the additions each pass makes AS IT EMITS: a pass adds a path
# only when it emitted a verdict for it, and the awk does the same, so a duplicate
# path within one pass behaves exactly as it did.
classify() {
  local mf="$1" root="$2" base="$3" src_map="$4" tgt_map="$5"
  local target hash_a pair name dest abs rel state ex
  local w; w="$(mktemp -d)"
  local seen1="$w/seen1" seen2="$w/seen2"
  : > "$seen1"; : > "$seen2"

  # Pass 1 — everything the source version shipped. Paths are in SOURCE space,
  # so the source map is what locates their base/ counterpart.
  : > "$w/p1"; : > "$w/p1lb"; : > "$w/p1lc"
  while IFS=$'\t' read -r target hash_a; do
    [ -n "$target" ] || continue
    printf '%s\n' "$target" >> "$seen1"
    _base_mid_var "$base" "$src_map" "$target"

    if [ -f "$root/$target" ]; then
      state=f
      printf '%s\0' "$target" >> "$w/p1lb"
      [ -n "$_BASE_MID" ] && printf '%s\0' "$_BASE_MID" >> "$w/p1lc"
    elif [ -e "$root/$target" ]; then
      state=e            # a directory (or other non-regular entry)
    else
      state=x
    fi
    printf '%s\t%s\t%s\t%s\n' "$target" "$hash_a" "$state" "$_BASE_MID" >> "$w/p1"
  done < <(manifest_paths "$mf")

  hash_paths "$root" "$w/p1lb" "$w/p1tb"
  hash_paths "$base" "$w/p1lc" "$w/p1tc"
  LC_ALL=C awk -F'\t' -v tb="$w/p1tb" -v tc="$w/p1tc" '
    FILENAME == tb { hb[$2] = $1; next }
    FILENAME == tc { hc[$2] = $1; next }
    {
      target = $1; ha = $2; st = $3; mid = $4
      if (st != "f") {
        if (st == "e")
          printf "keep\t%s\t%s\n", target, "not a regular file here; left untouched"
        else if (mid != "")
          printf "restore\t%s\t%s\n", target, "you deleted this; restoring at the new version"
        next
      }
      hbv = (target in hb) ? hb[target] : ""
      if (mid == "") {
        # Dropped upstream.
        if (hbv == ha) printf "delete\t%s\t%s\n", target, "no longer part of INSPIRE"
        else printf "keep\t%s\t%s\n", target, "no longer part of INSPIRE, but you edited it"
        next
      }
      hcv = (mid in hc) ? hc[mid] : ""
      if (hbv == ha) {
        if (hcv == ha) printf "noop\t%s\t\n", target
        else printf "replace\t%s\t%s\n", target, "untouched, takes the new version"
      } else {
        if (hcv == ha) printf "keep\t%s\t%s\n", target, "you changed it, we did not"
        else if (hcv == hbv) printf "noop\t%s\t%s\n", target, "your edit already matches the new version"
        else printf "ask\t%s\t%s\n", target, "you and we both changed it"
      }
    }
  ' "$w/p1tb" "$w/p1tc" "$w/p1"

  # Pass 2 — what the target version ships that the source did not. Paths are
  # in TARGET space. A file that merely MOVED is not new: it was already seen in
  # pass 1 under its SOURCE path, so that path is checked too before calling it
  # a creation. Without it every validator on a pre-0.3 project would be
  # announced as new at .inspire/bin/ while also being deleted from .claude/bin/.
  : > "$w/p2"; : > "$w/p2lb"; : > "$w/p2lc"
  for pair in $tgt_map; do
    name="${pair%%:*}"; dest="${pair#*:}"
    [ -d "$base/$name" ] || continue
    while IFS= read -r abs; do
      rel="${abs#"$base/$name"/}"
      _base_excluded "$name" "$rel" && continue
      target="$dest/$rel"
      _from_middle_var "$src_map" "$name/$rel"
      if [ -f "$root/$target" ]; then
        state=f
        printf '%s\0' "$target"      >> "$w/p2lb"
        printf '%s\0' "$name/$rel"   >> "$w/p2lc"
      elif [ -e "$root/$target" ]; then
        state=e
      else
        state=x
      fi
      printf '%s\t%s\t%s\t%s\n' "$target" "$name/$rel" "$_FROM_MIDDLE" "$state" >> "$w/p2"
    done < <(find "$base/$name" -type f)
  done

  hash_paths "$root" "$w/p2lb" "$w/p2tb"
  hash_paths "$base" "$w/p2lc" "$w/p2tc"
  LC_ALL=C awk -F'\t' -v sf="$seen1" -v tb="$w/p2tb" -v tc="$w/p2tc" -v sf2="$seen2" '
    FILENAME == sf { seen[$0] = 1; next }
    FILENAME == tb { hb[$2] = $1; next }
    FILENAME == tc { hc[$2] = $1; next }
    {
      target = $1; mid = $2; moved = $3; st = $4
      if (target in seen) next
      if (moved != "" && (moved in seen)) next
      if (st == "f" && (target in hb) && (mid in hc) && hb[target] == hc[mid])
        printf "noop\t%s\t\n", target
      else if (st == "x")
        printf "create\t%s\t%s\n", target, "new in this release"
      else
        printf "ask\t%s\t%s\n", target, "new in this release, and you already have a different file here"
      seen[target] = 1
      print target > sf2
    }
  ' "$seen1" "$w/p2tb" "$w/p2tc" "$w/p2"

  # Pass 3 — project-authored files inside directories INSPIRE owns. These are
  # never ours and must survive; this is the row that replaces materialize_entry's
  # `rm -rf` of a whole owned entry. Disk is still in SOURCE space at this point,
  # so walk the source map.
  local ex_name ex_rel
  : > "$w/p3"
  for pair in $src_map; do
    dest="${pair#*:}"
    [ -d "$root/$dest" ] || continue
    while IFS= read -r abs; do
      rel="${abs#"$root"/}"
      # NOT THEIRS IF WE SHIP IT BUT NEVER MATERIALIZE IT. `_base_excluded` is
      # exactly that question, and a path it rejects is INSPIRE's own staged
      # source, not project-authored work.
      #
      # The case that forced this: after a pre-0.3 upgrade, .inspire/bin/test/
      # still holds the 114 staged fixtures install.sh copied FROM, and
      # .inspire/bin IS the 0.3 dest_map root for `bin` — so every later run
      # walked them here, found them absent from `seen` (no manifest lists them
      # at that path, and pass 2 skips them for this very reason), and emitted
      # 114 x `keep … "yours — INSPIRE never shipped this"`. We shipped every
      # byte of it. That is the same false ownership claim the 0.3.0 hop had
      # removed, arriving from the other side, and it contradicted the hop's own
      # report, which correctly calls the prefix 0.2 staging residue and tells
      # the operator to delete it when ready. No new verb: the honest answer is
      # that this pass has nothing to say about these paths at all.
      #
      # DELIBERATE CONSEQUENCE, stated so it is not rediscovered as a bug: a
      # fixture the OPERATOR wrote under an excluded prefix (say
      # .claude/bin/test/my-fixture.sh on a pre-0.3 project) is skipped here too,
      # so it gets no `keep` verdict. It is not at risk — apply_base only ever
      # writes paths the target ships, and this prefix is by definition not one
      # of them — and it is still reported, by hop_rm_owned, which walks that
      # exact prefix per file and labels the survivors "yours — not shipped by
      # INSPIRE". Staying silent where a truthful line is available elsewhere
      # beats asserting ownership of 114 files that are ours.
      ex=0
      _middle_var "$src_map" "$rel"
      if [ -n "$_MIDDLE" ]; then
        ex_name="${_MIDDLE%%/*}"; ex_rel="${_MIDDLE#*/}"
        _base_excluded "$ex_name" "$ex_rel" && ex=1
      fi
      printf '%s\t%s\n' "$rel" "$ex" >> "$w/p3"
    done < <(find "$root/$dest" -type f)
  done

  # No hashing at all in pass 3 — it only ever asks whether a path was already
  # accounted for, so the whole pass is the membership test that used to cost a
  # grep per file.
  LC_ALL=C awk -F'\t' -v sf="$seen1" -v sf2="$seen2" '
    FILENAME == sf  { seen[$0] = 1; next }
    FILENAME == sf2 { seen[$0] = 1; next }
    {
      rel = $1; ex = $2
      if (rel in seen) next
      if (ex == "1") next
      printf "keep\t%s\t%s\n", rel, "yours — INSPIRE never shipped this"
      seen[rel] = 1
    }
  ' "$seen1" "$seen2" "$w/p3"

  rm -rf "$w"
}

# keepset_of <verdicts_file> <project_root> → one sha256 per line
#
# The hashes of everything the operator gets to keep: every `keep`, plus every
# `ask` — an unresolved conflict defaults to KEEPING their file, because doing
# nothing is how work survives.
#
# Hashes, not paths: the hops run between classification and application, and
# bytes survive a `mv` unchanged while paths do not.
keepset_of() {
  local vf="$1" root="$2" verdict target detail
  local w; w="$(mktemp -d)"
  : > "$w/list"
  while IFS=$'\t' read -r verdict target detail; do
    case "$verdict" in
      keep|ask) ;;
      *) continue ;;
    esac
    [ -f "$root/$target" ] || continue
    printf '%s\0' "$target" >> "$w/list"
  done < "$vf"
  hash_paths "$root" "$w/list" "$w/table"
  # awk, not `cut -f1`: a file that could not be read has no hash, and the old
  # loop emitted no line for it rather than an empty one.
  LC_ALL=C awk -F'\t' '$1 != "" { print $1 }' "$w/table" | LC_ALL=C sort -u
  rm -rf "$w"
}

# _apply_write <src_abs> <dst_abs> <middle> → install one file, atomically.
#
# Temp + rename PER FILE, so an interrupted or failed run never leaves a
# half-written file: the operator either has the old bytes or the new ones.
#
# The mode is set on the temp file BEFORE the rename, so what appears at the
# destination is already complete AND correctly permissioned — never briefly
# 0600 (mktemp's mode) or briefly non-executable.
#
# The mode rule mirrors materialize.sh's chmod_executables rather than the
# source file's own bit: base/hooks/*.sh are committed 644, yet the two
# registered hooks are invoked BY PATH from .claude/settings.json, so a 644
# dispatch.sh is a broken runtime. Everything else gets 644, not mktemp's 0600 —
# an upgrade that silently tightened hundreds of files would be a nasty
# surprise, and cp does not copy the source mode onto an existing temp file.
_apply_write() {
  local src="$1" dst="$2" mid="$3" tmp
  mkdir -p "$(dirname "$dst")" 2>/dev/null
  tmp="$(mktemp "$dst.XXXXXX" 2>/dev/null)" || {
    log "INSPIRE: could not write '$dst' — no temporary file could be created next to it."
    log "  It was left exactly as it was."
    return 1
  }
  if ! cp "$src" "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    log "INSPIRE: could not write '$dst' — the copy failed. It was left as it was."
    return 1
  fi
  case "$mid" in
    bin/*.sh|hooks/*.sh) chmod 755 "$tmp" 2>/dev/null ;;
    *) if [ -x "$src" ]; then chmod 755 "$tmp" 2>/dev/null
       else chmod 644 "$tmp" 2>/dev/null; fi ;;
  esac
  if mv "$tmp" "$dst" 2>/dev/null; then return 0; fi
  rm -f "$tmp"
  log "INSPIRE: could not replace '$dst' — it was left exactly as it was."
  return 1
}

# _prune_up <dir_abs> <stop_abs>
#
# Remove <dir_abs> and then each ancestor, while empty, stopping BEFORE <stop_abs>
# — the layout's own destination root, which the target version owns and fills.
#
# Bottom-up and ancestor-aware because one rmdir on the immediate parent is not
# enough: removing .claude/skills/inspire-learn/SKILL.md cannot prune
# inspire-learn/ while references/ is still there, and when references/ is emptied
# a moment later nothing retried the grandparent — so the 0.1 skill rename left an
# empty .claude/skills/inspire-learn/ behind that a clean install never creates
# (found by a blind verification of a real 0.1→0.4 run). Order within pass 2 does
# not matter: whichever deletion empties a subtree last is the one whose walk
# collapses the whole chain.
#
# `rmdir` refuses a non-empty directory, so this stops dead at anything of the
# operator's and can never be an `rm -rf`. `break` on the first refusal, because
# once a directory stays every ancestor of it stays too.
_prune_up() {
  local d="$1" stop="$2"
  while [ -n "$d" ] && [ "$d" != "$stop" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    rmdir "$d" 2>/dev/null || break
    d="$(dirname "$d")"
  done
  return 0
}

# apply_base <keepset> <source_manifest> <project_root> <base_dir> \
#            <src_map> <tgt_map> <record>
#
# Driven by the TARGET layout, so it is correct after the hops have moved
# things: classify's verdict paths are in the SOURCE layout and stop existing
# the moment a hop runs, which is why the keep-set is consulted BY CONTENT (a
# `mv` changes a path, never a byte) and why every path here is derived from
# base(Y) and tgt_map instead.
#
# Leaving a file alone is how an operator's work survives, so every uncertain
# case resolves to "leave it".
#
# Limitations, declared rather than handled:
#   · symlinks are unsupported (spec-level decision).
#   · the keep-set is content-addressed, so if a file the operator gets to keep
#     happens to be byte-identical to some OTHER stale file of ours, that other
#     file is left stale too. It is never lost, only not updated, and content
#     collision is the price of surviving the hops at all.
#   · pass 2's prune walks UP from each file it removed, stopping at the layout's
#     own destination root and at the first directory that is not empty. It
#     therefore clears scaffolding we emptied at any depth, and touches no
#     directory it did not empty — an operator's empty directory elsewhere under
#     an INSPIRE-owned root is not ours to remove, and a directory sitting where
#     we ship a FILE is reported `keep` by classify and must survive.
# Batched exactly like classify: a bash walk that decides everything a file test
# answers, one hash per side, one awk that reduces the rows to the list of files
# to actually install — and only then the writes. The hashes are taken before the
# first _apply_write, which is safe because a write to one target cannot change
# another target's bytes and never touches base/. The keep-set membership test,
# a `grep -Fxq` per file, is a set in the same awk.
apply_base() {
  local keep="$1" mf="$2" root="$3" base="$4" src_map="$5" tgt_map="$6" record="$7"
  local pair name dest abs rel target state mid rc=0
  local w; w="$(mktemp -d)"
  local kf="$keep"
  # The old grep tolerated a missing keep-set file (2>/dev/null); awk would not.
  [ -f "$kf" ] || kf=/dev/null

  # Pass 1 — every file the target version ships.
  : > "$w/p1"; : > "$w/p1lb"; : > "$w/p1lc"
  for pair in $tgt_map; do
    name="${pair%%:*}"; dest="${pair#*:}"
    [ -d "$base/$name" ] || continue
    while IFS= read -r abs; do
      rel="${abs#"$base/$name"/}"
      # "In base/" is NOT "shipped": bin/test/ and template-*.sh live here and
      # are never materialized. Without this the applier would install a dead
      # 114-file test harness into every project it touches.
      _base_excluded "$name" "$rel" && continue
      target="$dest/$rel"

      if [ -f "$root/$target" ]; then
        state=f
        printf '%s\0' "$target"    >> "$w/p1lb"
        printf '%s\0' "$name/$rel" >> "$w/p1lc"
      elif [ -e "$root/$target" ]; then
        state=e
      else
        state=x
      fi
      printf '%s\t%s\t%s\t%s\n' "$abs" "$target" "$name/$rel" "$state" >> "$w/p1"
    done < <(find "$base/$name" -type f)
  done

  hash_paths "$root" "$w/p1lb" "$w/p1tb"
  hash_paths "$base" "$w/p1lc" "$w/p1tc"
  LC_ALL=C awk -F'\t' -v kf="$kf" -v tb="$w/p1tb" -v tc="$w/p1tc" '
    FILENAME == kf { ks[$0] = 1; next }
    FILENAME == tb { hb[$2] = $1; next }
    FILENAME == tc { hc[$2] = $1; next }
    {
      abs = $1; target = $2; mid = $3; st = $4
      # A directory (or fifo, socket, device node) where we ship a file. `mv a b`
      # with b a directory puts a INSIDE it and reports success — silent tree
      # corruption. classify already reports this path as `keep`; do nothing.
      if (st == "e") next
      if (st == "f") {
        h = (target in hb) ? hb[target] : ""
        # Theirs to keep, or already identical to ours: leave it.
        if (h in ks) next
        if ((mid in hc) && h == hc[mid]) next
      }
      printf "%s\t%s\t%s\n", abs, target, mid
    }
  ' "$kf" "$w/p1tb" "$w/p1tc" "$w/p1" > "$w/p1act"

  while IFS=$'\t' read -r abs target mid; do
    [ -n "$abs" ] || continue
    # The decision above is made in both modes; only the act is switched, so a
    # preview can never diverge from what the real run decides.
    [ "$record" = 1 ] && continue
    _apply_write "$abs" "$root/$target" "$mid" || rc=2
  done < "$w/p1act"

  # Pass 2 — files we shipped at the SOURCE version that the target no longer
  # ships. Removed only when still byte-identical to what we shipped: an edited
  # one is the operator's and is never deleted (classify reports it as `keep`).
  #
  # That hash test is strictly stronger than consulting the keep-set here, which
  # is why it does not: every keep/ask verdict at a manifest path implies a hash
  # that differs from the manifest's, so an operator's file can never satisfy it.
  local path hash found tgt_root
  : > "$w/p2"; : > "$w/p2l"
  while IFS=$'\t' read -r path hash; do
    [ -n "$path" ] || continue
    # Source path → base-relative middle → where the target layout puts it.
    _middle_var "$src_map" "$path" || continue
    [ -n "$_MIDDLE" ] || continue
    mid="$_MIDDLE"
    _from_middle_var "$tgt_map" "$mid" || continue
    found="$_FROM_MIDDLE"
    [ -n "$found" ] || continue
    # DELIBERATELY `[ -f "$base/$mid" ]` and not _base_src: the only paths where
    # the two disagree are bin/test/**, whose target-space home (.inspire/bin/
    # test/) holds nothing but 0.2 STAGING RESIDUE — which hop 0.3.0 explicitly
    # leaves in place and reports to the operator as theirs to remove. The
    # materialized copy at .claude/bin/test/ is removed by that hop's
    # hop_rm_owned, per file, not here. Deleting the residue here would
    # contradict a report the operator has already read.
    [ -f "$base/$mid" ] && continue                          # still shipped
    [ -f "$root/$found" ] || continue
    printf '%s\0' "$found" >> "$w/p2l"
    printf '%s\t%s\t%s\n' "$found" "$hash" "$mid" >> "$w/p2"
  done < <(manifest_paths "$mf")

  # The batch is taken before the first rm, and nothing in the loop below can
  # invalidate it: unlinking one file does not change another's bytes, and the
  # prune only ever removes directories it just emptied.
  hash_paths "$root" "$w/p2l" "$w/p2t"
  LC_ALL=C awk -F'\t' -v tb="$w/p2t" '
    FILENAME == tb { hb[$2] = $1; next }
    # not ours to delete unless it is still byte-identical to what we shipped
    ($1 in hb) && hb[$1] == $2 { print $0 }
  ' "$w/p2t" "$w/p2" > "$w/p2act"

  while IFS=$'\t' read -r found hash mid; do
    [ -n "$found" ] || continue
    [ "$record" = 1 ] && continue
    rm -f "$root/$found" 2>/dev/null
    if [ -e "$root/$found" ]; then
      log "INSPIRE: could not delete '$found' — it is still on disk."
      rc=2
      continue
    fi
    # Best effort, and nothing claims it succeeded: rmdir refuses a non-empty
    # directory, so this clears our own emptied scaffolding and stops dead at
    # anything of theirs. Never rm -rf.
    #
    # The stop is this map entry's own destination root, derived by string math
    # from the two halves we already hold: `found` is <dest>/<rel> and `rel` is
    # `mid` minus its base/ directory name, so stripping the one from the other
    # leaves <dest> with no second lookup to keep in step.
    tgt_root="${found%"/${mid#*/}"}"
    _prune_up "$(dirname "$root/$found")" "$root/$tgt_root"
  done < "$w/p2act"

  rm -rf "$w"
  return "$rc"
}
