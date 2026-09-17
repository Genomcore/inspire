import os

from ..constants import CONFIG_SCHEMA
from ..errors import Refusal
from ..util import read_json

PROBLEMS = {
    "object": "the config is not a JSON object",
    "schema": "schema is %r, not %r",
    "roots": "%s must be a non-empty list of paths",
    "suite": "suite must carry at least one command",
    "suite_entry": "every suite entry needs a command string",
    "checks_entry": "every checks entry needs a command string",
}

REFUSALS = {
    "missing": ("no emanation config at %s. Write one — schema %r, with tests_roots, "
                "source_roots and at least one suite command — and re-run."),
    "unreadable": "%s is not readable JSON: %s",
    "unusable": "%s is not a usable emanation config: %s. Fix it and re-run.",
}


def validate_config(config):
    if not isinstance(config, dict):
        return [PROBLEMS["object"]]
    problems = []
    if config.get("schema") != CONFIG_SCHEMA:
        problems.append(PROBLEMS["schema"] % (config.get("schema"), CONFIG_SCHEMA))
    for key in ("tests_roots", "source_roots"):
        value = config.get(key)
        if not isinstance(value, list) or not value or \
                not all(isinstance(item, str) for item in value):
            problems.append(PROBLEMS["roots"] % key)
    suite = config.get("suite")
    if not isinstance(suite, list) or not suite:
        problems.append(PROBLEMS["suite"])
    else:
        for entry in suite:
            if not isinstance(entry, dict) or not isinstance(entry.get("command"), str):
                problems.append(PROBLEMS["suite_entry"])
    for entry in config.get("checks") or []:
        if not isinstance(entry, dict) or not isinstance(entry.get("command"), str):
            problems.append(PROBLEMS["checks_entry"])
    return problems


def load_config(path):
    if not os.path.exists(path):
        raise Refusal(REFUSALS["missing"] % (path, CONFIG_SCHEMA))
    try:
        config = read_json(path)
    except ValueError as error:
        raise Refusal(REFUSALS["unreadable"] % (path, error))
    problems = validate_config(config)
    if problems:
        raise Refusal(REFUSALS["unusable"] % (path, "; ".join(problems)))
    config.setdefault("frozen_paths", [])
    config.setdefault("scaffold_paths", [])
    config.setdefault("checks", [])
    config.setdefault("wall_clock", 3600)
    if config.get("max_turns") is not None:
        config["max_turns"] = int(config["max_turns"])
    return config
