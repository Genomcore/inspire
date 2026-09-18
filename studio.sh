#!/usr/bin/env bash
# Serve the orchestrator's graphs to LangGraph Studio: `bash studio.sh` from anywhere.
# --no-reload: the server rewrites .langgraph_api/ every 10s, and the watcher would
# restart it on each write. Relaunch after editing a graph.
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
if [ ! -x .venv/bin/langgraph ]; then
  uv venv -q .venv
  uv pip install -q -p .venv/bin/python 'langgraph-cli[inmem]' \
    'langgraph-checkpoint-sqlite>=2,<4' 'claude-agent-sdk>=0.2,<1'
fi
exec .venv/bin/langgraph dev --no-reload "$@"
