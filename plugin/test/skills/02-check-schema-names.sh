#!/usr/bin/env bash
# The NestJS skill's check-schema-names.mjs fails when two classes that @nestjs/swagger may
# document share a name, since the OpenAPI document keeps one schema per name, and passes
# on everything else. A schema file imports @nestjs/swagger or is named like the Swagger CLI
# plugin's DTO files (`.dto.ts`, `.entity.ts`).
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
CHECK="$HERE/../base/skills/inspire-code-nestjs/references/check-schema-names.mjs"
. "$HERE/lib/assert.sh"

if ! command -v node >/dev/null 2>&1; then
  skipped 14 "check-schema-names.mjs needs node on PATH"
  summary
  exit $?
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pkg="$work/pkg"
mkdir -p "$pkg/src/frameworks/dto" "$pkg/src/criteria/dto" "$pkg/src/plain" "$pkg/src/node_modules/lib" "$pkg/src/dist"

dto() { printf '%s\n' "import { ApiProperty } from '@nestjs/swagger';" "$2" > "$pkg/$1"; }

run_check() { (cd "$pkg" && node "$CHECK" "$@" 2>&1); }

dto src/frameworks/dto/criterion.request.ts 'export class CriterionRequest { @ApiProperty() name!: string; }'
dto src/criteria/dto/criterion.request.ts 'export class CriterionRequest { @ApiProperty() weight!: number; }'
out="$(run_check)"; status=$?
eq "two swagger classes of one name fail the check" "$status" 1
has "the failure names the class" "$out" "CriterionRequest is declared in"
has "the failure names the first file" "$out" "src/criteria/dto/criterion.request.ts"
has "the failure names the second file" "$out" "src/frameworks/dto/criterion.request.ts"

dto src/criteria/dto/criterion.request.ts 'export class UpdateCriterionRequest extends PartialType(CriterionRequest) {}'
printf '%s\n' 'export class CriterionRequest {}' > "$pkg/src/plain/criterion.ts"
dto src/criteria/dto/criterion.request.spec.ts 'class CriterionRequest {}'
dto src/node_modules/lib/criterion.ts 'export class CriterionRequest {}'
dto src/dist/criterion.ts 'export class CriterionRequest {}'
out="$(run_check)"; status=$?
eq "a class in a file without @nestjs/swagger, a spec, node_modules or dist is not counted" "$status" 0
eq "a passing check prints nothing" "$out" ""

dto src/frameworks/dto/criterion.request.ts 'export class CriterionRequest {}
function mixin() { return class CriterionRequest {} }'
out="$(run_check)"; status=$?
eq "a name declared twice in one file is not a duplicate" "$status" 0

printf '%s\n' 'import { ApiProperty } from "@nestjs/swagger";' 'export abstract class CriterionRequest {}' > "$pkg/src/plain/criterion.ts"
out="$(run_check)"; status=$?
eq "an abstract class and a double-quoted import count too" "$status" 1

printf '%s\n' 'import { ApiProperty } from "@nestjs/swagger/dist/decorators";' 'export class CriterionRequest {}' > "$pkg/src/plain/criterion.ts"
out="$(run_check)"; status=$?
eq "an import from a subpath of @nestjs/swagger counts" "$status" 1

rm "$pkg/src/plain/criterion.ts"
printf '%s\n' 'export class CriterionRequest {}' > "$pkg/src/plain/criterion.dto.ts"
out="$(run_check)"; status=$?
eq "a .dto.ts file without the import counts, as the Swagger CLI plugin documents it" "$status" 1
rm "$pkg/src/plain/criterion.dto.ts"

mkdir -p "$pkg/lib"
dto lib/criterion.ts 'export class CriterionRequest {}'
out="$(run_check lib)"; status=$?
eq "the roots given as arguments replace src" "$status" 0

out="$(run_check src lib)"; status=$?
eq "every root given is read" "$status" 1

out="$(run_check missing)"; status=$?
eq "a missing root fails with exit 2" "$status" 2
has "the failure names the missing root" "$out" "no directory missing under"

summary
