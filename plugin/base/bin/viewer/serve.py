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
    result.add_argument("--port", default=4319, type=int, help="port; 0 chooses a free port")
    result.add_argument("--open", action="store_true", help="open the viewer in the default browser")
    result.add_argument("--check", action="store_true", help="validate the source and exit")
    return result


def handler_for(source: Path):
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
    except (OSError, ValueError) as error:
        print(f"emanate-plan-viewer: {error}", file=sys.stderr)
        return 2
    if args.check:
        print(f"valid {SCHEMA}: {args.plan}")
        return 0
    if not 0 <= args.port <= 65535:
        print("emanate-plan-viewer: --port must be between 0 and 65535", file=sys.stderr)
        return 2

    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), handler_for(args.plan))
    except OSError as error:
        print(f"emanate-plan-viewer: cannot listen on 127.0.0.1:{args.port}: {error}", file=sys.stderr)
        return 3
    host, port = server.server_address[:2]
    url = f"http://{host}:{port}/"
    print(f"Emanation plan viewer: {url}", flush=True)
    print(f"Watching: {args.plan}", flush=True)
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
