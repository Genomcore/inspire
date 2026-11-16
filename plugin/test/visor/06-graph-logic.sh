#!/usr/bin/env bash
# The graph plugin's decisions that need no canvas, run under Node from its source
# module: the palette lookup, the legend's entries against a stub DOM, and which
# nodes a graph draws under scopeTo. The canvas drawing needs a browser.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$(cd -P "$HERE/.." && pwd -P)"
. "$HERE/lib/assert.sh"

LOGIC="$PLUGIN_ROOT/visor-src/inspire-graph/src/components/scripts/graph-logic.js"
N=12

major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if ! [ "$major" -ge 22 ] 2>/dev/null; then
  skipped "$N" "the graph logic under Node (no Node 22 or later)"
  summary
fi

# One Node run answers every question as a JSON object; bash asserts on its fields.
R="$(node --input-type=module - "$LOGIC" <<'JS'
import { pathToFileURL } from "node:url";
const L = await import(pathToFileURL(process.argv[2]).href);

const el = (tag) => ({
  tag, children: [], style: {}, className: "", text: "",
  get firstChild() { return this.children[0] ?? null; },
  appendChild(c) { this.children.push(c); return c; },
  removeChild(c) { this.children.splice(this.children.indexOf(c), 1); return c; },
});
globalThis.document = { createElement: el, createTextNode: (text) => ({ text }) };
const shown = (legend) =>
  legend.children.map((li) => li.children[1].text + "=" + li.children[0].style.backgroundColor).join(" ");

const palette = { entity: "#2f9e44", action: "#74b816", adr: "#c92a2a" };
const kinds = { "c.adr": "adr", e1: "entity", e2: "entity", z: "zeta", p: "policy", home: undefined, blank: "" };
const nodes = ["c.adr", "e1", "e2", "z", "p", "home", "blank", "tags/t"].map((id) => ({ id }));
const legend = el("ul");
L.renderLegend(legend, nodes, palette, (id) => kinds[id]);
const once = shown(legend);
L.renderLegend(legend, nodes, palette, (id) => kinds[id]);

let calls = 0;
const colors = L.resolvePalette(palette, (v) => { calls++; return "rgb(" + v + ")"; });
const ctor = el("ul");
L.renderLegend(ctor, [{ id: "k" }], { entity: "#2f9e44" }, () => "constructor");

// c and a are in module m; x is in n; y is in m but linked only through x.
const mod = { c: "m", a: "m", x: "n", y: "m" };
const ids = ["c", "a", "x", "y"];
const links = [
  { source: "c", target: "a" }, { source: "c", target: "x" }, { source: "x", target: "y" },
  { source: "c", target: "tags/t" }, { source: "x", target: "tags/u" },
];
const inM = (id) => mod[id] === "m";
const drawn = (depth, keep) => [...L.neighbourhoodOf("c", ids, links, depth, keep)].sort().join(" ");

console.log(JSON.stringify({
  legend: once,
  refill: shown(legend),
  ctorColor: String(colors.get("constructor")),
  ctorLegend: shown(ctor),
  calls,
  entity: colors.get("entity"),
  local: drawn(2, inM),
  global: drawn(-1, inM),
  plain: drawn(1, () => true),
  plainGlobal: drawn(undefined, () => true),
}));
JS
)"
f() { printf '%s' "$R" | jq -r --arg k "$1" '.[$k]'; }

# --- the legend ------------------------------------------------------------
has "the legend lists the palette's kinds on screen in palette order, the current page's included" \
  "$(f legend)" "entity=#2f9e44 adr=#c92a2a"
hasnt "the legend lists no palette kind that is not on screen" "$(f legend)" "action"
has "a kind the palette lacks follows the palette's, sorted, with the grey swatch" \
  "$(f legend)" "adr=#c92a2a policy=var(--gray) zeta=var(--gray)"
eq "a page with no kind, a tag and a repeated kind add no legend entry" \
  "$(f legend)" "entity=#2f9e44 adr=#c92a2a policy=var(--gray) zeta=var(--gray)"
eq "filling a legend twice leaves one set of entries" "$(f refill)" "$(f legend)"

# --- the palette -----------------------------------------------------------
eq "each palette colour resolves once per render" "$(f calls)" "3"
eq "a resolved palette colour is what the resolver returned" "$(f entity)" "rgb(#2f9e44)"
eq "a kind named constructor has no palette colour" "$(f ctorColor)" "undefined"
eq "a kind named constructor is listed with the grey swatch" "$(f ctorLegend)" "constructor=var(--gray)"

# --- the nodes a graph draws -----------------------------------------------
eq "scopeTo at depth 2: no page reached only through an out-of-scope one, the kept page's tag stays" \
  "$(f local)" "a c tags/t"
eq "scopeTo on the whole graph: every in-scope page and only the tags kept pages carry" \
  "$(f global)" "a c tags/t y"
eq "without scopeTo the walk keeps every neighbour, tags included, and a missing depth draws all" \
  "$(f plain) | $(f plainGlobal)" "a c tags/t x | a c tags/t tags/u x y"
summary
