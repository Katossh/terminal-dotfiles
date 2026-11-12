#!/usr/bin/env python3
"""Tests for the data-driven failure-message catalog and selector."""
from __future__ import annotations

import copy
import importlib.util
import json
import os
import random
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
ENGINE_PATH = ROOT / "config/terminal/zsh/failure-message-engine.py"
SPEC = importlib.util.spec_from_file_location("failure_message_engine", ENGINE_PATH)
assert SPEC is not None and SPEC.loader is not None
ENGINE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ENGINE)


class FailureMessageEngineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = ENGINE.load_catalog(ROOT, include_user=False)

    def test_repository_defaults_validate(self) -> None:
        self.assertEqual(self.catalog["issues"], [])
        self.assertEqual(len(self.catalog["characters"]), 4)
        self.assertGreaterEqual(len(self.catalog["messages"]), 100)

    def test_schema_does_not_expose_explicit_field(self) -> None:
        schema = json.loads((ROOT / "messages/schema/collection.schema.json").read_text())
        message_properties = schema["properties"]["messages"]["items"]["properties"]
        self.assertNotIn("explicit", message_properties)
        for message in self.catalog["messages"].values():
            self.assertNotIn("explicit", message)

    def test_rarity_is_rolled_before_character_and_message(self) -> None:
        with patch.dict(os.environ, {
            "DOTS_FAILURE_STYLE": "auto",
            "DOTS_FAILURE_MYTHIC_CHANCE": "10000",
            "DOTS_FAILURE_LEGENDARY_CHANCE": "10000",
        }, clear=False):
            result = ENGINE.select_message(
                self.catalog, "generic", "cargo test", "tester", rng=random.Random(7)
            )
        self.assertEqual(result["rarity"], "mythic")
        self.assertEqual(result["style"], "normal")
        self.assertEqual(result["character_id"], "terminal")

    def test_explicit_style_bypasses_automatic_rarity_roll(self) -> None:
        with patch.dict(os.environ, {
            "DOTS_FAILURE_STYLE": "normal",
            "DOTS_FAILURE_MYTHIC_CHANCE": "10000",
            "DOTS_FAILURE_LEGENDARY_CHANCE": "0",
        }, clear=False):
            result = ENGINE.select_message(
                self.catalog, "generic", "cargo test", "tester", rng=random.Random(3)
            )
        self.assertEqual(result["rarity"], "common")
        self.assertEqual(result["style"], "normal")

    def test_ecchi_messages_require_adult_eligible_character(self) -> None:
        with patch.dict(os.environ, {"DOTS_FAILURE_STYLE": "ecchi"}, clear=False):
            result = ENGINE.select_message(
                self.catalog, "generic", "cargo test", "tester", rng=random.Random(8)
            )
        self.assertEqual(result["character_id"], "yoruichi-shihoin")
        self.assertTrue(self.catalog["characters"][result["character_id"]]["adult_content_eligible"])
        self.assertFalse(self.catalog["characters"]["marin-kitagawa"]["adult_content_eligible"])

    def test_character_rarity_bounds_are_inclusive(self) -> None:
        catalog = copy.deepcopy(self.catalog)
        catalog["characters"]["marin-kitagawa"]["min_rarity"] = "rare"
        with patch.dict(os.environ, {"DOTS_FAILURE_STYLE": "anime"}, clear=False):
            for seed in range(30):
                result = ENGINE.select_message(
                    catalog, "generic", "cargo test", "tester", rng=random.Random(seed)
                )
                self.assertNotEqual(result["character_id"], "marin-kitagawa")

    def test_severity_tracks_repeat_streak(self) -> None:
        with patch.dict(os.environ, {"DOTS_FAILURE_STYLE": "normal"}, clear=False):
            repeat = ENGINE.select_message(
                self.catalog, "generic", "cargo test", "tester", streak=2, rng=random.Random(2)
            )
            severe = ENGINE.select_message(
                self.catalog, "generic", "cargo test", "tester", streak=3, rng=random.Random(2)
            )
        self.assertTrue(repeat["message_id"].startswith("generic-repeat-"))
        self.assertTrue(severe["message_id"].startswith("generic-severe-"))

    def test_custom_collection_overrides_message_id(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config_home = Path(temporary)
            collection_dir = config_home / "dots/messages/collections"
            collection_dir.mkdir(parents=True)
            custom = {
                "schema_version": 1,
                "id": "personal-overrides",
                "messages": [{
                    "id": "generic-base-1",
                    "character_id": "terminal",
                    "category": "generic",
                    "style": "normal",
                    "rarity": "common",
                    "severity": "base",
                    "text": "A private replacement for {command}.",
                }],
            }
            (collection_dir / "personal.json").write_text(json.dumps(custom), encoding="utf-8")
            catalog = ENGINE.load_catalog(ROOT, config_home=config_home, include_user=True)
        self.assertEqual(catalog["messages"]["generic-base-1"]["text"], "A private replacement for {command}.")
        self.assertEqual(catalog["issues"], [])

    def test_personal_data_cannot_weaken_builtin_character_eligibility(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config_home = Path(temporary)
            character_dir = config_home / "dots/messages/characters"
            character_dir.mkdir(parents=True)
            altered = dict(self.catalog["characters"]["marin-kitagawa"])
            altered["adult_content_eligible"] = True
            (character_dir / "marin.json").write_text(json.dumps(altered), encoding="utf-8")
            catalog = ENGINE.load_catalog(ROOT, config_home=config_home, include_user=True)
        self.assertFalse(catalog["characters"]["marin-kitagawa"]["adult_content_eligible"])
        self.assertTrue(any("duplicate character" in issue for issue in catalog["issues"]))

    def test_template_values_are_literal_and_control_characters_are_sanitised(self) -> None:
        with patch.dict(os.environ, {"DOTS_FAILURE_STYLE": "normal"}, clear=False):
            result = ENGINE.select_message(
                self.catalog, "generic", 'echo "$(touch /tmp/not-run)";\n', "tester",
                rng=random.Random(1),
            )
        self.assertIn('$(touch /tmp/not-run)"; ', result["text"])
        self.assertNotIn("\n", result["text"])

    def test_unknown_fields_are_rejected(self) -> None:
        message = copy.deepcopy(next(iter(self.catalog["messages"].values())))
        message["explicit"] = True
        with self.assertRaises(ValueError):
            ENGINE._validate_message(message)


if __name__ == "__main__":
    unittest.main(verbosity=2)
