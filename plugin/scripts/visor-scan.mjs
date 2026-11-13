// plugin/scripts/visor-scan.mjs QUARTZ KB — the frontmatter scan of /inspire:visor, run by
// visor.sh as `node --input-type=module -e` on the runtime it chose. It lists files as
// quartz/util/glob.ts does and parses them as readFrontmatterData in
// quartz/plugins/builtins/frontmatter.ts does, with the checkout's own packages, so it
// refuses exactly the files the build refuses.
//
// stdout: one JSON line {"path", "error"} per file Quartz cannot read; a non-zero exit
// means the scan itself failed.

import { createRequire } from "node:module"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { pathToFileURL } from "node:url"

const [quartz, kb] = process.argv.slice(1)
const require = createRequire(join(quartz, "package.json"))
const matter = require("gray-matter")
const jsYaml = require("js-yaml")
const toml = require("toml")
const YAML = require("yaml")
const { globby } = await import(pathToFileURL(require.resolve("globby")).href)

const configuration = YAML.parse(readFileSync(join(quartz, "quartz.config.yaml"), "utf8")).configuration ?? {}
const frontmatter = configuration.frontmatter ?? {}
if (frontmatter === false || frontmatter.enabled === false) process.exit(0)

const refuseJavaScript = () => {
  throw new Error("JavaScript frontmatter (---js / ---javascript) is not supported")
}
const options = {
  delimiters: frontmatter.delimiters ?? "---",
  language: frontmatter.language ?? "yaml",
  engines: {
    yaml: (s) => jsYaml.load(s, { schema: jsYaml.JSON_SCHEMA }),
    toml: (s) => toml.parse(s),
    javascript: refuseJavaScript,
    js: refuseJavaScript,
  },
}

const files = (await globby("**/*.*", { cwd: kb, ignore: configuration.ignorePatterns ?? [], gitignore: true }))
  .filter((fp) => fp.endsWith(".md"))
  .sort()
for (const path of files) {
  try {
    const { data } = matter(readFileSync(join(kb, path)), options)
    if (typeof data !== "object" || data === null || Array.isArray(data)) {
      const kind = Array.isArray(data) ? "list" : typeof data
      throw new Error(`Invalid frontmatter: expected properties (\`key: value\` lines), got a ${kind}`)
    }
  } catch (e) {
    console.log(JSON.stringify({ path, error: String(e?.message ?? e).split("\n")[0] }))
  }
}
