"""visualizador-orquestrador — read-only CLI that opens the run browser.

    visualizador-orquestrador                 # list every run
    visualizador-orquestrador --session <id>  # jump straight to one
"""

import argparse
import subprocess
import sys
import webbrowser

from server import serve

DEFAULT_PORT = 8765


def repo_root():
    proc = subprocess.run(["git", "rev-parse", "--show-toplevel"], text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        sys.exit("visualizador-orquestrador: not inside a git repository")
    return proc.stdout.strip()


def main(argv=None):
    parser = argparse.ArgumentParser(prog="visualizador-orquestrador")
    parser.add_argument("--session", help="run id to open directly")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--repo", help="repo root (default: detected from cwd)")
    parser.add_argument("--no-browser", action="store_true",
                        help="print the URL instead of opening it")
    args = parser.parse_args(argv)

    repo = args.repo or repo_root()
    url = "http://127.0.0.1:%d/" % args.port
    if args.session:
        url += "?session=%s" % args.session

    print("visualizador-orquestrador: reading %s/.inspire/emanate-runs" % repo)
    print("visualizador-orquestrador: serving %s" % url)
    if not args.no_browser:
        webbrowser.open(url)
    try:
        serve(repo, args.port)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
