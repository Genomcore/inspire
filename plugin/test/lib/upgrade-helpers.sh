#!/usr/bin/env bash
# The helpers test-upgrade.sh defined mid-file and reused across blocks.
# Bodies verbatim; they call sha256_of, so source scripts/lib/common.sh first.

# Count FILE deletions only. The directory-level line is `delete\t<prefix>/`,
# which a bare `^delete\t<prefix>/` grep also matches — requiring one more
# character after the final slash separates the two for good.
hop_deletes() { awk -F'\t' '$1=="delete" && $2 ~ /^\.claude\/bin\/test\/./' "$1" | wc -l | tr -d ' '; }

dirverdicts() { awk -F'\t' '$2==".claude/bin/test/"' "$1" | wc -l | tr -d ' '; }

verdict_for() { printf '%s' "$1" | awk -F'\t' -v t="$2" '$2==t{print $1; exit}'; }
detail_for()  { printf '%s' "$1" | awk -F'\t' -v t="$2" '$2==t{print $3; exit}'; }
# A content fingerprint of the whole project: path + hash of every file. classify
# must leave this byte-identical — it is the only assertion that actually proves
# "writes nothing" (a per-file existence check cannot see a rewrite).
tree_print() { ( cd "$1" && find . -type f | LC_ALL=C sort \
                 | while IFS= read -r f; do printf '%s %s\n' "$f" "$(sha256_of "$f")"; done ); }

same_file() { [ "$(sha256_of "$1")" = "$(sha256_of "$2")" ]; }
# Fast whole-tree fingerprint (path + content of every file). tree_print above
# spawns a process per file, which is too slow for a 935-file 0.2.1 fixture.
if command -v sha256sum >/dev/null 2>&1; then SHA_CMD="sha256sum"; else SHA_CMD="shasum -a 256"; fi
tree_hash() {
  local t; t="$(mktemp)"
  ( cd "$1" && find . -type f | LC_ALL=C sort | tr '\n' '\0' | xargs -0 $SHA_CMD ) > "$t" 2>/dev/null
  sha256_of "$t"; rm -f "$t"
}
# Octal mode, portably enough for the two platforms this suite runs on.
mode_of() {
  case "$(uname -s)" in Darwin*|*BSD*) stat -f '%Lp' "$1" ;; *) stat -c '%a' "$1" ;; esac
}
