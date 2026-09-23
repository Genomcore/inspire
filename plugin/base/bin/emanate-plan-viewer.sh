#!/usr/bin/env bash
# Serve one emanation-plan JSON document in the local graph viewer.
set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "emanate-plan-viewer.sh: python3 is required" >&2
  exit 127
fi

exec python3 "$HERE/viewer/serve.py" "$@"
