#!/usr/bin/env python3
"""Data-driven selection for terminal failure messages."""
from __future__ import annotations
import argparse
import json
import os
import random
import re
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
RARITIES = ("common", "uncommon", "rare", "epic", "legendary", "mythic")
RARITY_INDEX = {name: index for index, name in enumerate(RARITIES)}
STYLES = ("normal", "anime", "ecchi", "sarcastic", "dramatic", "rainbow")
CATEGORIES = ("any", "not_found", "permission", "missing_path", "git", "nix", "network", "generic")
SEVERITIES = ("base", "repeat", "severe")
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PLACEHOLDER_RE = re.compile(r"{([^{}]+)}")
ALLOWED_PLACEHOLDERS = {"command", "username"}


class CatalogError(Exception):
    """Message data could not be selected safely."""


def _safe_int(value: str | None, default: int, maximum: int) -> int:
    if value is None or not value.isdecimal():
        return default
    return min(int(value, 10), maximum)


def _read_json(path: Path) -> Any:
    if path.stat().st_size > 1_000_000:
        raise ValueError("file exceeds the 1 MB safety limit")
    return json.loads(path.read_text(encoding="utf-8"))


def _json_files(directory: Path, recursive: bool = False) -> list[Path]:
    if not directory.is_dir():
        return []
    iterator = directory.rglob("*.json") if recursive else directory.glob("*.json")
    return sorted(path for path in iterator if path.is_file())


def _validate_character(value: Any) -> None:
    required = {
        "schema_version", "id", "name", "persona",
        "min_rarity", "max_rarity", "adult_content_eligible",
    }
    if not isinstance(value, dict) or set(value) != required:
        raise ValueError("character must contain exactly the documented fields")
    if value["schema_version"] != SCHEMA_VERSION:
        raise ValueError("unsupported character schema_version")
    if not isinstance(value["id"], str) or not SLUG_RE.fullmatch(value["id"]):
        raise ValueError("id must be a lowercase hyphenated identifier")
    for key in ("name", "persona"):
        if not isinstance(value[key], str) or not value[key].strip():
            raise ValueError(f"{key} must be a non-empty string")
        if len(value[key]) > (120 if key == "name" else 500):
            raise ValueError(f"{key} is too long")
    for key in ("min_rarity", "max_rarity"):
        if value[key] not in RARITY_INDEX:
            raise ValueError(f"{key} must be one of: {', '.join(RARITIES)}")
    if RARITY_INDEX[value["min_rarity"]] > RARITY_INDEX[value["max_rarity"]]:
        raise ValueError("min_rarity cannot be higher than max_rarity")
    if not isinstance(value["adult_content_eligible"], bool):
        raise ValueError("adult_content_eligible must be a boolean")


def _validate_message(value: Any) -> None:
    required = {"id", "character_id", "category", "style", "rarity", "severity", "text"}
    if not isinstance(value, dict) or set(value) != required:
        raise ValueError("message must contain exactly the documented fields")
    for key in ("id", "character_id"):
        if not isinstance(value[key], str) or not SLUG_RE.fullmatch(value[key]):
            raise ValueError(f"{key} must be a lowercase hyphenated identifier")
    if value["category"] not in CATEGORIES:
        raise ValueError(f"category must be one of: {', '.join(CATEGORIES)}")
    if value["style"] not in STYLES:
        raise ValueError(f"style must be one of: {', '.join(STYLES)}")
    if value["rarity"] not in RARITY_INDEX:
        raise ValueError(f"rarity must be one of: {', '.join(RARITIES)}")
    if value["severity"] not in SEVERITIES:
        raise ValueError(f"severity must be one of: {', '.join(SEVERITIES)}")
    text = value["text"]
    if not isinstance(text, str) or not text.strip() or len(text) > 1000:
        raise ValueError("text must be a non-empty string of at most 1000 characters")
    if any(ord(char) < 32 or ord(char) == 127 for char in text):
        raise ValueError("text must be a single line without control characters")
    unknown = set(PLACEHOLDER_RE.findall(text)) - ALLOWED_PLACEHOLDERS
    if unknown:
        raise ValueError(f"unsupported template placeholders: {', '.join(sorted(unknown))}")


def _validate_collection(value: Any) -> None:
    if not isinstance(value, dict) or set(value) != {"schema_version", "id", "messages"}:
        raise ValueError("collection must contain exactly schema_version, id, and messages")
    if value["schema_version"] != SCHEMA_VERSION:
        raise ValueError("unsupported collection schema_version")
    if not isinstance(value["id"], str) or not SLUG_RE.fullmatch(value["id"]):
        raise ValueError("collection id must be a lowercase hyphenated identifier")
    if not isinstance(value["messages"], list) or not value["messages"]:
        raise ValueError("messages must be a non-empty array")
    seen: set[str] = set()
    for message in value["messages"]:
        _validate_message(message)
        if message["id"] in seen:
            raise ValueError(f"duplicate message id in collection: {message['id']}")
        seen.add(message["id"])


def load_catalog(
    repo_root: Path,
    config_home: Path | None = None,
    include_user: bool = True,
) -> dict[str, Any]:
    """Load tracked defaults first, then private/user collections.

    Character IDs are first-wins so private data cannot silently weaken a
    built-in character's eligibility. Message IDs are last-wins so custom
    collections can intentionally replace a default message.
    """
    repo_messages = repo_root / "messages"
    characters: dict[str, dict[str, Any]] = {}
    messages: dict[str, dict[str, Any]] = {}
    issues: list[str] = []
    character_sources = [
        (repo_messages / "characters", False),
        (repo_messages / "characters" / "private", True),
    ]
    collection_sources = [
        (repo_messages / "collections", False),
        (repo_messages / "collections" / "private", True),
    ]
    if include_user:
        config_home = config_home or Path(
            os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")
        )
        user_messages = config_home / "dots" / "messages"
        character_sources.append((user_messages / "characters", True))
        # Imported collections load first; deliberate personal collections
        # are the final override layer.
        collection_sources.extend([
            (user_messages / "imported", True),
            (user_messages / "collections", True),
        ])

    for directory, recursive in character_sources:
        for path in _json_files(directory, recursive):
            try:
                character = _read_json(path)
                _validate_character(character)
                character_id = character["id"]
                if character_id in characters:
                    issues.append(f"{path}: duplicate character '{character_id}'; first definition kept")
                    continue
                characters[character_id] = character
            except (OSError, UnicodeError, json.JSONDecodeError, ValueError, KeyError, TypeError) as exc:
                issues.append(f"{path}: {exc}")

    for directory, recursive in collection_sources:
        for path in _json_files(directory, recursive):
            try:
                collection = _read_json(path)
                _validate_collection(collection)
                for message in collection["messages"]:
                    messages[message["id"]] = message
            except (OSError, UnicodeError, json.JSONDecodeError, ValueError, KeyError, TypeError) as exc:
                issues.append(f"{path}: {exc}")

    valid_messages: dict[str, dict[str, Any]] = {}
    for message_id, message in messages.items():
        character = characters.get(message["character_id"])
        if character is None:
            issues.append(f"message '{message_id}' references unknown character '{message['character_id']}'")
            continue
        if message["style"] == "ecchi" and not character["adult_content_eligible"]:
            issues.append(f"message '{message_id}' uses ecchi style for an ineligible character")
            continue
        valid_messages[message_id] = message

    return {"characters": characters, "messages": valid_messages, "issues": issues}


def roll_rarity(rng: random.Random | random.SystemRandom) -> str:
    """Rarity chances use basis points (100 = 1%); higher tiers take priority."""
    chances = [
        ("mythic", _safe_int(os.environ.get("DOTS_FAILURE_MYTHIC_CHANCE"), 10, 10000)),
        ("legendary", _safe_int(os.environ.get("DOTS_FAILURE_LEGENDARY_CHANCE"), 100, 10000)),
        ("epic", _safe_int(os.environ.get("DOTS_FAILURE_RARITY_EPIC_CHANCE"), 0, 10000)),
        ("rare", _safe_int(os.environ.get("DOTS_FAILURE_RARITY_RARE_CHANCE"), 0, 10000)),
        ("uncommon", _safe_int(os.environ.get("DOTS_FAILURE_RARITY_UNCOMMON_CHANCE"), 0, 10000)),
    ]
    total = 0
    roll = rng.randrange(10000)
    for rarity, chance in chances:
        total += min(chance, 10000 - total)
        if roll < total:
            return rarity
        if total >= 10000:
            break
    return "common"


def roll_style(rng: random.Random | random.SystemRandom) -> str:
    rainbow_raw = os.environ.get("DOTS_FAILURE_RAINBOW_CHANCE")
    if rainbow_raw is None:
        rainbow_raw = os.environ.get("DOTS_FAILURE_RARE_CHANCE")
    rainbow_chance = _safe_int(rainbow_raw, 2, 100)
    roll = rng.randrange(100)
    if roll < rainbow_chance or rainbow_chance >= 100:
        return "rainbow"
    # Preserve the existing 48/28/14/8 distribution after reserving Rainbow.
    style_roll = (roll - rainbow_chance) * 98 // (100 - rainbow_chance)
    if style_roll < 48:
        style = "normal"
    elif style_roll < 76:
        style = "anime"
    elif style_roll < 90:
        style = "sarcastic"
    else:
        style = "dramatic"
    if style == "anime" and rng.randrange(100) < 65:
        return "ecchi"
    return style


def choose_style_and_rarity(rng: random.Random | random.SystemRandom) -> tuple[str, str]:
    requested = os.environ.get("DOTS_FAILURE_STYLE", "auto").lower()
    # Keep the old preview tokens as environment-variable aliases, not as
    # message styles. Rarity and content style remain separate data fields.
    if requested in ("legendary", "mythic"):
        return "normal", requested
    if requested not in ("auto", *STYLES):
        requested = "auto"
    if requested != "auto":
        return requested, "common"
    rarity = roll_rarity(rng)
    if rarity in ("uncommon", "rare", "epic", "legendary", "mythic"):
        return "normal", rarity
    return roll_style(rng), rarity


def _render_text(template: str, command: str, username: str) -> str:
    def clean(value: str) -> str:
        return "".join(" " if ord(char) < 32 or ord(char) == 127 else char for char in value)
    return template.replace("{command}", clean(command)).replace("{username}", clean(username))


def select_message(
    catalog: dict[str, Any],
    category: str,
    command: str,
    username: str,
    streak: int = 1,
    rng: random.Random | random.SystemRandom | None = None,
    avoid_id: str = "",
) -> dict[str, str]:
    rng = rng or random.SystemRandom()
    style, rarity = choose_style_and_rarity(rng)
    severity = "severe" if streak >= 3 else "repeat" if streak == 2 else "base"
    selected = [
        message for message in catalog["messages"].values()
        if message["style"] == style and message["rarity"] == rarity
        and message["category"] in (category, "any")
        and (style != "normal" or message["severity"] == severity)
    ]
    if not selected and style == "normal" and severity != "base":
        selected = [
            message for message in catalog["messages"].values()
            if message["style"] == style and message["rarity"] == rarity
            and message["category"] in (category, "any") and message["severity"] == "base"
        ]
    exact = [message for message in selected if message["category"] == category]
    if exact:
        selected = exact

    eligible: dict[str, list[dict[str, Any]]] = {}
    for message in selected:
        character_id = message["character_id"]
        character = catalog["characters"].get(character_id)
        if character is None:
            continue
        low = RARITY_INDEX[character["min_rarity"]]
        high = RARITY_INDEX[character["max_rarity"]]
        if not low <= RARITY_INDEX[rarity] <= high:
            continue
        if style == "ecchi" and not character["adult_content_eligible"]:
            continue
        eligible.setdefault(character_id, []).append(message)
    if not eligible:
        raise CatalogError(f"no eligible message for category={category}, style={style}, rarity={rarity}")

    # Select the character before selecting one of that character's messages.
    # Prefer speakers with an alternative to the previous line when possible.
    character_ids = sorted(eligible)
    alternatives = [
        character_id for character_id in character_ids
        if any(item["id"] != avoid_id for item in eligible[character_id])
    ]
    if alternatives:
        character_ids = alternatives
    character_id = rng.choice(character_ids)
    candidates = eligible[character_id]
    not_repeated = [item for item in candidates if item["id"] != avoid_id]
    if not_repeated:
        candidates = not_repeated
    message = rng.choice(candidates)
    return {
        "style": style,
        "rarity": rarity,
        "character_id": character_id,
        "character_name": catalog["characters"][character_id]["name"],
        "message_id": message["id"],
        "text": _render_text(message["text"], command, username),
    }


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="action", required=True)
    validate = subparsers.add_parser("validate", help="validate repository and personal message data")
    validate.add_argument("--repo-only", action="store_true")
    select = subparsers.add_parser("select", help="select one message")
    select.add_argument("--category", required=True)
    select.add_argument("--command", default="unknown")
    select.add_argument("--username", default=os.environ.get("USER", "user"))
    select.add_argument("--streak", type=int, default=1)
    select.add_argument("--avoid-id", default="")
    args = parser.parse_args()

    try:
        catalog = load_catalog(_repo_root(), include_user=not getattr(args, "repo_only", False))
        if args.action == "validate":
            if catalog["issues"]:
                for issue in catalog["issues"]:
                    print(f"error: {issue}", file=sys.stderr)
                return 1
            print(f"Validated {len(catalog['characters'])} characters and {len(catalog['messages'])} messages.")
            return 0
        if catalog["issues"] and os.environ.get("DOTS_FAILURE_DEBUG") == "1":
            for issue in catalog["issues"]:
                print(f"dots failure messages: {issue}", file=sys.stderr)
        category = args.category if args.category in CATEGORIES else "generic"
        result = select_message(
            catalog, category, args.command, args.username, max(1, args.streak),
            avoid_id=args.avoid_id,
        )
        print(result["style"])
        print(result["rarity"])
        print(result["character_id"])
        print(result["message_id"])
        print(result["text"])
        return 0
    except (CatalogError, OSError, ValueError) as exc:
        print(f"dots failure messages: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
