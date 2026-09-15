#!/usr/bin/env bash
# emanate-orchestrator.py, end to end, against the fake runner.
#
# The process is the one piece of the loop with no golden fixtures: its output is
# a git history and a run directory, not a JSON document a rule can diff. So it is
# driven here the way an operator drives it — a scratch repo, a real plan over the
# `clean-three-waves` spec, and a scripted runner standing in for the model.
#
# The fake runner is what makes that possible: every spawn is a deterministic file
# write, so a wave loop, a rework cycle, an arbitration round and a mid-phase kill
# are all reproducible. What is asserted below is therefore the PROCESS — the
# order of the merges, who spent a rework, what the brief carried back — never the
# judgement of a persona, which no test can have.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
REPO="$(cd -P "$HERE/../.." && pwd -P)"
. "$HERE/lib/assert.sh"

BIN="$PLUGIN_ROOT/base/bin"
ORCH="$BIN/emanate-orchestrator.py"
FIXTURE="$BIN/test/fixtures/emanate-plan/clean-three-waves/spec"
UNITTEST="plugin/base/bin/test/test-orchestrator.py"

# Commits must work on a machine with no git identity of its own, and the estate
# runs unattended. These are the run's identity, not the operator's.
export GIT_AUTHOR_NAME="INSPIRE test"    GIT_AUTHOR_EMAIL="test@inspire.invalid"
export GIT_COMMITTER_NAME="INSPIRE test" GIT_COMMITTER_EMAIL="test@inspire.invalid"
export GIT_CONFIG_NOSYSTEM=1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

premise "the process ships and is executable" "[ -x '$ORCH' ]"
premise "the three-wave plan fixture ships its spec tree" "[ -d '$FIXTURE/sdd' ]"

# ---------------------------------------------------------------------------
# The pure-logic suite runs first and counts as ONE assertion here: it has its
# own summary, and restating its count in this file's would make the estate's
# inventory move whenever a unittest case is added.
# ---------------------------------------------------------------------------
( cd "$REPO" && python3 -m unittest "$UNITTEST" ) >"$TMP/unittest.out" 2>&1
ut=$?
[ "$ut" -eq 0 ] || sed -n '1,40p' "$TMP/unittest.out"
check "unit: the pure-logic suite passes" "[ $ut -eq 0 ]"

# ---------------------------------------------------------------------------
# The scratch repo. The fixture's spec/ is the KB; everything else here is the
# minimum a suite needs to exist: a config, a runner that reports one assertion
# per `it(` it finds, and the two ignore lines t=0 demands.
# ---------------------------------------------------------------------------
mkrepo() {
  local p="$1" gi="${2:-full}" r
  mkdir -p "$p/tools" "$p/.inspire"
  cp -R "$FIXTURE" "$p/spec"

  # The fixture's spec/agents/ ships the two overseers; the personas and the
  # arbiter are the shells the plugin itself ships, copied rather than restated —
  # a `tools:` line the orchestrator reads is one the operator would really get.
  for r in contracter tester implementer arbiter; do
    cp "$PLUGIN_ROOT/base/agents/inspire-$r.md" "$p/spec/agents/inspire-$r.md"
  done

  cat > "$p/.inspire/emanate.json" <<'EOF'
{ "schema": "inspire.emanate-config/1",
  "tests_roots":  ["tests"],
  "source_roots": ["source"],
  "suite": [ { "command": "python3 tools/fake-jest.py {report}", "format": "jest" } ] }
EOF

  # The suite. A spec file's assertions pass when its body exists beside it —
  # which is exactly the all-red-then-green shape the gate needs, with no marker
  # for a persona to forge.
  cat > "$p/tools/fake-jest.py" <<'EOF'
#!/usr/bin/env python3
import glob, json, os, re, sys

out = sys.argv[1]
files = []
for f in sorted(glob.glob('tests/*.spec.ts')):
    stem = os.path.basename(f)[:-len('.spec.ts')]
    ok = os.path.exists(os.path.join('source', stem + '.implementer.ts'))
    titles = re.findall(r"""\bit\(\s*['"](.*?)['"]""", open(f).read())
    files.append({
        'name': os.path.abspath(f),
        'assertionResults': [
            {'title': t,
             'status': 'passed' if ok else 'failed',
             'failureMessages': [] if ok else ['no body under source/']}
            for t in titles],
    })
with open(out, 'w') as fh:
    json.dump({'testResults': files}, fh)
red = any(a['status'] == 'failed' for f in files for a in f['assertionResults'])
sys.exit(1 if red else 0)
EOF

  if [ "$gi" = full ]; then
    printf '.inspire/worktrees\n.inspire/emanate-runs\n' > "$p/.gitignore"
  else
    printf 'node_modules\n' > "$p/.gitignore"
  fi

  git -C "$p" init -q -b main
  git -C "$p" add -A
  git -C "$p" commit -qm "the fixture project" >/dev/null
}

# mkfake <dir> — the script.json on stdin.
mkfake() { mkdir -p "$1"; cat > "$1/script.json"; }

# orun <repo> <fakedir> [args...] — a run, from inside the scratch repo. The
# roots are the fixture's, and they are environment because every emanate-* tool
# reads them that way.
orun() {
  local p="$1" fake="$2"; shift 2
  ( cd "$p" && SDD_KB_ROOT=spec/kb SDD_SPEC_ROOT=spec/sdd \
      python3 "$ORCH" run --runner "fake:$fake" --bin "$BIN" \
        --profiles-root spec/profiles --agents-root spec/agents "$@" ) \
    >"$p.out" 2>"$p.err"
  echo $?
}

rundir() { echo "$1"/.inspire/emanate-runs/*; }
runid()  { basename "$(rundir "$1")"; }
goalwt() { echo "$1/.inspire/worktrees/emanate-all"; }
goallog(){ echo "$(goalwt "$1")/.inspire/last-emanation.log"; }

# st <repo> <python expression> — one fact out of state.json, so the assertions
# below state what they mean rather than how the state is shaped.
st() {
  python3 - "$1" "$2" <<'PY'
import glob, json, sys
p = sorted(glob.glob(sys.argv[1] + '/.inspire/emanate-runs/*/state.json'))[-1]
s = json.load(open(p))
IDS = ['audit.event', 'auth.org', 'auth.user', 'auth.user.list']
def u(i):          return s['units'][i]
def status(i):     return u(i)['status']
def rework(i, r):  return u(i)['rework'][r]
def infra(i, r):   return u(i)['infra_retries'][r]
def count(v):      return sum(1 for i in IDS if status(i) == v)
print(eval(sys.argv[2]))
PY
}

# pos <worktree> <unit> — where a unit's promote merge sits in the goal branch's
# history, newest first. A smaller number is a LATER merge.
pos() { git -C "$1" log --format=%s | grep -n "promote $2\$" | head -1 | cut -d: -f1; }

# ---------------------------------------------------------------------------
# A. The happy path. Every persona emits, nothing is rejected, the gate passes,
#    four units promote in graph order and the frontier closes.
# ---------------------------------------------------------------------------
A="$TMP/a"; AF="$TMP/a-fake"
mkrepo "$A"
mkfake "$AF" <<'EOF'
{ "personas": { "contracter":  { "mode": "stub-source" },
                "tester":      { "mode": "tests-from-contract" },
                "implementer": { "mode": "stub-source" } } }
EOF
rc="$(orun "$A" "$AF")"
[ "$rc" = 0 ] || sed -n '1,40p' "$A.err"
eq "A: the run ends and the report is written" "$rc" "0"
eq "A: all four units are promoted" "$(st "$A" "count('promoted')")" "4"

WT="$(goalwt "$A")"
check "A: the goal worktree is on disk" "[ -d '$WT' ]"
p_ev="$(pos "$WT" audit.event)"; p_org="$(pos "$WT" auth.org)"
p_usr="$(pos "$WT" auth.user)";  p_lst="$(pos "$WT" auth.user.list)"
premise "A: every unit left a promote merge on the goal branch" \
  "[ -n '$p_ev' ] && [ -n '$p_org' ] && [ -n '$p_usr' ] && [ -n '$p_lst' ]"
check "A: wave 1 merged before wave 2" "[ '$p_usr' -lt '$p_ev' ] && [ '$p_usr' -lt '$p_org' ]"
check "A: wave 2 merged before wave 3" "[ '$p_lst' -lt '$p_usr' ]"

body="$(git -C "$WT" log --format=%B)"
for trailer in "Emanate-Run:" "Emanate-Unit:" "Emanate-Gate: pass" "Emanate-Profiles:"; do
  has "A: the promote commits carry $trailer" "$body" "$trailer"
done

eq "A: every integration branch is deleted after promote" \
   "$(git -C "$A" branch --list 'emanate/all-*' | wc -l | tr -d ' ')" "0"
eq "A: the launch checkout was never moved off main" \
   "$(git -C "$A" rev-parse --abbrev-ref HEAD)" "main"
eq "A: the launch checkout was never written" \
   "$(git -C "$A" status --porcelain | wc -l | tr -d ' ')" "0"

LOG="$(goallog "$A")"
check "A: the log is committed on the goal branch" \
  "[ -n \"\$(git -C '$WT' log --oneline -- .inspire/last-emanation.log)\" ]"
check "A: the log carries the identity block" "grep -q '^# Emanation run ' '$LOG'"
eq "A: one closing block, at the exit" "$(grep -c '^## Report — ' "$LOG")" "1"
check "A: the closing block records the goal reached" "grep -q '^## Report — .*goal reached' '$LOG'"
check "A: the drill slot is filled with its reason" "grep -q 'drill skipped' '$LOG'"
eq "A: nothing was reworked" "$(st "$A" "sum(sum(u(i)['rework'].values()) for i in IDS)")" "0"

plan="$( cd "$WT" && SDD_KB_ROOT=spec/kb SDD_SPEC_ROOT=spec/sdd \
  "$BIN/emanate-plan.sh" --profiles-root spec/profiles --agents-root spec/agents \
  --tests-root tests 2>/dev/null )"
eq "A: a second plan over the goal branch sees the frontier realized" \
   "$(printf '%s' "$plan" | python3 -c 'import json,sys; print(json.load(sys.stdin)["realized_all"])')" "True"

left="$(ls "$A/.inspire/worktrees" 2>/dev/null | grep -cv '^emanate-all$')"
eq "A: no phase worktree is left on disk" "$left" "0"

# ---------------------------------------------------------------------------
# B. The citation check, the one read-only check that belongs to the tester.
#    A stale fingerprint and a missing one are two classes, and both cost the
#    tester a rework rather than reaching the gate as a coverage hole.
# ---------------------------------------------------------------------------
bcase() { # bcase <name> <fingerprint mode> <class>
  local n="$1" mode="$2" cls="$3"
  local p="$TMP/b-$n" f="$TMP/b-$n-fake"
  mkrepo "$p"
  mkfake "$f" <<EOF
{ "personas": { "contracter":  { "mode": "stub-source" },
                "tester":      { "mode": "tests-from-contract",
                                 "attempts": { "1": { "fingerprint": "$mode" } } },
                "implementer": { "mode": "stub-source" } } }
EOF
  local rc; rc="$(orun "$p" "$f")"
  eq "B/$n: the run still delivers" "$rc" "0"
  eq "B/$n: all four units are promoted" "$(st "$p" "count('promoted')")" "4"
  eq "B/$n: the tester spent exactly one rework, per unit" \
     "$(st "$p" "[rework(i,'tester') for i in IDS]")" "[1, 1, 1, 1]"

  local rd; rd="$(rundir "$p")"
  local recs; recs="$(ls "$rd/spawns" | grep tester | sort)"
  premise "B/$n: the tester was spawned twice for audit.event" \
    "[ \"\$(printf '%s\n' \"\$recs\" | grep -c '^audit-event-')\" -ge 2 ]"
  check "B/$n: the rework brief names $cls" \
    "grep -lq '$cls' $rd/spawns/*tester*.json"
  local first; first="$(printf '%s\n' "$recs" | head -1)"
  check "B/$n: the first tester brief carried no citation finding" \
    "! grep -q 'CI-0' '$rd/spawns/$first'"
}
bcase stale stale CI-03
check "B/stale: the finding shows both fingerprints" \
  "grep -h 'CI-03' -A4 $TMP/b-stale/.inspire/emanate-runs/*/spawns/*tester*.json | grep -q 'sha256:'"

# ---------------------------------------------------------------------------
# C. Rework exhausted. An overseer that never approves stalls the unit at the
#    role it rejected, and the units downstream of it are blocked, never started.
# ---------------------------------------------------------------------------
C="$TMP/c"; CF="$TMP/c-fake"
mkrepo "$C"
mkfake "$CF" <<'EOF'
{ "personas": { "contracter":  { "mode": "stub-source" },
                "tester":      { "mode": "tests-from-contract" },
                "implementer": { "mode": "stub-source" } },
  "overseers": { "inspire-quality-overseer": { "auth.org": { "contracter": [
      { "verdict": "REJECT", "findings": [ { "severity": "error", "blocking": true,
          "title": "the contract invents a field", "issue": "no such field in the KB",
          "follow_up": "re-read the derived contract" } ] },
      { "verdict": "REJECT", "findings": [ { "severity": "error", "blocking": true,
          "title": "the contract invents a field", "issue": "no such field in the KB",
          "follow_up": "re-read the derived contract" } ] },
      { "verdict": "REJECT", "findings": [ { "severity": "error", "blocking": true,
          "title": "the contract invents a field", "issue": "no such field in the KB",
          "follow_up": "re-read the derived contract" } ] } ] } } } }
EOF
rc="$(orun "$C" "$CF")"
eq "C: a stall is still an ending, not a crash" "$rc" "0"
eq "C: the rejected unit is stalled"            "$(st "$C" "status('auth.org')")" "stalled"
eq "C: it stalled at the role that was rejected" "$(st "$C" "u('auth.org')['phase']")" "contracter"
eq "C: the contracter spent every rework it had" "$(st "$C" "rework('auth.org','contracter')")" "3"
eq "C: the unit beside it still promoted"        "$(st "$C" "status('audit.event')")" "promoted"
eq "C: the dependent unit is blocked"            "$(st "$C" "status('auth.user')")" "blocked"
eq "C: and so is the unit behind it"             "$(st "$C" "status('auth.user.list')")" "blocked"
CLOG="$(goallog "$C")"
check "C: the run ends on a stall cascade" "grep -q '^## Report — .*stall cascade' '$CLOG'"
check "C: the stalled unit's integration branch is left in place" \
  "[ -n \"\$(git -C '$C' branch --list 'emanate/all-auth-org-*')\" ]"
CRD="$(rundir "$C")"
CREC="$(ls "$CRD/spawns" | grep '^auth-org-.*contracter' | sort)"
premise "C: the contracter was spawned once more than its rework allowance" \
  "[ \"\$(printf '%s\n' \"\$CREC\" | wc -l | tr -d ' ')\" -ge 3 ]"
check "C: the findings are handed back verbatim in a later brief" \
  "grep -lq 'the contract invents a field' $CRD/spawns/auth-org-*contracter*.json"
check "C: the first brief carried none of them" \
  "! grep -q 'the contract invents a field' \"$CRD/spawns/\$(printf '%s\n' \"\$CREC\" | head -1)\""

# ---------------------------------------------------------------------------
# D. An infrastructural ending is not the persona's fault, so it buys a free
#    retry and spends no rework.
# ---------------------------------------------------------------------------
D="$TMP/d"; DF="$TMP/d-fake"
mkrepo "$D"
mkfake "$DF" <<'EOF'
{ "personas": { "contracter":  { "mode": "stub-source" },
                "tester":      { "mode": "tests-from-contract" },
                "implementer": { "mode": "stub-source" } },
  "endings": { "auth.org": { "tester": [ "crash", "exit" ] } } }
EOF
rc="$(orun "$D" "$DF")"
eq "D: the run ends normally"                    "$rc" "0"
eq "D: the unit that crashed still promotes"     "$(st "$D" "status('auth.org')")" "promoted"
eq "D: the crash is counted as an infrastructural retry" \
   "$(st "$D" "infra('auth.org','tester')")" "1"
eq "D: and it cost the tester no rework"         "$(st "$D" "rework('auth.org','tester')")" "0"

# ---------------------------------------------------------------------------
# E. t=0. Each refusal happens before anything is spawned, and says what to fix.
# ---------------------------------------------------------------------------
E1="$TMP/e-dirty"; mkrepo "$E1"; mkfake "$TMP/e-fake" <<'EOF'
{ "personas": { "contracter": { "mode": "stub-source" },
                "tester": { "mode": "tests-from-contract" },
                "implementer": { "mode": "stub-source" } } }
EOF
echo scratch > "$E1/dirty.txt"
rc="$(orun "$E1" "$TMP/e-fake")"
eq "E/dirty: refused at t=0"                "$rc" "3"
check "E/dirty: the refusal names the path" "grep -q 'dirty.txt' '$E1.err'"
check "E/dirty: nothing was spawned"        "[ ! -d '$E1/.inspire/emanate-runs' ]"

E2="$TMP/e-floor"; mkrepo "$E2"
rc="$(orun "$E2" "$TMP/e-fake" --goal auth.user.list --ceiling 2)"
eq "E/floor: a ceiling under a named goal's floor is refused" "$rc" "3"
check "E/floor: the refusal names the floor it is under" \
  "grep -q 'floor' '$E2.err'"

E3="$TMP/e-ignore"; mkrepo "$E3" none
rc="$(orun "$E3" "$TMP/e-fake")"
eq "E/gitignore: an unignored run dir is refused" "$rc" "3"
check "E/gitignore: the refusal names the worktrees line"  "grep -q '.inspire/worktrees' '$E3.err'"
check "E/gitignore: the refusal names the run-dir line"    "grep -q '.inspire/emanate-runs' '$E3.err'"
check "E/gitignore: the launch checkout's own file is untouched" \
  "! grep -q 'emanate-runs' '$E3/.gitignore'"

E4="$TMP/e-ceiling"; mkrepo "$E4"
rc="$(orun "$E4" "$TMP/e-fake" --ceiling 1)"
eq "E/ceiling: a short ceiling without a goal is a warning, not a refusal" "$rc" "0"
eq "E/ceiling: only wave 1 was delivered" "$(st "$E4" "count('promoted')")" "2"
E4LOG="$(goallog "$E4")"
check "E/ceiling: the run ends exhausted at the declared ceiling" \
  "grep -q '^## Report — .*exhausted — ceiling 1 reached' '$E4LOG'"
check "E/ceiling: the identity block records plan's PR-20" \
  "sed -n '/^## Wave /q;p' '$E4LOG' | grep -q 'PR-20'"

# ---------------------------------------------------------------------------
# F. Resume. A process killed mid-phase leaves a state file that is the truth,
#    and resuming it neither re-runs a closed wave nor re-writes its block.
# ---------------------------------------------------------------------------
F="$TMP/f"; FF="$TMP/f-fake"
mkrepo "$F"
mkfake "$FF" <<'EOF'
{ "personas": { "contracter":  { "mode": "stub-source" },
                "tester":      { "mode": "tests-from-contract" },
                "implementer": { "mode": "stub-source" } },
  "endings": { "auth.user": { "tester": [ "kill" ] } } }
EOF
rc="$(orun "$F" "$FF")"
eq "F: the killed process exits 70"            "$rc" "70"
eq "F: the state shows the unit in its phase"  "$(st "$F" "status('auth.user')")" "in-phase"
eq "F: and names the phase it died in"         "$(st "$F" "u('auth.user')['phase']")" "tester"
FLOG="$(goallog "$F")"
eq "F: wave 1 had already closed before the kill" "$(grep -c '^## Wave 1 — closed' "$FLOG")" "1"

FID="$(runid "$F")"
( cd "$F" && SDD_KB_ROOT=spec/kb SDD_SPEC_ROOT=spec/sdd \
    python3 "$ORCH" resume "$FID" --runner "fake:$FF" --bin "$BIN" ) \
  >"$F.resume.out" 2>"$F.resume.err"
rc=$?
[ "$rc" = 0 ] || sed -n '1,40p' "$F.resume.err"
eq "F: the resumed run ends"                   "$rc" "0"
eq "F: all four units are promoted after resume" "$(st "$F" "count('promoted')")" "4"
eq "F: the interrupted phase is read as an infrastructural ending" \
   "$(st "$F" "infra('auth.user','tester')")" "1"
eq "F: and it cost the tester no rework"       "$(st "$F" "rework('auth.user','tester')")" "0"
eq "F: wave 1's block was not written twice"   "$(grep -c '^## Wave 1 — closed' "$FLOG")" "1"
eq "F: exactly one closing block"              "$(grep -c '^## Report — ' "$FLOG")" "1"
eq "F: the resume reused the run directory"    "$(ls "$F/.inspire/emanate-runs" | wc -l | tr -d ' ')" "1"

# ---------------------------------------------------------------------------
# G. Arbitration. A red gate with GV-03 is a question about who is wrong, and
#    the arbiter's answer is what decides which role reworks.
# ---------------------------------------------------------------------------
G="$TMP/g"; GF="$TMP/g-fake"
mkrepo "$G"
mkfake "$GF" <<'EOF'
{ "personas": { "contracter":  { "mode": "stub-source" },
                "tester":      { "mode": "tests-from-contract" },
                "implementer": { "mode": "stub-source",
                                 "attempts": { "1": { "skip_body": true } } } } }
EOF
rc="$(orun "$G" "$GF")"
[ "$rc" = 0 ] || sed -n '1,40p' "$G.err"
eq "G: the run recovers and ends"                "$rc" "0"
eq "G: the arbitrated unit is promoted"          "$(st "$G" "status('auth.org')")" "promoted"
eq "G: the implementer spent exactly one rework" "$(st "$G" "rework('auth.org','implementer')")" "1"
GRD="$(rundir "$G")"
premise "G: the implementer was spawned twice for auth.org" \
  "[ \"\$(ls '$GRD/spawns' | grep -c '^auth-org-.*implementer')\" -ge 2 ]"
check "G: the rework brief carries the gate's own finding" \
  "grep -lq 'GV-03' $GRD/spawns/auth-org-*implementer*.json"
check "G: the findings are tagged with emanate-gate" \
  "grep -lq 'emanate-gate' $GRD/spawns/auth-org-*implementer*.json"
check "G: and with the arbiter that routed them" \
  "grep -lq 'inspire-arbiter' $GRD/spawns/auth-org-*implementer*.json"

# ---------------------------------------------------------------------------
# H. A promote conflict. Both wave-1 units write one shared source file with
#    their own content; the second to promote cannot merge. That is a rework at
#    the implementer — the branch advanced onto the goal, the paths in the brief —
#    never a stall, and the goal branch ends with both units and no markers.
# ---------------------------------------------------------------------------
H="$TMP/h"; HF="$TMP/h-fake"
mkrepo "$H"
mkfake "$HF" <<'EOF'
{ "personas": { "contracter":  { "mode": "stub-source" },
                "tester":      { "mode": "tests-from-contract" },
                "implementer": { "mode": "stub-source",
                                 "attempts": { "1": { "shared": "registry.ts" } } } } }
EOF
rc="$(orun "$H" "$HF")"
[ "$rc" = 0 ] || sed -n '1,40p' "$H.err"
eq "H: the run recovers and ends"           "$rc" "0"
eq "H: all four units are promoted"         "$(st "$H" "count('promoted')")" "4"
eq "H: exactly one wave-1 unit reworked its implementer, once" \
   "$(st "$H" "sorted([rework('audit.event','implementer'), rework('auth.org','implementer')])")" "[0, 1]"
eq "H: the tester spent nothing"            "$(st "$H" "[rework(i,'tester') for i in IDS]")" "[0, 0, 0, 0]"
HRD="$(rundir "$H")"
check "H: the rework brief names the conflicting path" \
  "grep -lq 'registry.ts' $HRD/spawns/*implementer*.json"
check "H: and says the goal branch moved" \
  "grep -lq 'the goal branch moved under this unit' $HRD/spawns/*implementer*.json"
HWT="$(goalwt "$H")"
check "H: the shared file is on the goal branch"     "[ -f '$HWT/source/registry.ts' ]"
check "H: with no conflict markers"                  "! grep -q '^<<<<<<<' '$HWT/source/registry.ts'"
eq "H: and one unit's content, not both"    "$(grep -c 'registered by' "$HWT/source/registry.ts")" "1"
check "H: both wave-1 bodies are on the goal branch" \
  "[ -f '$HWT/source/audit-event.implementer.ts' ] && [ -f '$HWT/source/auth-org.implementer.ts' ]"
eq "H: the advance commit is in the goal branch's history" \
   "$(git -C "$HWT" log --format=%s | grep -c '^emanate: advance ')" "1"
eq "H: every integration branch is deleted after promote" \
   "$(git -C "$H" branch --list 'emanate/all-*' | wc -l | tr -d ' ')" "0"
left="$(ls "$H/.inspire/worktrees" 2>/dev/null | grep -cv '^emanate-all$')"
eq "H: no phase worktree is left on disk" "$left" "0"

summary
