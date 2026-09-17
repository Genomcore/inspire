import json
import os
import tempfile
import unittest

from orchestrator.config import load_config, validate_config
from orchestrator.errors import Refusal


def usable():
    return {"schema": "inspire.emanate-config/1", "tests_roots": ["tests"],
            "source_roots": ["source"],
            "suite": [{"command": "npm test -- --json --outputFile={report}",
                       "format": "jest"}]}


class ConfigValidation(unittest.TestCase):

    def test_the_shipped_shape_is_usable(self):
        self.assertEqual(validate_config(usable()), [])

    def test_a_foreign_schema_is_named(self):
        config = usable()
        config["schema"] = "inspire.emanate-config/0"
        self.assertEqual(len(validate_config(config)), 1)
        self.assertIn("schema", validate_config(config)[0])

    def test_the_four_required_keys_are_required(self):
        for key in ("schema", "tests_roots", "source_roots", "suite"):
            config = usable()
            del config[key]
            self.assertTrue(validate_config(config), "%s should be required" % key)

    def test_an_empty_suite_is_no_suite(self):
        config = usable()
        config["suite"] = []
        self.assertTrue(validate_config(config))

    def test_a_suite_entry_needs_a_command(self):
        config = usable()
        config["suite"] = [{"format": "jest"}]
        self.assertTrue(validate_config(config))

    def test_the_optional_keys_are_optional_and_still_typed(self):
        config = usable()
        config["frozen_paths"] = ["package.json"]
        config["checks"] = [{"command": "npx tsc --noEmit", "roles": ["implementer"]}]
        config["narrowed_test"] = "npx jest {file}"
        self.assertEqual(validate_config(config), [])
        config["checks"] = [{"roles": ["implementer"]}]
        self.assertTrue(validate_config(config))

    def test_a_missing_file_refuses_with_the_remedy(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(Refusal) as caught:
                load_config(os.path.join(root, "emanate.json"))
        self.assertIn("inspire.emanate-config/1", str(caught.exception))

    def test_defaults_are_filled_in_on_load(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "emanate.json")
            with open(path, "w") as stream:
                json.dump(usable(), stream)
            config = load_config(path)
        self.assertEqual(config["frozen_paths"], [])
        self.assertEqual(config["scaffold_paths"], [])
        self.assertEqual(config["checks"], [])
        self.assertEqual(config["wall_clock"], 3600)
