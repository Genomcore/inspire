#!/usr/bin/env bash
# Regression: init over a repo that already has an inspire_kb/.
# Moved from test-materialize.sh:558-625.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
SCRIPT="$PLUGIN_ROOT/scripts/materialize.sh"
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"

# ---------------------------------------------------------------------------
# Regression: /inspire:init over a repo that ALREADY has an inspire_kb/ must
# seed around it, never through it. The historical bug: init treated each
# top-level KB layer as an INSPIRE-owned entry and `rm -rf`'d it before
# copying the skeleton, so a restored backup, a KB vendored in before init, a
# hand-deleted lock — and above all the pre-0.3 migration, whose step 4 is
# `rm .inspire.lock` — all walked into total loss of the knowledge base.
# init must add only the layer files the project lacks.
# ---------------------------------------------------------------------------
pre="$(mktemp -d)/preproj"; mkdir -p "$pre"; ( cd "$pre" && git init -q )
mkdir -p "$pre/inspire_kb/00_bootstrap" "$pre/inspire_kb/03_features" \
         "$pre/inspire_kb/04_domain/billing/invoice" "$pre/inspire_kb/01_adr"
printf -- '---\nlanguage: en\n---\n# Our real stack\n' > "$pre/inspire_kb/00_bootstrap/stack.md"
printf -- '# Login\n\nAcceptance: user signs in.\n'      > "$pre/inspire_kb/03_features/feat-login.md"
printf -- '# Invoice\n\nfields:\n  - id\n'               > "$pre/inspire_kb/04_domain/billing/invoice/invoice.md"
printf -- '# ADR-0001: Use Postgres\n\nStatus: accepted\n' > "$pre/inspire_kb/01_adr/adr-0001-postgres.md"

pre_stack_before="$(shasum -a 256 "$pre/inspire_kb/00_bootstrap/stack.md" | cut -d' ' -f1)"
pre_feat_before="$(shasum -a 256 "$pre/inspire_kb/03_features/feat-login.md" | cut -d' ' -f1)"
pre_dom_before="$(shasum -a 256 "$pre/inspire_kb/04_domain/billing/invoice/invoice.md" | cut -d' ' -f1)"
pre_adr_before="$(shasum -a 256 "$pre/inspire_kb/01_adr/adr-0001-postgres.md" | cut -d' ' -f1)"

preout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$pre" \
  --source-root source --prototype-root prototype 2>/dev/null)"

check "PRE-EXISTING KB: authored feature survives init" \
  "[ -f '$pre/inspire_kb/03_features/feat-login.md' ] && [ '$pre_feat_before' = \"\$(shasum -a 256 '$pre/inspire_kb/03_features/feat-login.md' | cut -d' ' -f1)\" ]"
check "PRE-EXISTING KB: nested domain descriptor survives init" \
  "[ -f '$pre/inspire_kb/04_domain/billing/invoice/invoice.md' ] && [ '$pre_dom_before' = \"\$(shasum -a 256 '$pre/inspire_kb/04_domain/billing/invoice/invoice.md' | cut -d' ' -f1)\" ]"
check "PRE-EXISTING KB: authored ADR survives init" \
  "[ -f '$pre/inspire_kb/01_adr/adr-0001-postgres.md' ] && [ '$pre_adr_before' = \"\$(shasum -a 256 '$pre/inspire_kb/01_adr/adr-0001-postgres.md' | cut -d' ' -f1)\" ]"
# stack.md is the one KB file init may still edit — create_product_roots writes
# the answered roots into its frontmatter. It must be AMENDED, never replaced.
check "PRE-EXISTING KB: stack.md keeps its authored body" \
  "grep -q 'Our real stack' '$pre/inspire_kb/00_bootstrap/stack.md'"
check "PRE-EXISTING KB: stack.md gains the answered source_root" \
  "grep -q 'source_root' '$pre/inspire_kb/00_bootstrap/stack.md'"
# Seeding must still fill in what the project lacks, at file granularity.
check "PRE-EXISTING KB: missing file inside an existing layer is seeded" \
  "[ -f '$pre/inspire_kb/03_features/README.md' ]"
check "PRE-EXISTING KB: missing sibling in an existing layer is seeded" \
  "[ -f '$pre/inspire_kb/00_bootstrap/theme.md' ]"
check "PRE-EXISTING KB: wholly absent layer is created" \
  "[ -f '$pre/inspire_kb/99_tracker/README.md' ]"
check "PRE-EXISTING KB: design system still seeded" \
  "[ -f '$pre/inspire_kb/05_screens/design-system.md' ]"

check "PRE-EXISTING KB: reported as an adoption, not a fresh install" \
  "printf '%s' \"\$preout\" | jq -e '.existing_kb == true' >/dev/null"
check "PRE-EXISTING KB: adoption surfaced as a warning" \
  "printf '%s' \"\$preout\" | jq -e '[.warnings[] | select(test(\"already exists\"))] | length > 0' >/dev/null"
# The skill shows a dry run first, so the dry run must reveal the adoption too —
# that plan is the operator's only chance to say no.
predry="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$pre" \
  --source-root source --prototype-root prototype --dry-run 2>/dev/null)"
check "PRE-EXISTING KB: dry run also reports the adoption" \
  "printf '%s' \"\$predry\" | jq -e '.existing_kb == true' >/dev/null"

rm -rf "$(dirname "$pre")"

# A fresh repo must NOT be reported as an adoption.
frk="$(mktemp -d)/frproj"; mkdir -p "$frk"; ( cd "$frk" && git init -q )
frout="$("$SCRIPT" --mode init --plugin-root "$PLUGIN_ROOT" --project-root "$frk" \
  --source-root source --prototype-root prototype 2>/dev/null)"
check "fresh repo: not flagged as an existing KB" \
  "printf '%s' \"\$frout\" | jq -e '.existing_kb == false' >/dev/null"
rm -rf "$(dirname "$frk")"

summary
