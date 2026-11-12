#!/usr/bin/env bash
# .inspire/bin/_link-reads.sh — sourced by the validators that read the links of
# one frontmatter key, one `## Section` or one line, after _lib.sh.
#
# Both forms come out of `sdd_links`. A wikilink keeps the id it declares (right of
# the pipe); a Markdown link takes the id of the file its path names (D2), and a
# broken one names none — links-resolve.sh reports it. The caller runs
# `sdd_link_index` once in its own shell and removes `$SDD_LINK_INDEX_FILE` and
# `$SDD_ENTITY_INDEX_FILE` in its trap.

# sdd_link_id <form> <text> <path> — the id a link refers to; fails for a broken link
# and for a link to a directory, which names no id (D2).
sdd_link_id() {
  if [ "$1" = "wiki" ]; then printf '%s\n' "$2"
  elif [ -f "$3" ]; then sdd_artifact_id "$3"
  else return 1
  fi
}

# sdd_line_links <file> <from> <to> — the `sdd_links` rows between two lines.
sdd_line_links() {
  sdd_links "$1" | awk -F'\t' -v a="$2" -v b="$3" '$1 + 0 >= a + 0 && $1 + 0 <= b + 0'
}

# sdd_section_links <file> <section> — the `sdd_links` rows inside `## <section>`,
# found the way sdd_body_section finds it: a fenced heading is not a heading.
sdd_section_links() {
  local range
  range="$(awk -v header="$2" "${SDD_AWK_FM_READER}"'
      sdd_fence($0) || sdd_in_fence() { if (capture) to = NR; next }
      sdd_heading_name($0, "## ") == header { capture = 1; from = NR + 1; to = NR; next }
      /^## / && capture { exit }
      capture { to = NR }
      END { if (capture) print from, to }
    '"${SDD_AWK_FENCE_FUNCS}${SDD_AWK_HEADING_FUNCS}" "$1")"
  [ -n "$range" ] || return 0
  sdd_line_links "$1" ${range}
}

# sdd_section_link_ids <file> <section> — one id per link in the section.
sdd_section_link_ids() {
  local ln form target text path
  sdd_section_links "$1" "$2" | while IFS=$'\t' read -r ln form target text path; do
    sdd_link_id "$form" "$text" "$path" || true
  done
}

# sdd_link_in_text <rows> <text> — the first row of <rows> (`sdd_links` output)
# whose link is written in <text>, a frontmatter value or a table cell.
sdd_link_in_text() {
  local rows="$1" text="$2" ln form target t path best="" bestpos=-1 head
  while IFS=$'\t' read -r ln form target t path; do
    [ -n "$form" ] || continue
    case "$form" in
      wiki) head="${text%%"[[$target"*}" ;;
      *)    head="${text%%"]($target"*}" ;;
    esac
    [ "$head" != "$text" ] || continue
    if [ "$bestpos" -lt 0 ] || [ "${#head}" -lt "$bestpos" ]; then
      bestpos="${#head}"
      best="$ln"$'\t'"$form"$'\t'"$target"$'\t'"$t"$'\t'"$path"
    fi
  done <<< "$rows"
  [ -z "$best" ] || printf '%s\n' "$best"
  return 0
}

# sdd_fm_link_refs <file> <key> — one line per value of a frontmatter key (a scalar
# or a list): `{form}<TAB>{target}<TAB>{id}<TAB>{path}`, form wiki, md or bare (an id
# written without a link). The id is empty for a broken Markdown link; the path is
# empty unless a Markdown link resolves.
sdd_fm_link_refs() {
  local file="$1" rows value row ln form target text path id
  rows="$(sdd_links "$file")"
  while IFS= read -r value; do
    [ -n "$value" ] || continue
    row="$(sdd_link_in_text "$rows" "$value")"
    if [ -z "$row" ]; then
      printf 'bare\t%s\t%s\n' "$value" "$value"
      continue
    fi
    IFS=$'\t' read -r ln form target text path <<< "$row"
    id="$(sdd_link_id "$form" "$text" "$path")" || id=""
    printf '%s\t%s\t%s\t%s\n' "$form" "$target" "$id" "$path"
  done < <(yq --front-matter=extract \
    ".$2 | select(. != null) | ((select(tag == \"!!seq\") | .[]), select(tag != \"!!seq\"))" \
    "$file" 2>/dev/null)
}
