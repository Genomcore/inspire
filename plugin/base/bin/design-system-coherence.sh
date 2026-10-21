#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"
SCREENS_ROOT="$SDD_KB_ROOT/05_screens"
DESIGN_FILE="$SCREENS_ROOT/design-system.md"
TOKENS_FILE="$SCREENS_ROOT/design-tokens.json"
REQUIRED_SECTIONS=("Supported viewports" "Icons" "Reference")

emit() {
  sdd_finding "$1" "design-system-coherence" "$2" "$3"
  sdd_count_by_severity "$1"
}

in_scope() {
  local scope_dir="$1" file="$2"
  case "$(sdd_scope_norm "$file")" in
    "$scope_dir" | "$scope_dir"/*) return 0 ;;
  esac
  return 1
}

TOKEN_PROBLEMS='
  def types: ["color","dimension","fontFamily","fontWeight","duration","cubicBezier","number",
              "strokeStyle","border","transition","shadow","gradient","typography"];
  def is_alias: type == "string" and test("^\\{[^{}]+\\}$");
  def alias_path: .[1:-1];
  def tokens($node; $path; $inherited):
    ($node["$type"] // $inherited) as $type
    | if ($node | has("$value")) then {path: ($path | join(".")), type: $type, value: $node["$value"]}
      else $node | to_entries[] | select(.key | startswith("$") | not)
           | select(.value | type == "object")
           | tokens(.value; $path + [.key]; $type)
      end;
  def groups($node; $path):
    ($path | join(".")),
    ($node | to_entries[] | select(.key | startswith("$") | not)
           | select(.value | type == "object") | groups(.value; $path + [.key]));
  def names($node; $path):
    $node | to_entries[] | select(.key | startswith("$") | not)
    | (if (.key | test("[.{}]")) then "token name `\($path + [.key] | join("."))` carries `.`, `{` or `}`" else empty end),
      (if (.value | type == "object") then names(.value; $path + [.key]) else empty end);
  def shape_ok($kind):
    if is_alias then true
    elif $kind == "color" then
      (type == "string" and test("^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"))
      or (type == "object" and has("colorSpace") and has("components"))
    elif $kind == "dimension" then
      (type == "string" and test("^-?[0-9]+(\\.[0-9]+)?(px|rem)$"))
      or (type == "object" and (.value | type == "number") and (.unit == "px" or .unit == "rem"))
    elif $kind == "duration" then
      (type == "string" and test("^[0-9]+(\\.[0-9]+)?(ms|s)$"))
      or (type == "object" and (.value | type == "number") and (.unit == "ms" or .unit == "s"))
    elif $kind == "number" then type == "number"
    elif $kind == "fontWeight" then
      (type == "number" and . >= 1 and . <= 1000) or type == "string"
    elif $kind == "fontFamily" then
      type == "string" or (type == "array" and length > 0 and all(.[]; type == "string"))
    else true end;
  . as $root
  | [tokens($root; []; null)] as $all
  | ($all | map({key: .path, value: .}) | from_entries) as $index
  | def resolves($p; $depth):
      if $depth > 32 then "loop"
      elif ($index[$p] | not) then "missing"
      elif ($index[$p].value | is_alias) then resolves($index[$p].value | alias_path; $depth + 1)
      else "ok" end;
    names($root; []),
    ($all[] as $t
      | (if ($t.type == null) then "token `\($t.path)` has no `$type`, on itself or on a parent group"
         elif (types | index($t.type) | not) then "token `\($t.path)` has `$type` `\($t.type)`, outside the closed list"
         elif ($t.value | shape_ok($t.type) | not) then "token `\($t.path)` holds `\($t.value | tojson)`, which is not a \($t.type) value"
         else empty end),
        ([$t.value | .. | select(is_alias) | alias_path][] as $target
          | resolves($target; 0) as $verdict
          | if $verdict == "missing" then "token `\($t.path)` aliases `{\($target)}`, which names no token"
            elif $verdict == "loop" then "token `\($t.path)` aliases `{\($target)}`, whose chain never reaches a value"
            else empty end))
'

TOKEN_PATHS='
  def walk_paths($node; $path):
    ($path | join(".")),
    ($node | to_entries[] | select(.key | startswith("$") | not)
           | select(.value | type == "object") | walk_paths(.value; $path + [.key]));
  walk_paths(.; []) | select(length > 0)
'

GENERATED_TOKENS='
  def walk_tokens($node; $trail):
    if ($node | has("$value")) then
      select(($node["$extensions"].inspire.source // "") == "generated") | ($trail | join("."))
    else $node | to_entries[] | select(.key | startswith("$") | not)
         | select(.value | type == "object") | walk_tokens(.value; $trail + [.key])
    end;
  [walk_tokens(.; [])] | select(length > 0) | "\(length)\t\(join(" "))"
'

cited_tokens() {
  awk '
    /^[ \t]*(```|~~~)/ { fenced = !fenced; next }
    /<!--/ { incomment = 1 }
    incomment { if ($0 ~ /-->/) incomment = 0; next }
    !fenced { print }
  ' "$1" | grep -oE '`\{[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)+\}`' | tr -d '`{}' | sort -u
}

check_sections() {
  local section
  for section in "${REQUIRED_SECTIONS[@]}"; do
    sdd_has_section "$DESIGN_FILE" "$section" && continue
    emit "warning" "$DESIGN_FILE" \
      "design system carries no '## $section' section — run /inspire-bootstrap design-system backfill"
  done
}

check_tokens() {
  if ! jq -e 'type == "object"' "$TOKENS_FILE" >/dev/null 2>&1; then
    emit "error" "$TOKENS_FILE" "token file is not a JSON object"
    return 1
  fi
  local problem generated_n generated_paths
  while IFS= read -r problem; do
    [ -n "$problem" ] && emit "error" "$TOKENS_FILE" "$problem"
  done < <(jq -r "$TOKEN_PROBLEMS" "$TOKENS_FILE")
  IFS=$'\t' read -r generated_n generated_paths < <(jq -r "$GENERATED_TOKENS" "$TOKENS_FILE")
  if [ -n "${generated_n:-}" ]; then
    emit "warning" "$TOKENS_FILE" \
      "$generated_n token(s) generated and decided by nobody yet: $generated_paths — confirm each through /inspire-bootstrap design-system"
  fi
  return 0
}

check_citations() {
  local scope_dir="$1" known file path
  known="$(mktemp -t sdd-token-paths.XXXXXX)"
  jq -r "$TOKEN_PATHS" "$TOKENS_FILE" | sort -u > "$known"
  while IFS= read -r file; do
    in_scope "$scope_dir" "$file" || continue
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      grep -qxF "$path" "$known" && continue
      emit "warning" "$file" "cites token {$path}, which design-tokens.json does not define"
    done < <(cited_tokens "$file")
  done < <(find "$SCREENS_ROOT" -type f -name '*.md' ! -name 'README.md' 2>/dev/null | sort)
  rm -f "$known"
}

SCOPE_DIR="$(sdd_scope_intersect "$SCOPE" "$SCREENS_ROOT")"
[ -n "$SCOPE_DIR" ] || exit 0
[ -f "$DESIGN_FILE" ] || exit 0

if in_scope "$SCOPE_DIR" "$DESIGN_FILE"; then
  check_sections
fi

if [ ! -f "$TOKENS_FILE" ]; then
  if in_scope "$SCOPE_DIR" "$DESIGN_FILE"; then
    emit "warning" "$DESIGN_FILE" \
      "no design-tokens.json beside the design system — run /inspire-bootstrap design-system backfill"
  fi
  sdd_exit_with_counters
  exit $?
fi

tokens_ok=0
if in_scope "$SCOPE_DIR" "$TOKENS_FILE"; then
  check_tokens && tokens_ok=1
else
  jq -e 'type == "object"' "$TOKENS_FILE" >/dev/null 2>&1 && tokens_ok=1
fi

if [ "$tokens_ok" = 1 ]; then
  check_citations "$SCOPE_DIR"
fi

sdd_exit_with_counters
