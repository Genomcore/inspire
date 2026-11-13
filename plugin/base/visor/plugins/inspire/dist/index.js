import fs from "node:fs/promises"
import path from "node:path"

// The unit kind is the typed extension of the file name (x.screen.md -> "screen").
// A segment that is not a type name is a dotted file name (upgrade-to-0.17.0), not a kind.
const kindOf = (slug) => {
  const parts = String(slug ?? "").split("/").pop().split(".")
  const last = parts.length > 1 ? parts.at(-1) : undefined
  return /^[a-z][a-z-]*$/.test(last ?? "") ? last : undefined
}

// Adds each file's unit kind, module and lifecycle to its content-index entry, for
// client components such as the graph. It adds no tags, properties or pages.
export const Inspire = () => ({
  name: "Inspire",
  // the loader skips a transformer with no transform hook, even one that only extends the index
  markdownPlugins: () => [],
  extendContentIndex({ fileData }) {
    const fm = fileData.frontmatter ?? {}
    return {
      inspire: {
        kind: kindOf(fileData.slug),
        module: typeof fm.module === "string" ? fm.module : undefined,
        lifecycle: typeof fm.lifecycle === "string" ? fm.lifecycle : undefined,
      },
    }
  },
})

// A KB has a root README.md and no index.md, so the site root redirects to the README.
export const InspireHome = () => ({
  name: "InspireHome",
  async emit(ctx) {
    const readme = ctx.allSlugs.find((s) => s.toLowerCase() === "readme")
    if (!readme || ctx.allSlugs.includes("index")) return []
    const target = path.join(ctx.argv.output, "index.html")
    await fs.writeFile(
      target,
      `<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=./${readme}"><link rel="canonical" href="./${readme}">`,
    )
    return [target]
  },
})
