// The graph script's decisions that need no canvas. They live in their own module so
// plugin/test/visor/ runs them under Node; esbuild bundles them into the browser script.

const isKind = (kind) => typeof kind === "string" && kind !== "";
const isTag = (id) => id.startsWith("tags/");

// One resolution per palette entry and render, not per node. A Map lookup never
// reaches Object.prototype, so a kind named "constructor" gets no colour.
export function resolvePalette(palette, resolve) {
  const colors = new Map();
  for (const kind of Object.keys(palette)) colors.set(kind, resolve(palette[kind]));
  return colors;
}

// The palette's kinds on screen in palette order, then every other kind on screen,
// sorted, with no colour: those nodes draw grey. A page with no kind adds no entry.
export function legendEntries(palette, kinds) {
  const onScreen = new Set(kinds.filter(isKind));
  const paletted = Object.keys(palette);
  const listed = paletted.filter((kind) => onScreen.has(kind));
  const others = [...onScreen].filter((kind) => !paletted.includes(kind)).sort();
  return listed
    .map((kind) => ({ kind, color: palette[kind] }))
    .concat(others.map((kind) => ({ kind, color: null })));
}

// Every node drawn counts, the current page included. The legend is emptied here, at
// the moment it is filled, so two renders that overlap leave one set of entries.
export function renderLegend(legend, nodes, palette, kindOf) {
  const entries = legendEntries(palette, nodes.map((node) => kindOf(node.id)));
  while (legend.firstChild) legend.removeChild(legend.firstChild);
  for (const entry of entries) {
    const item = document.createElement("li");
    const swatch = document.createElement("span");
    swatch.className = "graph-legend-swatch";
    swatch.style.backgroundColor = entry.color ?? "var(--gray)";
    item.appendChild(swatch);
    item.appendChild(document.createTextNode(entry.kind));
    legend.appendChild(item);
  }
}

// The ids a graph draws. The walk never enters a page that fails `keep`, so a local
// graph shows no node cut off from the current page; a tag stays when a kept page
// links to it. A negative or missing depth means every kept page.
export function neighbourhoodOf(slug, ids, links, depth, keep) {
  const kept = (id) => id === slug || isTag(id) || keep(id);
  const nodes = new Set();
  if (!(depth >= 0)) {
    for (const id of ids) if (kept(id)) nodes.add(id);
    for (const link of links) {
      if (isTag(link.target) && nodes.has(link.source)) nodes.add(link.target);
    }
    return nodes;
  }
  let queue = [slug];
  const seen = new Set(queue);
  for (let d = 0; d <= depth && queue.length > 0; d++) {
    const next = [];
    for (const cur of queue) {
      nodes.add(cur);
      for (const link of links) {
        const other =
          link.source === cur ? link.target : link.target === cur ? link.source : null;
        if (other !== null && !seen.has(other) && kept(other)) {
          seen.add(other);
          next.push(other);
        }
      }
    }
    queue = next;
  }
  return nodes;
}
