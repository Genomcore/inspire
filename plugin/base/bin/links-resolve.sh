#!/usr/bin/env bash
# .inspire/bin/links-resolve.sh
#
# Rule: every link in a Markdown file under the KB is a relative Markdown link to a
# file or directory that exists (adr-markdown-links D1, D2). Templates
# (`*.template.md`) and `_migration/` are not checked. Frontmatter is read; a link in
# a code span or a fenced block is an example and is skipped (D4).
#
#   - A Markdown link whose path names no file and no directory → error. The path
#     joins the linking file's directory, out of the KB too; one that starts with
#     `/` joins the repository root (`sdd_repo_root`).
#   - A wikilink → error naming `/inspire:migrate`, which converts it (D5, D6).
#
# Severity: error at every lifecycle. A skill that writes a link creates its
# target first (D7), so a broken link is never work in progress.
#
# A link to one target is one finding per file, at the line where it first
# appears. The rule receives one `$1` and checks the files in `$1 ∩ the KB`.
#
# Usage:
#   .inspire/bin/links-resolve.sh                                     # the whole KB
#   .inspire/bin/links-resolve.sh inspire_kb/01_spec/_modules/auth    # one module
#   .inspire/bin/links-resolve.sh inspire_kb/99_tracker               # the tracker

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

check_file() {
  local file="$1" seen=" " ln form target text path
  while IFS=$'\t' read -r ln form target text path; do
    case "$seen" in *" $form:$target "*) continue ;; esac
    seen="$seen$form:$target "
    if [ "$form" = wiki ]; then
      sdd_finding error links-resolve "$file" \
        "wikilink [[$target]] at line $ln: convert it to a Markdown link with /inspire:migrate"
    elif [ -z "$path" ]; then
      sdd_finding error links-resolve "$file" \
        "link does not resolve: [$text]($target) at line $ln: no such file or directory relative to this one"
    else
      continue
    fi
    sdd_count_error
  done < <(sdd_links "$file" wiki)
}

while IFS= read -r file; do
  [ -n "$file" ] && check_file "$file"
done < <(sdd_find_linking "$SCOPE")

sdd_exit_with_counters
