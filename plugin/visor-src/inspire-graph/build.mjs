// Builds dist/index.js, unminified so the copy committed under plugin/base/ reads as
// source. Quartz supplies preact, so it stays an import.
import { build } from "esbuild";
import { compile } from "sass";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));

// A component's CSS and its browser script reach Quartz as strings, so both are
// compiled here and imported as text.
const componentAssets = {
  name: "component-assets",
  setup(b) {
    b.onLoad({ filter: /\.scss$/ }, (args) => ({
      contents: compile(args.path).css,
      loader: "text",
    }));
    b.onLoad({ filter: /\.inline\.ts$/ }, async (args) => {
      const result = await build({
        stdin: {
          contents: await fs.readFile(args.path, "utf8"),
          loader: "ts",
          resolveDir: path.dirname(args.path),
          sourcefile: path.relative(root, args.path),
        },
        absWorkingDir: root,
        write: false,
        bundle: true,
        platform: "browser",
        format: "esm",
        target: "es2020",
      });
      return { contents: result.outputFiles[0].text, loader: "text" };
    });
  },
};

await build({
  absWorkingDir: root,
  entryPoints: ["src/index.ts"],
  outfile: "dist/index.js",
  bundle: true,
  format: "esm",
  platform: "node",
  target: "es2022",
  jsx: "automatic",
  jsxImportSource: "preact",
  external: ["preact", "preact/*"],
  plugins: [componentAssets],
});
