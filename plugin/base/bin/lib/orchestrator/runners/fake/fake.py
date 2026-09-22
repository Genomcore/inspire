import os
import sys
import threading

from ...constants import ROLES
from ...state import SpawnResult
from ...util import read_json, write_json_atomic

KILL_LINE = "fake runner: killing the process during %s of %s\n"

SPAWN_TEXTS = {
    "ending": "fake %s ending at %s",
    "exit": "fake %s, attempt %d",
}

FILE_BODIES = {
    "stub": "// fake %s, attempt %d\nexport const attempt = %d;\n",
    "shared": "// registered by %s, attempt %d\n",
    "tests-header": "// fake tester, attempt %d",
    "claim": "// @claim %s%s",
    "test-case": "it('%s', () => {});",
    "scaffold": "// scaffold by the tester, attempt %d\n",
}

ARBITER_FINDING = {
    "title": "the test agrees with the contract",
    "issue": "the assertion follows the derived contract; the body does not.",
    "follow_up": "fix the body.",
}


class FakeRunner:

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
            sys.stderr.write(KILL_LINE % (role, unit_id))
            sys.stderr.flush()
            os._exit(70)
        if ending != "exit":
            return SpawnResult(ending, text=SPAWN_TEXTS["ending"] % (ending, role),
                               cost_usd=self.COST)
        spec = (self.script.get("personas") or {}).get(role) or {}
        attempts = (spec.get("attempts") or {}).get(str(attempt)) or {}
        if attempts.get("nothing"):
            pass
        elif spec["mode"] == "tests-from-contract":
            self._write_tests(cwd, brief, attempt, attempts)
        else:
            self._write_stub(cwd, brief, role, attempt, attempts)
        return SpawnResult("exit", text=SPAWN_TEXTS["exit"] % (role, attempt),
                           cost_usd=self.COST)

    def _write_stub(self, cwd, brief, role, attempt, attempts):
        suffix = "%s-partial" % role if attempts.get("skip_body") else role
        path = os.path.join(cwd, self.config["source_roots"][0],
                            "%s.%s.ts" % (brief["unit_slug"], suffix))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as stream:
            stream.write(FILE_BODIES["stub"] % (role, attempt, attempt))
        if attempts.get("shared"):
            path = os.path.join(cwd, self.config["source_roots"][0], attempts["shared"])
            with open(path, "w") as stream:
                stream.write(FILE_BODIES["shared"] % (brief["unit_slug"], attempt))

    def _write_tests(self, cwd, brief, attempt, attempts):
        contract = read_json(brief["contract_path"])
        lines = [FILE_BODIES["tests-header"] % attempt]
        fingerprint_mode = attempts.get("fingerprint")
        for index, claim in enumerate(contract.get("claims", [])):
            fingerprint = claim.get("fingerprint") or ""
            if fingerprint_mode == "omit":
                fingerprint = ""
            elif fingerprint_mode == "stale" and index == 0:
                fingerprint = "sha256:" + "0" * 64
            lines.append(FILE_BODIES["claim"] % (claim["id"],
                                                 " " + fingerprint if fingerprint else ""))
            lines.append(FILE_BODIES["test-case"] % claim["id"])
        path = os.path.join(cwd, self.config["tests_roots"][0],
                            "%s.spec.ts" % brief["unit_slug"])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as stream:
            stream.write("\n".join(lines) + "\n")
        if attempts.get("scaffold"):
            path = os.path.join(cwd, self.config["source_roots"][0], attempts["scaffold"])
            with open(path, "w") as stream:
                stream.write(FILE_BODIES["scaffold"] % attempt)

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
             "finding": dict(ARBITER_FINDING)}
            for path in brief.get("failing_files") or []]}
        return SpawnResult("exit", structured=payload, cost_usd=self.COST)

    def _drill(self, brief):
        return SpawnResult("exit", structured={"complete": True, "survivors": []},
                           cost_usd=self.COST)
