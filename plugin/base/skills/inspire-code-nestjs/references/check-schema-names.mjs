import { readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";

const SWAGGER_IMPORT = /from\s+["']@nestjs\/swagger["']/;
const CLASS = /^[ \t]*(?:export[ \t]+)?(?:default[ \t]+)?(?:abstract[ \t]+)?class[ \t]+([A-Za-z_$][\w$]*)/gm;
const SKIPPED_DIRECTORIES = new Set(["node_modules", "dist"]);
const TEST_FILE = /\.(?:spec|test|e2e-spec)\.ts$|\.d\.ts$/;

function* sourceFiles(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (!SKIPPED_DIRECTORIES.has(entry.name)) yield* sourceFiles(path);
    } else if (entry.name.endsWith(".ts") && !TEST_FILE.test(entry.name)) {
      yield path;
    }
  }
}

function schemaClasses(roots) {
  const filesByName = new Map();
  for (const root of roots) {
    for (const file of sourceFiles(root)) {
      const source = readFileSync(file, "utf8");
      if (!SWAGGER_IMPORT.test(source)) continue;
      for (const match of source.matchAll(CLASS)) {
        const name = match[1];
        const files = filesByName.get(name) ?? [];
        files.push(relative(process.cwd(), file).split("\\").join("/"));
        filesByName.set(name, files);
      }
    }
  }
  return filesByName;
}

const roots = process.argv.length > 2 ? process.argv.slice(2) : ["src"];
const duplicates = [...schemaClasses(roots)].filter(([, files]) => files.length > 1);

for (const [name, files] of duplicates) {
  console.error(
    `${name} is declared in ${files.join(", ")}. @nestjs/swagger names a schema after its class and keeps only the first class of a name, so the OpenAPI document shows one shape for all of them. Rename all but one.`,
  );
}
process.exit(duplicates.length > 0 ? 1 : 0);
