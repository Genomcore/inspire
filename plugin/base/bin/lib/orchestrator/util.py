"""The small helpers: slugs, subprocesses, atomic JSON, the two parsers."""

import json
import os
import re
import subprocess
import tempfile


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


def parse_version(text):
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", text or "")
    return tuple(int(part) for part in match.groups()) if match else None


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
