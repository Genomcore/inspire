#!/usr/bin/env bash
# .inspire/bin/escape-hatch-ratchet.sh
#
# Rule: the number of escape hatches in the product code may fall, never rise.
# An escape hatch is a deliberate suppression of a mechanical rule — a
# `@ts-expect-error`, an `eslint-disable`, a cast that bypasses the type system.
# Forbidding them outright gets the rule switched off wholesale, so they stay,
# under a ceiling that only moves down. See
# `.claude/skills/_references/quality-gates.md` Rule 4.
#
# This is the ONE rule in this library that reads `source/` rather than the
# knowledge base: escape hatches live in production code, not in specs. It is
# stack-agnostic — every pattern and every ceiling comes from the project's own
# config, so the runtime never hardcodes one language's suppression syntax.
#
# Config: `.escape-hatches.json` at the repo root (override with
# $ESCAPE_HATCH_CONFIG). Seeded by `/inspire_bootstrap stack` from the resolved
# stack profile's `## Quality gates`.
#
#   {
#     "scope":      ["source/src", "source/test"],
#     "extensions": ["ts", "tsx"],
#     "patterns": [
#       { "id": "ts-ignore",      "regex": "@ts-ignore",      "ceiling": 0 },
#       { "id": "ts-expect-error","regex": "@ts-expect-error", "ceiling": 4 },
#       { "id": "as-any",         "regex": "as any",           "ceiling": 3 }
#     ]
#   }
#
# Ceilings are PER PATTERN, not a single total: one total would let a commit
# trade a `@ts-expect-error` for three `as any` and still pass.
#
# The ceiling lives in the repository on purpose — the exception Rule 3 grants,
# because a suppression is source text, so both the count and its allowance are
# recomputable by anyone and land in the same diff. `--update` can only LOWER a
# ceiling; raising one is a hand edit to the config, visible in review.
#
# Counting is over the working tree, not the staged index. For an agent that
# commits what it just wrote these are the same bytes; a human staging a subset
# should run this before staging, not after.
#
# Severity: error when a count exceeds its ceiling.
#
# Usage:
#   .inspire/bin/escape-hatch-ratchet.sh             # check
#   .inspire/bin/escape-hatch-ratchet.sh --update    # lower ceilings that dropped
#   ESCAPE_HATCH_CONFIG=path .inspire/bin/escape-hatch-ratchet.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

CONFIG="${ESCAPE_HATCH_CONFIG:-.escape-hatches.json}"
MODE="check"
[ "${1:-}" = "--update" ] && MODE="update"

if [ ! -f "$CONFIG" ]; then
  sdd_finding "warning" "escape-hatch-ratchet" "$CONFIG" \
    "no escape-hatch config — the ceiling is unenforced (seed it with /inspire_bootstrap stack, per quality-gates.md Rule 4)"
  sdd_count_warning
  echo "escape-hatch-ratchet: no config at $CONFIG — nothing enforced."
  exit 0
fi

if ! jq -e '.patterns | type == "array" and length > 0' "$CONFIG" >/dev/null 2>&1; then
  sdd_finding "error" "escape-hatch-ratchet" "$CONFIG" \
    "config declares no patterns — an empty ratchet passes everything, which is worse than no ratchet because it looks installed"
  sdd_count_error
  sdd_exit_with_counters
  exit $?
fi

# ─────────────────────────────────────────────────────────────────────────────
# Build the file list: every configured scope dir, filtered by extension.
# Missing scope dirs are reported, not silently skipped — a typo'd path
# would otherwise read as "zero hatches, all clear".
# ─────────────────────────────────────────────────────────────────────────────

FILE_LIST="$(mktemp -t escape-hatch-files.XXXXXX)"
trap 'rm -f "$FILE_LIST"' EXIT

ext_args=()
while IFS= read -r ext; do
  [ -z "$ext" ] && continue
  [ ${#ext_args[@]} -gt 0 ] && ext_args+=(-o)
  ext_args+=(-name "*.${ext}")
done < <(jq -r '.extensions[]? // empty' "$CONFIG")

scope_count=0
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  scope_count=$((scope_count + 1))
  if [ ! -d "$dir" ]; then
    sdd_finding "warning" "escape-hatch-ratchet" "$dir" \
      "configured scope directory does not exist — its hatches are counted as zero"
    sdd_count_warning
    continue
  fi
  if [ ${#ext_args[@]} -gt 0 ]; then
    find "$dir" -type f \( "${ext_args[@]}" \) 2>/dev/null >> "$FILE_LIST"
  else
    find "$dir" -type f 2>/dev/null >> "$FILE_LIST"
  fi
done < <(jq -r '.scope[]? // empty' "$CONFIG")

if [ "$scope_count" -eq 0 ]; then
  sdd_finding "error" "escape-hatch-ratchet" "$CONFIG" \
    "config declares no scope — nothing would be counted"
  sdd_count_error
  sdd_exit_with_counters
  exit $?
fi

# ─────────────────────────────────────────────────────────────────────────────
# Count occurrences per pattern and compare against its ceiling.
# Occurrences, not matching lines: two `as any` on one line are two hatches.
# ─────────────────────────────────────────────────────────────────────────────

lowerable="$(mktemp -t escape-hatch-lower.XXXXXX)"
trap 'rm -f "$FILE_LIST" "$lowerable"' EXIT

printf '%-24s %8s %8s\n' "PATTERN" "COUNT" "CEILING"

# Fields are extracted per pattern with individual `jq -r` calls, NOT one pass
# through `@tsv`: @tsv escapes `\` to `\\`, so a config regex like `foo\.bar`
# would reach grep as `foo\\.bar` (a literal backslash), match nothing, count
# zero, and PASS — the silent-all-clear this rule exists to prevent.
pattern_total="$(jq '.patterns | length' "$CONFIG")"
i=0
while [ "$i" -lt "$pattern_total" ]; do
  id="$(jq -r ".patterns[$i].id // empty" "$CONFIG")"
  regex="$(jq -r ".patterns[$i].regex // empty" "$CONFIG")"
  ceiling="$(jq -r ".patterns[$i].ceiling // 0" "$CONFIG")"
  i=$((i + 1))
  [ -z "$id" ] && continue

  # An empty regex would make grep match every line; a non-integer ceiling would
  # make both comparisons below error out quietly — either way the pattern would
  # neither fail nor lower, a malformed entry passing silently.
  if [ -z "$regex" ]; then
    sdd_finding "error" "escape-hatch-ratchet" "$id" \
      "pattern '$id' declares no regex — it counts nothing and passes silently; fix it in $CONFIG"
    sdd_count_error
    continue
  fi
  if ! printf '%s' "$ceiling" | grep -qE '^[0-9]+$'; then
    sdd_finding "error" "escape-hatch-ratchet" "$id" \
      "pattern '$id' has a non-integer ceiling ('$ceiling') — it can neither fail nor ratchet; fix it in $CONFIG"
    sdd_count_error
    continue
  fi

  count=0
  if [ -s "$FILE_LIST" ]; then
    count="$(tr '\n' '\0' < "$FILE_LIST" \
      | xargs -0 grep -Eoh -- "$regex" 2>/dev/null | wc -l | tr -d ' ')"
  fi

  printf '%-24s %8s %8s\n' "$id" "$count" "$ceiling"

  if [ "$count" -gt "$ceiling" ]; then
    # Name the files so the diff that broke it is obvious. Cap the list —
    # the finding is the ceiling breach, not a full inventory.
    offenders="$(tr '\n' '\0' < "$FILE_LIST" \
      | xargs -0 grep -EnH -- "$regex" 2>/dev/null | head -5 | tr '\n' ' ')"
    sdd_finding "error" "escape-hatch-ratchet" "$id" \
      "$count occurrences of '$regex' exceed the ceiling of $ceiling — remove one, or raise the ceiling in $CONFIG as a reviewable edit and open a cleanup ticket. First hits: $offenders"
    sdd_count_error
  elif [ "$count" -lt "$ceiling" ]; then
    printf '%s\t%s\n' "$id" "$count" >> "$lowerable"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# The ratchet's downward direction. Only ever lowers.
# ─────────────────────────────────────────────────────────────────────────────

if [ -s "$lowerable" ]; then
  if [ "$MODE" = "update" ]; then
    while IFS=$'\t' read -r id count; do
      [ -z "$id" ] && continue
      updated="$(jq --arg id "$id" --argjson c "$count" \
        '.patterns = [.patterns[] | if .id == $id then .ceiling = $c else . end]' \
        "$CONFIG")" || continue
      printf '%s\n' "$updated" > "$CONFIG"
      echo "lowered: $id → $count"
    done < "$lowerable"
  else
    echo ""
    echo "Ceilings that can be lowered (run with --update):"
    awk -F'\t' '{ printf "  %s → %s\n", $1, $2 }' "$lowerable"
  fi
fi

sdd_exit_with_counters
