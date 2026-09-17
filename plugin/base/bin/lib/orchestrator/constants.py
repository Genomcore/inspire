CONFIG_SCHEMA = "inspire.emanate-config/1"
STATE_SCHEMA = "inspire.emanate-state/1"

ROLES = ("contracter", "tester", "implementer")
PERSONA_SHELLS = dict((role, "inspire-%s.md" % role) for role in ROLES)
REQUIRED_OVERSEERS = ("inspire-security-overseer.md", "inspire-quality-overseer.md")
ARBITER_SHELL = "inspire-arbiter.md"
WRITING_TOOLS = ("Bash", "Write", "Edit", "NotebookEdit", "Agent")
MIN_CLAUDE_VERSION = (2, 1, 259)

EXIT_OK = 0
EXIT_REFUSED = 3
EXIT_INTERNAL = 4

TESTER_GATE_CLASSES = ("GV-01", "GV-02", "GV-04")

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

WORKTREES_DIR = ".inspire/worktrees"
RUNS_DIR = ".inspire/emanate-runs"
CONFIG_PATH = ".inspire/emanate.json"
LOG_PATH = ".inspire/last-emanation.log"
LEDGER_PATH = RUNS_DIR + "/ledger.jsonl"
