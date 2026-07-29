#!/usr/bin/env bash
#
# plugin/scripts/materialize.sh — the deterministic engine shared by /inspire:init
# and /inspire:update.
#
# Everything mechanical lives here rather than in skill prose: copying entries,
# chmod, excluding bin/test/, seeding the design system, seeding CLAUDE.md and
# .gitignore, creating product roots, the marker-based settings.json merge, and
# writing .inspire.lock. Skills carry
# judgment — preconditions, questions, routing, reporting; this script carries
# the copy rules exactly once so init and update cannot drift apart.
#
# Never materialized itself: this file and plugin/test/ live outside plugin/base/,
# so /inspire:init has no path that would ever copy them into a project.
#
# Usage:
#   materialize.sh --mode init|update|drift-check
#                   --plugin-root PATH        # ${CLAUDE_PLUGIN_ROOT}
#                   --project-root PATH       # repo root
#                   [--source-root VALUE]     # e.g. source | . | none   (init/update)
#                   [--prototype-root VALUE]  # e.g. prototype | none    (init/update)
#                   [--declare-marketplace]   # add extraKnownMarketplaces + enabledPlugins
#                   [--skip RELPATH]...       # update: drifted paths, never overwritten
#                   [--dry-run]               # plan only, write nothing
#
# stdout: a JSON summary (machine-readable). stderr: human progress.
# exit:   0 ok · 1 precondition failure · 2 partial failure (nothing committed)
#
# Prerequisites: bash 4+, yq (Mike Farah's v4), jq 1.6+.

set -uo pipefail

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

log() { printf '%s\n' "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
Usage: materialize.sh --mode init|update|drift-check
                       --plugin-root PATH --project-root PATH
                       [--source-root VALUE] [--prototype-root VALUE]
                       [--declare-marketplace] [--skip RELPATH]... [--dry-run]
EOF
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Prints a JSON array from its arguments (each one string element). No args → [].
arr_to_json() {
  if [ "$#" -eq 0 ]; then
    printf '[]'
    return 0
  fi
  printf '%s\n' "$@" | jq -R -s 'split("\n") | map(select(length > 0))'
}

# True if skip path $1 is $2 itself, or nested under it.
is_skip_relevant() {
  [ "$1" = "$2" ] && return 0
  case "$1" in
    "$2"/*) return 0 ;;
  esac
  return 1
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
SKIP_PATHS=()

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
      --skip)
        [ "$#" -ge 2 ] || { log "materialize.sh: --skip requires a value"; usage; exit 1; }
        SKIP_PATHS+=("$2"); shift 2 ;;
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
    init|update|drift-check) ;;
    *) log "materialize.sh: --mode must be one of init|update|drift-check (got '${MODE:-<missing>}')"; usage; exit 1 ;;
  esac
  [ -n "$PLUGIN_ROOT" ] || { log "materialize.sh: --plugin-root is required"; usage; exit 1; }
  [ -n "$PROJECT_ROOT" ] || { log "materialize.sh: --project-root is required"; usage; exit 1; }
  [ -d "$PLUGIN_ROOT" ] || { log "materialize.sh: --plugin-root '$PLUGIN_ROOT' is not a directory"; exit 1; }
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
# Copy plan: base/{kb,bin,hooks,skills} → project targets. bin/test/ is never
# materialized — neither the fixtures nor the harness (see Global Constraints).
# ---------------------------------------------------------------------------

MAP_NAMES=(kb bin hooks skills)
MAP_DESTS=(inspire_kb .inspire/bin .claude/inspire/hooks .claude/skills)

COPIED=()
SKIPPED=()
CREATED=()
TRACKED_ENTRIES=()   # dest-relative entries whose files feed the lock
FILES_LINES=()       # "relpath<TAB>sha256" lines, built once disk state settles
SETTINGS_STATUS="unchanged"
LOCK_STATUS="unchanged"

# Copies (or skip-restores) one top-level entry. $1=src abs path, $2=dest abs
# path, $3=dest path relative to $PROJECT_ROOT.
materialize_entry() {
  local src="$1" dest_abs="$2" dest_rel="$3"

  local relevant=()
  if [ "${#SKIP_PATHS[@]}" -gt 0 ]; then
    local sp
    for sp in "${SKIP_PATHS[@]}"; do
      [ -n "$sp" ] || continue
      if is_skip_relevant "$sp" "$dest_rel"; then
        relevant+=("$sp")
        SKIPPED+=("$sp")
      fi
    done
  fi

  TRACKED_ENTRIES+=("$dest_rel")

  if [ "$DRY_RUN" = 1 ]; then
    [ "${#relevant[@]}" -eq 0 ] && COPIED+=("$dest_rel")
    return 0
  fi

  if [ "${#relevant[@]}" -eq 0 ]; then
    # INSPIRE owns this entry outright: replace it, never the parent directory.
    rm -rf "$dest_abs"
    mkdir -p "$(dirname "$dest_abs")"
    cp -R "$src" "$dest_abs"
    COPIED+=("$dest_rel")
    return 0
  fi

  # A --skip path falls inside this entry: back up its exact pre-run state
  # (present or absent), replace the entry wholesale, then restore that exact
  # state so the skipped path is never touched, byte for byte.
  local backup
  backup="$(mktemp -d)"
  local existed=()
  local i=0 sp_abs
  for sp in "${relevant[@]}"; do
    sp_abs="$PROJECT_ROOT/$sp"
    if [ -e "$sp_abs" ]; then
      mkdir -p "$(dirname "$backup/$i")"
      cp -R "$sp_abs" "$backup/$i"
      existed[$i]=1
    else
      existed[$i]=0
    fi
    i=$((i + 1))
  done

  rm -rf "$dest_abs"
  mkdir -p "$(dirname "$dest_abs")"
  cp -R "$src" "$dest_abs"

  i=0
  for sp in "${relevant[@]}"; do
    sp_abs="$PROJECT_ROOT/$sp"
    if [ "${existed[$i]}" = 1 ]; then
      rm -rf "$sp_abs"
      mkdir -p "$(dirname "$sp_abs")"
      cp -R "$backup/$i" "$sp_abs"
    else
      rm -rf "$sp_abs"
    fi
    i=$((i + 1))
  done
  rm -rf "$backup"
}

copy_plan() {
  local idx name dest_rel src_dir dest_dir entry entry_name dest_entry dest_entry_rel
  for idx in 0 1 2 3; do
    name="${MAP_NAMES[$idx]}"
    dest_rel="${MAP_DESTS[$idx]}"
    src_dir="$PLUGIN_ROOT/base/$name"
    dest_dir="$PROJECT_ROOT/$dest_rel"
    [ -d "$src_dir" ] || continue

    [ "$DRY_RUN" = 1 ] || mkdir -p "$dest_dir"

    for entry in "$src_dir"/*; do
      [ -e "$entry" ] || continue
      entry_name="$(basename "$entry")"

      # bin/test/ is never materialized — neither fixtures nor harness.
      [ "$name" = "bin" ] && [ "$entry_name" = "test" ] && continue
      # Defensive: a template-maintenance script never leaks into a project.
      case "$entry_name" in template-*.sh) continue ;; esac

      dest_entry="$dest_dir/$entry_name"
      dest_entry_rel="$dest_rel/$entry_name"
      materialize_entry "$entry" "$dest_entry" "$dest_entry_rel"
      log "  · $name/$entry_name → $dest_entry_rel"
    done
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
# existing design-system.md — that file belongs to the project from here on, so
# it is not tracked in the lock (it is meant to diverge).
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

merge_settings() {
  local settings="$PROJECT_ROOT/.claude/settings.json"
  local existing="{}"

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
    --arg repo_slug "$repo_slug" \
    '
    # Idempotency: drop every hook entry this runtime previously injected —
    # matched solely by the INSPIRE-MANAGED marker on its command — before
    # adding the current pair back. A group left with no hooks is dropped too.
    .hooks.SessionStart = ((.hooks.SessionStart // [])
      | map(.hooks = ((.hooks // []) | map(select(((.command // "") | contains("INSPIRE-MANAGED")) | not))))
      | map(select((.hooks | length) > 0)))
    | .hooks.PreToolUse = ((.hooks.PreToolUse // [])
      | map(.hooks = ((.hooks // []) | map(select(((.command // "") | contains("INSPIRE-MANAGED")) | not))))
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
# .inspire.lock — provenance + per-file hashes for drift-check.
# ---------------------------------------------------------------------------

# Hashes every file under each tracked entry, once disk state has settled
# (after chmod, after the stack.md frontmatter edit — never a stale hash).
compute_lock_files() {
  FILES_LINES=()
  [ "$DRY_RUN" = 1 ] && return 0
  [ "${#TRACKED_ENTRIES[@]}" -gt 0 ] || return 0

  local rel abs f relpath
  for rel in "${TRACKED_ENTRIES[@]}"; do
    abs="$PROJECT_ROOT/$rel"
    if [ -d "$abs" ]; then
      while IFS= read -r f; do
        relpath="${f#"$PROJECT_ROOT"/}"
        FILES_LINES+=("$relpath"$'\t'"$(sha256_of "$f")")
      done < <(find "$abs" -type f)
    elif [ -f "$abs" ]; then
      FILES_LINES+=("$rel"$'\t'"$(sha256_of "$abs")")
    fi
  done
}

write_lock() {
  if [ "$DRY_RUN" = 1 ]; then
    LOCK_STATUS="planned"
    return 0
  fi

  local version released
  version="$(jq -r '.version // "unknown"' "$PLUGIN_JSON" 2>/dev/null || echo unknown)"
  released="$(jq -r '.released // "unknown"' "$PLUGIN_JSON" 2>/dev/null || echo unknown)"

  local files_json="{}"
  if [ "${#FILES_LINES[@]}" -gt 0 ]; then
    files_json="$(printf '%s\n' "${FILES_LINES[@]}" | jq -R -s '
      split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}
    ')"
  fi

  local lock="$PROJECT_ROOT/.inspire.lock"
  local tmp
  tmp="$(mktemp "${lock}.XXXXXX" 2>/dev/null || mktemp)"
  jq -n \
    --arg v "$version" --arg r "$released" --arg sha "unknown" \
    --arg ia "$(date +%Y-%m-%d)" \
    --argjson files "$files_json" \
    '{inspire_version: $v, released: $r, template_sha: $sha, installed_at: $ia, files: $files}' \
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
# drift-check — read-only: hashes recorded paths against disk. Writes nothing.
# ---------------------------------------------------------------------------

run_drift_check() {
  local lock="$PROJECT_ROOT/.inspire.lock"
  if [ ! -f "$lock" ]; then
    log "materialize.sh: no .inspire.lock at $PROJECT_ROOT — run /inspire:init first"
    exit 1
  fi

  local lock_version plugin_version
  lock_version="$(jq -r '.inspire_version // "unknown"' "$lock" 2>/dev/null || echo unknown)"
  plugin_version="$(jq -r '.version // "unknown"' "$PLUGIN_JSON" 2>/dev/null || echo unknown)"

  local unchanged=() drifted=() missing=()
  local path hash abs cur
  while IFS=$'\t' read -r path hash; do
    [ -n "$path" ] || continue
    abs="$PROJECT_ROOT/$path"
    if [ ! -e "$abs" ]; then
      missing+=("$path")
    else
      cur="$(sha256_of "$abs")"
      if [ "$cur" = "$hash" ]; then
        unchanged+=("$path")
      else
        drifted+=("$path")
      fi
    fi
  done < <(jq -r '.files // {} | to_entries[] | "\(.key)\t\(.value)"' "$lock" 2>/dev/null)

  local unchanged_json drifted_json missing_json
  if [ "${#unchanged[@]}" -gt 0 ]; then unchanged_json="$(arr_to_json "${unchanged[@]}")"; else unchanged_json="[]"; fi
  if [ "${#drifted[@]}" -gt 0 ]; then drifted_json="$(arr_to_json "${drifted[@]}")"; else drifted_json="[]"; fi
  if [ "${#missing[@]}" -gt 0 ]; then missing_json="$(arr_to_json "${missing[@]}")"; else missing_json="[]"; fi

  jq -n \
    --arg mode "drift-check" \
    --arg lock_version "$lock_version" \
    --arg plugin_version "$plugin_version" \
    --argjson unchanged "$unchanged_json" \
    --argjson drifted "$drifted_json" \
    --argjson missing "$missing_json" \
    '{mode: $mode, lock_version: $lock_version, plugin_version: $plugin_version, unchanged: $unchanged, drifted: $drifted, missing: $missing}'
}

# ---------------------------------------------------------------------------
# init / update
# ---------------------------------------------------------------------------

run_materialize() {
  log "INSPIRE · materialize ($MODE) → $PROJECT_ROOT"

  copy_plan
  chmod_executables
  seed_design_system
  seed_claude_md
  seed_gitignore
  create_product_roots
  merge_settings
  compute_lock_files
  write_lock

  local copied_json skipped_json created_json
  if [ "${#COPIED[@]}" -gt 0 ]; then copied_json="$(arr_to_json "${COPIED[@]}")"; else copied_json="[]"; fi
  if [ "${#SKIPPED[@]}" -gt 0 ]; then skipped_json="$(arr_to_json "${SKIPPED[@]}")"; else skipped_json="[]"; fi
  if [ "${#CREATED[@]}" -gt 0 ]; then created_json="$(arr_to_json "${CREATED[@]}")"; else created_json="[]"; fi

  local version
  version="$(jq -r '.version // "unknown"' "$PLUGIN_JSON" 2>/dev/null || echo unknown)"

  local dry_bool="false"
  [ "$DRY_RUN" = 1 ] && dry_bool="true"

  jq -n \
    --arg mode "$MODE" \
    --arg version "$version" \
    --argjson copied "$copied_json" \
    --argjson skipped "$skipped_json" \
    --argjson created "$created_json" \
    --arg settings "$SETTINGS_STATUS" \
    --arg lock "$LOCK_STATUS" \
    --argjson dry_run "$dry_bool" \
    '{mode: $mode, version: $version, copied: $copied, skipped: $skipped, created: $created, settings: $settings, lock: $lock}
     + (if $dry_run then {dry_run: true} else {} end)'

  log "INSPIRE · materialize ($MODE) done."
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  validate_args
  resolve_paths

  case "$MODE" in
    drift-check) run_drift_check ;;
    init|update) run_materialize ;;
  esac
}

main "$@"
