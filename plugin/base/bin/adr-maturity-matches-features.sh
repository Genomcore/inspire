#!/usr/bin/env bash
# .inspire/bin/adr-maturity-matches-features.sh
#
# Rule: every ADR a 🟢 Implemented feature links to is itself at `implemented`.
#
# The decision layer is the only KB layer no gate reads, and it holds the most expensive
# claims in the vault — the architectural guarantees. Left unchecked, an ADR sits at
# `design` while the code that realizes it has been in production for months, and anyone
# reading the KB to answer "is what we wanted actually built?" gets the wrong answer from
# the layer that should be most authoritative.
#
# **The converse is deliberately NOT a rule.** An `implemented` ADR with no feature
# pointing at it is normal: an ADR may be realized by infrastructure, by several features
# at once, or by work that predates the feature layer. Walking ADRs and demanding a
# feature would turn a decision record into a bookkeeping chore. This gate walks
# **features** and asks about the ADRs they claim; it never walks ADRs asking for features.
# Same shape, and the same reason, as `touched-entity-lifecycle.sh`.
#
# Only 🟢 Implemented features are checked, and that is a decision rather than an
# omission. On the maturity ladder (design → prototyped → implemented) a feature that is
# 🟡 Planned or 🔵 In progress *should* be pointing at a `design`-stage ADR — the decision
# is made before the code exists. Flagging those would report the ladder working correctly
# as a defect, and a gate that fires on healthy states is one people learn to skip.
#
# Three findings, distinguished because the fixes differ:
#
#   adr-behind-feature   ADR at `design` / `prototyped` while the feature says 🟢. Either
#                        the ADR is stale (promote it) or the feature overclaims (demote
#                        it). The gate cannot tell which, so it says both.
#   adr-retired          ADR `superseded` / `rejected` while the feature says 🟢 — the
#                        feature claims to realize a decision the vault has withdrawn.
#                        Strictly worse than being behind: the code may implement
#                        something the project decided against.
#   adr-status-unreadable  The ADR carries no parseable `**Status:**` line, so the claim
#                        cannot be checked either way. Reported rather than passed over —
#                        a gate that silently skips what it cannot read is decoration.
#
# An unresolvable ADR wikilink is a warning here and nothing more: `wikilinks-resolve.sh`
# already owns that rule, and two rules reporting one defect trains people to filter both.
#
# Severity is `error` for every finding it emits, because it only ever looks at 🟢
# Implemented features — there is no earlier lifecycle state to be lenient about. The
# lifecycle-progressive shape of the other gates does not apply.
#
# **Deliberately absent from `review.sh`'s default rule list, and not because it reads
# `source/` — it does not.** `review.sh` hands every rule its own `$SCOPE`, which is the
# *spec* root (`inspire_kb/04_domain`). This rule walks the *features* root. Added to the
# default list it would be handed the domain tree, find no feature files in it, and report
# nothing — passing for ever while appearing to be enforced, which is worse than being
# absent. A rule whose scope contract differs from `review.sh`'s belongs where it can be
# given its own root: `pre-pr.sh`, and direct invocation.
#
# The three source-touching gates reach the same conclusion for a different reason; do not
# collapse the two rationales, because this one would still hold if the rule never touched
# a line of product code.
#
# Config (env, all optional): SDD_FEATURES_ROOT · SDD_ADR_ROOT.
#
# Usage:
#   .inspire/bin/adr-maturity-matches-features.sh                       # every feature
#   .inspire/bin/adr-maturity-matches-features.sh inspire_kb/03_features/analytics

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_FEATURES_ROOT}"

if [ ! -d "$SCOPE" ]; then
  sdd_finding "warning" "adr-maturity-matches-features" "$SCOPE" \
    "features root does not exist — no ADR claim can be checked"
  sdd_count_warning
  sdd_exit_with_counters
  exit $?
fi

# Resolve an ADR wikilink target to a file under the ADR root.
#
# Targets appear in two forms across the layers — path form from features
# (`[[../../01_adr/adr-x]]`) and pipe form from descriptors
# (`[[../../../01_adr/adr-x|adr-x]]`) — so match on the **basename** rather than the
# written path. That also means a link whose relative depth is wrong still resolves here:
# depth is `wikilinks-resolve.sh`'s rule, and this gate must not fail to check a maturity
# claim because a `../` was miscounted.
adr_path_for() {
  local target="$1" base
  base="$(sdd_unwrap_wikilink "$target")"
  base="${base##*/}"
  base="${base%.md}"
  [ -z "$base" ] && return 1
  [ -d "$SDD_ADR_ROOT" ] || return 1
  find "$SDD_ADR_ROOT" -type f -name "${base}.md" 2>/dev/null | head -1
}

# The status word from an ADR's `**Status:**` prose line. ADRs carry no frontmatter, by
# their own format: the line is authored for a human reader first.
#
# Lowercased, and only the first word is kept — `superseded by [[x]]` must classify as
# `superseded`, and a trailing date or parenthetical must not defeat the match.
adr_status_of() {
  local file="$1"
  grep -m1 '^\*\*Status:\*\*' "$file" 2>/dev/null \
    | sed -E 's/^\*\*Status:\*\*[[:space:]]*//; s/[[:space:]].*$//; s/[^A-Za-z-]//g' \
    | tr '[:upper:]' '[:lower:]'
}

# Two passes, because the unit of a finding is the **ADR**, not the (feature, ADR) pair.
#
# Several features legitimately rest on one decision, and the fix for a stale ADR is a
# single `promote` however many features cite it. Reporting per pair emits the same file
# several times with nearly identical messages, which is the shape people learn to skim.
# So: collect claimants first, report
# once per ADR, and name every feature so the operator can judge the claim.
#
# CLAIMS holds one `<adr-path>\t<feature-basename>` row per pair; UNRESOLVED holds the
# links that never reached an ADR file.
CLAIMS="$(mktemp -t adr-claims.XXXXXX)"
UNRESOLVED="$(mktemp -t adr-unresolved.XXXXXX)"
trap 'rm -f "$CLAIMS" "$UNRESOLVED"' EXIT

collect_feature() {
  local file="$1" state
  state="$(grep -m1 '^\*\*State:\*\*' "$file" 2>/dev/null || true)"

  # Only 🟢 Implemented. See the header: earlier states legitimately point at
  # design-stage ADRs, and reporting that would be reporting the ladder working.
  case "$state" in *"Implemented"*) ;; *) return 0 ;; esac

  local target adr seen=""
  while IFS= read -r target; do
    [ -z "$target" ] && continue

    # A feature may cite the same ADR in several sections; count it once.
    case "$seen" in *"|$target|"*) continue ;; esac
    seen="$seen|$target|"

    adr="$(adr_path_for "$target" || true)"
    if [ -z "$adr" ]; then
      printf '%s\t%s\n' "$file" "$target" >> "$UNRESOLVED"
      continue
    fi
    printf '%s\t%s\n' "$adr" "${file##*/}" >> "$CLAIMS"
  done < <(grep -oE '\[\[[^]]*adr-[^]]*\]\]' "$file" 2>/dev/null \
             | sed -E 's/^\[\[//; s/\]\]$//' | sort -u)
}

while IFS= read -r feature; do
  [ -z "$feature" ] && continue
  case "$(basename "$feature")" in README.md|_*) continue ;; esac
  collect_feature "$feature"
done < <(find "$SCOPE" -type f -name '*.md' 2>/dev/null | sort)

while IFS=$'\t' read -r file target; do
  [ -z "$file" ] && continue
  sdd_finding "warning" "adr-maturity-matches-features" "$file" \
    "links ADR \`$target\`, which does not resolve under $SDD_ADR_ROOT — the maturity claim cannot be checked (link resolution itself is wikilinks-resolve's rule)"
  sdd_count_warning
done < <(sort -u "$UNRESOLVED" 2>/dev/null)

while IFS= read -r adr; do
  [ -z "$adr" ] && continue
  claimants="$(awk -F'\t' -v a="$adr" '$1 == a { print $2 }' "$CLAIMS" | sort -u | paste -sd ',' - | sed 's/,/, /g')"
  status="$(adr_status_of "$adr")"
  case "$status" in
    implemented)
      ;;
    design|prototyped)
      sdd_finding "error" "adr-maturity-matches-features" "$adr" \
        "is at \`$status\` while 🟢 Implemented feature(s) rest on it: $claimants — an ADR the shipped code realizes must say so. Promote it (\`/inspire-adr promote\`) if the code has landed, or demote the feature if it has not; the vault currently answers \"is this built?\" two different ways"
      sdd_count_error
      ;;
    superseded|rejected)
      sdd_finding "error" "adr-maturity-matches-features" "$adr" \
        "is \`$status\` yet 🟢 Implemented feature(s) claim to realize it: $claimants — the feature claims a decision the vault has withdrawn. Either the code implements something this project decided against, or the feature should point at the ADR that replaced it"
      sdd_count_error
      ;;
    *)
      sdd_finding "error" "adr-maturity-matches-features" "$adr" \
        "carries no parseable \`**Status:**\` line, so the maturity claimed by 🟢 $claimants cannot be checked — add one from the ladder (design | prototyped | implemented | superseded by [[x]] | rejected)"
      sdd_count_error
      ;;
  esac
done < <(cut -f1 "$CLAIMS" 2>/dev/null | sort -u)

sdd_exit_with_counters
