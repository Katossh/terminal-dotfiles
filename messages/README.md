# Failure-message data

The interactive failure handler remains in Zsh, but the message catalogue is data-driven.
The Python selector loads JSON, rolls rarity, resolves an eligible character, and chooses
one of that character's messages. The shell continues to own command capture, sanitisation,
colour, animation, and terminal output.

## Layout

- `schema/character.schema.json` and `schema/collection.schema.json`: versioned JSON schemas.
- `characters/*.json`: shared character pool; each file defines one character.
- `collections/*.json`: message collections. The tracked `default.json` is the baseline.
- `examples/`: templates for new characters and collections. These files are not loaded.

Private repository-local files may be placed under `characters/private/` and
`collections/private/`; Git ignores only those two directories. Prefer the user's
configuration directory for private or imported material:

```text
$XDG_CONFIG_HOME/dots/messages/
├── characters/
├── collections/
└── imported/
```

When `XDG_CONFIG_HOME` is unset, the default is `~/.config`.

## Character definition

A character has an ID, display name, persona description, inclusive rarity bounds,
and an adult-content eligibility flag. The persona describes the intended voice; messages
are authored text rather than generated at runtime.

Character IDs are first-definition-wins. A personal file cannot silently replace a
built-in profile or loosen its eligibility; create a new ID for a custom character.

## Message definition

Every message has:

- `id`: globally unique message identifier; a later personal collection with the same ID overrides the earlier text.
- `character_id`: the speaker from the shared character pool.
- `category`: a failure category or `any` for a shared style pool.
- `style`: `normal`, `anime`, `ecchi`, `sarcastic`, `dramatic`, or `rainbow`. Legendary and Mythic belong exclusively to the rarity field.
- `rarity`: `common`, `uncommon`, `rare`, `epic`, `legendary`, or `mythic`.
- `severity`: `base`, `repeat`, or `severe`; escalation is used by the normal style.
- `text`: one line of text. The supported placeholders are `{command}` and `{username}`.

There is no `explicit` message field. Style and adult-content eligibility are separate
concepts: an `ecchi` message is eligible only when its character profile sets
`adult_content_eligible` to `true`. The loader rejects Ecchi messages assigned to an
ineligible character. Marin Kitagawa's built-in profile is non-sexual and cannot be
overridden by a personal file with the same ID.

## Selection order

1. Decide rarity first (Mythic, Legendary, Epic, Rare, Uncommon, then Common).
2. Choose a content style for that rarity; explicit `DOTS_FAILURE_STYLE` values remain useful for previews. The legacy `legendary` and `mythic` environment values force a rarity but are not message styles.
3. Build the eligible character set from rarity bounds, style restrictions, and available messages.
4. Select a character, then select one message belonging to that character.
5. Prefer a different message from the immediately previous one; apply the existing escalation tier.

The default automatic Common style distribution remains 48% Normal, 28% Anime,
14% Sarcastic, 8% Dramatic, with the configured Rainbow share reserved separately.
As before, 65% of automatic Anime rolls are converted to the Ecchi style. Only adult-eligible
characters can speak those messages.

## Validation

From the repository root:

```sh
python3 config/terminal/zsh/failure-message-engine.py validate --repo-only
python3 tests/test-failure-message-engine.py
```

For local authoring, run `validate` without `--repo-only` to include personal and imported
collections. Malformed files are ignored at runtime; set `DOTS_FAILURE_DEBUG=1` to print
loader diagnostics. Message IDs from personal/imported collections override matching
default IDs without editing tracked defaults.
