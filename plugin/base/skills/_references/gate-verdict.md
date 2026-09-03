# The gate verdict

The structured projection `.inspire/bin/emanate-gate.sh` prints on stdout —
claim coverage x citing tests x suite result, folded into one pass/fail
verdict the orchestrator weighs before it promotes a unit (D8) — a merge,
never a lifecycle edit; see § Consumers.
This file owns its JSON shape, the suite-results schema it consumes, the
exit codes and the `GV-*` catalogue gate names itself. A separate file from
[`derived-contract.md`](derived-contract.md) on purpose: two schemas, two
exit-code tables, two id catalogues, two consumer sets, so a rule keeps one
home.

**Gate produces evidence; it does not promote.** It writes nothing, edits no
frontmatter, and never runs a suite — the results are handed in, because
D4's "never trusting a persona's green" means gate must not be the one
producing the green it then reads. An approval from either overseer is
necessary and never sufficient (D3): gate is the deterministic half a
rejection alone cannot stand in for.

## CLI

```
emanate-gate.sh --contract FILE|-  --results FILE
                [--tests-root DIR]...  [--previous FILE]
```

The current working directory is the repo root, as everywhere in
`.inspire/bin/`. Gate reads **no KB** and needs neither `SDD_KB_ROOT` nor
`SDD_SPEC_ROOT` — everything it needs arrives as an argument.

- `--contract FILE` — the derived contract (`emanate-derive.sh`'s stdout),
  one JSON object; `-` reads stdin. Required.
- `--results FILE` — the suite results (`emanate-results.sh`'s stdout),
  § below. Required.
- `--tests-root DIR` — repeatable. The tree(s) grepped for `@claim` tokens.
  Defaults to `tests` (CWD-relative) when none given. Gate never resolves a
  stack profile's own test-path convention — this is always an argument
  (R2 in the implementation brief), never a heuristic on prose.
- `--previous FILE` — the previous run's derived contract, for `delta`
  (joined by claim id, never array order).

## Suite results — `inspire.suite-results/1`

A small JSON manifest — not JUnit XML. JUnit's
"zero adapters" claim breaks on the one field gate needs, the
testcase-to-**file** binding, which is optional or differently-spelled
across runners (jest-junit, go-junit-report, vitest, pytest all disagree). A
format gate can read only *sometimes* is worse than one that is normalized
once, and the manifest keeps gate on `jq` alone.

**`.inspire/bin/emanate-results.sh` is what normalizes it**, from whatever a
real runner prints; this file is that script's declared authority for the
shape, so the two cannot drift. The orchestrator invokes it rather than
authoring the manifest itself — handing that to judgement would put a schema
inside prose doctrine, the one place a persona could produce a
plausible-but-wrong shape and have every claim read as not-run. A second
runner dialect is a reader function there; a second *format* gate accepts is
`lib/gate-results.sh`, the one place JUnit would go.

```json
{ "schema": "inspire.suite-results/1",
  "tests": [ { "file": "tests/auth/user-create.spec.ts",
               "name": "rejects a non-administrator",
               "status": "passed" },
             { "file": "tests/auth/user-create.spec.ts",
               "name": "stores one row per email",
               "status": "failed", "message": "expected 1, got 2" } ] }
```

- `status` is one of `passed` | `failed` | `skipped`. Anything else is
  exit 5.
- `message` is optional. It is spooled and then never read again — no
  verdict field, no finding and no line of the stderr report interpolates
  it — so it is validated for shape and ignored.
- A missing or duplicated `schema`, a non-array `tests`, an entry whose
  `file` or `name` is not a string or whose `message` is neither a string
  nor absent, or an entry any of whose four fields carries the record
  separator `U+001F`, is exit 5 — an old or foreign shape is an error,
  never a silently-empty section (D7's strictness, applied to gate's own
  input: a silent misread would mark every claim not-run, the vacuity trap
  in a new coat).
- Two of those want saying plainly. A key is checked by **type**, not
  presence: a missing key reads as null, so the type test subsumes the
  presence test, while an object-valued `file` would satisfy a presence
  test and then empty the spool. And the separator is **refused rather
  than escaped**, because the spool joins the four fields with it: one
  inside `file` or `name` shifts every field after it, forging a `passed`
  status for a test the suite skipped. Covering all four — `message`
  included, which cannot forge — keeps that property structural rather
  than resting on `message` being last. No runner emits `U+001F`.
- **Sniffed before parsing**: a file whose first non-whitespace byte is `<`
  is rejected as XML at exit 5 without ever reaching the JSON parser.

**Path matching is exact after normalization**: a leading `./` stripped, `/`
runs collapsed, a trailing `/` dropped — applied to both a citation's file
and a results entry's `file` before either is compared, so the orchestrator
may spell a path either way. Nothing fuzzy, no suffix matching. Paths are
matched **as spelled, relative to the working directory**: an absolute
`--tests-root` discovers absolute citation paths, which match no relative
`file` entry, and the diagnostic below is what says so.

**A diagnostic, never a finding**: if `tests[]` is non-empty and no entry's
`file` matches any file discovered under the tests roots, one warning line
goes to stderr — so an all-uncited run is never mistaken for a
misconfigured `--tests-root`, or the reverse.

## Citations

For each `--tests-root`, every regular file is walked and grepped for
`@claim[[:space:]]+[^[:space:]]+([[:space:]]+sha256:[0-9a-f]+)?` — the shared
scanner's grammar, for which `tester.md` is normative in **both** halves: the
id runs from the first non-space after `@claim` to the first whitespace or
the end of the line — a trailing
`.` is legal inside an id and is read as part of it — and the optional second
word is the fingerprint below, which `tester.md` § The fingerprint half tells
the tester to write. A discovered path
carrying `:` or a newline is exit 3 (symlinks/exotic paths are a declared
non-support, `CLAUDE.md`).

**The token takes an optional second word: the claim's fingerprint** —
`@claim <id> <fingerprint>`, spelled exactly as
[`derived-contract.md`](derived-contract.md) § The fingerprint emits it,
`sha256:<hex>`. Anything else after the id is prose and is ignored, as
everything after the id always was, so a trailing comment can never be
misread as a fingerprint.

**Both forms are valid here, and gate reads only the id half.** An id-only
citation covers a claim exactly as it did before the fingerprint existed, and
so does one naming a *stale* fingerprint: someone did write a test for this
claim, which is the whole of what coverage asks. The fingerprint is read by
`/inspire-emanate plan` instead, where matching it is what makes a unit
**realized** ([`emanation-plan.md`](emanation-plan.md) § Realization) — which is
the tester's own reason to write one, since an id-only citation leaves the unit
in the frontier for good. One scanner (`lib/gate-citations.sh`) serves both
readings; there is no second grammar.

**Granularity is the file.** A citation is `{file, line}`, never a test
name — a grep knows no test syntax, and binding a token to the test that
follows it is exactly the machine check `tester.md` rules out.

## The verdict — stdout, `inspire.gate-verdict/1`

Valid JSON on every exit that produces a verdict (0, 1, 4). Empty on 2, 3,
5, 127.

```json
{ "schema": "inspire.gate-verdict/1",
  "unit": { "kind", "id", "path", "lifecycle" },
  "verdict": "pass" | "fail",
  "claims": [ { "id", "oracle", "fingerprint",
                "status": "covered"|"uncited"|"cited-not-run"|"cited-failed"|"store-uncited",
                "citations": [ { "file", "line" } ... ],
                "findings": [ "GV-01" ... ] } ... ],
  "findings": [ { "class", "target", "message", "remedy" } ... ],
  "summary": { "claims": N, "covered": N, "uncited": N,
               "cited_not_run": N, "cited_failed": N, "store_uncited": N,
               "oracles": { "test": N, "store": N },
               "tests": { "total": N, "passed": N, "failed": N, "skipped": N },
               "findings_by_class": { "GV-01": N, ... } },
  "delta": { "changed": [ids], "unchanged": [ids], "new": [ids], "retired": [ids] } }
```

- `unit` is copied from the contract's own `unit` object, never re-derived.
- `findings[]` reuses derive's refusal grammar `{class, target, message,
  remedy}` exactly, so an operator reads one vocabulary across both tools.
- A claim's own `findings` array holds 0 or 1 class ids — the three
  per-claim classes (`GV-01`/`GV-02`/`GV-03`) are mutually exclusive by
  status.
- `delta` is **absent** (no key at all) when `--previous` was not given —
  never `null`, never an empty object — and on the `GV-00` path below even
  when it was.
- **The one rule**: `verdict = (findings == 0) ? "pass" : "fail"`.

Stderr carries a grouped human report mirroring `emanate-derive.sh`'s
`report_refusals`/`report_derived`: a `GATE pass|fail <kind> <id>` head
line, findings grouped by class, and a counts tail.

## Fingerprints and `--previous`

**Gate never computes a fingerprint** — derive owns them
([`derived-contract.md`](derived-contract.md) § The fingerprint); every
claim's `fingerprint` string is copied through verbatim.

With `--previous`, the two `claims[]` arrays join **by `id`, never by array
order** (claim order is not stable across a re-emanation):

- `unchanged` — id in both, same `fingerprint`.
- `changed` — id in both, different `fingerprint`. A `changed` claim that is
  also `covered` is reported in both places and is **not** a finding: gate
  reports, the orchestrator decides whether to re-emanate.
- `new` — id only in the current contract.
- `retired` — id only in the previous contract. A retired id never appears
  in `claims[]` (it is not a claim any more) — only in `delta.retired`.

## The `GV-*` catalogue

Every class sets `verdict: "fail"` and exit 1 (`GV-00` is exit 4's own
shape, below).

| id | fires when | target |
|---|---|---|
| `GV-00` | the contract is a derive refusal object (exit 4 path only) | the unit |
| `GV-01` | **uncited claim** — an `oracle: "test"` claim with no `@claim` token under any tests root | the claim id |
| `GV-02` | **cited, not run** — every citing file is absent from `tests[]`, or present with every one of its entries `skipped` | the claim id |
| `GV-03` | **cited, failed** — a citing file has >=1 entry with status `failed` | the claim id |
| `GV-04` | **dangling citation** — a token whose id starts with this unit's claim-id prefix (the substring before the first `/`) but names no claim in the contract | the citing `file:line` |
| `GV-05` | **suite red elsewhere** — `tests[]` holds a `failed` entry in a file that cites nothing for this unit | the results file |
| `GV-06` | **vacuous contract** — the contract's `claims[]` is present but empty | the unit |

**`GV-04`'s prefix scoping is load-bearing.** A shared tests tree holds
citations for every unit in the vault; treating any unknown id as dangling
would fire on every run. The prefix scope catches exactly the real defect
— a citation left behind after a claim was retired or re-keyed — and
ignores every other unit's tokens.

**`oracle: "store"` claims never fire `GV-01`.** A store claim is asserted
against the schema the contracter emitted; requiring a citation would
contradict the tester's own doctrine (`tester.md`, `quality-overseer.md`).
An uncited store claim gets status `store-uncited`, is counted in
`summary.store_uncited`, and is never a finding. A store claim that *is*
cited runs the ordinary covered/not-run/failed path like any other claim.

**Two non-findings, decided here.** A `tests[]` entry naming a file outside
every tests root is not a finding — policing the runner is not gate's job,
though its `failed` status still counts toward `GV-05`. And a unit whose
claims are *all* `store` gets one stderr line (*"no test-oracle claim in
this unit — the schema is the oracle"*) plus `summary.oracles`, never a
finding.

## `GV-00` — the refused-contract shape

On exit 4 the verdict still carries the full `inspire.gate-verdict/1`
shape — `verdict: "fail"`, an empty `claims[]`, and one `GV-00` finding per
row of the underlying problem:

- if the contract is a genuine derive refusal object, one `GV-00` finding
  per entry of its `refused[]`, target forced to the unit id (a unit that
  never derived has no finer-grained thing to point at), message prefixed
  with derive's own `target` — the artifact path to go and fix — and with
  the original `DR-*`/`OS-*` class where derive's message does not already
  open with it, so nothing is lost;
- if the contract is not even that — unparseable JSON, or a foreign/missing
  `schema` — one synthetic `GV-00` finding naming the mismatch.

A unit that did not derive cannot be gated, and saying so in the verdict's
own grammar is better than saying nothing.

**No `delta` on this path, even with `--previous`.** The contract short-
circuits before the previous one is ever read, and a delta against claims
that failed to derive would be a comparison with nothing.

## Exit codes

| exit | meaning |
|---|---|
| `0` | pass — no finding. Verdict on stdout. |
| `1` | fail — one or more findings. Verdict on stdout: a normal outcome the orchestrator branches on, not a crash. |
| `2` | usage — unknown flag, missing `--contract` or `--results`. |
| `3` | an input path does not exist or is unreadable (contract, results, a `--tests-root`, `--previous`), or a discovered test path carries a `:`/newline. |
| `4` | the contract is unusable — see `GV-00` above. |
| `5` | the results file is not `inspire.suite-results/1`. |
| `127` | a required tool is missing (`jq`). |

Gate needs **`jq` only** — no `yq`, no `python3`, no `perl`. It does not
source `_lib.sh`/`_keyed-heads.sh`, and it does not source
`derive-*.sh` either: it composes on derive's *output*, never its
implementation, so the two packages evolve independently.

## Consumers

`/inspire-emanate run`'s gate step is the entry point; nothing else runs it.
The orchestrator reads the verdict as the deterministic half of its promote
decision — and **promote is git-side**: the unit's integration branch merges
into the run's turn branch, carrying the verdict's digest in the merge
commit's trailers. **No `lifecycle:` is walked and no KB file is written**,
because a run never touches the knowledge base
(`inspire-emanate/references/run.md` § promote). Gate itself calls nothing,
edits no frontmatter, and never writes `lifecycle:` either.
