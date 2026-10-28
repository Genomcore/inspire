#!/usr/bin/env bash
# Layout hop: 0.12.x → 0.13.0 — every stack profile becomes a skill of its own.
#
# Sourced by lib/chain.sh with hop-ops already initialised. What moved:
#
#   .claude/skills/inspire-code/profiles/<id>.md   → .claude/skills/inspire-code-<id>/SKILL.md
#   .claude/skills/inspire-code/profiles/<id>/<p>  → .claude/skills/inspire-code-<id>/<p>
#
# and the rest of inspire-code — its SKILL.md, its references, the profiles'
# README and _example — is simply no longer shipped. That half needs no line
# here: classify already reads it as dropped upstream, so an untouched file is
# deleted and an edited one is kept where it is.
#
# THIS HOP ONLY CARRIES EDITS. classify runs before it, against the 0.12 paths:
# a pristine profile is `delete` at its old path and its new skill is a
# `create`, so the applier lays the shipped version down with no help from
# here. An edited one is `keep` at its old path — and left there, the operator's
# `## Bindings` would sit in a file nothing reads while a pristine skill with
# the shipped seed took over. So an edited file moves to its new path, where
# its hash (already in the keep-set) makes the applier leave it alone.
#
# A moved PROFILE is always a question, because the new version always differs
# from it: the skill's frontmatter gained `name`, `description` and `stack`, and
# lost `kind` and `id`. That is "you and we both changed it", the one case the
# merge asks about. --take-mine (or no answer) keeps theirs at the new path, to
# be given the new frontmatter by hand; --take-base leaves theirs at the old
# path, untouched, and takes the shipped skill. Either way nothing is lost. A
# moved REFERENCE asks only when we changed it too.
#
# Only paths INSPIRE shipped are moved, read from the source manifest, so the
# set follows whatever version the chain starts from. A profile the operator
# authored is theirs and stays where it is; the report names its new home.

_h13_old=".claude/skills/inspire-code/profiles"

# _h13_new <old path> → the 0.13 path, or rc 1 for a path that does not move.
_h13_new() {
  local _h13_n_rel="${1#"$_h13_old"/}" _h13_n_id
  case "$_h13_n_rel" in
    README.md|_example.md) return 1 ;;
    */*) _h13_n_id="${_h13_n_rel%%/*}"
         printf '.claude/skills/inspire-code-%s/%s\n' "$_h13_n_id" "${_h13_n_rel#*/}" ;;
    *.md) printf '.claude/skills/inspire-code-%s/SKILL.md\n' "${_h13_n_rel%.md}" ;;
    *) return 1 ;;
  esac
}

# _h13_taken <path> <array name> → 0 when the operator named <path> in it.
_h13_taken() {
  local _h13_t_p
  if [ "$2" = TAKE_BASE ]; then
    for _h13_t_p in ${TAKE_BASE[@]+"${TAKE_BASE[@]}"}; do [ "$_h13_t_p" = "$1" ] && return 0; done
  else
    for _h13_t_p in ${TAKE_MINE[@]+"${TAKE_MINE[@]}"}; do [ "$_h13_t_p" = "$1" ] && return 0; done
  fi
  return 1
}

while IFS=$'\t' read -r _h13_path _h13_hash; do
  case "$_h13_path" in "$_h13_old"/*) ;; *) continue ;; esac
  _h13_dst="$(_h13_new "$_h13_path")" || continue
  # Shipped by the target, or the move has nowhere to land.
  [ -f "$plugin_root/base/skills/${_h13_dst#.claude/skills/}" ] || continue
  [ -f "$PROJECT_ROOT/$_h13_path" ] || continue
  _h13_disk="$(sha256_of "$PROJECT_ROOT/$_h13_path")"
  [ "$_h13_disk" = "$_h13_hash" ] && continue          # pristine: the applier has it

  if _h13_taken "$_h13_dst" TAKE_BASE; then
    # A report row carrying the path, so the resolution reads as consumed.
    _hop_journal report "$_h13_dst" "$_h13_dst takes the shipped version (--take-base). Your edited copy stays at $_h13_path, and nothing reads it there."
    continue
  fi
  hop_mv "$_h13_path" "$_h13_dst" || continue
  if _h13_taken "$_h13_dst" TAKE_MINE; then
    _hop_journal keep "$_h13_dst" 'kept on your instruction (--take-mine)'
  elif [ "$(sha256_of "$plugin_root/base/skills/${_h13_dst#.claude/skills/}")" != "$_h13_hash" ]; then
    case "$_h13_dst" in
      */SKILL.md) hop_ask "$_h13_dst" "your edited profile, moved here unchanged. The skill's frontmatter is new: add name, description and stack: <id>, and drop kind and id (--take-mine), or take the shipped skill and keep yours at $_h13_path (--take-base)" ;;
      *) hop_ask "$_h13_dst" "your edited reference, moved here unchanged; this release changed it too" ;;
    esac
  fi
done < <(manifest_paths "$HOP_SOURCE_MANIFEST")

hop_report 'Stack profiles are skills now: .claude/skills/<name>/SKILL.md with stack: <id> in its frontmatter, served only to the units whose stack.md profiles: names that id. A profile you authored under .claude/skills/inspire-code/profiles/ was left where it is, and nothing reads it there.'
