"""Read-only HTTP server over `.inspire/emanate-runs/`: two JSON endpoints plus
the static React front end in `web/`. Stdlib only — no build step, no
dependency the rest of this repo doesn't already carry.
"""

import glob
import json
import mimetypes
import os
import re

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RUNS_DIR = ".inspire/emanate-runs"
WEB_DIR = os.path.join(os.path.dirname(__file__), "web")
RUN_ID_RE = re.compile(r"^[0-9]{8}-[0-9]{6}-[0-9a-f]+$")


def list_runs(repo):
    runs = []
    for state_path in glob.glob(os.path.join(repo, RUNS_DIR, "*", "state.json")):
        run_id = os.path.basename(os.path.dirname(state_path))
        if not RUN_ID_RE.match(run_id):
            continue
        try:
            with open(state_path) as stream:
                data = json.load(stream)
        except (OSError, ValueError):
            continue
        runs.append({"run_id": run_id, "status": data.get("status"),
                     "exit": data.get("exit"), "goal_branch": data.get("goal_branch"),
                     "started_at": data.get("started_at"), "ended_at": data.get("ended_at"),
                     "spend_usd": data.get("spend_usd"), "spawn_count": data.get("spawn_count")})
    runs.sort(key=lambda row: row.get("started_at") or "", reverse=True)
    return runs


def load_state(repo, run_id):
    if not RUN_ID_RE.match(run_id):
        return None
    path = os.path.join(repo, RUNS_DIR, run_id, "state.json")
    if not os.path.commonpath([os.path.abspath(path), os.path.abspath(repo)]) == \
            os.path.abspath(repo):
        return None
    try:
        with open(path) as stream:
            return json.load(stream)
    except (OSError, ValueError):
        return None


class Handler(BaseHTTPRequestHandler):
    repo = None

    def log_message(self, fmt, *args):
        pass

    def _json(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _static(self, path):
        rel = path.lstrip("/") or "index.html"
        full = os.path.normpath(os.path.join(WEB_DIR, rel))
        if not full.startswith(os.path.abspath(WEB_DIR)):
            self.send_error(404)
            return
        if not os.path.isfile(full):
            full = os.path.join(WEB_DIR, "index.html")
        content_type = mimetypes.guess_type(full)[0] or "application/octet-stream"
        with open(full, "rb") as stream:
            body = stream.read()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/api/runs":
            self._json(list_runs(self.repo))
            return
        match = re.match(r"^/api/runs/([^/]+)/state$", path)
        if match:
            state = load_state(self.repo, match.group(1))
            if state is None:
                self._json({"error": "no such run"}, status=404)
            else:
                self._json(state)
            return
        self._static(path)


def serve(repo, port):
    Handler.repo = repo
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.serve_forever()


def demo():
    import tempfile

    with tempfile.TemporaryDirectory() as repo:
        run_dir = os.path.join(repo, RUNS_DIR, "20260101-000000-abcd")
        os.makedirs(run_dir)
        with open(os.path.join(run_dir, "state.json"), "w") as stream:
            json.dump({"status": "RUNNING", "started_at": "2026-01-01T00:00:00Z",
                      "goal_branch": "emanate/all", "units": {}}, stream)
        assert list_runs(repo)[0]["run_id"] == "20260101-000000-abcd"
        assert load_state(repo, "20260101-000000-abcd")["status"] == "RUNNING"
        assert load_state(repo, "../../etc/passwd") is None
        assert load_state(repo, "not-a-run-id") is None
    print("ok")


if __name__ == "__main__":
    demo()
