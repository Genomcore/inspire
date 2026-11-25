import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";

const SWAGGER_IMPORT = /from\s+["']@nestjs\/swagger(?:\/[^"']*)?["']/;
const PLUGIN_FILE = /\.(?:dto|entity)\.ts$/;
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

function isSchemaFile(file, source) {
  return PLUGIN_FILE.test(file) || SWAGGER_IMPORT.test(source);
}

function schemaClasses(roots) {
  const filesByName = new Map();
  for (const root of roots) {
    for (const file of sourceFiles(root)) {
      const source = readFileSync(file, "utf8");
      if (!isSchemaFile(file, source)) continue;
      const shown = relative(process.cwd(), file).split("\\").join("/");
      const names = new Set([...source.matchAll(CLASS)].map((match) => match[1]));
      for (const name of names) {
        filesByName.set(name, [...(filesByName.get(name) ?? []), shown]);
      }
    }
  }
  return filesByName;
}

const roots = process.argv.length > 2 ? process.argv.slice(2) : ["src"];
const missing = roots.filter((root) => !existsSync(root));
if (missing.length > 0) {
  console.error(`check-schema-names: no directory ${missing.join(", ")} under ${process.cwd()}. Run it from the NestJS package, or pass its source directories.`);
  process.exit(2);
}

const duplicates = [...schemaClasses(roots)].filter(([, files]) => files.length > 1);
for (const [name, files] of duplicates) {
  console.error(
    `${name} is declared in ${files.join(", ")}. @nestjs/swagger names a schema after its class and keeps only the first class of a name, so the OpenAPI document shows one shape for all of them. Rename all but one.`,
  );
}
process.exit(duplicates.length > 0 ? 1 : 0);
