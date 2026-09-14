#!/usr/bin/env python3
"""emanate-orchestrator — the unattended emanation loop, as a process.

The doctrine is `.claude/skills/inspire-emanate/references/run.md` (the schedule,
the phase envelope, the report) and `inspire-code/references/roles/` (the judgment
each spawned agent applies). This file is the mechanics only: t=0's refusals, the
wave loop, the per-unit handoff sequence, arbitration, the drill, promotion, the
report, and the state file a killed run resumes from.

It spawns agents through a runner seam, so the whole process runs without a model:
`--runner fake:DIR` replays a script. Standard library only.

    emanate-orchestrator.py run    [--goal SEL] [--ceiling N] [--scope PATH]...
    emanate-orchestrator.py resume <run-id>
    emanate-orchestrator.py check-citations --contract FILE [--tests-root DIR]...

Exit codes: 0 the run ended and the report was written, whatever the outcome ·
2 usage · 3 refused at t=0, nothing spawned · 4 internal, a tool answered outside
its documented codes.
"""

import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import uuid

CONFIG_SCHEMA = "inspire.emanate-config/1"
STATE_SCHEMA = "inspire.emanate-state/1"
CITATION_SCHEMA = "inspire.citation-check/1"

ROLES = ("contracter", "tester", "implementer")
PERSONA_SHELLS = dict((role, "inspire-%s.md" % role) for role in ROLES)
REQUIRED_OVERSEERS = ("inspire-security-overseer.md", "inspire-quality-overseer.md")
ARBITER_SHELL = "inspire-arbiter.md"
WRITING_TOOLS = ("Bash", "Write", "Edit", "NotebookEdit", "Agent")
MIN_CLAUDE_VERSION = (2, 1, 259)

EXIT_OK = 0
EXIT_REFUSED = 3
EXIT_INTERNAL = 4

# The tester's own grammar (`roles/tester.md` § Citing a claim), shared with
# `lib/gate-citations.sh`: an id, and an optional fingerprint after it.
CLAIM_TOKEN = re.compile(r"@claim\s+(\S+)(?:\s+(sha256:[0-9a-f]+))?")

TESTER_GATE_CLASSES = ("GV-01", "GV-02", "GV-04")

# The promote message's trailer block, in the order an operator scans a log for:
# the run and the unit first. The state file sorts its keys, so the order lives
# here rather than in the dict the run builds.
TRAILER_ORDER = ("Emanate-Run", "Emanate-Unit", "Emanate-Template-Sha",
                 "Emanate-Profiles", "Emanate-Gate", "Emanate-Harness")

OVERSEER_SCHEMA = {
    "type": "object",
    "required": ["verdict", "findings"],
    "properties": {
        "verdict": {"type": "string", "enum": ["APPROVE", "REJECT"]},
        "findings": {"type": "array", "items": {
            "type": "object",
            "properties": {"severity": {"type": "string"}, "title": {"type": "string"},
                           "issue": {"type": "string"}, "follow_up": {"type": "string"},
                           "blocking": {"type": "boolean"}}}},
    },
}

ARBITER_SCHEMA = {
    "type": "object",
    "required": ["verdicts"],
    "properties": {"verdicts": {"type": "array", "items": {
        "type": "object",
        "required": ["test_file", "at_fault"],
        "properties": {"test_file": {"type": "string"},
                       "at_fault": {"type": "string",
                                    "enum": ["tester", "body", "specification"]},
                       "finding": {"type": "object"}}}}},
}

DRILL_SCHEMA = {
    "type": "object",
    "required": ["complete", "survivors"],
    "properties": {"complete": {"type": "boolean"},
                   "survivors": {"type": "array", "items": {
                       "type": "object",
                       "properties": {"file": {"type": "string"}, "line": {"type": "integer"},
                                      "mutation": {"type": "string"},
                                      "missing_test": {"type": "string"}}}}},
}


class Refusal(Exception):
    """t=0 said no. Nothing was spawned, and nothing of the operator's moved."""


class Internal(Exception):
    """A tool answered outside its documented exit codes."""


class Infrastructural(Exception):
    """A phase failed without anyone judging it — a crash, an empty emission, a
    recipe step that would not run. Nobody rejected the persona."""


class Stall(Exception):
    def __init__(self, unit_class, reason, findings=None, next_act=None):
        Exception.__init__(self, reason)
        self.unit_class = unit_class
        self.reason = reason
        self.findings = findings or []
        self.next_act = next_act


# ---------------------------------------------------------------- small helpers

def slugify(text):
    """run.md's slug rule: runs of anything outside a-z0-9 collapse to one hyphen."""
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")


def write_json_atomic(path, data):
    directory = os.path.dirname(path) or "."
    handle, tmp = tempfile.mkstemp(dir=directory, prefix=".tmp-")
    with os.fdopen(handle, "w") as stream:
        json.dump(data, stream, indent=2, sort_keys=True)
        stream.write("\n")
    os.replace(tmp, path)


def read_json(path):
    with open(path) as stream:
        return json.load(stream)


def tail(text, limit=2000):
    text = (text or "").strip()
    return text[-limit:]


def sh(command, cwd, env=None, timeout=None):
    return subprocess.run(["bash", "-lc", command], cwd=cwd, env=env, timeout=timeout,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def finding(source, title, issue, follow_up, severity="error", cls=None):
    """The one finding shape this process hands around, rendered by
    `_references/findings-format.md`'s three slots."""
    record = {"source": source, "severity": severity, "title": title,
              "issue": issue, "follow_up": follow_up}
    if cls:
        record["class"] = cls
    return record


def render_findings(findings):
    if not findings:
        return ""
    out = ["## Findings from the last attempt", ""]
    for item in findings:
        out.append("### %s · %s — %s" % (item.get("severity", "error"),
                                         item.get("source", "unknown"),
                                         item.get("title", "")))
        out.append("")
        out.append("**Issue.** %s" % item.get("issue", ""))
        out.append("")
        if item.get("follow_up"):
            out.append("**Suggested follow-up.** %s" % item["follow_up"])
            out.append("")
    return "\n".join(out)


def render_brief(brief):
    """A brief is pointers and facts. Nothing here says what the role emits — the
    role doc says that, and the derived contract says what this unit needs."""
    lines = ["# %s" % brief.get("heading", "Emanation handoff"), ""]
    for label, key in (("role", "role"), ("role doctrine", "role_doc"),
                       ("unit", "unit_id"), ("kind", "unit_kind"),
                       ("knowledge-base artifact", "unit_path"),
                       ("derived contract", "contract_path"),
                       ("worktree", "worktree"), ("boundary", "boundary"),
                       ("suite results", "results_path"),
                       ("gate verdict", "verdict_path")):
        if brief.get(key):
            lines.append("- **%s** — %s" % (label, brief[key]))
    for label, key in (("resolved profiles", "profiles"), ("tests roots", "tests_roots"),
                       ("owned paths", "owned"), ("changed paths", "changed_paths"),
                       ("failing citations", "failing_files")):
        if brief.get(key):
            lines.append("- **%s** — %s" % (label, ", ".join(brief[key])))
    wire = brief.get("wire_conventions") or {}
    if wire.get("ids"):
        lines.append("- **wire conventions** — %s" % ", ".join(wire["ids"]))
    for row in wire.get("decisions") or []:
        lines.append("  - %s — %s" % (row.get("decision"), row.get("answer")))
    if brief.get("environment"):
        lines.append("- **environment** — `%s`" % brief["environment"])
    for note in brief.get("notes") or []:
        lines.append("- %s" % note)
    lines.append("")
    if brief.get("findings"):
        lines.append(render_findings(brief["findings"]))
    return "\n".join(lines)


# ------------------------------------------------------------------ the config

def validate_config(config):
    """Every problem with a parsed emanation config. Empty means usable."""
    if not isinstance(config, dict):
        return ["the config is not a JSON object"]
    problems = []
    if config.get("schema") != CONFIG_SCHEMA:
        problems.append("schema is %r, not %r" % (config.get("schema"), CONFIG_SCHEMA))
    for key in ("tests_roots", "source_roots"):
        value = config.get(key)
        if not isinstance(value, list) or not value or \
                not all(isinstance(item, str) for item in value):
            problems.append("%s must be a non-empty list of paths" % key)
    suite = config.get("suite")
    if not isinstance(suite, list) or not suite:
        problems.append("suite must carry at least one command")
    else:
        for entry in suite:
            if not isinstance(entry, dict) or not isinstance(entry.get("command"), str):
                problems.append("every suite entry needs a command string")
    for key in ("frozen_paths", "checks"):
        if key in config and not isinstance(config[key], list):
            problems.append("%s must be a list" % key)
    for entry in config.get("checks") or []:
        if not isinstance(entry, dict) or not isinstance(entry.get("command"), str):
            problems.append("every checks entry needs a command string")
    for key in ("declaration_only", "narrowed_test"):
        if key in config and not isinstance(config[key], str):
            problems.append("%s must be a command string" % key)
    return problems


def load_config(path):
    if not os.path.exists(path):
        raise Refusal(
            "no emanation config at %s. Write one — schema %r, with tests_roots, "
            "source_roots and at least one suite command — and re-run." % (path, CONFIG_SCHEMA))
    try:
        config = read_json(path)
    except ValueError as error:
        raise Refusal("%s is not readable JSON: %s" % (path, error))
    problems = validate_config(config)
    if problems:
        raise Refusal("%s is not a usable emanation config: %s. Fix it and re-run."
                      % (path, "; ".join(problems)))
    config.setdefault("frozen_paths", [])
    config.setdefault("checks", [])
    return config


# --------------------------------------------------------------- the citations

def scan_citations(roots, cwd):
    """Every `@claim` token under the tests roots, as {file, line, id, fingerprint}."""
    found = []
    for root in roots:
        base = os.path.join(cwd, root)
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [name for name in dirnames if name != ".git"]
            for name in sorted(filenames):
                path = os.path.join(dirpath, name)
                try:
                    with open(path, encoding="utf-8", errors="replace") as stream:
                        text = stream.read()
                except OSError:
                    continue
                if "@claim" not in text:
                    continue
                for number, line in enumerate(text.splitlines(), 1):
                    for match in CLAIM_TOKEN.finditer(line):
                        found.append({"file": os.path.relpath(path, cwd), "line": number,
                                      "id": match.group(1), "fingerprint": match.group(2)})
    return found


def classify_citations(contract, citations):
    """The four classes of the citation check, over one unit's contract.

    CI-01 a token naming no claim of this unit · CI-02 a citation with no
    fingerprint · CI-03 a fingerprint that does not match the contract's ·
    CI-04 a `test`-oracle claim nothing cites. Coverage reads the id and
    realization reads the fingerprint, so an id-only citation passes the gate and
    leaves the unit unrealized for good — which is why CI-02 is a finding here.
    """
    claims = dict((claim["id"], claim) for claim in contract.get("claims", []))
    prefixes = set(claim_id.split("/", 1)[0] for claim_id in claims)
    unit_id = (contract.get("unit") or {}).get("id")
    if unit_id:
        prefixes.add(unit_id)
    findings = []
    cited = set()
    for citation in citations:
        claim_id = citation["id"]
        where = "%s:%s" % (citation["file"], citation["line"])
        if claim_id not in claims:
            # Prefix-scoped exactly as GV-04 is: a shared tests tree holds every
            # other unit's tokens, and those are not this unit's business.
            if claim_id.split("/", 1)[0] in prefixes:
                findings.append(finding(
                    "citation-check", "CI-01 dangling citation — %s" % where,
                    "`@claim %s` names no claim in this unit's derived contract." % claim_id,
                    "copy the id from the contract verbatim, or drop the token.",
                    cls="CI-01"))
            continue
        cited.add(claim_id)
        expected = claims[claim_id].get("fingerprint")
        if not citation["fingerprint"]:
            findings.append(finding(
                "citation-check", "CI-02 citation with no fingerprint — %s" % where,
                "`@claim %s` carries no fingerprint, so the claim is covered but the "
                "unit is never realized." % claim_id,
                "write the second word exactly as the contract emits it: %s"
                % (expected or "sha256:…"), cls="CI-02"))
        elif expected and citation["fingerprint"] != expected:
            findings.append(finding(
                "citation-check", "CI-03 fingerprint mismatch — %s" % where,
                "`@claim %s` cites %s; the contract emits %s."
                % (claim_id, citation["fingerprint"], expected),
                "copy the contract's fingerprint verbatim.", cls="CI-03"))
    for claim in contract.get("claims", []):
        if claim.get("oracle") == "test" and claim["id"] not in cited:
            findings.append(finding(
                "citation-check", "CI-04 uncited claim — %s" % claim["id"],
                "no test under the tests roots cites this `test`-oracle claim.",
                "write a test for it and cite it with its fingerprint.", cls="CI-04"))
    return findings


# ------------------------------------------------------------- the gate reading

def route_gate_verdict(verdict):
    """What a gate verdict means for the loop: (action, subject).

    `pass` · `stall` on a class no persona can answer · `arbitrate` on GV-03,
    where only the contract can say who is at fault · `rework` for one role.
    GV-01/02/04 are tester-shaped and reach the gate only when the tester's own
    checks missed them, so they route back there rather than to the implementer.
    """
    findings = verdict.get("findings") or []
    classes = [item.get("class") for item in findings]
    if verdict.get("verdict") == "pass":
        return ("pass", None)
    for blocked in ("GV-00", "GV-06"):
        if blocked in classes:
            return ("stall", blocked)
    if "GV-03" in classes:
        return ("arbitrate", None)
    if any(cls in TESTER_GATE_CLASSES for cls in classes):
        return ("rework", "tester")
    return ("rework", "implementer")


def gate_findings(verdict):
    """The gate's own `{class, target, message, remedy}` rows, in this process's shape."""
    return [finding("emanate-gate", "%s — %s" % (row.get("class"), row.get("target")),
                    row.get("message", ""), row.get("remedy", ""), cls=row.get("class"))
            for row in verdict.get("findings") or []]


def gate_digest(verdict):
    summary = verdict.get("summary") or {}
    return "%s %s/%s" % (verdict.get("verdict", "fail"),
                         summary.get("covered", 0), summary.get("claims", 0))


# ------------------------------------------------------------------ the shells

def parse_tools_line(text):
    """An agent shell's `tools:` allowlist, or None when the frontmatter has none."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for line in lines[1:]:
        if line.strip() == "---":
            return None
        match = re.match(r"tools:\s*(.+)$", line)
        if match:
            body = match.group(1).strip().strip("[]")
            return [item.strip() for item in body.split(",") if item.strip()]
    return None


def is_read_only(tools):
    """D3: an overseer writes nothing, and Bash can write."""
    return tools is not None and not any(tool in WRITING_TOOLS for tool in tools)


def parse_version(text):
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", text or "")
    return tuple(int(part) for part in match.groups()) if match else None


# ------------------------------------------------------------------- the state

class State:
    """`inspire.emanate-state/1` — the run's whole record, written atomically after
    every transition, so a killed process can be resumed against it."""

    def __init__(self, path, data):
        self.path = path
        self.data = data
        self.lock = threading.Lock()

    @classmethod
    def load(cls, path):
        return cls(path, read_json(path))

    def save(self):
        with self.lock:
            write_json_atomic(self.path, self.data)

    def unit(self, unit_id):
        return self.data["units"][unit_id]


# ------------------------------------------------------------- the runner seam

class SpawnResult:
    def __init__(self, ending, text="", structured=None, session_id="", cost_usd=0.0):
        self.ending = ending  # exit | exhausted | budget | timeout | crash | ratelimit
        self.text = text
        self.structured = structured
        self.session_id = session_id
        self.cost_usd = cost_usd

    def record(self, brief, schema):
        return {"brief": brief, "schema": schema, "ending": self.ending,
                "structured": self.structured, "text": tail(self.text, 8000),
                "session_id": self.session_id, "cost_usd": self.cost_usd}


# Deny rules for every spawned agent. These match the COMMAND STRING and are a
# speed bump, not a fence: an agent that spells the same call differently walks
# past them. The robust form is a PreToolUse deny hook, which is planned and not
# yet shipped; until it is, the harvest filter (only a phase's owned paths leave
# its worktree) is what actually holds.
DENY_RULES = ["Bash(git push:*)", "Bash(git update-ref:*)", "Bash(git merge:*)",
              "Bash(git branch:*)", "Bash(git worktree:*)",
              "Bash(.inspire/bin/emanate-harvest.sh:*)"]


class ClaudeRunner:
    """One spawn is one fresh headless session. Never `--resume`, never `--bare`:
    a persona that carried context from the last attempt would be reworking from
    memory rather than from the findings it was handed."""

    def __init__(self, contracts_dir, wall_clock, max_turns=None, spawn_budget=None):
        self.contracts_dir = contracts_dir
        self.wall_clock = wall_clock
        self.max_turns = max_turns
        self.spawn_budget = spawn_budget
        self.ratelimit_retries = 0

    def spawn(self, shell_name, shell_tools, cwd, brief, schema):
        command = ["claude", "-p", render_brief(brief),
                   "--agent", shell_name,
                   "--permission-mode", "dontAsk",
                   "--permission-prompts", "none",
                   "--restricted",
                   "--output-format", "json",
                   "--session-id", str(uuid.uuid4()),
                   "--add-dir", self.contracts_dir]
        if shell_tools:
            joined = ",".join(shell_tools)
            command += ["--tools", joined, "--allowedTools", joined]
        if self.max_turns:
            command += ["--max-turns", str(self.max_turns)]
        if self.spawn_budget:
            command += ["--max-budget-usd", str(self.spawn_budget)]
        if schema:
            command += ["--json-schema", json.dumps(schema)]
        command += ["--disallowedTools"] + DENY_RULES
        try:
            proc = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, text=True, timeout=self.wall_clock)
        except subprocess.TimeoutExpired:
            return SpawnResult("timeout", text="wall clock of %ss reached" % self.wall_clock)
        try:
            payload = json.loads(proc.stdout)
        except ValueError:
            return SpawnResult("crash", text=tail(proc.stdout) + "\n" + tail(proc.stderr))
        text = str(payload.get("result", ""))
        ending = "exit"
        subtype = payload.get("subtype")
        if subtype == "max_turns":
            ending = "exhausted"
        elif subtype == "budget":
            ending = "budget"
        elif payload.get("is_error"):
            if "rate limit" in text.lower():
                ending = "ratelimit"
                self.ratelimit_retries += 1
                time.sleep(min(60, 5 * self.ratelimit_retries))
            else:
                ending = "crash"
        return SpawnResult(ending, text=text, structured=payload.get("structured_output"),
                           session_id=payload.get("session_id", ""),
                           cost_usd=float(payload.get("total_cost_usd") or 0.0))


class FakeRunner:
    """The process driven without a model. `DIR/script.json` says what each spawn
    does and `DIR/.counters.json` persists the sequence positions — so a `kill`,
    which takes the whole process down mid-phase, resumes against the same script
    rather than replaying it from the top."""

    COST = 0.01

    def __init__(self, directory, config):
        self.dir = directory
        self.config = config
        script_path = os.path.join(directory, "script.json")
        self.script = read_json(script_path) if os.path.exists(script_path) else {}
        self.counters_path = os.path.join(directory, ".counters.json")
        self.lock = threading.Lock()

    def _next(self, key):
        with self.lock:
            counters = read_json(self.counters_path) if os.path.exists(self.counters_path) else {}
            position = counters.get(key, 0)
            counters[key] = position + 1
            write_json_atomic(self.counters_path, counters)
            return position

    def spawn(self, shell_name, shell_tools, cwd, brief, schema):
        role = brief.get("role")
        if role in ROLES:
            return self._persona(role, cwd, brief)
        if role == "overseer":
            return self._overseer(shell_name, brief)
        if role == "arbiter":
            return self._arbiter(brief)
        return self._drill(brief)

    def _ending(self, unit_id, role):
        sequence = ((self.script.get("endings") or {}).get(unit_id) or {}).get(role) or []
        position = self._next("endings:%s:%s" % (unit_id, role))
        return sequence[position] if position < len(sequence) else "exit"

    def _persona(self, role, cwd, brief):
        unit_id = brief["unit_id"]
        attempt = self._next("attempt:%s:%s" % (unit_id, role)) + 1
        ending = self._ending(unit_id, role)
        if ending == "kill":
            sys.stderr.write("fake runner: killing the process during %s of %s\n"
                             % (role, unit_id))
            sys.stderr.flush()
            os._exit(70)
        if ending != "exit":
            return SpawnResult(ending, text="fake %s ending at %s" % (ending, role),
                               cost_usd=self.COST)
        spec = (self.script.get("personas") or {}).get(role) or {}
        attempts = (spec.get("attempts") or {}).get(str(attempt)) or {}
        mode = spec.get("mode") or ("tests-from-contract" if role == "tester" else "stub-source")
        if mode == "tests-from-contract":
            self._write_tests(cwd, brief, attempt, attempts)
        else:
            self._write_stub(cwd, brief, role, attempt, attempts)
        return SpawnResult("exit", text="fake %s, attempt %d" % (role, attempt),
                           cost_usd=self.COST)

    def _write_stub(self, cwd, brief, role, attempt, attempts):
        # `skip_body` emits something harvestable that is NOT the body the fixture's
        # runner looks for, so the suite stays red and the gate reaches GV-03.
        suffix = "%s-partial" % role if attempts.get("skip_body") else role
        path = os.path.join(cwd, self.config["source_roots"][0],
                            "%s.%s.ts" % (brief["unit_slug"], suffix))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as stream:
            stream.write("// fake %s, attempt %d\nexport const attempt = %d;\n"
                         % (role, attempt, attempt))

    def _write_tests(self, cwd, brief, attempt, attempts):
        contract = read_json(brief["contract_path"])
        lines = ["// fake tester, attempt %d" % attempt]
        if attempts.get("pass"):
            lines.append("// PASS")
        fingerprint_mode = attempts.get("fingerprint")
        for index, claim in enumerate(contract.get("claims", [])):
            fingerprint = claim.get("fingerprint") or ""
            if fingerprint_mode == "omit":
                fingerprint = ""
            elif fingerprint_mode == "stale" and index == 0:
                fingerprint = "sha256:" + "0" * 64
            lines.append("// @claim %s%s" % (claim["id"],
                                             " " + fingerprint if fingerprint else ""))
            lines.append("it('%s', () => {});" % claim["id"])
        path = os.path.join(cwd, self.config["tests_roots"][0],
                            "%s.spec.ts" % brief["unit_slug"])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as stream:
            stream.write("\n".join(lines) + "\n")

    def _overseer(self, shell_name, brief):
        unit_id = brief["unit_id"]
        phase = brief["boundary"]
        sequence = (((self.script.get("overseers") or {}).get(shell_name) or {})
                    .get(unit_id) or {}).get(phase) or []
        position = self._next("overseer:%s:%s:%s" % (shell_name, unit_id, phase))
        payload = (sequence[position] if position < len(sequence)
                   else {"verdict": "APPROVE", "findings": []})
        return SpawnResult("exit", structured=payload, cost_usd=self.COST)

    def _arbiter(self, brief):
        unit_id = brief["unit_id"]
        payload = (self.script.get("arbiter") or {}).get(unit_id)
        if payload is None:
            payload = {"verdicts": [
                {"test_file": path, "at_fault": "body",
                 "finding": {"title": "the test agrees with the contract",
                             "issue": "the assertion follows the derived contract; the body does not.",
                             "follow_up": "fix the body."}}
                for path in brief.get("failing_files") or []]}
        return SpawnResult("exit", structured=payload, cost_usd=self.COST)

    def _drill(self, brief):
        payload = (self.script.get("drill") or {}).get(brief["unit_id"])
        if payload is None:
            payload = {"complete": True, "survivors": []}
        return SpawnResult("exit", structured=payload, cost_usd=self.COST)


# ------------------------------------------------------------------ the report

WORKTREES_DIR = ".inspire/worktrees"
RUNS_DIR = ".inspire/emanate-runs"
LOG_PATH = ".inspire/last-emanation.log"


class Report:
    """`report-skeleton.md` filled, never composed: an identity block at t=0, one
    block as each wave closes, one closing block at the exit. Each is committed on
    the goal branch as it is written, so the account travels with the work."""

    def __init__(self, path, commit):
        self.path = path
        self.commit = commit
        self.lock = threading.Lock()

    def write_block(self, block, label):
        with self.lock:
            os.makedirs(os.path.dirname(self.path), exist_ok=True)
            with open(self.path, "a") as stream:
                stream.write(block.rstrip() + "\n\n")
            self.commit(label)

    def truncate(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, "w"):
            pass

    def rewrite_status(self, status):
        """`status` is the one line this file corrects in place — the worked example
        of the skeleton's own "the last position wins"."""
        with self.lock:
            with open(self.path) as stream:
                text = stream.read()
            text = text.replace("- **status** — RUNNING", "- **status** — %s" % status, 1)
            with open(self.path, "w") as stream:
                stream.write(text)


# ------------------------------------------------------------ the orchestrator

class Orchestrator:

    def __init__(self, args):
        self.args = args
        self.git_lock = threading.Lock()
        self.spend_lock = threading.Lock()
        self.spend = 0.0
        self.harness = ""
        self.verify_rounds = {}
        self.last_results = {}
        self.last_verdict = {}
        self.baseline_line = "baseline skipped — nothing planned"
        self.truncated = False
        self.plan = {}
        self.plan_units = {}
        self.shells = {}
        self.overseer_shells = []
        self.state = None
        self.report = None

    # ---- git, serialized: every write to a ref, a worktree or a commit ----

    def git(self, arguments, cwd=None, check=True):
        proc = subprocess.run(["git"] + arguments, cwd=cwd or self.repo, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if check and proc.returncode != 0:
            raise Internal("git %s failed: %s" % (" ".join(arguments), tail(proc.stderr, 600)))
        return proc

    def git_write(self, arguments, cwd=None, check=True):
        with self.git_lock:
            return self.git(arguments, cwd=cwd, check=check)

    def commit_log(self, label):
        message = "emanate(log): %s — %s" % (self.run_id, label)
        with self.git_lock:
            # -f: the process chose this path, so a project-wide `*.log` rule is
            # not the operator declining it.
            self.git(["add", "-f", LOG_PATH], cwd=self.goal_worktree)
            self.git(["commit", "-m", message], cwd=self.goal_worktree)

    # ---- paths ----

    def contract_path(self, unit_id):
        return os.path.join(self.run_dir, "contracts", "%s.json" % unit_id)

    def phase_worktree(self, unit_slug, phase):
        return os.path.join(self.repo, WORKTREES_DIR, "emanate-%s-%s-%s-%s"
                            % (self.goal_slug, unit_slug, self.stamp, phase))

    def integration_branch(self, unit_slug):
        return "emanate/%s-%s-%s" % (self.goal_slug, unit_slug, self.stamp)

    def owned_pathspec(self, role):
        if role == "tester":
            return list(self.config["tests_roots"])
        return list(self.config["source_roots"]) + \
            [":(exclude)%s" % root for root in self.config["tests_roots"]]

    # ---------------------------------------------------------------- t = 0

    def start(self):
        """Everything that can refuse, refuses here. Each step gates the next, and
        a refusal leaves nothing spawned."""
        self.repo = repo_root()
        self.check_launch_checkout()

        self.config = load_config(os.path.join(self.repo, self.args.config))
        self.bin = self.args.bin or os.environ.get("INSPIRE_BIN") or \
            os.path.join(self.repo, ".inspire", "bin")
        self.plan_bin = os.path.join(self.bin, "emanate-plan.sh")
        if not os.path.exists(self.plan_bin):
            raise Refusal("no emanate-plan.sh under %s — point --bin (or $INSPIRE_BIN) at "
                          "this project's `.inspire/bin`." % self.bin)

        self.goal_slug = self.compute_goal_slug()
        now = datetime.datetime.utcnow()
        self.stamp = now.strftime("%Y%m%d-%H%M%S")
        self.run_id = "%s-%s" % (self.stamp, uuid.uuid4().hex[:4])
        self.run_dir = os.path.join(self.repo, RUNS_DIR, self.run_id)
        os.makedirs(os.path.join(self.run_dir, "contracts"), exist_ok=True)
        os.makedirs(os.path.join(self.run_dir, "spawns"), exist_ok=True)

        self.runner = self.build_runner()
        self.open_goal_branch()
        self.plan = self.run_plan()
        write_json_atomic(os.path.join(self.run_dir, "plan.json"), self.plan)

        self.report = Report(os.path.join(self.goal_worktree, LOG_PATH), self.commit_log)

        if self.plan.get("realized_all") or not self.plan.get("waves"):
            self.new_state([], {})
            self.write_identity()
            self.finish("goal reached — nothing left to build")
            return

        self.check_ceiling()
        self.read_shells()
        planned, waves = self.select_waves()
        units = self.derive_units(planned, waves)
        self.new_state(waves, units)
        self.baseline()
        self.write_identity()

    def write_identity(self):
        """Step 9, and the first thing this run writes: every step above it can
        still refuse, and a refusal may not empty the last run's account."""
        self.report.truncate()
        self.report.write_block(self.identity_block(), "identity")

    def check_launch_checkout(self):
        status = self.git(["status", "--porcelain"]).stdout.strip()
        if status:
            raise Refusal("the launch checkout is not clean:\n%s\nCommit those paths or "
                          "set them aside, then re-run." % status)
        head = self.git(["symbolic-ref", "--short", "HEAD"], check=False)
        if head.returncode != 0:
            raise Refusal("HEAD is detached. Run from the branch this effort is launched from.")
        self.launch_branch = head.stdout.strip()
        # The trailing slash is what asks the question about the DIRECTORY: neither
        # path exists yet at t=0, and a bare name is tested as a file, which a
        # `dir/` rule never matches.
        uncovered = [path for path in (WORKTREES_DIR, RUNS_DIR)
                     if self.git(["check-ignore", "-q", path + "/"],
                                 check=False).returncode != 0]
        if uncovered:
            raise Refusal(
                "`.gitignore` does not cover %s. Add these lines to `.gitignore` and commit "
                "them:\n%s\nThis process never writes the launch checkout, `.gitignore` "
                "included." % (" and ".join(uncovered),
                               "\n".join("%s/" % path for path in uncovered)))

    def compute_goal_slug(self):
        if self.args.goal:
            slug = slugify(self.args.goal)
        elif self.args.scope:
            slug = "-".join(slugify(os.path.basename(path.rstrip("/")))
                            for path in self.args.scope)
        else:
            slug = "all"
        if self.args.variant:
            slug = "%s-%s" % (slug, slugify(self.args.variant))
        return slug

    def build_runner(self):
        contracts = os.path.join(self.run_dir, "contracts")
        spec = self.args.runner
        if spec == "claude":
            try:
                proc = subprocess.run(["claude", "--version"], stdout=subprocess.PIPE,
                                      stderr=subprocess.PIPE, text=True)
            except OSError:
                raise Refusal("`claude` is not on PATH — this run has nothing to spawn with.")
            version = parse_version(proc.stdout)
            if version is None or version < MIN_CLAUDE_VERSION:
                raise Refusal("claude %s is below the %s this loop needs. Upgrade it and re-run."
                              % (proc.stdout.strip() or "?",
                                 ".".join(str(part) for part in MIN_CLAUDE_VERSION)))
            self.harness = "claude %s" % proc.stdout.strip()
            return ClaudeRunner(contracts, self.args.wall_clock, self.args.max_turns,
                                self.args.spawn_budget_usd)
        if spec.startswith("fake:"):
            directory = spec[len("fake:"):]
            if not os.path.isdir(directory):
                raise Refusal("no fake-runner directory at %s." % directory)
            self.harness = "fake:%s" % directory
            return FakeRunner(directory, self.config)
        raise Refusal("unknown runner %r — use `claude` or `fake:DIR`." % spec)

    def open_goal_branch(self):
        # A goal worktree removed by hand — `.inspire/worktrees/` is scratch this
        # process itself tells the operator to ignore — stays registered, and git
        # then refuses to re-attach it. Pruning first is a no-op when nothing is stale.
        self.git_write(["worktree", "prune"])
        self.goal_branch = "emanate/%s" % self.goal_slug
        self.goal_worktree = os.path.join(self.repo, WORKTREES_DIR, "emanate-%s" % self.goal_slug)
        exists = self.git(["rev-parse", "--verify", "--quiet", "refs/heads/" + self.goal_branch],
                          check=False).returncode == 0
        if not exists:
            self.git_write(["worktree", "add", "-b", self.goal_branch, self.goal_worktree,
                            self.launch_branch])
            self.cut_here = True
            return
        self.cut_here = False
        if not os.path.exists(self.goal_worktree):
            self.git_write(["worktree", "add", self.goal_worktree, self.goal_branch])
        merge = self.git_write(["merge", "--no-edit", self.launch_branch],
                               cwd=self.goal_worktree, check=False)
        if merge.returncode != 0:
            conflicts = self.git(["diff", "--name-only", "--diff-filter=U"],
                                 cwd=self.goal_worktree, check=False).stdout.split()
            self.git_write(["merge", "--abort"], cwd=self.goal_worktree, check=False)
            raise Refusal("merging %s into %s conflicts on: %s. Resolve it by hand in %s, "
                          "then re-run — a conflict resolution is a judgment nobody is "
                          "present to make."
                          % (self.launch_branch, self.goal_branch,
                             ", ".join(conflicts) or "unknown paths", self.goal_worktree))

    def plan_command(self):
        command = [self.plan_bin]
        for path in self.args.scope:
            command += ["--scope", path]
        if self.args.goal:
            command += ["--goal", self.args.goal]
        if self.args.ceiling:
            command += ["--ceiling", str(self.args.ceiling)]
        for selector in self.args.reemanate:
            command += ["--reemanate", selector]
        if self.args.profiles_root:
            command += ["--profiles-root", self.args.profiles_root]
        if self.args.agents_root:
            command += ["--agents-root", self.args.agents_root]
        for root in self.config["tests_roots"]:
            if os.path.isdir(os.path.join(self.goal_worktree, root)):
                command += ["--tests-root", root]
        return command

    def run_plan(self):
        proc = subprocess.run(self.plan_command(), cwd=self.goal_worktree, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode == 0:
            return json.loads(proc.stdout)
        if proc.returncode == 1:
            plan = json.loads(proc.stdout)
            rows = ["  %s · %s · %s · %s" % (item.get("code"),
                                             item.get("unit") or item.get("target") or "—",
                                             item.get("message"), item.get("remedy"))
                    for item in plan.get("findings", []) if item.get("severity") == "error"]
            raise Refusal("the plan is not ready:\n%s" % "\n".join(rows))
        if proc.returncode == 4:
            refused = json.loads(proc.stdout).get("refused", [])
            rows = ["  %s · %s · %s · %s" % (item.get("code"), item.get("target"),
                                             item.get("message"), item.get("remedy"))
                    for item in refused]
            raise Refusal("plan refused:\n%s" % "\n".join(rows))
        raise Refusal("emanate-plan.sh exited %d: %s"
                      % (proc.returncode, tail(proc.stderr, 800)))

    def check_ceiling(self):
        goal = self.plan.get("goal")
        if goal and self.args.ceiling and self.args.ceiling < goal.get("floor", 0):
            raise Refusal("--ceiling %d is below the floor %d to `%s`: this run provably "
                          "cannot reach its goal. Raise the ceiling, or narrow the goal."
                          % (self.args.ceiling, goal["floor"], goal.get("selector")))

    def read_shells(self):
        root = os.path.join(self.goal_worktree,
                            self.args.agents_root or os.path.join(".claude", "agents"))
        if not os.path.isdir(root):
            raise Refusal("no agent shells at %s — there is nothing to spawn." % root)
        names = sorted(name for name in os.listdir(root) if name.endswith(".md"))
        missing = [shell for shell in PERSONA_SHELLS.values() if shell not in names]
        if missing:
            raise Refusal("the persona shells %s are missing from %s."
                          % (", ".join(missing), root))
        for shell in REQUIRED_OVERSEERS + (ARBITER_SHELL,):
            if shell not in names:
                raise Refusal("%s is missing from %s — this loop refuses to run without it."
                              % (shell, root))
        for name in names:
            with open(os.path.join(root, name)) as stream:
                tools = parse_tools_line(stream.read())
            self.shells[name] = tools
            read_only_required = name.endswith("-overseer.md") or name == ARBITER_SHELL
            if read_only_required and not is_read_only(tools):
                raise Refusal("%s declares `tools: %s` — an oracle writes nothing, so its "
                              "allowlist may name none of %s."
                              % (name, ", ".join(tools or []) or "(none)",
                                 ", ".join(WRITING_TOOLS)))
        self.overseer_shells = [name for name in names if name.endswith("-overseer.md")]

    def select_waves(self):
        """What this run plans against, and what it may actually execute: the plan's
        waves narrowed to the goal's closure, and that list truncated to the declared
        ceiling. Both are kept — the waves beyond the ceiling are units this run knows
        about and will not reach, which is a roster line rather than an omission."""
        planned = [list(wave) for wave in self.plan["waves"]]
        goal = self.plan.get("goal")
        if goal:
            wanted = set(goal.get("units") or [])
            planned = [[unit for unit in wave if unit in wanted] for wave in planned]
            planned = [wave for wave in planned if wave]
        waves = planned
        if self.args.ceiling and self.args.ceiling < len(planned):
            waves = planned[:self.args.ceiling]
            self.truncated = True
        return planned, waves

    def derive_units(self, planned, waves):
        """One derivation per unit this run will execute, once, in the goal worktree.
        Plan already ran derive over the whole frontier, so a non-zero exit here is a
        refusal rather than a finding: the substrate changed under us. A unit the
        ceiling puts out of reach is recorded and never derived — nothing would read
        its contract."""
        runnable = set(unit for wave in waves for unit in wave)
        units = {}
        for entry in self.plan["units"]:
            if not any(entry["id"] in wave for wave in planned):
                continue
            self.plan_units[entry["id"]] = entry
            units[entry["id"]] = self.blank_unit(entry, planned)
            if entry["id"] not in runnable:
                units[entry["id"]]["status"] = "blocked"
                units[entry["id"]]["reason"] = ("beyond the declared ceiling of %d wave(s)"
                                                % self.args.ceiling)
                continue
            proc = subprocess.run([os.path.join(self.bin, "emanate-derive.sh"), entry["kind"],
                                   "--file", entry["path"]],
                                  cwd=self.goal_worktree, text=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if proc.returncode != 0:
                raise Refusal("emanate-derive.sh exited %d on %s: %s"
                              % (proc.returncode, entry["id"], tail(proc.stderr, 600)))
            with open(self.contract_path(entry["id"]), "w") as stream:
                stream.write(proc.stdout)
        return units

    def blank_unit(self, entry, waves):
        wave_index = next(index for index, wave in enumerate(waves) if entry["id"] in wave)
        return {"id": entry["id"], "kind": entry["kind"], "path": entry["path"],
                "slug": slugify(entry["id"]), "wave": wave_index + 1,
                "status": "pending", "phase": None, "done": [],
                "integration_branch": None, "verify_worktree": None,
                "rework": dict((role, 0) for role in ROLES),
                "infra_retries": dict((role, 0) for role in ROLES),
                "dropped": [], "verify_findings": [], "gate_digest": None,
                "drill": None, "trailers": {}, "stall_class": None, "reason": None,
                "next_act": None, "findings": [], "graded_on": "derived claims"}

    def new_state(self, waves, units):
        path = os.path.join(self.run_dir, "state.json")
        self.state = State(path, {
            "schema": STATE_SCHEMA, "run_id": self.run_id, "stamp": self.stamp,
            "launch_branch": self.launch_branch, "goal_branch": self.goal_branch,
            "goal_worktree": self.goal_worktree, "cut_here": self.cut_here,
            "run_dir": self.run_dir, "config": self.config, "bin": self.bin,
            "args": {"goal": self.args.goal, "ceiling": self.args.ceiling,
                     "scope": self.args.scope, "reemanate": self.args.reemanate,
                     "rework": self.args.rework, "variant": self.args.variant,
                     "parallel": self.args.parallel, "budget_usd": self.args.budget_usd,
                     "profiles_root": self.args.profiles_root,
                     "agents_root": self.args.agents_root},
            "waves": waves, "wave_index": 0, "spend_usd": 0.0, "spawn_count": 0,
            "truncated": self.truncated, "harness": self.harness,
            "shells": self.shells, "plan_units": self.plan_units,
            "status": "RUNNING", "exit": None, "units": units})
        self.state.save()

    def baseline(self):
        """A red baseline in realized territory refuses: GV-05 cannot tell a
        pre-existing failure from one this run caused."""
        roots = [root for root in self.config["tests_roots"]
                 if self.tree_holds_files(os.path.join(self.goal_worktree, root))]
        if not roots:
            self.baseline_line = "baseline skipped — no tests under the tests roots"
            return
        worktree = self.phase_worktree("baseline", "baseline")
        self.git_write(["worktree", "add", "--detach", worktree, self.goal_branch])
        try:
            try:
                self.run_recipe(worktree)
                results, _ = self.run_suite(worktree, os.path.join(self.run_dir, "baseline"))
            except Infrastructural as failure:
                raise Refusal("the baseline could not be established: %s" % failure)
            failed = sorted(set(entry["file"] for entry in results["tests"]
                                if entry["status"] == "failed"))
            if failed:
                raise Refusal("the baseline suite is red in realized territory: %s. Emanating "
                              "onto a red suite makes every later verdict unreadable."
                              % ", ".join(failed))
            self.baseline_line = "baseline green in a recipe-provisioned worktree"
        finally:
            self.discard(worktree)

    def tree_holds_files(self, path):
        for _, _, filenames in os.walk(path):
            if filenames:
                return True
        return False

    # --------------------------------------------------------- the substrate

    def run_suite(self, cwd, out_dir):
        """The whole suite, then `emanate-results.sh` over what it wrote. A suite
        command is tolerated non-zero — a red suite is exactly the case the gate
        needs — but one that leaves no report has not run at all."""
        os.makedirs(out_dir, exist_ok=True)
        reports = []
        dialect = "jest"
        for index, entry in enumerate(self.config["suite"]):
            report = os.path.join(out_dir, "report-%d.json" % index)
            if os.path.exists(report):
                os.remove(report)
            proc = sh(entry["command"].replace("{report}", report), cwd=cwd)
            if not os.path.exists(report):
                raise Infrastructural("the suite command `%s` left no report at %s: %s"
                                      % (entry["command"], report, tail(proc.stderr, 800)))
            reports.append(report)
            if entry.get("format"):
                dialect = entry["format"]
        command = [os.path.join(self.bin, "emanate-results.sh")]
        for report in reports:
            command += ["--from", report]
        command += ["--format", dialect, "--root", cwd]
        proc = subprocess.run(command, cwd=cwd, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode != 0:
            raise Infrastructural("emanate-results.sh exited %d: %s"
                                  % (proc.returncode, tail(proc.stderr, 800)))
        results_path = os.path.join(out_dir, "results.json")
        with open(results_path, "w") as stream:
            stream.write(proc.stdout)
        return json.loads(proc.stdout), results_path

    def verify_suite(self, ustate, cwd, out_dir):
        try:
            results, results_path = self.run_suite(cwd, out_dir)
        except Infrastructural as failure:
            raise Stall("infrastructural", "verify could not run the suite: %s" % failure)
        self.last_results[ustate["id"]] = results_path
        return results, results_path

    def next_verify_dir(self, ustate):
        round_number = self.verify_rounds.get(ustate["id"], 0) + 1
        self.verify_rounds[ustate["id"]] = round_number
        return os.path.join(self.run_dir, "verify", "%s-%d" % (ustate["slug"], round_number))

    def run_recipe(self, worktree):
        for step in self.plan.get("preflight", {}).get("worktree_recipe", []) or []:
            proc = sh(step["command"], cwd=worktree)
            if proc.returncode != 0:
                raise Infrastructural("the recipe's `%s` step failed in %s: %s"
                                      % (step.get("step"), worktree, tail(proc.stderr, 600)))

    def environment_step(self):
        for step in self.plan.get("preflight", {}).get("worktree_recipe", []) or []:
            if step.get("step") == "environment":
                return step.get("command")
        return None

    def tip(self, ustate):
        return self.git(["rev-parse", ustate["integration_branch"]]).stdout.strip()

    def save(self):
        self.state.data["spend_usd"] = self.spend
        self.state.save()

    def discard(self, worktree):
        self.git_write(["worktree", "remove", "--force", worktree], check=False)

    def run_harvest(self, ustate, role, worktree, extra):
        command = [os.path.join(self.bin, "emanate-harvest.sh"), worktree,
                   ustate["integration_branch"], "--label", role] + extra + \
            ["--"] + self.owned_pathspec(role)
        return subprocess.run(command, cwd=self.repo, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    # ------------------------------------------------------------- spawning

    def spawn(self, shell, brief, schema, cwd):
        result = self.runner.spawn(shell[:-3], self.shells.get(shell), cwd, brief, schema)
        with self.spend_lock:
            self.spend += result.cost_usd
            index = self.state.data["spawn_count"] + 1
            self.state.data["spawn_count"] = index
        path = os.path.join(self.run_dir, "spawns", "%s-%s-%03d.json"
                            % (brief.get("unit_slug", "run"), shell[:-3], index))
        write_json_atomic(path, result.record(brief, schema))
        self.save()
        return result

    def persona_brief(self, ustate, role, worktree, findings):
        entry = self.plan_units[ustate["id"]]
        return {"heading": "%s — %s" % (role, ustate["id"]),
                "role": role,
                "role_doc": ".claude/skills/inspire-code/references/roles/%s.md" % role,
                "unit_id": ustate["id"], "unit_kind": ustate["kind"],
                "unit_path": ustate["path"], "unit_slug": ustate["slug"],
                "contract_path": self.contract_path(ustate["id"]),
                "worktree": worktree,
                "profiles": entry.get("profiles") or [],
                "wire_conventions": self.plan.get("wire_conventions") or {},
                "tests_roots": self.config["tests_roots"],
                "owned": self.owned_pathspec(role),
                "environment": self.environment_step(),
                "findings": findings}

    # ------------------------------------------------------------ the waves

    def execute(self):
        self.wave_loop()
        return EXIT_OK

    def wave_loop(self):
        waves = self.state.data["waves"]
        spend_exhausted = False
        while self.state.data["wave_index"] < len(waves):
            index = self.state.data["wave_index"]
            wave = waves[index]
            runnable = []
            for unit_id in wave:
                ustate = self.state.unit(unit_id)
                if ustate["status"] in ("promoted", "stalled", "blocked"):
                    continue
                blocker = self.blocked_by(unit_id)
                if blocker:
                    self.mark_blocked(ustate, "downstream of %s, which is %s"
                                      % (blocker[0], blocker[1]))
                    continue
                runnable.append(unit_id)
            if self.args.budget_usd and self.spend >= self.args.budget_usd:
                spend_exhausted = True
                for unit_id in runnable:
                    self.mark_blocked(self.state.unit(unit_id), "spend ceiling reached")
                runnable = []
            if runnable:
                workers = min(self.args.parallel, len(runnable))
                with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
                    for future in [pool.submit(self.run_unit, unit_id) for unit_id in runnable]:
                        future.result()
            self.state.data["wave_index"] = index + 1
            self.save()
            self.report.write_block(self.wave_block(index + 1, wave), "wave %d" % (index + 1))
            if spend_exhausted:
                for later in waves[index + 1:]:
                    for unit_id in later:
                        ustate = self.state.unit(unit_id)
                        if ustate["status"] == "pending":
                            self.mark_blocked(ustate, "spend ceiling reached")
                break
        self.finish(self.exit_reason(spend_exhausted))

    def blocked_by(self, unit_id):
        for edge in self.plan_units[unit_id].get("requires") or []:
            other = self.state.data["units"].get(edge.get("id"))
            if other and other["status"] in ("stalled", "blocked"):
                return (edge["id"], other["status"])
        return None

    def mark_blocked(self, ustate, reason):
        ustate["status"] = "blocked"
        ustate["reason"] = reason
        self.save()

    def exit_reason(self, spend_exhausted):
        units = list(self.state.data["units"].values())
        stalled = [unit for unit in units if unit["status"] == "stalled"]
        blocked = [unit for unit in units if unit["status"] == "blocked"]
        if spend_exhausted:
            return "exhausted — spend ceiling %s USD reached" % self.args.budget_usd
        cascade = [unit for unit in blocked
                   if (unit.get("reason") or "").startswith("downstream of")]
        if stalled and cascade:
            return "stall cascade"
        if stalled:
            return "goal not reached — stalled units"
        if self.truncated:
            return "exhausted — ceiling %d reached" % self.args.ceiling
        return "goal reached"

    # ------------------------------------------------------------- one unit

    def run_unit(self, unit_id):
        ustate = self.state.unit(unit_id)
        try:
            self.open_unit(ustate)
            self.drive_unit(ustate)
        except Stall as stall:
            self.record_stall(ustate, stall)
        except Infrastructural as failure:
            self.record_stall(ustate, Stall("infrastructural", str(failure)))

    def open_unit(self, ustate):
        ustate["status"] = "in-phase"
        branch = ustate["integration_branch"] or self.integration_branch(ustate["slug"])
        ustate["integration_branch"] = branch
        if self.git(["rev-parse", "--verify", "--quiet", "refs/heads/" + branch],
                    check=False).returncode != 0:
            self.git_write(["branch", branch, self.goal_branch])
        # Recorded only once the recipe has run in it: a tree killed mid-provision
        # is cut again on a resume rather than reused half-built.
        if not ustate["verify_worktree"]:
            worktree = self.phase_worktree(ustate["slug"], "verify")
            if os.path.exists(worktree):
                self.discard(worktree)
            self.git_write(["worktree", "add", "--detach", worktree, branch])
            self.run_recipe(worktree)
            ustate["verify_worktree"] = worktree
        self.save()

    def drive_unit(self, ustate):
        for role in ROLES:
            if role in ustate["done"]:
                continue
            ustate["phase"] = role
            self.save()
            self.handoff(ustate, role, [])
            ustate["done"].append(role)
            ustate["phase"] = None
            self.save()
        ustate["phase"] = "gate"
        self.save()
        verdict = self.gate_loop(ustate)
        ustate["gate_digest"] = gate_digest(verdict)
        self.save()
        self.drill(ustate)
        self.promote(ustate, verdict)

    def handoff(self, ustate, role, findings):
        """prepare → spawn → A read-only checks → B harvest → C tool checks →
        D overseers, looping on this role's own rejections until the boundary
        clears. A rejection spends a rework attempt; an infrastructural ending
        gets one free retry first, because nobody judged the persona."""
        free_retry_used = False
        while True:
            tip_before = self.tip(ustate)
            try:
                worktree = self.prepare(ustate, role)
            except Infrastructural as failure:
                self.after_infrastructural(ustate, role, str(failure), free_retry_used, findings)
                free_retry_used = True
                continue
            try:
                result = self.spawn(PERSONA_SHELLS[role],
                                    self.persona_brief(ustate, role, worktree, findings),
                                    None, worktree)
                if result.ending != "exit":
                    raise Infrastructural("the %s spawn ended in %s" % (role, result.ending))
                rejection = self.checks_a(ustate, role, worktree, tip_before)
                if rejection:
                    self.discard(worktree)
                    findings = rejection
                    self.spend_rework(ustate, role, findings, "the %s boundary" % role)
                    continue
                tip = self.harvest(ustate, role, worktree)
            except Infrastructural as failure:
                self.discard(worktree)
                self.after_infrastructural(ustate, role, str(failure), free_retry_used, findings)
                free_retry_used = True
                continue
            self.repoint_verify(ustate, tip)
            rejection = self.checks_c(ustate, role, tip_before, tip)
            if not rejection:
                rejection = self.overseer_gate(ustate, role, tip_before, tip)
            if rejection:
                findings = rejection
                self.spend_rework(ustate, role, findings, "the %s boundary" % role)
                continue
            return tip

    def after_infrastructural(self, ustate, role, reason, free_retry_used, findings):
        """Nobody judged the persona, so the first one of a handoff is free; every
        later one spends a rework attempt."""
        ustate["infra_retries"][role] += 1
        self.save()
        if free_retry_used:
            self.spend_rework(ustate, role, findings, reason)

    def spend_rework(self, ustate, role, findings, what):
        ustate["rework"][role] += 1
        ustate["findings"] = findings
        self.save()
        if ustate["rework"][role] > self.args.rework:
            raise Stall("rework exhausted",
                        "the %s exhausted its rework budget (%d attempts) at %s"
                        % (role, self.args.rework, what), findings)

    def prepare(self, ustate, role):
        worktree = self.phase_worktree(ustate["slug"], role)
        if os.path.exists(worktree):
            self.discard(worktree)
        self.git_write(["worktree", "add", "--detach", worktree, self.tip(ustate)])
        try:
            self.run_recipe(worktree)
            if role == "tester" and self.config.get("declaration_only"):
                proc = sh(self.config["declaration_only"], cwd=worktree)
                if proc.returncode != 0:
                    raise Infrastructural("the declaration-only recipe failed: %s"
                                          % tail(proc.stderr, 600))
        except Infrastructural:
            self.discard(worktree)
            raise
        return worktree

    def repoint_verify(self, ustate, tip):
        self.git_write(["checkout", "--detach", tip], cwd=ustate["verify_worktree"])
        # The last results describe a tree that no longer exists. The verdict they
        # produced stays: it is why this boundary is being read again.
        self.last_results.pop(ustate["id"], None)

    # ---- A: read-only, in the persona's own worktree, no tool spawn ----

    def checks_a(self, ustate, role, worktree, tip_before):
        if self.tip(ustate) != tip_before:
            return [finding(role, "the persona moved the integration branch",
                            "the integration branch is at %s; it was at %s when this phase "
                            "began." % (self.tip(ustate)[:12], tip_before[:12]),
                            "work inside the worktree only — the branch is the "
                            "orchestrator's to move.")]
        if not self.git(["status", "--porcelain"], cwd=worktree).stdout.strip():
            raise Infrastructural("the %s emitted nothing" % role)
        dropped = self.harvest_plan(ustate, role, worktree)
        if dropped:
            ustate["dropped"] = sorted(set(ustate["dropped"]) | set(dropped))
            self.save()
            return [finding(role, "paths outside the %s's owned set" % role,
                            "these paths would be dropped at harvest: %s" % ", ".join(dropped),
                            "emit inside %s and nowhere else."
                            % ", ".join(self.owned_pathspec(role)))]
        if role == "tester":
            contract = read_json(self.contract_path(ustate["id"]))
            problems = classify_citations(
                contract, scan_citations(self.config["tests_roots"], worktree))
            if problems:
                return problems
        return None

    def harvest_plan(self, ustate, role, worktree):
        proc = self.run_harvest(ustate, role, worktree, ["--mode", "plan"])
        return json.loads(proc.stdout).get("dropped") or []

    # ---- B: harvest ----

    def harvest(self, ustate, role, worktree):
        with self.git_lock:
            proc = self.run_harvest(ustate, role, worktree, ["--discard"])
        if proc.returncode == 0:
            return self.tip(ustate)
        if proc.returncode == 6:
            raise Infrastructural("nothing to harvest from the %s" % role)
        # Every phase worktree is discarded at harvest or at stall: the emission is
        # on the integration branch, which is the autopsy.
        self.discard(worktree)
        if proc.returncode == 7:
            raise Stall("harvest conflict",
                        "the %s's emission does not apply onto %s: %s"
                        % (role, ustate["integration_branch"], tail(proc.stderr, 600)))
        raise Stall("tool error", "emanate-harvest.sh exited %d at the %s handoff: %s"
                    % (proc.returncode, role, tail(proc.stderr, 600)))

    # ---- C: the tool checks, in the verify worktree at the new tip ----

    def checks_c(self, ustate, role, tip_before, tip):
        worktree = ustate["verify_worktree"]
        findings = []
        for entry in self.config["checks"]:
            roles = entry.get("roles")
            if roles and role not in roles:
                continue
            proc = sh(entry["command"], cwd=worktree)
            if proc.returncode != 0:
                findings.append(finding(
                    "check:%s" % entry["command"], "the declared check failed",
                    tail(proc.stdout + "\n" + proc.stderr, 1200),
                    "make `%s` pass." % entry["command"]))
        proc = subprocess.run([os.path.join(self.bin, "escape-hatch-ratchet.sh")],
                              cwd=worktree, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode == 1:
            findings.append(finding(
                "escape-hatch-ratchet", "the escape-hatch count rose",
                tail(proc.stderr, 1200),
                "remove the suppression. The ceiling is raised by hand, in review — "
                "never by the loop."))
        if role == "tester":
            findings += self.tester_checks(ustate)
        if role == "implementer":
            findings += self.frozen_path_findings(tip_before, tip)
        return findings or None

    def tester_checks(self, ustate):
        """The two repo-scoped rules, scoped to this unit and attributed: only an
        error whose subject is this unit halts it, and the rest are reported. Then
        the all-red invariant, which only holds while no body exists."""
        worktree = ustate["verify_worktree"]
        scope = os.path.dirname(ustate["path"]) or "."
        env = dict(os.environ)
        env["SDD_TEST_SCOPE"] = self.config["tests_roots"][0]
        findings = []
        for rule in ("declared-errors-tested.sh", "criteria-have-tests.sh"):
            proc = subprocess.run([os.path.join(self.bin, rule), scope],
                                  cwd=worktree, env=env, text=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            for row in parse_jsonl(proc.stderr):
                if row.get("severity") == "error" and targets_unit(row.get("target"), ustate):
                    findings.append(finding(row.get("rule", rule), row.get("target", ""),
                                            row.get("message", ""),
                                            "the rule's subject is this unit — answer it "
                                            "before the gate."))
                else:
                    ustate["verify_findings"].append(
                        "%s · %s — %s: %s" % (row.get("severity"), row.get("rule"),
                                              row.get("target"), row.get("message")))
        self.save()
        if "implementer" not in ustate["done"]:
            results, _ = self.verify_suite(ustate, worktree, self.next_verify_dir(ustate))
            claims = set(claim["id"] for claim in
                         read_json(self.contract_path(ustate["id"])).get("claims", []))
            citing = set(citation["file"] for citation in
                         scan_citations(self.config["tests_roots"], worktree)
                         if citation["id"] in claims)
            green = sorted(set(entry["file"] for entry in results["tests"]
                               if entry["status"] == "passed" and entry["file"] in citing))
            if green:
                findings.append(finding(
                    "all-red", "vacuity: passes without bodies",
                    "these files cite this unit's claims and pass in a tree with no "
                    "bodies: %s" % ", ".join(green),
                    "a test that passes before the body exists asserts nothing."))
        return findings

    def frozen_path_findings(self, tip_before, tip):
        changed = self.git(["diff", "--name-only", "%s..%s" % (tip_before, tip)]).stdout.split()
        frozen = [path for path in changed if path in self.config["frozen_paths"]]
        if not frozen:
            return []
        return [finding("frozen-paths", "a frozen path was changed",
                        "this phase changed %s, which the project froze."
                        % ", ".join(frozen),
                        "revert those paths — a frozen path is the operator's.")]

    # ---- D: the overseers ----

    def overseer_gate(self, ustate, role, tip_before, tip):
        changed = self.git(["diff", "--name-only", "%s..%s" % (tip_before, tip)]).stdout.split()
        worktree = ustate["verify_worktree"]
        brief = {"heading": "overseer read — %s at the %s boundary" % (ustate["id"], role),
                 "role": "overseer", "boundary": role,
                 "unit_id": ustate["id"], "unit_kind": ustate["kind"],
                 "unit_path": ustate["path"], "unit_slug": ustate["slug"],
                 "contract_path": self.contract_path(ustate["id"]),
                 "worktree": worktree, "changed_paths": changed,
                 "profiles": self.plan_units[ustate["id"]].get("profiles") or [],
                 "notes": ["answer in the structured shape: verdict APPROVE or REJECT, "
                           "plus findings."]}
        for key, path in (("results_path", self.last_results.get(ustate["id"])),
                          ("verdict_path", self.last_verdict.get(ustate["id"]))):
            if path:
                brief[key] = path
        shells = self.overseer_shells
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(shells)) as pool:
            answers = list(pool.map(
                lambda shell: (shell, self.spawn(shell, dict(brief, heading="%s — %s"
                                                             % (shell[:-3], brief["heading"])),
                                                 OVERSEER_SCHEMA, worktree)), shells))
        findings = []
        for shell, result in answers:
            structured = result.structured or {}
            approved = result.ending == "exit" and structured.get("verdict") == "APPROVE"
            rows = structured.get("findings") or []
            if approved:
                for row in rows:
                    ustate["verify_findings"].append(
                        "%s · %s — %s" % (row.get("severity", "info"), shell[:-3],
                                          row.get("title", "")))
                continue
            # A REJECT is carried back as the overseer wrote it — the blocking rows
            # if it marked any, all of them otherwise. Only a spawn that answered
            # nothing is reported as one.
            rejection = [row for row in rows if row.get("blocking", True)] or rows
            if structured.get("verdict") != "REJECT" or not rejection:
                rejection = [{"title": "no answer from the overseer",
                              "issue": "the spawn ended in %s and returned %s."
                                       % (result.ending,
                                          structured.get("verdict") or "no verdict"),
                              "follow_up": "re-emit the boundary; the overseer "
                                           "reads it again."}]
            for row in rejection:
                findings.append(finding(shell[:-3], row.get("title", ""),
                                        row.get("issue", ""), row.get("follow_up", ""),
                                        row.get("severity", "error")))
        self.save()
        return findings or None

    # ---- the gate, and arbitration ----

    def gate_loop(self, ustate):
        """The deterministic half. An overseer's approval never substitutes for it,
        and a red suite here is a question the contract answers, never the loser of
        the argument."""
        while True:
            verdict, results_path, verdict_path = self.run_gate(ustate)
            action, subject = route_gate_verdict(verdict)
            if action == "pass":
                return verdict
            if action == "stall":
                raise Stall("gate", "the gate returned %s: %s"
                            % (subject, "; ".join(row.get("message", "")
                                                  for row in verdict.get("findings") or [])),
                            gate_findings(verdict))
            if action == "arbitrate":
                role, findings = self.arbitrate(ustate, verdict, results_path, verdict_path)
            else:
                role, findings = subject, gate_findings(verdict)
            self.spend_rework(ustate, role, findings, "the gate")
            self.handoff(ustate, role, findings)

    def run_gate(self, ustate):
        worktree = ustate["verify_worktree"]
        out_dir = self.next_verify_dir(ustate)
        _, results_path = self.verify_suite(ustate, worktree, out_dir)
        command = [os.path.join(self.bin, "emanate-gate.sh"),
                   "--contract", self.contract_path(ustate["id"]),
                   "--results", results_path]
        for root in self.config["tests_roots"]:
            if os.path.isdir(os.path.join(worktree, root)):
                command += ["--tests-root", root]
        proc = subprocess.run(command, cwd=worktree, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode not in (0, 1, 4):
            raise Stall("gate defect",
                        "emanate-gate.sh exited %d and reached no verdict: %s"
                        % (proc.returncode, tail(proc.stderr, 600)),
                        next_act="/inspire-lesson note")
        verdict = json.loads(proc.stdout)
        verdict_path = os.path.join(out_dir, "verdict.json")
        write_json_atomic(verdict_path, verdict)
        self.last_verdict[ustate["id"]] = verdict_path
        return verdict, results_path, verdict_path

    def arbitrate(self, ustate, verdict, results_path, verdict_path):
        """A red test against a wrong body. The derived contract is the referee, and
        the answer is never the losing agent's to give."""
        failing = sorted(set(
            citation["file"]
            for claim in verdict.get("claims") or []
            if "GV-03" in (claim.get("findings") or [])
            for citation in claim.get("citations") or []))
        brief = {"heading": "arbitration — %s" % ustate["id"], "role": "arbiter",
                 "unit_id": ustate["id"], "unit_kind": ustate["kind"],
                 "unit_path": ustate["path"], "unit_slug": ustate["slug"],
                 "contract_path": self.contract_path(ustate["id"]),
                 "worktree": ustate["verify_worktree"],
                 "results_path": results_path, "verdict_path": verdict_path,
                 "failing_files": failing,
                 "role_doc": ".claude/skills/inspire-code/references/roles/arbiter.md",
                 "notes": ["answer in the structured shape: one verdict per failing test "
                           "file, each naming the party at fault."]}
        result = self.spawn(ARBITER_SHELL, brief, ARBITER_SCHEMA, ustate["verify_worktree"])
        verdicts = (result.structured or {}).get("verdicts") or []
        findings = []
        for row in verdicts:
            detail = row.get("finding") or {}
            findings.append(finding("inspire-arbiter",
                                    detail.get("title", row.get("test_file", "")),
                                    detail.get("issue", ""), detail.get("follow_up", "")))
        faults = set(row.get("at_fault") for row in verdicts)
        if "specification" in faults:
            raise Stall("specification",
                        "neither the test nor the body can be squared with the contract for "
                        "%s — the specification is wrong or missing." % ustate["id"],
                        findings + gate_findings(verdict),
                        next_act="route the finding to the skill that owns the artifact "
                                 "(`inspire-domain`, `inspire-screens` or `inspire-feature`)")
        role = "tester" if "tester" in faults else "implementer"
        return role, findings + gate_findings(verdict)

    # ---- the drill ----

    def drill(self, ustate):
        """A measurement, never a gate: it runs only on a unit that already passed,
        it reaches nothing, and it can never fail a run."""
        if not self.config.get("narrowed_test"):
            ustate["drill"] = "drill skipped — no narrowed-test command declared"
            self.save()
            return
        ustate["phase"] = "drill"
        self.save()
        worktree = self.phase_worktree(ustate["slug"], "drill")
        if os.path.exists(worktree):
            self.discard(worktree)
        self.git_write(["worktree", "add", "--detach", worktree, self.tip(ustate)])
        try:
            self.run_recipe(worktree)
            brief = {"heading": "mutation drill — %s" % ustate["id"], "role": "drill",
                     "unit_id": ustate["id"], "unit_slug": ustate["slug"],
                     "unit_path": ustate["path"], "worktree": worktree,
                     "contract_path": self.contract_path(ustate["id"]),
                     "role_doc": ".claude/skills/inspire-code/references/tdd.md",
                     "notes": [
                         "run tdd.md step 7's catalogue over this unit's diff "
                         "(`git diff --name-only %s..HEAD`), k = 5 to 10, one mutation at "
                         "a time, reverting between." % self.goal_branch,
                         "the narrowed test command is `%s`, with `{file}` replaced by the "
                         "test file." % self.config["narrowed_test"],
                         "NEVER act on a survivor: report it. This worktree is discarded."]}
            result = self.spawn(PERSONA_SHELLS["implementer"], brief, DRILL_SCHEMA, worktree)
            if result.ending != "exit":
                ustate["drill"] = "drill incomplete — %s" % result.ending
            else:
                payload = result.structured or {}
                survivors = payload.get("survivors") or []
                if not payload.get("complete"):
                    ustate["drill"] = "drill incomplete — the catalogue did not finish"
                elif not survivors:
                    ustate["drill"] = "no survivors"
                else:
                    ustate["drill"] = "; ".join(
                        "%s:%s — %s → %s" % (row.get("file"), row.get("line"),
                                             row.get("mutation"), row.get("missing_test"))
                        for row in survivors)
        except Infrastructural as failure:
            ustate["drill"] = "drill incomplete — %s" % failure
        finally:
            self.discard(worktree)
            ustate["phase"] = None
            self.save()

    # ---- promote ----

    def promote(self, ustate, verdict):
        trailers = {"Emanate-Run": self.run_id, "Emanate-Unit": ustate["id"],
                    "Emanate-Template-Sha": self.template_sha(),
                    "Emanate-Profiles": self.profile_hashes(ustate),
                    "Emanate-Gate": gate_digest(verdict),
                    "Emanate-Harness": self.harness}
        message = "emanate: promote %s\n\n%s\n" % (
            ustate["id"], "\n".join("%s: %s" % (key, trailers[key]) for key in TRAILER_ORDER))
        with self.git_lock:
            merge = self.git(["merge", "--no-ff", "-m", message, ustate["integration_branch"]],
                             cwd=self.goal_worktree, check=False)
            if merge.returncode != 0:
                self.git(["merge", "--abort"], cwd=self.goal_worktree, check=False)
                raise Stall("promote conflict",
                            "%s does not merge into %s: %s"
                            % (ustate["integration_branch"], self.goal_branch,
                               tail(merge.stdout + merge.stderr, 600)))
            self.git(["branch", "-d", ustate["integration_branch"]], cwd=self.goal_worktree)
        self.discard(ustate["verify_worktree"])
        ustate["verify_worktree"] = None
        ustate["trailers"] = trailers
        ustate["status"] = "promoted"
        ustate["phase"] = None
        self.save()

    def template_sha(self):
        path = os.path.join(self.repo, ".inspire.lock")
        if not os.path.exists(path):
            return "none"
        return read_json(path).get("template_sha") or "none"

    def profile_hashes(self, ustate):
        root = os.path.join(self.goal_worktree,
                            self.args.profiles_root or
                            os.path.join(".claude", "skills", "inspire-code", "profiles"))
        pairs = []
        for profile in self.plan_units[ustate["id"]].get("profiles") or []:
            path = os.path.join(root, "%s.md" % profile)
            if not os.path.exists(path):
                continue
            with open(path, "rb") as stream:
                pairs.append("%s=%s" % (profile, hashlib.sha256(stream.read()).hexdigest()[:12]))
        return ",".join(pairs) or "none"

    def record_stall(self, ustate, stall):
        ustate["status"] = "stalled"
        ustate["stall_class"] = stall.unit_class
        ustate["reason"] = stall.reason
        ustate["findings"] = stall.findings or ustate["findings"]
        ustate["next_act"] = stall.next_act
        if ustate["verify_worktree"]:
            self.discard(ustate["verify_worktree"])
            ustate["verify_worktree"] = None
        self.save()

    # ------------------------------------------------------------ the report

    def identity_block(self):
        plan = self.plan
        goal = plan.get("goal") or {}
        warnings = [row for row in plan.get("findings") or []
                    if row.get("severity") == "warning"]
        preflight = plan.get("preflight") or {}
        components = ", ".join(item.get("name", "") for item in
                               preflight.get("components") or []) or "*none declared*"
        lines = ["# Emanation run %s" % self.run_id, "",
                 "- **launch branch** — %s" % self.launch_branch,
                 "- **goal branch** — %s, %s" % (self.goal_branch,
                                                 "cut here" if self.cut_here
                                                 else "advanced from an earlier run"),
                 "- **goal worktree** — %s" % os.path.relpath(self.goal_worktree, self.repo),
                 "- **scope** — %s" % (", ".join(self.args.scope) or "*none*"),
                 "- **goal** — %s" % (self.args.goal or "*none*"),
                 "- **selectors** — %s" % (", ".join(self.args.reemanate) or "*none*"),
                 "- **budget** — floor %s · effective floor %s · declared ceiling %s · "
                 "waves permitted %s"
                 % (plan.get("floor"), goal.get("floor", plan.get("floor")),
                    self.args.ceiling or "*unset*", len(self.state.data["waves"])),
                 "- **preflight** — components: %s, declared, not probed by this process; "
                 "%s" % (components, self.baseline_line),
                 "- **harness** — %s" % self.harness,
                 "- **warnings** — %s"
                 % ("; ".join("%s: %s" % (row.get("code"), row.get("message"))
                              for row in warnings) or "*none*"),
                 "- **status** — RUNNING"]
        return "\n".join(lines)

    def wave_block(self, number, wave):
        lines = ["## Wave %d — closed" % number, ""]
        for unit_id in wave:
            unit = self.state.unit(unit_id)
            lines += self.unit_rows(unit)
        lines += ["### Findings", "", "*none recorded by the process*", "",
                  "- **frontier after this wave** — %d units" % self.frontier()]
        return "\n".join(lines)

    def unit_rows(self, unit):
        status = {"promoted": "delivered"}.get(unit["status"], unit["status"])
        trailers = unit.get("trailers") or {}
        rows = ["### %s — %s" % (unit["id"], status), ""]
        rows.append("- **integration branch** — %s"
                    % (unit["integration_branch"] if unit["status"] != "promoted"
                       else "merged"))
        rows.append("- **gate verdict** — %s" % (unit["gate_digest"] or "*not reached*"))
        rows.append("- **rework cycles** — %s · **infrastructural retries** — %s"
                    % (" · ".join("%s %d" % (role, unit["rework"][role]) for role in ROLES),
                       " · ".join("%s %d" % (role, unit["infra_retries"][role])
                                  for role in ROLES)))
        rows.append("- **harvest dropped** — %s"
                    % (", ".join(unit["dropped"]) or "*nothing dropped*"))
        rows.append("- **drill** — %s" % (unit["drill"] or "*not reached*"))
        rows.append("- **verify, did not halt** — %s"
                    % ("; ".join(unit["verify_findings"]) or "*none*"))
        rows.append("- **promote trailers** — %s"
                    % ("; ".join("%s %s" % (key, trailers[key]) for key in TRAILER_ORDER
                                 if key in trailers) or "*none — not promoted*"))
        if unit["status"] in ("stalled", "blocked"):
            remedy = unit.get("next_act") or "read the integration branch, then re-run"
            rows.append("- **stalled or blocked only** — %s: %s. Next act: %s"
                        % (unit.get("stall_class") or "blocked",
                           unit.get("reason") or "", remedy))
            for item in unit.get("findings") or []:
                rows.append("  - %s · %s — %s" % (item.get("source"), item.get("title"),
                                                  item.get("issue")))
        rows.append("- **graded on** — %s" % unit["graded_on"])
        rows.append("")
        return rows

    def frontier(self):
        return sum(1 for unit in self.state.data["units"].values()
                   if unit["status"] not in ("promoted", "stalled", "blocked"))

    def closing_block(self, exit_reason):
        units = self.state.data["units"]
        delivered = [unit for unit in units.values() if unit["status"] == "promoted"]
        stalled = [unit for unit in units.values() if unit["status"] == "stalled"]
        blocked = [unit for unit in units.values() if unit["status"] == "blocked"]
        goal_relative = os.path.relpath(self.goal_worktree, self.repo)
        lines = ["## Report — %s" % exit_reason, "",
                 "- **budget answer** — waves actually executed %d, against ceiling %s and "
                 "floor %s" % (self.state.data["wave_index"], self.args.ceiling or "*unset*",
                               self.plan.get("floor")),
                 "- **spend** — %.4f USD, a client-side estimate: it is the sum of what each "
                 "spawn reported, not a billing figure" % self.spend,
                 "- **delivered** — %s"
                 % (", ".join("%s (merged)" % unit["id"] for unit in delivered) or "*none*"),
                 "- **stalled** — %s"
                 % ("; ".join("%s — %s, %s" % (unit["id"], unit.get("stall_class"),
                                               unit["integration_branch"])
                              for unit in stalled) or "*none*"),
                 "- **blocked** — %s"
                 % ("; ".join("%s — %s" % (unit["id"], unit.get("reason"))
                              for unit in blocked) or "*none*"),
                 "- **worktrees still on disk** — the goal worktree `%s`" % goal_relative,
                 "- **pre-PR** — the rules verify did not run "
                 "(`profile-gates-installed.sh`, `adr-maturity-matches-features.sh`) and "
                 "`criteria-have-tests.sh`'s 🟡 limitation",
                 "- **where the work is** — the goal branch `%s`, its worktree `%s`; "
                 "`git -C %s log --oneline %s..` shows the effort and "
                 "`git -C %s diff --stat %s` its shape. The launch checkout was never moved "
                 "and never written."
                 % (self.goal_branch, goal_relative, goal_relative, self.launch_branch,
                    goal_relative, self.launch_branch),
                 "- **next act** — open the PR from the goal branch `%s`%s"
                 % (self.goal_branch,
                    "".join("; %s: %s" % (unit["id"],
                                          unit.get("next_act") or
                                          "read %s and answer the findings above"
                                          % unit["integration_branch"])
                            for unit in stalled)),
                 "- **run dir** — %s" % os.path.relpath(self.run_dir, self.repo)]
        return "\n".join(lines)

    def finish(self, exit_reason):
        self.state.data["status"] = "ENDED"
        self.state.data["exit"] = exit_reason
        self.save()
        self.report.rewrite_status(exit_reason)
        self.report.write_block(self.closing_block(exit_reason), "closing")
        sys.stderr.write("emanation %s ended: %s\n" % (self.run_id, exit_reason))

    # ------------------------------------------------------------- resuming

    def resume(self):
        """A killed run is resumed against its own state: the phase that was in
        flight counts as an infrastructural ending — nobody judged it — and a unit
        past its personas re-enters at verify and the gate."""
        self.repo = repo_root()
        self.run_dir = os.path.join(self.repo, RUNS_DIR, self.args.run_id)
        state_path = os.path.join(self.run_dir, "state.json")
        if not os.path.exists(state_path):
            raise Refusal("no run %s under %s." % (self.args.run_id, RUNS_DIR))
        self.state = State.load(state_path)
        data = self.state.data
        if data["status"] == "ENDED":
            raise Refusal("run %s already ended: %s. Start a new run toward the same goal."
                          % (self.args.run_id, data["exit"]))
        self.config = data["config"]
        self.bin = self.args.bin or data["bin"]
        self.run_id = data["run_id"]
        self.stamp = data["stamp"]
        self.launch_branch = data["launch_branch"]
        self.goal_branch = data["goal_branch"]
        self.goal_worktree = data["goal_worktree"]
        self.goal_slug = self.goal_branch.split("/", 1)[1]
        self.cut_here = data["cut_here"]
        self.shells = data["shells"]
        self.overseer_shells = [name for name in sorted(self.shells)
                                if name.endswith("-overseer.md")]
        self.plan_units = data["plan_units"]
        self.plan = read_json(os.path.join(self.run_dir, "plan.json"))
        self.spend = data.get("spend_usd", 0.0)
        self.harness = data["harness"]
        self.truncated = data["truncated"]
        for key, value in data["args"].items():
            if getattr(self.args, key, None) in (None, [], 0):
                setattr(self.args, key, value)
        self.runner = self.build_runner()
        self.report = Report(os.path.join(self.goal_worktree, LOG_PATH), self.commit_log)
        for unit in data["units"].values():
            if unit["status"] == "in-phase":
                phase = unit.get("phase")
                if phase in ROLES:
                    unit["infra_retries"][phase] += 1
                unit["phase"] = None
                unit["status"] = "pending"
        self.save()


# ------------------------------------------------------------------ the rules

def parse_jsonl(text):
    rows = []
    for line in (text or "").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    return rows


def targets_unit(target, unit):
    """A rule's finding is this unit's when it names this unit's path or id — the
    display form with `::` included. Everything else in the scoped path is a
    sibling, and grading it here would halt the wave on its own remaining work."""
    if not target:
        return False
    return target in (unit["path"], unit["id"]) or target.replace("::", ".") == unit["id"]


def repo_root():
    proc = subprocess.run(["git", "rev-parse", "--show-toplevel"], text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise Refusal("not a git repository — this loop's whole audit trail is git.")
    return proc.stdout.strip()


# --------------------------------------------------------------------- the CLI

def check_citations_command(args):
    contract = read_json(args.contract)
    roots = args.tests_root or ["tests"]
    findings = classify_citations(contract, scan_citations(roots, os.getcwd()))
    json.dump({"schema": CITATION_SCHEMA,
               "unit": (contract.get("unit") or {}).get("id"),
               "findings": findings}, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 1 if findings else 0


def parse_args(argv):
    parser = argparse.ArgumentParser(
        prog="emanate-orchestrator.py",
        description="the unattended emanation loop: waves, handoffs, the gate, a report")
    sub = parser.add_subparsers(dest="command")
    sub.required = True

    run = sub.add_parser("run")
    run.add_argument("--goal")
    run.add_argument("--ceiling", type=int)
    run.add_argument("--scope", action="append", default=[])
    run.add_argument("--rework", type=int, default=2)
    run.add_argument("--variant")
    run.add_argument("--reemanate", action="append", default=[])
    run.add_argument("--config", default=os.path.join(".inspire", "emanate.json"))
    run.add_argument("--runner", default="claude")
    run.add_argument("--parallel", type=int, default=3)
    run.add_argument("--max-turns", type=int, dest="max_turns")
    run.add_argument("--spawn-budget-usd", type=float, dest="spawn_budget_usd")
    run.add_argument("--budget-usd", type=float, dest="budget_usd")
    run.add_argument("--wall-clock", type=int, dest="wall_clock", default=3600)
    run.add_argument("--bin")
    run.add_argument("--profiles-root", dest="profiles_root")
    run.add_argument("--agents-root", dest="agents_root")

    resume = sub.add_parser("resume")
    resume.add_argument("run_id")
    resume.add_argument("--runner", default="claude")
    resume.add_argument("--bin")
    resume.add_argument("--wall-clock", type=int, dest="wall_clock", default=3600)
    resume.add_argument("--max-turns", type=int, dest="max_turns")
    resume.add_argument("--spawn-budget-usd", type=float, dest="spawn_budget_usd")

    citations = sub.add_parser("check-citations")
    citations.add_argument("--contract", required=True)
    citations.add_argument("--tests-root", action="append", default=[], dest="tests_root")

    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        if args.command == "check-citations":
            return check_citations_command(args)
        orchestrator = Orchestrator(args)
        if args.command == "run":
            orchestrator.start()
            if orchestrator.state.data["status"] == "ENDED":
                return EXIT_OK
        else:
            orchestrator.resume()
        return orchestrator.execute()
    except Refusal as refusal:
        sys.stderr.write("REFUSED — %s\n" % refusal)
        return EXIT_REFUSED
    except Internal as failure:
        sys.stderr.write("INTERNAL — %s\n" % failure)
        return EXIT_INTERNAL


if __name__ == "__main__":
    sys.exit(main())
