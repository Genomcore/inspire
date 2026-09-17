import contextlib
import glob
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

from orchestrator import graph as graphmod
from orchestrator.orchestrator import Orchestrator

BIN = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FIXTURE = os.path.join(BIN, "test", "fixtures", "emanate-plan", "clean-three-waves", "spec")
AGENTS = os.path.join(os.path.dirname(BIN), "agents")
UNITS = ("audit.event", "auth.org", "auth.user", "auth.user.list")

CONFIG = {"schema": "inspire.emanate-config/1", "tests_roots": ["tests"],
          "source_roots": ["source"],
          "suite": [{"command": "python3 tools/fake-jest.py {report}", "format": "jest"}]}

FAKE_JEST = '''import glob, json, os, re, sys
out = sys.argv[1]
files = []
for f in sorted(glob.glob('tests/*.spec.ts')):
    stem = os.path.basename(f)[:-len('.spec.ts')]
    ok = os.path.exists(os.path.join('source', stem + '.implementer.ts'))
    titles = re.findall(r"""\\bit\\(\\s*['"](.*?)['"]""", open(f).read())
    files.append({'name': os.path.abspath(f), 'assertionResults': [
        {'title': t, 'status': 'passed' if ok else 'failed',
         'failureMessages': [] if ok else ['no body under source/']} for t in titles]})
json.dump({'testResults': files}, open(out, 'w'))
sys.exit(1 if any(a['status'] == 'failed' for f in files
                  for a in f['assertionResults']) else 0)
'''

PERSONAS = {"contracter": {"mode": "stub-source"},
            "tester": {"mode": "tests-from-contract"},
            "implementer": {"mode": "stub-source"}}

ENV = {"SDD_KB_ROOT": "spec/kb", "SDD_SPEC_ROOT": "spec/sdd",
       "GIT_AUTHOR_NAME": "INSPIRE test", "GIT_AUTHOR_EMAIL": "test@inspire.invalid",
       "GIT_COMMITTER_NAME": "INSPIRE test", "GIT_COMMITTER_EMAIL": "test@inspire.invalid",
       "GIT_CONFIG_NOSYSTEM": "1"}


def verdict(*classes, **over):
    rows = [{"class": cls, "target": "t", "message": "m", "remedy": "r"}
            for cls in classes]
    return dict({"verdict": "fail" if classes else "pass", "findings": rows}, **over)


class Topology(unittest.TestCase):
    """The flow, read off the compiled graph rather than the source."""

    def test_the_run_graph_compiles_with_every_stage_of_the_flow(self):
        nodes = set(graphmod.build().get_graph().nodes)
        self.assertLessEqual({"preflight", "plan", "ceiling", "shells", "derive_units",
                              "derive", "baseline", "wave", "unit", "report"}, nodes)

    def test_the_unit_graph_compiles_with_the_whole_boundary(self):
        nodes = set(graphmod.build_unit().get_graph().nodes)
        self.assertLessEqual({"prepare", "contracter", "tester", "implementer",
                              "harvest", "verify", "overseer", "overseers", "gate",
                              "drill", "promote", "arbitrate", "stalled", "rework"},
                             nodes)

    def test_the_gate_edge_routes_all_four_verdicts(self):
        self.assertEqual(graphmod.route_gate({"verdict": verdict()}), "drill")
        self.assertEqual(graphmod.route_gate({"verdict": verdict("GV-00")}), "stalled")
        self.assertEqual(graphmod.route_gate({"verdict": verdict("GV-03")}), "arbitrate")
        self.assertEqual(graphmod.route_gate({"verdict": verdict("GV-05")}), "rework")

    def test_a_rework_edge_comes_back_to_the_persona_the_gate_named(self):
        self.assertEqual(graphmod.route_role({"role": "tester"}), "tester")
        self.assertEqual(graphmod.route_promote({"retry": True, "role": "implementer"}),
                         "implementer")
        self.assertEqual(graphmod.route_persona({"retry": False, "role": "tester"}),
                         "harvest")


def build_repo(root):
    """The fixture project an operator would really have: the plan fixture's spec
    tree as the KB, a suite, the shells, and the two ignore lines t=0 demands."""
    os.makedirs(os.path.join(root, "tools"))
    os.makedirs(os.path.join(root, ".inspire"))
    shutil.copytree(FIXTURE, os.path.join(root, "spec"))
    for role in ("contracter", "tester", "implementer", "arbiter"):
        shutil.copy(os.path.join(AGENTS, "inspire-%s.md" % role),
                    os.path.join(root, "spec", "agents", "inspire-%s.md" % role))
    with open(os.path.join(root, ".inspire", "emanate.json"), "w") as stream:
        json.dump(CONFIG, stream)
    with open(os.path.join(root, "tools", "fake-jest.py"), "w") as stream:
        stream.write(FAKE_JEST)
    with open(os.path.join(root, ".gitignore"), "w") as stream:
        stream.write(".inspire/worktrees\n.inspire/emanate-runs\n")
    for command in (["init", "-q", "-b", "main"], ["add", "-A"],
                    ["commit", "-qm", "the fixture project"]):
        subprocess.run(["git", "-C", root] + command, check=True,
                       stdout=subprocess.DEVNULL, env=dict(os.environ, **ENV))


def run_args(root, script, **over):
    """The `run` arguments an operator would pass, and the script the fake runner
    answers from."""
    fake = os.path.join(root, "..", "fake")
    os.makedirs(fake, exist_ok=True)
    with open(os.path.join(fake, "script.json"), "w") as stream:
        json.dump(script, stream)
    args = dict(goal=None, ceiling=None, scope=[], rework=2, variant=None, reemanate=[],
                runner="fake:" + fake, parallel=2, budget_usd=None, bin=BIN,
                profiles_root="spec/profiles", agents_root="spec/agents")
    args.update(over)
    return args


def drive(root, entry, args):
    """One invocation over that project, from inside it. The process reports its
    own ending on stderr; a `-v` line per case is what the suite reads, so the
    account goes to the buffer here."""
    run = Orchestrator(SimpleNamespace(**args))
    here = os.getcwd()
    os.chdir(root)
    try:
        with contextlib.redirect_stderr(io.StringIO()):
            return run, entry(run)
    finally:
        os.chdir(here)


def emanate(root, script, **over):
    """One `run_graph` over that project, the way `run` would reach it: the run
    and the state the graph ended with."""
    return drive(root, graphmod.run_graph, run_args(root, script, **over))


KILLABLE = """
import json, os, sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
from types import SimpleNamespace
from orchestrator.graph import run_graph
from orchestrator.orchestrator import Orchestrator
os.chdir(sys.argv[2])
run_graph(Orchestrator(SimpleNamespace(**json.loads(sys.argv[3]))))
"""


def emanate_until_killed(root, script, **over):
    args = run_args(root, script, **over)
    return subprocess.run([sys.executable, "-c", KILLABLE, os.path.join(BIN, "lib"),
                           root, json.dumps(args)],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).returncode


@unittest.skipUnless(shutil.which("uv") and shutil.which("git") and shutil.which("bash"),
                     "the process needs uv, git and bash to reach its first spawn")
class EndToEnd(unittest.TestCase):
    """The graph driven by the fake runner over `clean-three-waves`: the same
    three waves, four units and one report the loop has always produced."""

    def setUp(self):
        self.root = os.path.join(tempfile.mkdtemp(), "repo")
        os.makedirs(self.root)
        self.addCleanup(shutil.rmtree, os.path.dirname(self.root), ignore_errors=True)
        patch = mock.patch.dict(os.environ, ENV)
        patch.start()
        self.addCleanup(patch.stop)
        build_repo(self.root)

    def test_three_waves_invoke_to_the_end_and_every_unit_promotes(self):
        run, final = emanate(self.root, {"personas": PERSONAS})
        data = run.state
        self.assertEqual(data["exit"], "goal reached")
        self.assertEqual(sorted(unit for unit, record in data["units"].items()
                                if record["status"] == "promoted"), sorted(UNITS))
        self.assertEqual(data["wave_index"], 3)
        self.assertTrue(os.path.exists(os.path.join(run.run_dir, "checkpoint.sqlite")))

        self.assertEqual(final["run_dir"], run.run_dir)
        self.assertEqual(final["goal_branch"], run.goal_branch)
        self.assertEqual(final["goal_worktree"], run.goal_worktree)
        self.assertEqual(final["waves"], data["waves"])
        self.assertEqual(final["wave_index"], 3)
        self.assertEqual(final["exit_reason"], "goal reached")
        self.assertEqual(final["plan"]["units"], run.plan["units"])
        self.assertEqual(sorted(final["units"]), sorted(UNITS))
        self.assertEqual(final["spawn_count"], data["spawn_count"])
        self.assertEqual(final["spend_usd"], data["spend_usd"])
        self.assertEqual(final["units"]["auth.org"]["rework"],
                         data["units"]["auth.org"]["rework"])

    def test_a_killed_run_resumes_from_its_checkpoint_and_still_reaches_the_goal(self):
        script = {"personas": PERSONAS, "endings": {"auth.user": {"tester": ["kill"]}}}
        self.assertEqual(emanate_until_killed(self.root, script), 70)
        with open(glob.glob(os.path.join(self.root, ".inspire", "emanate-runs", "*",
                                         "state.json"))[0]) as stream:
            killed = json.load(stream)
        self.assertEqual(killed["units"]["auth.user"]["status"], "in-phase")
        self.assertEqual(killed["units"]["auth.user"]["phase"], "tester")

        run, _ = drive(self.root, graphmod.resume_graph,
                       dict(run_id=killed["run_id"], bin=BIN,
                            runner=run_args(self.root, script)["runner"]))
        units = run.state["units"]
        self.assertEqual(run.state["exit"], "goal reached")
        self.assertEqual(sorted(unit for unit, record in units.items()
                                if record["status"] == "promoted"), sorted(UNITS))
        self.assertEqual(units["auth.user"]["infra_retries"]["tester"], 1)
        self.assertEqual(units["auth.user"]["rework"]["tester"], 0)
        self.assertIn("interrupted", [entry["ended_at"]
                                      for entry in units["auth.user"]["timeline"]])
        self.assertEqual([entry["index"] for entry in run.state["wave_log"]],
                         [1, 2, 3])

    def test_the_unit_cuts_at_stalled_once_rework_reaches_its_limit(self):
        reject = {"verdict": "REJECT", "findings": [
            {"severity": "error", "blocking": True, "title": "the contract invents a field",
             "issue": "no such field in the KB", "follow_up": "re-read the contract"}]}
        run, _ = emanate(self.root, {
            "personas": PERSONAS,
            "overseers": {"inspire-quality-overseer": {
                "auth.org": {"contracter": [reject, reject, reject]}}}},
            ceiling=1, rework=2)
        units = run.state["units"]
        self.assertEqual(units["auth.org"]["status"], "stalled")
        self.assertEqual(units["auth.org"]["stall_class"], "rework exhausted")
        self.assertEqual(units["auth.org"]["rework"]["contracter"], 3)
        self.assertEqual(units["auth.org"]["phase"], "contracter")
        self.assertEqual(units["audit.event"]["status"], "promoted")


if __name__ == "__main__":
    unittest.main()
