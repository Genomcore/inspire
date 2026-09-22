#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["langgraph>=0.2,<1", "langgraph-checkpoint-sqlite>=2,<4",
#                 "claude-agent-sdk>=0.2,<1"]
# ///
"""emanate-orchestrator — the unattended emanation loop, as a process.

The specification is `lib/orchestrator/README.md` (the refusals, the schedule, the
phase envelope, the report) and `inspire-code/references/roles/` (the judgment
each spawned agent applies). This file is the mechanics only: t=0's refusals, the
waves, the per-unit handoff sequence, arbitration, the drill, promotion, the
report, and the checkpoint a killed run resumes from. The flow over them is
declared once, as a graph, in `lib/orchestrator/graph/`.

It spawns agents through a runner seam, so the whole process runs without a model:
`--runner fake:DIR` replays a script.

The dependencies above are PEP 723 inline metadata: `uv run` reads them and
resolves them into a cached environment, so a project needs no `pyproject`, no
venv to manage and nothing beyond `uv` on PATH.

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

    # `--runner`/`--bin` and the two roots mean the same thing to both subcommands.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--runner", default="claude")
    common.add_argument("--model")
    common.add_argument("--bin")
    common.add_argument("--profiles-root", dest="profiles_root")
    common.add_argument("--agents-root", dest="agents_root")

    run = sub.add_parser("run", parents=[common])
    run.add_argument("--goal")
    run.add_argument("--ceiling", type=int)
    run.add_argument("--scope", action="append", default=[])
    run.add_argument("--rework", type=int, default=2)
    run.add_argument("--variant")
    run.add_argument("--reemanate", action="append", default=[])
    run.add_argument("--parallel", type=int, default=3)
    run.add_argument("--budget-usd", type=float, dest="budget_usd")

    resume = sub.add_parser("resume", parents=[common])
    resume.add_argument("run_id")

    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    # After the parse, so `--help` still answers under a bare interpreter, which
    # has no langgraph — only `uv run` resolves the header above.
    from orchestrator.graph import resume_graph, run_graph
    try:
        # A new run opens its own thread; a resume picks that thread up.
        (run_graph if args.command == "run" else resume_graph)(Orchestrator(args))
        return EXIT_OK
    except Refusal as refusal:
        sys.stderr.write("REFUSED — %s\n" % refusal)
        return EXIT_REFUSED
    except Internal as failure:
        sys.stderr.write("INTERNAL — %s\n" % failure)
        return EXIT_INTERNAL


if __name__ == "__main__":
    sys.exit(main())
