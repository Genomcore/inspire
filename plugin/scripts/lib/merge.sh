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
# This filter is why a "does the target ship it?" question is not just
# `[ -f base/<middle> ]`. It mirrors materialize.sh's copy_plan exactly, and it
# is load-bearing in BOTH directions:
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
_middle() {
  local map="$1" path="$2" pair name dest
  for pair in $map; do
    name="${pair%%:*}"; dest="${pair#*:}"
    case "$path" in
      "$dest"/*) printf '%s\n' "$name/${path#"$dest"/}"; return 0 ;;
    esac
  done
  return 1
}

# _from_middle <dest_map> <middle> → the path that map materializes it at
_from_middle() {
  local map="$1" mid="$2" pair name dest
  for pair in $map; do
    name="${pair%%:*}"; dest="${pair#*:}"
    case "$mid" in
      "$name"/*) printf '%s\n' "$dest/${mid#"$name"/}"; return 0 ;;
    esac
  done
  return 1
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
_base_src() {
  local base="$1" map="$2" path="$3" mid name rel
  mid="$(_middle "$map" "$path")" || return 1
  [ -n "$mid" ] || return 1
  name="${mid%%/*}"; rel="${mid#*/}"
  _base_excluded "$name" "$rel" && return 1
  [ -f "$base/$mid" ] || return 1
  printf '%s\n' "$base/$mid"
}

# classify <source_manifest> <project_root> <base_dir> <src_map> <tgt_map>
#   → lines `<verdict>\t<path>\t<detail>` on stdout.
classify() {
  local mf="$1" root="$2" base="$3" src_map="$4" tgt_map="$5"
  local target hash_a hash_b hash_c src pair name dest abs rel moved
  local seen; seen="$(mktemp)"; : > "$seen"

  # Pass 1 — everything the source version shipped. Paths are in SOURCE space,
  # so the source map is what locates their base/ counterpart.
  while IFS=$'\t' read -r target hash_a; do
    [ -n "$target" ] || continue
    printf '%s\n' "$target" >> "$seen"
    src="$(_base_src "$base" "$src_map" "$target")" || src=""

    if [ ! -f "$root/$target" ]; then
      if [ -e "$root/$target" ]; then
        # A directory (or other non-regular entry) where we shipped a file.
        printf 'keep\t%s\t%s\n' "$target" "not a regular file here; left untouched"
      elif [ -n "$src" ]; then
        printf 'restore\t%s\t%s\n' "$target" "you deleted this; restoring at the new version"
      fi
      continue
    fi
    hash_b="$(sha256_of "$root/$target")"

    if [ -z "$src" ]; then
      # Dropped upstream.
      if [ "$hash_b" = "$hash_a" ]; then
        printf 'delete\t%s\t%s\n' "$target" "no longer part of INSPIRE"
      else
        printf 'keep\t%s\t%s\n' "$target" "no longer part of INSPIRE, but you edited it"
      fi
      continue
    fi
    hash_c="$(sha256_of "$src")"

    if [ "$hash_b" = "$hash_a" ]; then
      if [ "$hash_c" = "$hash_a" ]; then
        printf 'noop\t%s\t\n' "$target"
      else
        printf 'replace\t%s\t%s\n' "$target" "untouched, takes the new version"
      fi
    else
      if [ "$hash_c" = "$hash_a" ]; then
        printf 'keep\t%s\t%s\n' "$target" "you changed it, we did not"
      elif [ "$hash_c" = "$hash_b" ]; then
        printf 'noop\t%s\t%s\n' "$target" "your edit already matches the new version"
      else
        printf 'ask\t%s\t%s\n' "$target" "you and we both changed it"
      fi
    fi
  done < <(manifest_paths "$mf")

  # Pass 2 — what the target version ships that the source did not. Paths are
  # in TARGET space. A file that merely MOVED is not new: it was already seen in
  # pass 1 under its SOURCE path, so that path is checked too before calling it
  # a creation. Without it every validator on a pre-0.3 project would be
  # announced as new at .inspire/bin/ while also being deleted from .claude/bin/.
  for pair in $tgt_map; do
    name="${pair%%:*}"; dest="${pair#*:}"
    [ -d "$base/$name" ] || continue
    while IFS= read -r abs; do
      rel="${abs#"$base/$name"/}"
      _base_excluded "$name" "$rel" && continue
      target="$dest/$rel"
      grep -Fxq "$target" "$seen" && continue
      moved="$(_from_middle "$src_map" "$name/$rel")" || moved=""
      if [ -n "$moved" ]; then
        grep -Fxq "$moved" "$seen" && continue
      fi
      if [ -e "$root/$target" ]; then
        if [ -f "$root/$target" ] \
           && [ "$(sha256_of "$root/$target")" = "$(sha256_of "$abs")" ]; then
          printf 'noop\t%s\t\n' "$target"
        else
          printf 'ask\t%s\t%s\n' "$target" "new in this release, and you already have a different file here"
        fi
      else
        printf 'create\t%s\t%s\n' "$target" "new in this release"
      fi
      printf '%s\n' "$target" >> "$seen"
    done < <(find "$base/$name" -type f)
  done

  # Pass 3 — project-authored files inside directories INSPIRE owns. These are
  # never ours and must survive; this is the row that replaces materialize_entry's
  # `rm -rf` of a whole owned entry. Disk is still in SOURCE space at this point,
  # so walk the source map.
  for pair in $src_map; do
    dest="${pair#*:}"
    [ -d "$root/$dest" ] || continue
    while IFS= read -r abs; do
      rel="${abs#"$root"/}"
      grep -Fxq "$rel" "$seen" && continue
      printf 'keep\t%s\t%s\n' "$rel" "yours — INSPIRE never shipped this"
      printf '%s\n' "$rel" >> "$seen"
    done < <(find "$root/$dest" -type f)
  done

  rm -f "$seen"
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
  while IFS=$'\t' read -r verdict target detail; do
    case "$verdict" in
      keep|ask) ;;
      *) continue ;;
    esac
    [ -f "$root/$target" ] || continue
    sha256_of "$root/$target"
  done < "$vf" | LC_ALL=C sort -u
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
#   · pass 2 prunes only the immediate parent directory of a file it removed,
#     and only if that leaves it empty. Deeper empty scaffolding may remain;
#     nothing claims otherwise, and hop_rm_owned owns the deep prune.
apply_base() {
  local keep="$1" mf="$2" root="$3" base="$4" src_map="$5" tgt_map="$6" record="$7"
  local pair name dest abs rel target h rc=0

  # Pass 1 — every file the target version ships.
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

      # A directory (or fifo, socket, device node) where we ship a file. `mv a b`
      # with b a directory puts a INSIDE it and reports success — silent tree
      # corruption. classify already reports this path as `keep`; do nothing.
      if [ -e "$root/$target" ] && [ ! -f "$root/$target" ]; then
        continue
      fi

      if [ -f "$root/$target" ]; then
        h="$(sha256_of "$root/$target")"
        # Theirs to keep, or already identical to ours: leave it.
        grep -Fxq "$h" "$keep" 2>/dev/null && continue
        [ "$h" = "$(sha256_of "$abs")" ] && continue
      fi

      # The decision above is made in both modes; only the act is switched, so a
      # preview can never diverge from what the real run decides.
      [ "$record" = 1 ] && continue
      _apply_write "$abs" "$root/$target" "$name/$rel" || rc=2
    done < <(find "$base/$name" -type f)
  done

  # Pass 2 — files we shipped at the SOURCE version that the target no longer
  # ships. Removed only when still byte-identical to what we shipped: an edited
  # one is the operator's and is never deleted (classify reports it as `keep`).
  #
  # That hash test is strictly stronger than consulting the keep-set here, which
  # is why it does not: every keep/ask verdict at a manifest path implies a hash
  # that differs from the manifest's, so an operator's file can never satisfy it.
  local path hash mid found
  while IFS=$'\t' read -r path hash; do
    [ -n "$path" ] || continue
    # Source path → base-relative middle → where the target layout puts it.
    mid="$(_middle "$src_map" "$path")" || continue
    [ -n "$mid" ] || continue
    found="$(_from_middle "$tgt_map" "$mid")" || continue
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
    [ "$(sha256_of "$root/$found")" = "$hash" ] || continue   # not ours to delete
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
    rmdir "$(dirname "$root/$found")" 2>/dev/null
  done < <(manifest_paths "$mf")

  return "$rc"
}
