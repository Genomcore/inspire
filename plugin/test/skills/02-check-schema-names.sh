#!/usr/bin/env bash
# The NestJS skill's check-schema-names.mjs fails when two classes declared in files that
# import @nestjs/swagger share a name, since the OpenAPI document keeps one schema per
# name, and passes on everything else.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
CHECK="$HERE/../base/skills/inspire-code-nestjs/references/check-schema-names.mjs"
. "$HERE/lib/assert.sh"

if ! command -v node >/dev/null 2>&1; then
  skipped 9 "check-schema-names.mjs needs node on PATH"
  summary
  exit $?
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pkg="$work/pkg"
mkdir -p "$pkg/src/frameworks/dto" "$pkg/src/criteria/dto" "$pkg/src/plain" "$pkg/node_modules/lib"

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
dto node_modules/lib/criterion.ts 'export class CriterionRequest {}'
out="$(run_check)"; status=$?
eq "a class in a file without @nestjs/swagger, a spec or node_modules is not counted" "$status" 0
eq "a passing check prints nothing" "$out" ""

printf '%s\n' 'import { ApiProperty } from "@nestjs/swagger";' 'export abstract class CriterionRequest {}' > "$pkg/src/plain/criterion.ts"
out="$(run_check)"; status=$?
eq "an abstract class and a double-quoted import count too" "$status" 1

mkdir -p "$pkg/lib"
out="$(run_check lib)"; status=$?
eq "the roots given as arguments replace src" "$status" 0

out="$(run_check src lib)"; status=$?
eq "every root given is read" "$status" 1

summary
