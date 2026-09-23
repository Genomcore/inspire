#!/usr/bin/env python3
"""A loopback-only, no-cache server for the emanation plan graph viewer."""

from __future__ import annotations

import argparse
import json
import mimetypes
import sys
import webbrowser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional
from urllib.parse import urlsplit


SCHEMA = "inspire.emanation-plan/2"
HERE = Path(__file__).resolve().parent
INDEX = HERE / "index.html"
sys.path.insert(0, str(HERE.parent / "schemas"))
from emanation_run_state import validate_run_state  # noqa: E402 - sibling payload module


def plan_path(value: str) -> Path:
    path = Path(value).expanduser().resolve()
    if not path.is_file():
        raise argparse.ArgumentTypeError(f"not a readable file: {value}")
    return path


def read_plan(path: Path) -> bytes:
    raw = path.read_bytes()
    try:
        document = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid JSON: {error}") from error
    if not isinstance(document, dict) or document.get("schema") != SCHEMA:
        actual = document.get("schema") if isinstance(document, dict) else None
        raise ValueError(f"schema must be {SCHEMA!r}, got {actual!r}")
    return raw


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        description="Serve an inspire.emanation-plan/2 document as a live graph."
    )
    result.add_argument("plan", type=plan_path, help="path to the plan JSON")
    result.add_argument("--run-state", type=lambda value: Path(value).expanduser().resolve(), help="optional mutable run-state JSON")
    result.add_argument("--examples-dir", type=lambda value: Path(value).expanduser().resolve(), help="prepared local demo examples")
    result.add_argument("--port", default=4319, type=int, help="port; 0 chooses a free port")
    result.add_argument("--open", action="store_true", help="open the viewer in the default browser")
    result.add_argument("--check", action="store_true", help="validate the source and exit")
    return result


def read_examples(directory: Path) -> list[dict]:
    manifest = json.loads((directory / "examples.json").read_text())
    if not isinstance(manifest, list) or not manifest:
        raise ValueError("examples.json must contain a nonempty list")
    names = set()
    for item in manifest:
        if not isinstance(item, dict) or not isinstance(item.get("name"), str):
            raise ValueError("each example needs a name")
        name = item["name"]
        if not name or any(character not in "abcdefghijklmnopqrstuvwxyz0123456789-" for character in name) or name in names:
            raise ValueError(f"invalid or duplicate example name: {name!r}")
        names.add(name)
        read_plan(directory / name / "plan.json")
    return manifest


def handler_for(source: Path, run_state: Optional[Path] = None,
                examples_dir: Optional[Path] = None):
    examples = read_examples(examples_dir) if examples_dir is not None else []
    example_names = {item["name"] for item in examples}

    class ViewerHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
            route = urlsplit(self.path).path
            if route in ("/", "/index.html"):
                self.send_file(INDEX, "text/html; charset=utf-8")
                return
            if route == "/plan.json":
                try:
                    payload = read_plan(source)
                except (OSError, ValueError) as error:
                    self.send_json_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
                    return
                self.send_bytes(payload, "application/json; charset=utf-8")
                return
            if examples_dir is not None and route == "/examples.json":
                payload = json.dumps(examples).encode("utf-8")
                self.send_bytes(payload, "application/json; charset=utf-8")
                return
            if examples_dir is not None and route.startswith("/examples/") and route.endswith("/plan.json"):
                name = route[len("/examples/"):-len("/plan.json")]
                if name in example_names:
                    try:
                        payload = read_plan(examples_dir / name / "plan.json")
                    except (OSError, ValueError) as error:
                        self.send_json_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
                        return
                    self.send_bytes(payload, "application/json; charset=utf-8")
                    return
            if route == "/run-state.json":
                if run_state is None or not run_state.is_file():
                    self.send_error(HTTPStatus.NOT_FOUND)
                    return
                try:
                    plan_bytes = read_plan(source)
                    payload = run_state.read_bytes()
                    document = json.loads(payload)
                    validate_run_state(document, json.loads(plan_bytes), plan_bytes)
                except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
                    self.send_json_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
                    return
                self.send_bytes(payload, "application/json; charset=utf-8")
                return
            if route == "/health":
                self.send_bytes(b"ok\n", "text/plain; charset=utf-8")
                return
            self.send_error(HTTPStatus.NOT_FOUND)

        def send_file(self, path: Path, content_type: Optional[str] = None) -> None:
            try:
                payload = path.read_bytes()
            except OSError:
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            self.send_bytes(payload, content_type or mimetypes.guess_type(path.name)[0] or "application/octet-stream")

        def send_bytes(self, payload: bytes, content_type: str) -> None:
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(payload)

        def send_json_error(self, status: HTTPStatus, message: str) -> None:
            payload = json.dumps({"error": message}).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format: str, *args: object) -> None:
            return

    return ViewerHandler


def main(argv: Optional[list[str]] = None) -> int:
    args = parser().parse_args(argv)
    try:
        read_plan(args.plan)
        if args.examples_dir:
            read_examples(args.examples_dir)
    except (OSError, ValueError) as error:
        print(f"emanate-plan-viewer: {error}", file=sys.stderr)
        return 2
    if args.check:
        if args.run_state:
            try:
                payload = args.run_state.read_bytes()
                plan_bytes = read_plan(args.plan)
                validate_run_state(json.loads(payload), json.loads(plan_bytes), plan_bytes)
            except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
                print(f"emanate-plan-viewer: {error}", file=sys.stderr)
                return 2
        print(f"valid {SCHEMA}: {args.plan}")
        return 0
    if not 0 <= args.port <= 65535:
        print("emanate-plan-viewer: --port must be between 0 and 65535", file=sys.stderr)
        return 2

    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), handler_for(args.plan, args.run_state, args.examples_dir))
    except OSError as error:
        print(f"emanate-plan-viewer: cannot listen on 127.0.0.1:{args.port}: {error}", file=sys.stderr)
        return 3
    host, port = server.server_address[:2]
    url = f"http://{host}:{port}/"
    print(f"Emanation plan viewer: {url}", flush=True)
    print(f"Watching: {args.plan}", flush=True)
    if args.run_state:
        print(f"Run state: {args.run_state}", flush=True)
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
