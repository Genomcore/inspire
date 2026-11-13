# inspire-graph

The source of the visor's graph panel, a Quartz component plugin. The built copy
ships under `plugin/base/visor/plugins/inspire-graph/` and materializes into a project
as `.inspire/visor/plugins/inspire-graph/`. Nothing in this directory ships to a project.

## Origin

Adapted from [quartz-community/graph](https://github.com/quartz-community/graph) at tag
`v1.0.3` (commit `ef69a56`), MIT licensed; `LICENSE` is upstream's, and `package.json`
keeps upstream's `repository`, so the shipped copy names its origin. The built file also
bundles functions of `@quartz-community/utils` (MIT, Quartz Community).

What differs from upstream:

- Two options on `localGraph` and `globalGraph`:
  - `nodeColors: {field, palette}` colours each node by a content-index field, read by
    dot path (`inspire.kind`). `palette` maps a field value to a CSS colour. A node whose
    value is not in the palette is grey. The current page takes its kind's colour too,
    and a ring in the theme's text colour marks it.
  - `scopeTo: <field>` keeps the pages whose field equals the current page's
    (`inspire.module` limits a graph to the page's module) and the tags those pages
    carry. A local graph walks only through kept pages, so no node it draws is cut off
    from the current page.
- A legend lists the kinds drawn on the graph, the current page's included: the palette
  entries first, in palette order, then each kind the palette lacks, sorted, with the
  grey swatch. A page with no kind has no entry. The legend sits below the local graph
  and over the bottom-left corner of the global graph; its text and frame use the
  theme's colours, so it follows light and dark mode.
- The decisions that need no canvas (palette lookup, legend entries, which nodes a
  graph draws) live in `src/components/scripts/graph-logic.js`, which
  `plugin/test/visor/06-graph-logic.sh` runs under Node.
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
