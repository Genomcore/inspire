"""The scripted runner: the whole process driven without a model."""

import os
import sys
import threading

from ...constants import ROLES
from ...state import SpawnResult
from ...util import read_json, write_json_atomic


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
        if spec["mode"] == "tests-from-contract":
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
        # `shared` writes one more file under a name every unit of the wave uses,
        # with content only this unit would write: the promote conflict.
        if attempts.get("shared"):
            path = os.path.join(cwd, self.config["source_roots"][0], attempts["shared"])
            with open(path, "w") as stream:
                stream.write("// registered by %s, attempt %d\n" % (brief["unit_slug"], attempt))

    def _write_tests(self, cwd, brief, attempt, attempts):
        contract = read_json(brief["contract_path"])
        lines = ["// fake tester, attempt %d" % attempt]
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
        payload = {"verdicts": [
            {"test_file": path, "at_fault": "body",
             "finding": {"title": "the test agrees with the contract",
                         "issue": "the assertion follows the derived contract; the body does not.",
                         "follow_up": "fix the body."}}
            for path in brief.get("failing_files") or []]}
        return SpawnResult("exit", structured=payload, cost_usd=self.COST)

    def _drill(self, brief):
        return SpawnResult("exit", structured={"complete": True, "survivors": []},
                           cost_usd=self.COST)
