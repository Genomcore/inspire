#!/usr/bin/env bash
# .inspire/bin/profile-gates-installed.sh
#
# Rule: every quality gate a resolved stack profile DECLARES is actually present in the
# project's config.
#
# This is the gate that guards the other gates. A profile's `## Quality gates` section is
# the spec for a project's mechanical enforcement, and without this rule nothing compares
# that spec to reality. The failure it exists for is quiet and typical: the profile
# promises three plugin sets and a coverage floor, the config has none of them, and every
# run of every other validator passes. Prose is not enforcement — a rule is not in force
# until something loads or checks it, and the *checker* itself is the piece most easily
# written yet never installed.
#
# **It reads the profile's `gates:` frontmatter, never its prose.** That separation is the
# whole design, not an implementation shortcut. `## Quality gates` deliberately names rules
# the stack **rejects** on measured evidence (`complexity`, with the reason), so a validator
# scraping the prose would demand the very thing the reasoning refuses — and a gate whose
# findings are wrong is one people learn to filter. The prose says why; the frontmatter says
# what must be true.
#
# Contract, per entry in `gates:`:
#
#   literal:  grepped VERBATIM (grep -F) against the config file. No regex, no globbing —
#             the same choice as sdd_literal_in_tests, and for the same reason: the only way
#             to satisfy it is to actually put it there.
#   config:   path relative to the project's source root.
#   expect:   `present` (default) or `absent`. `absent` is how a deliberate non-adoption
#             stays deliberate: re-adopting the rule then requires editing the profile,
#             which is the decision being made explicit rather than arriving quietly.
#
# **What it cannot see, stated rather than implied:** a literal that is present but switched
# `off`, and a rule whose severity is `warn` where the profile meant `error`. A text match
# cannot tell those apart. The stronger check is asking the toolchain for its resolved
# config (`eslint --print-config <file>` and its equivalents), which is stack-specific and
# therefore belongs in a profile-declared verification command, not in this generic rule.
# Today's failure mode was the blunt one — the rule simply was not there — so this catches
# what actually happens; widen it if a present-but-disabled gate ever ships.
#
# Findings:
#
#   gate-not-installed      declared `present`, missing from the config. Error.
#   gate-unexpectedly-present  declared `absent`, found. Error — a rejected rule came back.
#   config-missing          the config file the gate names does not exist. Error: the claim
#                           cannot be checked, and an unverifiable gate must not read as a
#                           passing one.
#   profile-missing         `stack.md` resolves a profile that has no file. Error.
#   gates-undeclared        the profile has a `## Quality gates` section and no `gates:`
#                           frontmatter. Warning, not error: declaring the contract is work
#                           this rule is asking for, not a defect in the project's code.
#
# Only profiles the project actually resolves are checked — `stack.md`'s `profiles:` — so an
# unused profile in the catalogue never blocks anyone.
#
# Reads the KB (stack.md), the runtime (the profiles) and the product's config, so it is
# deliberately absent from `review.sh`'s default rule list: that hands every rule the spec
# root, and this one takes no scope at all.
#
# Config (env, all optional): SDD_BOOTSTRAP_ROOT · SDD_PROFILES_ROOT · SDD_SOURCE_ROOT.
#
# Usage:
#   .inspire/bin/profile-gates-installed.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

RULE="profile-gates-installed"
STACK_FILE="$SDD_BOOTSTRAP_ROOT/stack.md"

if [ ! -f "$STACK_FILE" ]; then
  sdd_finding "warning" "$RULE" "$STACK_FILE" \
    "no stack.md — nothing declares which profiles this project resolves, so no gate can be checked"
  sdd_count_warning
  sdd_exit_with_counters
  exit $?
fi

PROFILES="$(sdd_fm_list "$STACK_FILE" '.profiles')"
if [ -z "$PROFILES" ]; then
  sdd_finding "warning" "$RULE" "$STACK_FILE" \
    "declares no \`profiles:\` — /inspire_code falls back to inference, and with no resolved profile there is no gate contract to enforce"
  sdd_count_warning
  sdd_exit_with_counters
  exit $?
fi

check_profile() {
  local id="$1" profile="$SDD_PROFILES_ROOT/$1.md"

  if [ ! -f "$profile" ]; then
    sdd_finding "error" "$RULE" "$STACK_FILE" \
      "resolves profile \`$id\` but $profile does not exist — the stack names a contract nothing defines"
    sdd_count_error
    return 0
  fi

  local count
  count="$(yq --front-matter=extract '.gates | length' "$profile" 2>/dev/null || echo 0)"
  case "$count" in ''|*[!0-9]*) count=0 ;; esac

  if [ "$count" -eq 0 ]; then
    # Only worth saying when the prose promises something a contract could carry.
    if grep -q '^## Quality gates' "$profile" 2>/dev/null; then
      sdd_finding "warning" "$RULE" "$profile" \
        "has a \`## Quality gates\` section but no \`gates:\` frontmatter — the prose promises enforcement and nothing checks the project installed it. Declare the machine-checkable half"
      sdd_count_warning
    fi
    return 0
  fi

  local i literal config expect target
  for ((i = 0; i < count; i++)); do
    literal="$(yq --front-matter=extract ".gates[$i].literal" "$profile" 2>/dev/null)"
    config="$(yq --front-matter=extract ".gates[$i].config" "$profile" 2>/dev/null)"
    expect="$(yq --front-matter=extract ".gates[$i].expect // \"present\"" "$profile" 2>/dev/null)"

    if [ -z "$literal" ] || [ "$literal" = "null" ] || [ -z "$config" ] || [ "$config" = "null" ]; then
      sdd_finding "error" "$RULE" "$profile" \
        "gate #$((i + 1)) is missing \`literal\` or \`config\` — an entry that names neither can never be checked, so it reads as a gate while being none"
      sdd_count_error
      continue
    fi

    target="$SDD_SOURCE_ROOT/$config"
    if [ ! -f "$target" ]; then
      sdd_finding "error" "$RULE" "$target" \
        "profile \`$id\` declares gate \`$literal\` in this file, which does not exist — the gate cannot be verified, and an unverifiable gate must not read as an installed one"
      sdd_count_error
      continue
    fi

    if grep -qF -- "$literal" "$target" 2>/dev/null; then
      if [ "$expect" = "absent" ]; then
        sdd_finding "error" "$RULE" "$target" \
          "contains \`$literal\`, which profile \`$id\` declares as deliberately NOT adopted — re-adopting it is a decision, so update the profile's \`## Quality gates\` reasoning and its \`gates:\` entry, or take it back out"
        sdd_count_error
      fi
    elif [ "$expect" != "absent" ]; then
      sdd_finding "error" "$RULE" "$target" \
        "does not contain \`$literal\`, which profile \`$id\` declares as an installed quality gate — either install it or stop promising it. A documented gate the project never installed is enforcement that exists only on paper"
      sdd_count_error
    fi
  done
}

while IFS= read -r id; do
  [ -z "$id" ] && continue
  check_profile "$id"
done <<< "$PROFILES"

sdd_exit_with_counters
