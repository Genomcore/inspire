#!/usr/bin/env python3
"""Build local viewer examples from pinned KBs and serve demo mode.

The benchmark's gitlinks select the KB commits. Case working trees, which may
contain benchmark-run edits, are never read or modified. A bundled Genomics
Suite snapshot shows a simulated mid-run state. Prepared plans live in temp.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional


HERE = Path(__file__).resolve().parent
BIN = HERE.parent / "base" / "bin"
sys.path.insert(0, str(BIN / "schemas"))
from emanation_run_state import validate_run_state  # noqa: E402

CASES = {
    "simple": "simple-case",
    "clinical": "clinical-recruitment-portal",
    "cross-centre": "cross-centre-sharing-console",
}
GENOMICS = HERE / "fixtures" / "viewer-examples" / "genomics-suite"
NAMES = (*CASES, "genomics-suite")
LABELS = {
    "simple": "Simple case",
    "clinical": "Clinical recruitment portal",
    "cross-centre": "Cross centre sharing console",
    "genomics-suite": "Genomics Suite · mid run",
}


def default_reference_root() -> Path:
    git_dir = subprocess.run(
        ["git", "-C", str(HERE), "rev-parse", "--path-format=absolute", "--git-common-dir"],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    return Path(git_dir).resolve().parent.parent / "reference-kbs"


def pinned_commit(root: Path, case: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-tree", "HEAD", "--", "cases/" + case],
        check=True, capture_output=True, text=True,
    )
    fields = result.stdout.split()
    if len(fields) < 3 or fields[:2] != ["160000", "commit"]:
        raise ValueError("reference-kbs has no pinned gitlink for " + case)
    return fields[2]


def write_atomic(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=str(path.parent), prefix="." + path.name + ".", delete=False) as file:
        temporary = Path(file.name)
        file.write(payload)
    os.replace(str(temporary), str(path))


def build(root: Path, cache: Path, name: str, force: bool = False) -> dict:
    case = CASES[name]
    pin = pinned_commit(root, case)
    directory = cache / name
    manifest_path = directory / "manifest.json"
    plan_path = directory / "plan.json"
    if not force and plan_path.is_file() and manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text())
        if manifest.get("pin") == pin:
            return manifest

    with tempfile.TemporaryDirectory(prefix="inspire-viewer-" + name + "-") as snapshot:
        archive = subprocess.Popen(
            ["git", "-C", str(root / "cases" / case), "archive", pin, ".claude", "inspire_kb"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        assert archive.stdout is not None
        extraction = subprocess.run(["tar", "-x", "-C", snapshot], stdin=archive.stdout, capture_output=True)
        archive.stdout.close()
        archive_error = archive.stderr.read() if archive.stderr else b""
        if archive.wait() or extraction.returncode:
            raise RuntimeError((archive_error + extraction.stderr).decode("utf-8", "replace"))
        result = subprocess.run(["bash", str(BIN / "emanate-plan.sh")], cwd=snapshot, capture_output=True)
    if result.returncode not in (0, 1, 4):
        raise RuntimeError(result.stderr.decode("utf-8", "replace"))
    plan = json.loads(result.stdout)
    if plan.get("schema") != "inspire.emanation-plan/2":
        raise ValueError("planner did not return an emanation plan")
    manifest = {
        "name": name,
        "label": LABELS[name],
        "case": case,
        "pin": pin,
        "ready": plan.get("ready"),
        "units": sum(len(wave["units"]) for wave in plan.get("waves", [])),
        "waves": len(plan.get("waves", [])),
        "findings": len(plan.get("findings", [])),
        "run_state": False,
    }
    write_atomic(plan_path, result.stdout)
    write_atomic(directory / "report.txt", result.stderr)
    write_atomic(manifest_path, (json.dumps(manifest, indent=2) + "\n").encode())
    return manifest


def build_genomics(cache: Path) -> dict:
    plan_raw = (GENOMICS / "plan.json").read_bytes()
    state_raw = (GENOMICS / "run-state.json").read_bytes()
    plan = json.loads(plan_raw)
    run_state = json.loads(state_raw)
    validate_run_state(run_state, plan, plan_raw)
    digest = hashlib.sha256(plan_raw + state_raw).hexdigest()
    directory = cache / "genomics-suite"
    manifest_path = directory / "manifest.json"
    if manifest_path.is_file() and (directory / "plan.json").is_file() and (directory / "run-state.json").is_file():
        manifest = json.loads(manifest_path.read_text())
        if manifest.get("fixture_sha256") == digest:
            return manifest
    manifest = {
        "name": "genomics-suite",
        "label": LABELS["genomics-suite"],
        "case": "genomics-suite",
        "fixture_sha256": digest,
        "ready": plan.get("ready"),
        "units": sum(len(wave["units"]) for wave in plan.get("waves", [])),
        "waves": len(plan.get("waves", [])),
        "findings": len(plan.get("findings", [])),
        "run_state": True,
    }
    write_atomic(directory / "plan.json", plan_raw)
    write_atomic(directory / "run-state.json", state_raw)
    write_atomic(manifest_path, (json.dumps(manifest, indent=2) + "\n").encode())
    return manifest


def select(root: Path, cache: Path, name: str) -> dict:
    manifest = build_genomics(cache) if name == "genomics-suite" else build(root, cache, name)
    write_atomic(cache / "current-plan.json", (cache / name / "plan.json").read_bytes())
    write_atomic(cache / "current.json", (json.dumps(manifest, indent=2) + "\n").encode())
    return manifest


def prepare(root: Path, cache: Path, force: bool = False) -> list[dict]:
    examples = []
    for name in CASES:
        item = build(root, cache, name, force=force)
        examples.append(item)
        print(f"{name}: {item['units']} units, {item['waves']} waves, ready={item['ready']}", flush=True)
    item = build_genomics(cache)
    examples.append(item)
    print(f"genomics-suite: {item['units']} units, {item['waves']} waves, simulated mid run", flush=True)
    write_atomic(cache / "examples.json", (json.dumps(examples, indent=2) + "\n").encode())
    return examples


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "list", "select", "serve"))
    parser.add_argument("name", nargs="?", choices=NAMES)
    parser.add_argument("--reference-root", type=Path, default=None)
    parser.add_argument("--cache", type=Path, default=Path(tempfile.gettempdir()) / "inspire-viewer-reference-cases")
    parser.add_argument("--port", type=int, default=4319, help="port for serve (default: 4319)")
    parser.add_argument("--force", action="store_true", help="rebuild cached plans during prepare")
    args = parser.parse_args(argv)
    if args.command == "select" and not args.name:
        parser.error("select needs an example name: " + ", ".join(NAMES))
    if args.name and args.command in ("prepare", "list"):
        parser.error(args.command + " takes no example name")
    if args.force and args.command != "prepare":
        parser.error("--force is only valid with prepare")
    root = (args.reference_root or default_reference_root()).expanduser().resolve()
    cache = args.cache.expanduser().resolve()
    if args.command == "list":
        for name in NAMES:
            manifest_path = cache / name / "manifest.json"
            if manifest_path.is_file():
                item = json.loads(manifest_path.read_text())
                source = item.get("pin", "bundled")[:7]
                print(f"{name:14} {item['units']:3} units  {item['waves']} waves  ready={item['ready']}  {source}")
            else:
                print(f"{name:12} not prepared")
        return 0
    if not (root / ".git").exists():
        parser.error("reference-kbs repository not found: " + str(root))
    if args.command == "prepare":
        prepare(root, cache, force=args.force)
        return 0
    if args.command == "serve":
        prepare(root, cache)
        name = args.name or "simple"
        os.execv(sys.executable, [sys.executable, str(BIN / "viewer" / "serve.py"),
                                  str(cache / name / "plan.json"), "--examples-dir", str(cache),
                                  "--port", str(args.port)])
    item = select(root, cache, args.name)
    print(f"Selected {item['name']}: {item['units']} units, {item['waves']} waves, ready={item['ready']}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
