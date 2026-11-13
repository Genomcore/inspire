# inspire-graph

The source of the visor's graph panel, a Quartz component plugin. The built copy
ships under `plugin/base/visor/plugins/inspire-graph/` and materializes into a project
as `.inspire/visor/plugins/inspire-graph/`. Nothing in this directory ships to a project.

## Origin

Adapted from [quartz-community/graph](https://github.com/quartz-community/graph) at tag
`v1.0.3` (commit `ef69a56`), MIT licensed; `LICENSE` is upstream's. The built file also
bundles functions of `@quartz-community/utils` (MIT, Quartz Community).

What differs from upstream:

- Two options on `localGraph` and `globalGraph`:
  - `nodeColors: {field, palette}` colours each node by a content-index field, read by
    dot path (`inspire.kind`). `palette` maps a field value to a CSS colour. A node whose
    value is not in the palette is grey; the current page keeps Quartz's `secondary`
    colour.
  - `scopeTo: <field>` keeps only the nodes whose field equals the current page's
    (`inspire.module` limits a graph to the page's module).
- A legend lists the palette entries drawn on the graph, in palette order. It sits below
  the local graph and over the bottom-left corner of the global graph. Grey nodes have
  no entry. Its text and frame use the theme's colours, so it follows light and dark
  mode.
- The build is one esbuild script (`build.mjs`) with three dev dependencies, and its
  output is unminified.

## Build

```sh
bash plugin/scripts/build-visor-graph.sh
```

It needs Node 22 or later and npm, installs the locked dev dependencies into a
temporary copy of this directory, and rewrites `package.json`, `LICENSE` and
`dist/index.js` in the base copy. `plugin/test/visor/01-graph-plugin.sh` fails when
the committed `dist/` differs from a fresh build.
