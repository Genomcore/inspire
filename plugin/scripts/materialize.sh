#!/usr/bin/env bash
#
# plugin/scripts/materialize.sh — the deterministic engine shared by /inspire:init
# and /inspire:update.
#
# Everything mechanical lives here rather than in skill prose: version detection,
# layout verification, the layout hops, the three-way content merge, chmod,
# excluding bin/test/, seeding the KB and the design system, seeding CLAUDE.md and
# .gitignore, creating product roots, the marker-based settings.json merge, and
# writing .inspire.lock. Skills carry judgment — preconditions, questions,
# routing, reporting; this script carries the merge rules exactly once so init
# and update cannot drift apart.
#
# Never materialized itself: this file and plugin/test/ live outside plugin/base/,
# so /inspire:init has no path that would ever copy them into a project.
#
# Usage:
#   materialize.sh --mode init|update|plan
#                   --plugin-root PATH        # ${CLAUDE_PLUGIN_ROOT}
#                   --project-root PATH       # repo root
#                   [--source-root VALUE]     # e.g. source | . | none   (init/update)
#                   [--prototype-root VALUE]  # e.g. prototype | none    (init/update)
#                   [--declare-marketplace]   # add extraKnownMarketplaces + enabledPlugins
#                   [--take-base RELPATH]...  # update: resolve an `ask` row to OUR version
#                   [--take-mine RELPATH]...  # update: resolve an `ask` row to THEIRS
#                   [--skip RELPATH]...       # deprecated alias for --take-mine
#                   [--dry-run]               # plan only, write nothing
#
# --mode update is the chain-driven upgrade: detect the project's version,
# verify its layout, classify content against the manifest that version shipped,
# run the layout hops, then apply the target version's base/ around everything
# the operator gets to keep. An `ask` row nobody resolved defaults to KEEPING the
# operator's file — doing nothing is how work survives.
#
# --mode plan is read-only: it detects the project's version, verifies its
# layout, enumerates the hop chain in RECORD mode, classifies content and
# reports the result — a JSON summary on stdout, a grouped report on stderr.
# It writes nothing to the project. `drift-check` is accepted as a deprecated
# alias for it.
#
# stdout: a JSON summary (machine-readable). stderr: human progress.
# exit:   0 ok · 1 precondition failure · 2 partial failure (nothing committed)
#
# Prerequisites: bash 3.2+ (macOS default), yq (Mike Farah's v4), jq 1.6+.

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/manifest.sh"
. "$SCRIPT_DIR/lib/hop-ops.sh"
. "$SCRIPT_DIR/lib/chain.sh"
. "$SCRIPT_DIR/lib/merge.sh"
. "$SCRIPT_DIR/lib/report.sh"

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

usage() {
  cat >&2 <<'EOF'
Usage: materialize.sh --mode init|update|plan
                       --plugin-root PATH --project-root PATH
                       [--source-root VALUE] [--prototype-root VALUE]
                       [--declare-marketplace]
                       [--take-base RELPATH]... [--take-mine RELPATH]...
                       [--dry-run]

       'drift-check' is accepted as a deprecated alias for 'plan'.
       '--skip'       is accepted as a deprecated alias for '--take-mine'.
EOF
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

MODE=""
PLUGIN_ROOT=""
PROJECT_ROOT=""
SOURCE_ROOT=""
PROTOTYPE_ROOT=""
SOURCE_ROOT_SET=0
PROTOTYPE_ROOT_SET=0
DECLARE_MARKETPLACE=0
DRY_RUN=0
# The two ways an `ask` row gets resolved. Repeatable, project-relative paths in
# the SOURCE layout's space — the space classify's verdicts are in, which is
# also the space `--mode plan` reports them in, so the operator can hand a path
# straight back from the plan.
TAKE_BASE=()
TAKE_MINE=()

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mode)
        [ "$#" -ge 2 ] || { log "materialize.sh: --mode requires a value"; usage; exit 1; }
        MODE="$2"; shift 2 ;;
      --plugin-root)
        [ "$#" -ge 2 ] || { log "materialize.sh: --plugin-root requires a value"; usage; exit 1; }
        PLUGIN_ROOT="$2"; shift 2 ;;
      --project-root)
        [ "$#" -ge 2 ] || { log "materialize.sh: --project-root requires a value"; usage; exit 1; }
        PROJECT_ROOT="$2"; shift 2 ;;
      --source-root)
        [ "$#" -ge 2 ] || { log "materialize.sh: --source-root requires a value"; usage; exit 1; }
        SOURCE_ROOT="$2"; SOURCE_ROOT_SET=1; shift 2 ;;
      --prototype-root)
        [ "$#" -ge 2 ] || { log "materialize.sh: --prototype-root requires a value"; usage; exit 1; }
        PROTOTYPE_ROOT="$2"; PROTOTYPE_ROOT_SET=1; shift 2 ;;
      --declare-marketplace)
        DECLARE_MARKETPLACE=1; shift 1 ;;
      # A resolution value is matched against a verdict path and, for --take-base,
      # decides that a file gets overwritten. It must therefore not be able to
      # name anything outside the project: the values are echoed back from a plan
      # the operator may have hand-edited, and a lock or report is not a
      # capability grant.
      --take-base)
        [ "$#" -ge 2 ] || { log "materialize.sh: --take-base requires a value"; usage; exit 1; }
        case "$2" in
          /*|*..*)
            log "materialize.sh: --take-base '$2' must be project-relative without '..'"; exit 1 ;;
        esac
        TAKE_BASE+=("$2"); shift 2 ;;
      --take-mine)
        [ "$#" -ge 2 ] || { log "materialize.sh: --take-mine requires a value"; usage; exit 1; }
        case "$2" in
          /*|*..*)
            log "materialize.sh: --take-mine '$2' must be project-relative without '..'"; exit 1 ;;
        esac
        TAKE_MINE+=("$2"); shift 2 ;;
      # Deprecated. --skip used to mean "do not overwrite this drifted path",
      # which is exactly --take-mine now that the merge decides per file rather
      # than replacing whole entries. Kept so the 0.3 update skill's command
      # line keeps working.
      --skip)
        [ "$#" -ge 2 ] || { log "materialize.sh: --skip requires a value"; usage; exit 1; }
        case "$2" in
          /*|*..*)
            log "materialize.sh: --skip '$2' must be a project-relative path without '..'"; exit 1 ;;
        esac
        TAKE_MINE+=("$2"); shift 2 ;;
      --dry-run)
        DRY_RUN=1; shift 1 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        log "materialize.sh: unknown flag '$1'"; usage; exit 1 ;;
    esac
  done
}

validate_args() {
  case "$MODE" in
    init|update|plan) ;;
    drift-check) MODE=plan ;;   # deprecated alias
    *) log "materialize.sh: --mode must be init, update or plan (got '${MODE:-<missing>}')"; usage; exit 1 ;;
  esac
  [ -n "$PLUGIN_ROOT" ] || { log "materialize.sh: --plugin-root is required"; usage; exit 1; }
  [ -n "$PROJECT_ROOT" ] || { log "materialize.sh: --project-root is required"; usage; exit 1; }
  [ -d "$PLUGIN_ROOT" ] || { log "materialize.sh: --plugin-root '$PLUGIN_ROOT' is not a directory"; exit 1; }
  # A directory is not enough: every consumer of $PLUGIN_ROOT/base degrades
  # SILENTLY when it is absent (apply_base becomes a no-op, the seeds return
  # early), so a wrong --plugin-root would otherwise report a successful install
  # that installed nothing — and write an .inspire.lock that makes /inspire:init
  # refuse forever while update cannot seed the KB. Fail loudly instead.
  [ -d "$PLUGIN_ROOT/base" ] || {
    log "materialize.sh: --plugin-root '$PLUGIN_ROOT' has no base/ — not an INSPIRE plugin root"; exit 1; }
  [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ] || {
    log "materialize.sh: --plugin-root '$PLUGIN_ROOT' has no .claude-plugin/plugin.json — not an INSPIRE plugin root"; exit 1; }
  [ -d "$PROJECT_ROOT" ] || { log "materialize.sh: --project-root '$PROJECT_ROOT' is not a directory"; exit 1; }
  command -v jq >/dev/null 2>&1 || { log "materialize.sh: jq is required on PATH"; exit 1; }
  command -v yq >/dev/null 2>&1 || { log "materialize.sh: yq is required on PATH"; exit 1; }
  git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    log "materialize.sh: --project-root '$PROJECT_ROOT' is not a git work tree"; exit 1; }
}

resolve_paths() {
  PLUGIN_ROOT="$(cd -P "$PLUGIN_ROOT" && pwd -P)"
  PROJECT_ROOT="$(cd -P "$PROJECT_ROOT" && pwd -P)"
  PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
}

# ---------------------------------------------------------------------------
# Module-level state.
#
# The layout this plugin version installs. Its dest_map — and every source
# version's — comes from layouts.tsv via layout_map, never from a literal here.
#
# There is no copy plan any more. base/{bin,hooks,skills} reach the project
# through lib/merge.sh's apply_base, driven by the target layout's dest_map and
# by classify's verdicts, so "in the project but never shipped by us" is a KEEP
# row and the file survives by construction. The function this replaced,
# materialize_entry, did `rm -rf` on a whole owned entry before `cp -R` — which
# destroyed a project-authored file living inside an INSPIRE-owned directory
# (say .claude/skills/inspire-code/references/go-best-practices.md) with nothing
# able to protect it: the lock never tracked it, so drift-check never reported
# it and --skip could never cover it.
#
# base/kb is deliberately outside that map. Everything in the map is
# INSPIRE-owned runtime; the KB is product content and is only ever *seeded*
# (see seed_kb), never replaced, in either mode.
# ---------------------------------------------------------------------------
TARGET_LAYOUT='0.3'

# Everything this run ADDED that was not there before, whole KB layers included.
# There is no separate `copied` list any more: the runtime half is reported per
# file by render_report from the verdicts and the hop journal, so a second,
# entry-granular list of the same work would only be a way for the two to
# disagree.
CREATED=()
WARNINGS=()
SETTINGS_STATUS="unchanged"
LOCK_STATUS="unchanged"

# Seed inspire_kb/ from base/kb — strictly additive, in BOTH modes.
#
# The KB is PRODUCT content, not runtime. INSPIRE never owns a file under
# inspire_kb/ the way it owns .claude/skills/: from the moment a layer exists,
# what is in it belongs to the project. So this is a seed, never a copy:
#
#   · a path absent on disk      → copied from the skeleton
#   · a path already on disk     → left byte-for-byte, and recursed into, so a
#                                  layer the project already has still gains the
#                                  skeleton files it happens to lack
#
# It must be file-granular, not entry-granular. The deleted materialize_entry
# (rm -rf + cp -R per top-level entry) destroyed an existing KB outright: every
# authored feature, descriptor, ADR, screen and ticket under a layer directory
# went with the directory. Nothing protected them — the lock did not track the
# KB, so drift-check never reported a KB path and --skip could never cover one.
#
# It runs on UPGRADE as well as init, and that is the point: a 0.2 project must
# finally receive the KB layers added since (98_lessons, and whatever a later
# release adds). There are four rows and no delete row — a layer INSPIRE stopped
# shipping stays exactly where it is, because by then it is the project's.
seed_kb() {
  local src_dir="$PLUGIN_ROOT/base/kb"
  local dest_dir="$PROJECT_ROOT/inspire_kb"
  [ -d "$src_dir" ] || return 0

  local entry entry_name dest_entry dest_entry_rel added kept f rel target
  for entry in "$src_dir"/*; do
    [ -e "$entry" ] || continue
    entry_name="$(basename "$entry")"
    dest_entry="$dest_dir/$entry_name"
    dest_entry_rel="inspire_kb/$entry_name"

    if [ ! -e "$dest_entry" ]; then
      CREATED+=("$dest_entry_rel")
      if [ "$DRY_RUN" = 1 ]; then
        log "  · [dry-run] would seed $dest_entry_rel"
      else
        mkdir -p "$dest_dir"
        cp -R "$entry" "$dest_entry" || {
          log "materialize.sh: failed to seed $entry → $dest_entry"; exit 2; }
        log "  · kb/$entry_name → $dest_entry_rel"
      fi
      continue
    fi

    # Already on disk. Add only what is missing beneath it; touch nothing else.
    # A non-directory (or a type mismatch against the skeleton) is the
    # project's — left exactly as found.
    added=0; kept=0
    if [ -d "$entry" ] && [ -d "$dest_entry" ]; then
      while IFS= read -r f; do
        rel="${f#"$entry"/}"
        target="$dest_entry/$rel"
        if [ -e "$target" ]; then
          kept=$((kept + 1))
          continue
        fi
        added=$((added + 1))
        CREATED+=("$dest_entry_rel/$rel")
        [ "$DRY_RUN" = 1 ] && continue
        mkdir -p "$(dirname "$target")"
        cp "$f" "$target" || {
          log "materialize.sh: failed to seed $f → $target"; exit 2; }
      done < <(find "$entry" -type f)
    else
      kept=1
    fi
    log "  · $dest_entry_rel already present — left as-is (seeded $added missing file(s), kept $kept)"
  done
}

# chmod +x every .sh this run copied under .inspire/bin/ and .claude/inspire/hooks/,
# derived from the SOURCE tree so a foreign script sitting in either dir is never
# touched — same ownership rule as the copy itself.
chmod_executables() {
  [ "$DRY_RUN" = 1 ] && return 0
  local src_sh rel
  while IFS= read -r src_sh; do
    rel="${src_sh#"$PLUGIN_ROOT"/base/}"
    case "$rel" in
      bin/*) rel=".inspire/${rel}" ;;
      hooks/*) rel=".claude/inspire/${rel}" ;;
    esac
    [ -f "$PROJECT_ROOT/$rel" ] && chmod +x "$PROJECT_ROOT/$rel"
  done < <(find "$PLUGIN_ROOT/base/bin" "$PLUGIN_ROOT/base/hooks" -type f -name '*.sh' ! -path '*/test/*' 2>/dev/null)
}

# Seed the live design system from the bootstrap theme, once. Never clobbers an
# existing design-system.md — that file belongs to the project from here on.
# It lives under inspire_kb, which is outside the layout dest_map entirely, so
# it is free to diverge without ever being reported as drift.
seed_design_system() {
  local theme_src="$PLUGIN_ROOT/base/kb/00_bootstrap/theme.md"
  local design_dest="$PROJECT_ROOT/inspire_kb/05_screens/design-system.md"
  [ -f "$theme_src" ] || return 0

  if [ -f "$design_dest" ]; then
    log "  · inspire_kb/05_screens/design-system.md already present — left as-is"
    return 0
  fi

  CREATED+=("inspire_kb/05_screens/design-system.md")
  if [ "$DRY_RUN" = 1 ]; then
    log "  · [dry-run] would seed inspire_kb/05_screens/design-system.md"
    return 0
  fi
  mkdir -p "$(dirname "$design_dest")"
  cp "$theme_src" "$design_dest"
  log "  · seeded inspire_kb/05_screens/design-system.md from theme.md"
}

# Seed the project's root CLAUDE.md from the stub template, once. Never
# clobbers an existing CLAUDE.md — a brownfield adopter brings their own, and
# from here on the file is the project's: `/inspire_bootstrap init` refines
# the seeded stub in place, it is not re-seeded on update.
seed_claude_md() {
  local stub_src="$PLUGIN_ROOT/base/templates/CLAUDE.md"
  local claude_dest="$PROJECT_ROOT/CLAUDE.md"
  [ -f "$stub_src" ] || return 0

  if [ -f "$claude_dest" ]; then
    log "  · CLAUDE.md already present — left as-is"
    return 0
  fi

  CREATED+=("CLAUDE.md")
  if [ "$DRY_RUN" = 1 ]; then
    log "  · [dry-run] would seed CLAUDE.md"
    return 0
  fi
  cp "$stub_src" "$claude_dest"
  log "  · seeded CLAUDE.md"
}

# Seed (or extend) the project's .gitignore with the entries INSPIRE needs —
# chiefly .claude/settings.local.json, Claude Code's personal per-user
# override file, which must never be committed/shared. A pre-existing
# .gitignore is never replaced: the block is appended under a marked comment,
# and the marker makes a second run's append a no-op (idempotent).
GITIGNORE_MARK_BEGIN="# --- INSPIRE (materialize.sh) ---"
GITIGNORE_MARK_END="# --- end INSPIRE ---"

seed_gitignore() {
  local gi="$PROJECT_ROOT/.gitignore"
  local block
  block="$GITIGNORE_MARK_BEGIN
.claude/settings.local.json
$GITIGNORE_MARK_END"

  if [ ! -f "$gi" ]; then
    CREATED+=(".gitignore")
    if [ "$DRY_RUN" = 1 ]; then
      log "  · [dry-run] would create .gitignore"
      return 0
    fi
    printf '%s\n' "$block" > "$gi"
    log "  · created .gitignore"
    return 0
  fi

  if grep -qF "$GITIGNORE_MARK_BEGIN" "$gi" 2>/dev/null; then
    log "  · .gitignore already has the INSPIRE block — left as-is"
    return 0
  fi

  if [ "$DRY_RUN" = 1 ]; then
    log "  · [dry-run] would append the INSPIRE block to .gitignore"
    return 0
  fi
  printf '\n%s\n' "$block" >> "$gi"
  log "  · appended the INSPIRE block to .gitignore"
}

# The 0.3 runtime is meant to be COMMITTED — that is what lets it travel with
# the repo, so teammates and CI need no plugin. A .gitignore rule that excludes
# it therefore defeats the whole delivery model, silently: init reports
# "settings: merged, lock: written" and `git status` shows nothing at all.
#
# The common case is a 0.2 project. Its install.sh wrote `/.claude`, because
# back then the runtime was regenerated locally and never committed. Appending
# `.claude/settings.local.json` cannot undo that: git cannot re-include a path
# below an excluded directory, so no line this script adds could fix it.
#
# So: report, never rewrite. The operator's .gitignore is the operator's.
warn_shadowed_runtime() {
  local shadowed=() p
  for p in .claude/skills .claude/inspire/hooks .inspire/bin; do
    if git -C "$PROJECT_ROOT" check-ignore -q --no-index "$p" 2>/dev/null; then
      shadowed+=("$p")
    fi
  done
  [ "${#shadowed[@]}" -gt 0 ] || return 0

  WARNINGS+=("gitignore excludes the INSPIRE runtime: ${shadowed[*]} — the runtime will not be committed, so teammates and CI will not have it. Remove the rule (a 0.2 install wrote '/.claude') and commit these paths.")
  {
    echo ""
    echo "  WARNING · .gitignore excludes the INSPIRE runtime"
    echo ""
    for p in "${shadowed[@]}"; do
      echo "      $p  ($(git -C "$PROJECT_ROOT" check-ignore -v --no-index "$p" 2>/dev/null | awk -F'\t' '{print $1}'))"
    done
    echo ""
    echo "  v0.3 expects these committed — that is what makes the runtime travel"
    echo "  with the repo, so teammates and CI need no plugin. A v0.2 install.sh"
    echo "  wrote '/.claude' for the opposite model."
    echo ""
    echo "  Nothing this script appends can undo it: git cannot re-include a path"
    echo "  below an excluded directory. Remove the rule by hand, then commit."
    echo ""
  } >&2
}

# Create the product-side roots (source/prototype) at their configured location.
# ".", "none" and empty create nothing; an existing directory is left alone.
# Also writes both values into inspire_kb/00_bootstrap/stack.md frontmatter —
# but only for a root whose flag was actually passed, so an update call that
# omits a root never clobbers what is already recorded there. Product READMEs
# are one-time scaffolds, not tracked in the lock (meant to be replaced by real
# code / diverge immediately, like the design system).
create_product_roots() {
  local concept value flag_set dest template
  for concept in source prototype; do
    if [ "$concept" = source ]; then value="$SOURCE_ROOT"; flag_set="$SOURCE_ROOT_SET"; else value="$PROTOTYPE_ROOT"; flag_set="$PROTOTYPE_ROOT_SET"; fi
    [ "$flag_set" = 1 ] || continue

    case "$value" in
      ""|.|none)
        log "  · $concept root is '${value:-unset}' — nothing to create" ;;
      *)
        dest="$PROJECT_ROOT/$value"
        if [ -d "$dest" ]; then
          log "  · $value/ already present — left as-is"
        else
          CREATED+=("$value")
          if [ "$DRY_RUN" = 1 ]; then
            log "  · [dry-run] would create $value/"
          else
            mkdir -p "$dest"
            template="$PLUGIN_ROOT/base/templates/$concept-README.md"
            [ -f "$template" ] && cp "$template" "$dest/README.md"
            log "  · created $value/"
          fi
        fi
        ;;
    esac
  done

  [ "$DRY_RUN" = 1 ] && return 0
  local stack="$PROJECT_ROOT/inspire_kb/00_bootstrap/stack.md"
  [ -f "$stack" ] || return 0

  local expr=""
  [ "$SOURCE_ROOT_SET" = 1 ] && expr=".source_root = \"$SOURCE_ROOT\""
  if [ "$PROTOTYPE_ROOT_SET" = 1 ]; then
    if [ -n "$expr" ]; then expr="$expr | .prototype_root = \"$PROTOTYPE_ROOT\""; else expr=".prototype_root = \"$PROTOTYPE_ROOT\""; fi
  fi
  [ -n "$expr" ] || return 0
  yq -i --front-matter=process "$expr" "$stack" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# .claude/settings.json — marker-based merge, never a wholesale rewrite.
# ---------------------------------------------------------------------------

# merge_settings <hop_journal>
#
# The journal's `unregister` rows are plain SUBSTRINGS queued by a hop (see
# hop_unregister_hook). They are drained into the ONE write below rather than a
# second pass over the file, so a project only ever sees one settings.json
# rewrite per run — and so the three unmarked pre-0.3 registrations, which point
# at .claude/hooks/ and carry no INSPIRE-MANAGED marker the re-merge could see,
# are actually retired instead of being left to fire alongside the new pair.
merge_settings() {
  local settings="$PROJECT_ROOT/.claude/settings.json"
  local existing="{}"

  # NOT `IFS=$'\t' read -r verb path detail`: bash collapses runs of tabs, and a
  # `report\t\t<message>` row has an empty middle field, so the message would
  # slide into $path and a report could be mistaken for a queued substring.
  local extra_drop=() jline
  while IFS= read -r jline; do
    [ -n "$jline" ] || continue
    _tsv_split "$jline"
    [ "$RVERB" = "unregister" ] || continue
    [ -n "$RPATH" ] || continue
    extra_drop+=("$RPATH")
  done < "${1:-/dev/null}"

  if [ -f "$settings" ]; then
    if ! existing="$(jq -e . "$settings" 2>/dev/null)"; then
      log "materialize.sh: $settings exists but is not valid JSON — refusing to touch it"
      exit 2
    fi
  fi

  local session_cmd='$CLAUDE_PROJECT_DIR/.claude/inspire/hooks/session-start.sh # INSPIRE-MANAGED'
  local dispatch_cmd='$CLAUDE_PROJECT_DIR/.claude/inspire/hooks/dispatch.sh # INSPIRE-MANAGED'

  local repo_url repo_slug
  repo_url="$(jq -r '.repository // ""' "$PLUGIN_JSON" 2>/dev/null || true)"
  repo_slug="$(printf '%s' "$repo_url" | sed -E 's#^https?://github\.com/##; s#\.git$##')"
  [ -n "$repo_slug" ] || repo_slug="Genomcore/inspire"

  local declare_bool="false"
  [ "$DECLARE_MARKETPLACE" = 1 ] && declare_bool="true"

  local merged
  merged="$(printf '%s' "$existing" | jq \
    --arg session_cmd "$session_cmd" \
    --arg dispatch_cmd "$dispatch_cmd" \
    --argjson declare_marketplace "$declare_bool" \
    --argjson drop "$(arr_to_json ${extra_drop[@]+"${extra_drop[@]}"})" \
    --arg repo_slug "$repo_slug" \
    '
    # Idempotency, plus retirement of what a hop queued. One predicate, used by
    # both filters: an entry stays unless its command carries the
    # INSPIRE-MANAGED marker (ours, re-added below) or contains a queued
    # substring (a stale registration from an older layout). `contains` on
    # strings is plain substring matching, so there is no regex to escape.
    def keep_hook:
      (.command // "") as $c
      | (($c | contains("INSPIRE-MANAGED")) | not)
        and (([$drop[] | select($c | contains(.))] | length) == 0);

    .hooks.SessionStart = ((.hooks.SessionStart // [])
      | map(.hooks = ((.hooks // []) | map(select(keep_hook))))
      | map(select((.hooks | length) > 0)))
    | .hooks.PreToolUse = ((.hooks.PreToolUse // [])
      | map(.hooks = ((.hooks // []) | map(select(keep_hook))))
      | map(select((.hooks | length) > 0)))
    | .hooks.SessionStart += [ { hooks: [ { type: "command", command: $session_cmd } ] } ]
    | .hooks.PreToolUse  += [ { matcher: "Bash", hooks: [ { type: "command", command: $dispatch_cmd } ] } ]
    | if $declare_marketplace then
        .extraKnownMarketplaces = ((.extraKnownMarketplaces // {}) + { inspire: { source: { source: "github", repo: $repo_slug } } })
        | .enabledPlugins = ((.enabledPlugins // {}) + { "inspire@inspire": true })
      else . end
    ')"

  [ -n "$merged" ] || { log "materialize.sh: settings merge produced no output"; exit 2; }

  if [ "$DRY_RUN" = 1 ]; then
    SETTINGS_STATUS="planned"
    return 0
  fi

  mkdir -p "$(dirname "$settings")"
  local tmp
  tmp="$(mktemp "${settings}.XXXXXX" 2>/dev/null || mktemp)"
  printf '%s\n' "$merged" > "$tmp"
  if ! jq -e . "$tmp" >/dev/null 2>&1; then
    log "materialize.sh: merged settings.json failed validation — leaving the original untouched"
    rm -f "$tmp"
    exit 2
  fi
  mv "$tmp" "$settings"
  SETTINGS_STATUS="merged"
}

# ---------------------------------------------------------------------------
# .inspire.lock — provenance only.
#
# The per-file `files` map is GONE. It existed to drive drift detection, and
# drift is now derived from plugin/manifests/<version>.json instead — a baseline
# that ships with the plugin and cannot be rebaselined by a --skip, cannot be
# hand-edited into an arbitrary path, and exists for versions installed before
# the lock ever carried hashes. Keeping both would mean two disagreeing answers
# to "what did we ship?".
#
# template_sha now carries the manifest's `commit` for the installed version
# instead of the literal "unknown" it used to hardcode — inspire-lesson stamps
# that value onto every lesson it writes, so "unknown" made the provenance of
# every lesson in every project unresolvable.
# ---------------------------------------------------------------------------

# write_lock <version>
write_lock() {
  if [ "$DRY_RUN" = 1 ]; then
    LOCK_STATUS="planned"
    return 0
  fi

  local released commit mf
  released="$(jq -r '.released // "unknown"' "$PLUGIN_JSON" 2>/dev/null || echo unknown)"
  commit="unknown"
  mf="$(manifest_path "$PLUGIN_ROOT" "$1" || true)"
  # A version with no shipped manifest is the release currently being cut: its
  # own commit does not exist yet, so "unknown" is the honest answer.
  if [ -n "$mf" ]; then
    commit="$(jq -r '.commit // "unknown"' "$mf" 2>/dev/null || echo unknown)"
    [ -n "$commit" ] || commit="unknown"
  fi

  local lock="$PROJECT_ROOT/.inspire.lock"
  local tmp
  tmp="$(mktemp "${lock}.XXXXXX" 2>/dev/null || mktemp)"
  jq -n \
    --arg v "$1" --arg r "$released" --arg c "$commit" \
    --arg ia "$(date +%Y-%m-%d)" \
    '{inspire_version: $v, released: $r, template_sha: $c, installed_at: $ia}' \
    > "$tmp"

  if ! jq -e . "$tmp" >/dev/null 2>&1; then
    log "materialize.sh: generated .inspire.lock failed validation"
    rm -f "$tmp"
    exit 2
  fi
  mv "$tmp" "$lock"
  LOCK_STATUS="written"
}

# ---------------------------------------------------------------------------
# plan — read-only: detects the version, verifies the layout, enumerates the
# hop chain in RECORD mode, classifies content, reports. Writes nothing.
# `drift-check` is a deprecated alias (see validate_args).
# ---------------------------------------------------------------------------

# A pre-0.3 (install.sh-era) project is no longer refused here: detect_version
# and the hop chain treat it as simply the longest chain there is. The one
# remaining hand-migration guard is require_migrated_layout below, for the one
# shape detect_version cannot recover from on its own (see its comment).
#
# The migration text itself, used by `init` against an unmigrated v0.2 tree
# (require_migrated_layout). $1 opens, $2 says what is being refused; both may
# be multi-line.
print_v02_migration() {
  local why="$1" refusal="$2"
  {
    echo ""
    printf '%s\n' "$why"
    echo ""
    echo "    .inspire_kb/      →  inspire_kb/"
    echo "    .claude/bin/      →  .inspire/bin/"
    echo "    .claude/hooks/    →  .claude/inspire/hooks/"
    echo "    .inspire/{skills,install.sh,manifest.json}  →  removed (now the plugin)"
    echo ""
    echo "Migrate by hand once, then re-run:"
    echo ""
    echo "  1. git mv .inspire_kb inspire_kb"
    echo "  2. Untrack the v0.2 runtime that WAS committed:"
    echo "       git rm -r --cached --ignore-unmatch \\"
    echo "         .inspire/skills .inspire/install.sh .inspire/manifest.json"
    echo "     then delete the v0.2 runtime that was NOT (v0.2 gitignored"
    echo "     /.claude, so these were never tracked — 'git rm' would abort on"
    echo "     them and take the whole command with it):"
    echo "       rm -rf .claude/bin .claude/hooks \\"
    echo "         .inspire/skills .inspire/install.sh .inspire/manifest.json"
    echo "  3. Remove the three INSPIRE hook entries from .claude/settings.json"
    echo "     (they point at .claude/hooks/ and carry no INSPIRE-MANAGED marker)"
    echo "  4. Remove the '/.claude' line your v0.2 install wrote into .gitignore."
    echo "     v0.3 expects .claude/skills/ and .claude/inspire/hooks/ to be"
    echo "     COMMITTED — that is what makes the runtime travel with the repo."
    echo "     Left in place it hides the entire new runtime from git, silently."
    echo "  5. rm .inspire.lock"
    echo "  6. Run /inspire:init — it will materialize the v0.3 layout and seed a"
    echo "     lock with drift tracking. Your inspire_kb/ is left alone: init only"
    echo "     adds skeleton files your KB does not already have."
    echo ""
    printf '%s\n' "$refusal"
    echo ""
  } >&2
}

# An unmigrated v0.2 tree: .inspire_kb/ present, inspire_kb/ absent. Detection
# cannot catch this one on its own — the operator may have already reached
# step 5 (`rm .inspire.lock`) without doing step 1 (`git mv`), or never had a
# lock to begin with. Without this guard init exits 0 reporting a clean
# install, having seeded an EMPTY inspire_kb/ beside the real one: the whole
# knowledge base left at a path no v0.3 skill ever reads, and nothing in the
# output saying so.
require_migrated_layout() {
  [ -d "$PROJECT_ROOT/.inspire_kb" ] || return 0
  [ -d "$PROJECT_ROOT/inspire_kb" ] && return 0

  print_v02_migration \
"This project still has the pre-0.3 layout — .inspire_kb/ is present and
inspire_kb/ is not — and v0.3 moved the runtime:" \
"Refusing to proceed: an init here would strand your knowledge base at
.inspire_kb/, where no v0.3 skill looks, and seed an empty inspire_kb/
beside it. Start at step 1."
  exit 1
}

# init over a project that already has inspire_kb/ is an ADOPTION, not a fresh
# install: a completed v0.2 migration, a restored backup, a KB vendored in
# before init, or a lock deleted by hand. seed_kb makes it safe — nothing under
# inspire_kb/ is replaced — but "safe" is not the same as "expected", so it is
# reported rather than passed over in silence, and /inspire:init confirms it
# with the operator before writing anything.
EXISTING_KB=0
detect_existing_kb() {
  [ -d "$PROJECT_ROOT/inspire_kb" ] || return 0
  EXISTING_KB=1
  local n
  n="$(find "$PROJECT_ROOT/inspire_kb" -type f 2>/dev/null | wc -l | tr -d ' ')"
  WARNINGS+=("inspire_kb/ already exists ($n file(s)) — this is an adoption, not a fresh install. Nothing under it is replaced; only skeleton files it lacks are added.")
  log "  · inspire_kb/ already exists ($n file(s)) — adopting it: seeding only what is missing"
}

# run_plan — detect, verify, enumerate the hop chain in RECORD mode, classify,
# report. Never writes: hop_ops_init/run_chain run with HOP_RECORD=1, and
# classify itself only ever emits verdicts on stdout (see lib/merge.sh).
run_plan() {
  local target hint src score layout
  target="$(jq -r '.version // "unknown"' "$PLUGIN_JSON")"

  hint=""
  [ -f "$PROJECT_ROOT/.inspire.lock" ] \
    && hint="$(jq -r '.inspire_version // ""' "$PROJECT_ROOT/.inspire.lock" 2>/dev/null)"

  local det; det="$(detect_version "$PLUGIN_ROOT" "$PROJECT_ROOT" "$hint")" || exit 1
  src="$(printf '%s' "$det" | cut -f1)"
  score="$(printf '%s' "$det" | cut -f2)"

  case "$(version_cmp "$target" "$src")" in
    -1) log "INSPIRE: the installed plugin ($target) is older than this project ($src)."
        log "  Refusing to downgrade. Run /plugin update inspire first."
        exit 1 ;;
  esac

  layout="$(manifest_layout "$(manifest_path "$PLUGIN_ROOT" "$src")")"
  verify_layout "$PLUGIN_ROOT" "$PROJECT_ROOT" "$layout" || exit 1

  # Record the layout half without performing it.
  HOP_JOURNAL="$(mktemp)"
  hop_ops_init "$PROJECT_ROOT" "$(manifest_path "$PLUGIN_ROOT" "$src")" 1 || {
    log "materialize.sh: could not initialize the hop journal — refusing to plan"
    log "  without one, since the report and audit trail depend on it."
    exit 1
  }
  run_chain "$PLUGIN_ROOT" "$src" "$target"

  local verdicts src_map tgt_map
  src_map="$(layout_map "$PLUGIN_ROOT" "$layout")"
  tgt_map="$(layout_map "$PLUGIN_ROOT" "$TARGET_LAYOUT")"
  verdicts="$(mktemp)"
  classify "$(manifest_path "$PLUGIN_ROOT" "$src")" "$PROJECT_ROOT" \
           "$PLUGIN_ROOT/base" "$src_map" "$tgt_map" > "$verdicts"

  render_report "$src" "$target" "$HOP_JOURNAL" "$verdicts" 1

  # CHAIN_RAN is SPACE-separated (see lib/chain.sh), not newline-separated.
  local chain_json ask_json
  chain_json="$(printf '%s' "$CHAIN_RAN" | jq -R -s 'split(" ")|map(select(length>0))')"
  ask_json="$(awk -F'\t' '$1=="ask"{print $2}' "$verdicts" \
    | jq -R -s 'split("\n")|map(select(length>0))')"

  local counts_json
  counts_json="$(awk -F'\t' '{c[$1]++} END{
        printf "{\"noop\":%d,\"replace\":%d,\"keep\":%d,\"ask\":%d,\"create\":%d,\"restore\":%d,\"delete\":%d}",
        c["noop"]+0,c["replace"]+0,c["keep"]+0,c["ask"]+0,c["create"]+0,c["restore"]+0,c["delete"]+0}' "$verdicts")"

  jq -n \
    --arg src "$src" --arg tgt "$target" --arg sc "$score" --arg ly "$layout" \
    --argjson chain "$chain_json" --argjson ask "$ask_json" --argjson counts "$counts_json" \
    '{mode:"plan", source_version:$src, target_version:$tgt, score:($sc|tonumber),
      layout:$ly, chain:$chain, verdicts:$counts, ask:$ask}'

  rm -f "$verdicts" "$HOP_JOURNAL"
}

# ---------------------------------------------------------------------------
# init / update
# ---------------------------------------------------------------------------

# One pipeline for both modes. `init` is the degenerate upgrade: no source
# manifest, so every base file is a create, nothing is kept, and no hop runs.
#
# THE ORDER IS THE CORRECTNESS ARGUMENT, and it is not rearrangeable:
#
#   1. classify BEFORE the hops. A pre-0.3 manifest records pre-0.3 paths, and
#      those paths stop existing the moment a hop moves them. Classifying after
#      would match nothing.
#   2. reduce the decisions to a set of HASHES (keepset_of), also before the
#      hops. Bytes survive a `mv`; paths do not. This is what lets step 4 run
#      against the target layout with no path translation at all.
#   3. run the hops.
#   4. apply_base AFTER the hops, driven by the TARGET layout.
#
# Get 1 and 4 the wrong way round and either nothing matches or an operator's
# edit is silently overwritten.
run_materialize() {
  local target src layout verdicts
  target="$(jq -r '.version // "unknown"' "$PLUGIN_JSON")"

  local keepset src_map tgt_map src_manifest
  keepset="$(mktemp)"
  tgt_map="$(layout_map "$PLUGIN_ROOT" "$TARGET_LAYOUT")"

  log "INSPIRE · materialize ($MODE) → $PROJECT_ROOT"

  if [ "$MODE" = "init" ]; then
    require_migrated_layout
    detect_existing_kb
    src="$target"; layout="$TARGET_LAYOUT"; src_map="$tgt_map"
    HOP_JOURNAL="$(mktemp)"
    hop_ops_init "$PROJECT_ROOT" /dev/null "$DRY_RUN" || {
      log "materialize.sh: could not initialize the hop journal — refusing to proceed"
      log "  without one, since the report and audit trail depend on it."
      exit 1
    }
    verdicts="$(mktemp)"
    # A fresh install has no source manifest: every base file is a create, and
    # nothing is kept.
    classify /dev/null "$PROJECT_ROOT" "$PLUGIN_ROOT/base" "$src_map" "$tgt_map" > "$verdicts"
    : > "$keepset"
    src_manifest=/dev/null
  else
    local hint det
    hint=""
    [ -f "$PROJECT_ROOT/.inspire.lock" ] \
      && hint="$(jq -r '.inspire_version // ""' "$PROJECT_ROOT/.inspire.lock" 2>/dev/null)"
    det="$(detect_version "$PLUGIN_ROOT" "$PROJECT_ROOT" "$hint")" || exit 1
    src="$(printf '%s' "$det" | cut -f1)"
    case "$(version_cmp "$target" "$src")" in
      -1) log "INSPIRE: plugin $target is older than project $src — refusing to downgrade."
          log "  Run /plugin update inspire first."
          exit 1 ;;
    esac
    layout="$(manifest_layout "$(manifest_path "$PLUGIN_ROOT" "$src")")"
    # This is also the guard that catches a HALF-MIGRATED pre-0.3 tree — the one
    # shape require_migrated_layout cannot see, because it stands down as soon as
    # inspire_kb/ exists. A project that ran only `git mv .inspire_kb inspire_kb`
    # matches neither layout signature, and .claude/skills/ is the same
    # destination in both, so proceeding would overwrite locally-edited shipped
    # skills while leaving the v0.2 remnants and their unmarked hook
    # registrations behind. Refuse before writing anything instead.
    verify_layout "$PLUGIN_ROOT" "$PROJECT_ROOT" "$layout" || exit 1

    src_manifest="$(manifest_path "$PLUGIN_ROOT" "$src")"
    src_map="$(layout_map "$PLUGIN_ROOT" "$layout")"
    verdicts="$(mktemp)"
    classify "$src_manifest" "$PROJECT_ROOT" "$PLUGIN_ROOT/base" \
             "$src_map" "$tgt_map" > "$verdicts"
    _apply_resolutions "$verdicts"
    keepset_of "$verdicts" "$PROJECT_ROOT" > "$keepset"

    HOP_JOURNAL="$(mktemp)"
    hop_ops_init "$PROJECT_ROOT" "$src_manifest" "$DRY_RUN" || {
      log "materialize.sh: could not initialize the hop journal — refusing to proceed"
      log "  without one, since the report and audit trail depend on it."
      exit 1
    }
    # Unlike --mode plan, a hop failure here is real: the tree is mid-migration.
    run_chain "$PLUGIN_ROOT" "$src" "$target" || exit 2
  fi

  apply_base "$keepset" "$src_manifest" "$PROJECT_ROOT" \
             "$PLUGIN_ROOT/base" "$src_map" "$tgt_map" "$DRY_RUN" || exit 2

  seed_kb                       # additive in BOTH modes now
  chmod_executables
  seed_design_system
  seed_claude_md
  seed_gitignore
  create_product_roots
  warn_shadowed_runtime
  merge_settings "$HOP_JOURNAL"
  write_lock "$target"

  render_report "$src" "$target" "$HOP_JOURNAL" "$verdicts" "$DRY_RUN"

  local created_json warnings_json
  if [ "${#CREATED[@]}" -gt 0 ]; then created_json="$(arr_to_json "${CREATED[@]}")"; else created_json="[]"; fi
  if [ "${#WARNINGS[@]}" -gt 0 ]; then warnings_json="$(arr_to_json "${WARNINGS[@]}")"; else warnings_json="[]"; fi

  local dry_bool="false"
  [ "$DRY_RUN" = 1 ] && dry_bool="true"

  local existing_kb_bool="false"
  [ "$EXISTING_KB" = 1 ] && existing_kb_bool="true"

  jq -n \
    --arg mode "$MODE" --arg src "$src" --arg tgt "$target" \
    --argjson created "$created_json" \
    --argjson warnings "$warnings_json" \
    --argjson existing_kb "$existing_kb_bool" \
    --arg settings "$SETTINGS_STATUS" --arg lock "$LOCK_STATUS" \
    --argjson dry_run "$dry_bool" \
    '{mode:$mode, source_version:$src, version:$tgt, created:$created,
      warnings:$warnings, existing_kb:$existing_kb, settings:$settings, lock:$lock}
     + (if $dry_run then {dry_run: true} else {} end)'

  rm -f "$verdicts" "$HOP_JOURNAL" "$keepset"

  log "INSPIRE · materialize ($MODE) done."
}

# Rewrite `ask` rows according to --take-base / --take-mine. An unresolved ask
# stays the operator's file: doing nothing is how work survives.
#
# --take-mine is applied second, so naming the same path in both flags resolves
# to keeping their file. That is the safe direction, and the only one worth
# defining for what is operator error.
_apply_resolutions() {
  # `vpath`, not `target`: run_materialize's `target` is the plugin VERSION, and
  # two different meanings behind one name in the same call chain is how a future
  # edit gets it wrong.
  local vf="$1" tmp p line verdict vpath detail
  tmp="$(mktemp)"
  # Parameter-expansion split, not `IFS=$'\t' read -r a b c`: bash collapses
  # runs of tabs, so a row whose detail is empty must not lose a field on the
  # way through — the file is re-read by keepset_of and render_report.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    _tsv_split "$line"
    verdict="$RVERB"; vpath="$RPATH"; detail="$RDETAIL"
    if [ "$verdict" = "ask" ]; then
      for p in ${TAKE_BASE[@]+"${TAKE_BASE[@]}"}; do
        [ "$p" = "$vpath" ] && verdict=replace && break
      done
      for p in ${TAKE_MINE[@]+"${TAKE_MINE[@]}"}; do
        [ "$p" = "$vpath" ] && verdict=keep && break
      done
      [ "$verdict" = "ask" ] && verdict=keep
    fi
    printf '%s\t%s\t%s\n' "$verdict" "$vpath" "$detail" >> "$tmp"
  done < "$vf"
  mv "$tmp" "$vf"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  validate_args
  resolve_paths

  case "$MODE" in
    plan)        run_plan ;;
    init|update) run_materialize ;;
  esac
}

main "$@"
