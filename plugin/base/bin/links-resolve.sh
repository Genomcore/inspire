#!/usr/bin/env bash
# .inspire/bin/links-resolve.sh
#
# Rule: every link in an action, an entity or a screen is a relative Markdown
# link to a file that exists (adr-markdown-links D1, D2). Frontmatter is read;
# a link in a code span or a fenced block is an example and is skipped (D4).
#
#   - A Markdown link whose path, joined to the linking file's directory, names
#     no file → error.
#   - A wikilink → error naming `/inspire:migrate`, which converts it (D5, D6).
#     The finding says whether it resolves, through the routes `sdd_links`
#     documents: `/inspire:migrate` converts only a wikilink that resolves.
#
# Severity: error at every lifecycle. A skill that writes a link creates its
# target first (D7), so a broken link is never work in progress.
#
# A link to one target is one finding per file, at the line where it first
# appears. The rule receives one `$1` and checks the files in `$1 ∩ 01_spec`;
# the wikilink index is always built KB-wide, so a scoped run still resolves a
# link that points outside its scope.
#
# Usage:
#   .inspire/bin/links-resolve.sh                                     # every layer
#   .inspire/bin/links-resolve.sh inspire_kb/01_spec/_modules/auth    # one module
#   .inspire/bin/links-resolve.sh inspire_kb/01_spec/_faces           # every face

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

trap 'rm -f "${SDD_LINK_INDEX_FILE:-}" "${SDD_ENTITY_INDEX_FILE:-}"' EXIT
sdd_link_index

check_file() {
  local file="$1" seen=" " ln form target text path
  while IFS=$'\t' read -r ln form target text path; do
    case "$seen" in *" $form:$target "*) continue ;; esac
    seen="$seen$form:$target "
    if [ "$form" = wiki ] && [ -n "$path" ]; then
      sdd_finding error links-resolve "$file" \
        "wikilink [[$target]] at line $ln: convert it to a Markdown link with /inspire:migrate (it resolves to $path)"
    elif [ "$form" = wiki ]; then
      sdd_finding error links-resolve "$file" \
        "wikilink does not resolve: [[$target]] at line $ln: /inspire:migrate converts the wikilinks that resolve and lists this one"
    elif [ -z "$path" ]; then
      sdd_finding error links-resolve "$file" \
        "link does not resolve: [$text]($target) at line $ln: no such file relative to this one"
    else
      continue
    fi
    sdd_count_error
  done < <(sdd_links "$file")
}

SPEC_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_SPEC_ROOT")"
[ -n "$SPEC_SCOPE" ] || exit 0

while IFS= read -r file; do
  [ -n "$file" ] && check_file "$file"
done < <(sdd_find_actions "$SPEC_SCOPE"; sdd_find_entities "$SPEC_SCOPE"; sdd_find_screens "$SPEC_SCOPE")

sdd_exit_with_counters
