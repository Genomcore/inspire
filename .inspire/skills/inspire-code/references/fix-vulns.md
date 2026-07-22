# /inspire_code fix-vulns — npm vulnerability remediation

**Scope: npm only** (any project with `package.json` / `package-lock.json`). For
other ecosystems (pip, Maven, Gradle, SPM, cargo) this subcommand does not apply —
say so and stop.

Fix npm security vulnerabilities directly — reach the agreed severity bar with the
**fewest `overrides` possible**, without breaking build or tests. You run in the
operator's conversation, so you **can and should ask** when a decision is needed
(Step 6).

> **Private registry.** If `npm install` / `npm audit` fails with 401/403, the
> project uses a private registry — authenticate with it first (project-specific
> command; check the project's README / bootstrap docs). This reference stays
> registry-agnostic and hard-codes no organization's login.

## Hard rules (non-negotiable)

1. **NEVER run `npm audit fix --force`.** It downgrades parents, breaks
   peerDependencies, and is the opposite of fixing. Plain `npm audit fix` (no
   `--force`) is allowed but rarely helps.
2. **Severity bar: 0 high / 0 critical is mandatory.** moderate / low are tolerated
   if the only fix would require an override (rule 3). Confirm a different bar only
   if the operator signalled one.
3. **Avoid `overrides`. Last resort, ONLY when a HIGH/CRITICAL has no other fix
   path** (no published parent release — stable, rc, or next — uses a patched
   version). A moderate/low that would need an override → leave it.
4. **You MAY bump majors** of direct dependencies and **change the affected source
   code and tests** to make the bump work. That is preferred over an override.
5. **Do not touch files in an unresolved-merge state.** If `git status` shows
   `UU`/`AA`, or unrelated in-progress work, and a test fails because of it,
   **report it and ask** — never silently edit that file.
6. **ALWAYS test-remove every existing override (Step 1) first, and remove the
   obsolete ones.** Mandatory. For each `overrides.<name>`: delete it,
   `npm install`, re-audit; if the bar still holds it stays removed, otherwise
   restore it. Never finish with an override the audit proves unnecessary. If the
   removal check errors, fix the check and re-run — don't skip and leave it in.

## Workflow

### Step 0 — Baseline
```bash
# (authenticate to the private registry first if the project uses one)
npm audit 2>&1 | tail -40
npm audit --json 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>console.log(JSON.stringify(JSON.parse(d).metadata.vulnerabilities)))"
git status --short   # note any UU / unrelated changes BEFORE you start
```

### Step 1 — Can any EXISTING override be removed? (MANDATORY — see hard rule 6)
Upstream may have caught up. Test removal **one at a time, for every override**:
```bash
npm pkg delete overrides.<name>
npm install >/dev/null 2>&1
npm audit --json 2>/dev/null > /tmp/a.json
node -e "const m=require('/tmp/a.json').metadata.vulnerabilities; console.log('high:'+m.high+' crit:'+m.critical+' mod:'+m.moderate)"
```
Within the bar → keep removed. Otherwise restore (`npm pkg set overrides.<name>="<range>"`).
If the check itself errors, fix it and re-run. Report which overrides are now obsolete.

### Step 2 — Find the REAL source of each vulnerable package
Don't assume the obvious parent is the culprit. Locate every nested copy and see who
pins it:
```bash
find node_modules -path '*/node_modules/<pkg>/package.json' | while read f; do echo "$(node -p "require('./$f').version") <- $f"; done
```
For each suspected parent, check **exact pin vs range** — this decides whether a
non-override fix exists:
```bash
npm view <parent>@<installed-version> dependencies.<pkg>   # "4.1.1" (exact, won't move) vs "^4.1.0" (range, auto-resolves)
```
> A transitive dep often looks like it comes from one parent but is really pinned
> **exactly** by another. Bumping the wrong parent fixes nothing. Always confirm the
> source before acting.

### Step 3 — Try a non-override fix (preferred order)
1. **Bump the direct dependency** that owns the chain to a version whose range
   already pulls the patched transitive dep. Majors allowed.
2. **Check newer / pre-release parents** when the latest stable still pins a
   vulnerable version:
   ```bash
   npm view <parent> dist-tags --json
   npm view <parent>@next dependencies.<pkg>
   npm view <parent>@latest dependencies.<pkg>
   ```
3. If the parent pins the transitive dep **exactly**, adding it as a direct
   dependency does NOT replace the nested copy — npm keeps the parent's exact copy.
   Only an override works then.

### Step 4 — Override only as last resort (HIGH/CRITICAL with no other path)
- Use the narrowest range that satisfies the advisory's "patched in" version.
- A global override is fine when multiple nested copies need the same bump and all
  consumers are API-compatible. **Verify API compatibility** before forcing a major
  across the tree (a removed/renamed method in the new major breaks any consumer
  still calling it).

### Step 5 — Verify
```bash
find node_modules -path '*/node_modules/<pkg>/package.json' | while read f; do echo "$(node -p "require('./$f').version") <- $f"; done
npm run build 2>&1 | tail -5
npm test 2>&1 | grep -E "Tests:|Test Suites:"
```
- Build must pass.
- For test failures, decide whether they are **caused by your change** or
  **pre-existing** (unrelated in-progress work / a `UU` file). Report pre-existing
  failures as such; never silently "fix" unrelated files.

### Step 6 — When the two rules collide, ASK the operator
If a HIGH/CRITICAL can ONLY be killed by an override (no parent release fixes it),
the "avoid overrides" preference and the "never high" bar conflict. Ask:
- **A:** keep the single override → 0 high, some moderate. (recommended — honours the bar)
- **B:** no overrides → leaves the high. (violates the bar)

Use the smallest number of overrides that satisfies the severity bar.

## Output

```markdown
## Vulnerability Fix Report

| | Before | After |
|---|---|---|
| critical | X | X |
| high | X | X |
| moderate | X | X |
| low | X | X |

### Overrides
- Removed (now obsolete): ...
- Added (last resort, HIGH/CRITICAL only): `<pkg>: <range>` — why no other path
- Kept: ...

### Dependency bumps
| Package | From | To | Major? | Code/tests touched |

### Build & tests
- build: PASS/FAIL
- tests: N passed, M failed — P pre-existing (reason) vs Q regressions

### Remaining (tolerated) vulnerabilities
| Package | Severity | Source (who pins it) | Self-resolves when |
```

## Notes
- Work in the project the operator points you at (cwd). Re-run `npm install` after
  every `package.json` edit.
- Prefer `npm pkg set/delete` for surgical edits; otherwise edit `package.json`.
- Never push or commit unless asked (Rule 7 of the skill).
