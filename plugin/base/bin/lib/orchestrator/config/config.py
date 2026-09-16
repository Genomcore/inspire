"""The emanation config: what makes one usable, and how it is loaded."""

import os

from ..constants import CONFIG_SCHEMA
from ..errors import Refusal
from ..util import read_json


def validate_config(config):
    """Every problem with a parsed emanation config. Empty means usable."""
    if not isinstance(config, dict):
        return ["the config is not a JSON object"]
    problems = []
    if config.get("schema") != CONFIG_SCHEMA:
        problems.append("schema is %r, not %r" % (config.get("schema"), CONFIG_SCHEMA))
    for key in ("tests_roots", "source_roots"):
        value = config.get(key)
        if not isinstance(value, list) or not value or \
                not all(isinstance(item, str) for item in value):
            problems.append("%s must be a non-empty list of paths" % key)
    suite = config.get("suite")
    if not isinstance(suite, list) or not suite:
        problems.append("suite must carry at least one command")
    else:
        for entry in suite:
            if not isinstance(entry, dict) or not isinstance(entry.get("command"), str):
                problems.append("every suite entry needs a command string")
    for entry in config.get("checks") or []:
        if not isinstance(entry, dict) or not isinstance(entry.get("command"), str):
            problems.append("every checks entry needs a command string")
    return problems


def load_config(path):
    if not os.path.exists(path):
        raise Refusal(
            "no emanation config at %s. Write one — schema %r, with tests_roots, "
            "source_roots and at least one suite command — and re-run." % (path, CONFIG_SCHEMA))
    try:
        config = read_json(path)
    except ValueError as error:
        raise Refusal("%s is not readable JSON: %s" % (path, error))
    problems = validate_config(config)
    if problems:
        raise Refusal("%s is not a usable emanation config: %s. Fix it and re-run."
                      % (path, "; ".join(problems)))
    config.setdefault("frozen_paths", [])
    config.setdefault("checks", [])
    config.setdefault("wall_clock", 3600)
    if config.get("max_turns") is not None:
        config["max_turns"] = int(config["max_turns"])  # the runner and the report both count on it
    return config
