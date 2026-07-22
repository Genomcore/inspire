# /inspire_code fix-build — build-error remediation

Fix build errors directly — not just analyze. Reach a clean build with the
**minimal** set of changes, understanding the code before touching it.

> **Private registry.** If dependency resolution fails with 401/403, the project
> likely uses a private package registry — authenticate with it first (the command
> is project-specific; check the project's README / bootstrap docs). This skill
> stays stack- and registry-agnostic: it does not hard-code any organization's
> login.

## Process

1. **Run the build** and capture every error. Use the active stack profile's
   `## Build & verify` commands when present (SKILL.md → Stack profiles); otherwise
   the project's build command. The commands below are the common defaults:
   ```bash
   npm run build 2>&1 || npx tsc --noEmit 2>&1
   ```

2. **Parse** — extract error code, file, line, and message for each error. Group
   related errors; do not fix them one at a time.

3. **Diagnose** — determine the root cause. Common cases (TypeScript shown; the
   same "fix the cause, not the symptom" applies to any compiler):

   | Error | Fix |
   |---|---|
   | TS2322 Type not assignable | Fix the type; add an assertion only with justification |
   | TS2304 Cannot find name | Add the import or declaration |
   | TS2307 Cannot find module | Install the package or fix the path |
   | TS2339 Property does not exist | Add it to the interface or fix the typo |
   | TS7006 Implicit any | Add a type annotation |
   | Swift: No such module | Resolve packages (`swift package resolve`) |
   | Kotlin: Unresolved reference | Check imports and dependencies |

4. **Fix** — implement the minimal fix in source files. No side effects on
   unrelated code. Prefer proper types over `any` or assertions — an assertion that
   silences a real type error is the forbidden escape hatch (see
   [`tdd.md`](tdd.md), "Never silence the toolchain").

5. **Verify** — rebuild (and lint) to confirm the fix is real and introduced
   nothing new:
   ```bash
   npm run build && npm run lint
   ```

## Rules

- **Minimal changes** — only fix what is broken.
- **Understand before fixing** — a build error often points at a design mistake;
  read the surrounding code.
- **Prefer proper types** over `any` or casts.
- **Batch fixes aggressively** — don't rebuild after every single edit.
- **A build error that is really a spec problem** (the code can't compile because
  the contract it was written against doesn't match the action descriptor) is a
  hand-back, not a cast — route it to `/inspire_domain` rather than forcing the
  types.
