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

Exit codes: 0 the run ended and the report was written, whatever the outcome ·
2 usage · 3 refused at t=0, nothing spawned · 4 internal, a tool answered outside
its documented codes.

The mechanics themselves are `lib/orchestrator/`, alongside this file and found
through its own real path — so a symlinked or copied `bin` still resolves them.
"""

import os
import sys

# Before anything under `lib/` is imported: this process runs inside a project's
# own `.inspire/bin`, and may not leave a `__pycache__` in it.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "lib"))

import argparse

from orchestrator.constants import EXIT_INTERNAL, EXIT_OK, EXIT_REFUSED
from orchestrator.errors import Internal, Refusal
from orchestrator.orchestrator import Orchestrator


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
    run.add_argument("--runner", default="claude")
    run.add_argument("--parallel", type=int, default=3)
    run.add_argument("--budget-usd", type=float, dest="budget_usd")
    run.add_argument("--bin")
    run.add_argument("--profiles-root", dest="profiles_root")
    run.add_argument("--agents-root", dest="agents_root")

    resume = sub.add_parser("resume")
    resume.add_argument("run_id")
    resume.add_argument("--runner", default="claude")
    resume.add_argument("--bin")

    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        orchestrator = Orchestrator(args)
        if args.command == "run":
            orchestrator.start()
        else:
            orchestrator.resume()
        if orchestrator.state.data["status"] != "ENDED":
            orchestrator.wave_loop()
        return EXIT_OK
    except Refusal as refusal:
        sys.stderr.write("REFUSED — %s\n" % refusal)
        return EXIT_REFUSED
    except Internal as failure:
        sys.stderr.write("INTERNAL — %s\n" % failure)
        return EXIT_INTERNAL


if __name__ == "__main__":
    sys.exit(main())
