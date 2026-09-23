#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const html = fs.readFileSync(process.argv[2], "utf8");
const start = html.indexOf("      function applyFilters() {");
const end = html.indexOf("\n      function updateMetrics(", start);
assert(start >= 0 && end > start, "viewer exposes applyFilters");
const applyFiltersSource = html.slice(start, end);

function element(dataset, classes = []) {
  const values = new Set(classes);
  return {
    dataset,
    style: {},
    classList: {
      contains: (name) => values.has(name),
      toggle: (name, enabled) => enabled ? values.add(name) : values.delete(name),
    },
    has: (name) => values.has(name),
  };
}

const nodes = [
  element({ key: "unit:screen" }, ["node"]),
  element({ key: "unit:entity" }, ["node"]),
  element({ key: "unit:action" }, ["node"]),
  element({ key: "unit:outside" }, ["node"]),
];
const edges = [
  element({ index: "0", source: "unit:entity", target: "unit:screen" }, ["edge"]),
  element({ index: "1", source: "unit:action", target: "unit:screen" }, ["edge"]),
  element({ index: "2", source: "unit:outside", target: "unit:screen" }, ["edge"]),
];
const path = { nodes: new Set(["unit:screen", "unit:entity", "unit:action"]), edges: new Set([0, 1]) };
const state = {
  selected: "unit:screen", focus: "path", kindFocus: "entity",
  nodes: new Map([
    ["unit:screen", { id: "screen", kind: "screen" }],
    ["unit:entity", { id: "entity", kind: "entity" }],
    ["unit:action", { id: "action", kind: "action" }],
    ["unit:outside", { id: "outside", kind: "entity" }],
  ]),
  scene: { columns: [] },
};
const controls = {
  search: { value: "" },
  "show-ordering": { checked: true },
  "show-deferred": { checked: true },
  "show-navigation": { checked: true },
  "show-external": { checked: true },
};
const graph = {
  querySelectorAll(selector) {
    if (selector === ".node") return nodes;
    if (selector === ".edge") return edges;
    return [];
  },
  querySelector: () => null,
};
const context = {
  state, graph, $: (id) => controls[id], clearEdgeHover: () => {}, buildPath: () => path,
};
vm.runInNewContext(`${applyFiltersSource}\nthis.applyFilters = applyFilters;`, context);

context.applyFilters();
assert(!nodes[0].has("dim"), "selected screen remains visible as the path anchor");
assert(!nodes[1].has("dim"), "entity on the path is emphasized");
assert(nodes[2].has("dim"), "action on the path fades under entity focus");
assert(nodes[3].has("dim"), "entity outside the path still fades");
assert(edges[0].has("hot"), "path edge touching the focused type stays highlighted");
assert(edges[1].has("dim"), "path edge without the focused type fades");
assert(edges[2].has("dim"), "edge outside the path fades");

state.focus = "only";
context.applyFilters();
assert.equal(nodes[2].style.display, "", "other types on the path remain inspectable");
assert(nodes[2].has("dim"), "type focus still applies in Only path");
assert.equal(nodes[3].style.display, "none", "Only path hides unrelated units");

state.kindFocus = null;
context.applyFilters();
assert(!nodes[2].has("dim"), "clearing type focus restores the full path");
assert(edges[1].has("hot"), "clearing type focus restores all path edges");

console.log("PASS type focus composes with Build path and Only path");
