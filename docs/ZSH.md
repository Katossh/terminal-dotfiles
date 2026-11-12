# Zsh configuration

## Startup layout

The zshenv file is linked to ~/.zshenv. It defines XDG paths, sets ZDOTDIR=$XDG_CONFIG_HOME/zsh, and discovers the dotfiles checkout. Interactive startup then reads:

1. .zshrc — PATH, history, options, Oh My Zsh and plugin initialization, module loading, Starship, and optional tmux startup.
2. aliases.zsh and completion.zsh — aliases, interactive helpers, completion matching, and cache styles.
3. command-state.zsh — records the last completed command, its status, working directory, and expanded form.
4. failure-classifier.zsh and failure-messages.zsh — conservatively classify failures and render one notice per failed command.
5. command-suggestions.zsh and diagnostics.zsh — offer safe typo candidates and provide why / why --verbose without rerunning the previous command.
6. handlers.zsh — reports each failed command once and runs a typo correction only after explicit confirmation.
7. prompt.zsh — Starship initialization (or a simple fallback prompt when Starship is unavailable).
8. failure-animation.zsh — registers after Starship, animates ordinary emoji before the input marker, and paints Legendary/Mythic gradients in place at the original failure-output location.

The framework, plugins, history and completion caches stay outside the Git checkout.

## Runtime framework and plugins

The installer manages these upstream checkouts under XDG_DATA_HOME:

| Component | Runtime path | Purpose |
|---|---|---|
| Oh My Zsh | oh-my-zsh/ | Plugin loader and built-in plugins |
| git | oh-my-zsh/plugins/git/ | Git aliases and completions |
| z | oh-my-zsh/plugins/z/ | Directory-jump history |
| zsh-autosuggestions | oh-my-zsh/plugins/zsh-autosuggestions/ | Fish-like command suggestions |
| fzf-tab | zsh/custom/plugins/fzf-tab/ | Fuzzy completion menus |
| fast-syntax-highlighting | zsh/custom/plugins/fast-syntax-highlighting/ | Syntax highlighting while typing |
| zsh-completions | zsh/custom/plugins/zsh-completions/ | Additional completion definitions |

git, z, and zsh-autosuggestions are shipped within the Oh My Zsh repository. The other three repositories are cloned separately into its custom plugin area.

## Loading order

The order in .zshrc is intentional:

- zsh-completions/src is prepended to fpath before Oh My Zsh initializes completion.
- Oh My Zsh runs compinit and loads git and z.
- fzf-tab is loaded before ZLE widget wrappers.
- zsh-autosuggestions is enabled when present.
- fast-syntax-highlighting is loaded last so it can wrap widgets installed by earlier plugins.

The disabled zsh-manydots-magic experiment is not part of the active setup.

## Failure messages

Failed commands receive randomized, data-driven notices. Zsh still captures command state,
classifies failures, sanitises terminal input, and handles rendering. The Python standard-library
selector loads JSON character profiles and message collections, rolls rarity, chooses an eligible
character, and selects one of that character's messages. Python 3 is already a required package.

Message data lives in the repository's top-level `messages/` directory. See
[`messages/README.md`](../messages/README.md) for the schemas, character and collection formats,
private overrides, precedence rules, and validation commands.

### Selection order

1. Roll rarity first: Common, Uncommon, Rare, Epic, Legendary, or Mythic.
2. Choose a style for the rolled rarity. Explicit `DOTS_FAILURE_STYLE` values remain available for previews.
3. Filter the shared character pool by inclusive rarity bounds and content eligibility.
4. Select an eligible character, then select one message belonging to that character.
5. Apply repeat escalation and anti-repeat selection, then pass the selected message to the renderer.

The default automatic Common style distribution remains 48% Normal, 28% Anime,
14% Sarcastic, and 8% Dramatic, with the configured Rainbow share reserved separately.
As before, 65% of automatic Anime selections are converted to Ecchi. Ecchi messages can
only be selected for characters whose profile has `adult_content_eligible: true`.
Marin Kitagawa's built-in profile is non-sexual, and personal files cannot override the
eligibility of a built-in character.

The first interactive Zsh prompt still plays one 12-frame emoji animation (~1 second),
even before any command has failed. Failure messages animate their actual text with a moving
24-bit colour gradient: Legendary uses metallic gold, Mythic uses charcoal-to-silver, Rainbow
sweeps through the spectrum, Anime and Ecchi use pink/violet palettes, and everyday styles use
a restrained Catppuccin-inspired gradient. Legendary and Mythic always animate; other styles
use `DOTS_FAILURE_ANIMATION_CHANCE` (default 100%). The effect is rendered synchronously at
the message's output position by repainting the same terminal rows, then leaves the final
coloured text as ordinary selectable output. There is no Kitty image overlay, background
animation process, or persistent screen placement. The renderer works in Kitty, Alacritty,
tmux, and other ANSI-compatible terminals without ImageMagick. Set
`DOTS_FAILURE_GRADIENT_INTERVAL` to change the frame delay; set `DOTS_FAILURE_ANIMATION=0`
or `NO_COLOR` to disable coloured animation. Normal, sarcastic, and dramatic messages share
the general reaction pool; Anime, Ecchi, and Rainbow each use a dedicated emoji pool. The
independent prompt emoji animation continues to use an asynchronous ZLE file-descriptor watcher.

The animation pools are:

| Message style | Emoji pool |
|---|---|
| Normal / Sarcastic / Dramatic | 👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠 |
| Anime | 😭 🥰 🥺 💖 💗 💓 💕 |
| Ecchi | 😏 ❤️ 🩷 💘 |
| Rainbow | 🧡 💛 💚 💙 🤍 |

### Environment variables

| Variable | Default | Meaning |
|---|---:|---|
| `DOTS_FAILURE_STYLE` | `auto` | `auto`, `normal`, `anime`, `ecchi`, `sarcastic`, `dramatic`, `rainbow`, `legendary`, or `mythic`. Explicit styles bypass automatic rarity/style rolls. |
| `DOTS_FAILURE_MESSAGE_CHANCE` | `100` | Percentage chance (0–100) that a failure notice is shown. |
| `DOTS_FAILURE_RAINBOW_CHANCE` | `2` | Percentage chance (0–100) for automatic Rainbow style. `DOTS_FAILURE_RARE_CHANCE` remains a legacy alias for this setting. |
| `DOTS_FAILURE_MYTHIC_CHANCE` | `10` | Mythic rarity chance in basis points; 10 = 0.1%. |
| `DOTS_FAILURE_LEGENDARY_CHANCE` | `100` | Legendary rarity chance in basis points; 100 = 1%. |
| `DOTS_FAILURE_RARITY_EPIC_CHANCE` | `0` | Epic rarity chance in basis points. |
| `DOTS_FAILURE_RARITY_RARE_CHANCE` | `0` | Rare rarity chance in basis points; distinct from the legacy Rainbow alias. |
| `DOTS_FAILURE_RARITY_UNCOMMON_CHANCE` | `0` | Uncommon rarity chance in basis points. |
| `DOTS_FAILURE_ANIMATION_CHANCE` | `100` | Percentage chance (0–100) for in-place gradient animation on non-rare styles. |
| `DOTS_FAILURE_GRADIENT_INTERVAL` | `0.08` | Delay between message-gradient frames in seconds (valid range: 0.01–1.00). |
| `DOTS_FAILURE_ANIMATION_INTERVAL` | `0.08` | Delay between prompt emoji frames in seconds. |
| `DOTS_FAILURE_ANIMATION_INFINITE` | `0` | Set to `1`, `true`, `yes`, or `on` to loop ordinary prompt emoji animations while idle. |
| `DOTS_FAILURE_EMOJI_ANIMATION_INFINITE` | `0` | Compatibility alias for the earlier main-branch name. |
| `DOTS_FAILURE_ANIMATION_CONTINUOUS` | `0` | Older compatibility alias for Infinite mode. |
| `DOTS_FAILURE_ANIMATION_PROMPT_MARKER` | `❯` | Prompt character immediately after the ordinary animated emoji. |
| `DOTS_FAILURE_ANIMATION` | `1` | Set to `0` to disable message and prompt animation. |
| `DOTS_FAILURE_MESSAGE_ESCALATION` | `1` | Set to `0`, `false`, `no`, or `off` to disable repeat escalation. |
| `DOTS_FAILURE_DEBUG` | `0` | Set to `1` to print diagnostics for malformed or conflicting local message data. |
| `NO_COLOR` | unset | Disables ANSI colours and coloured message animation. |

Rarity chances use basis points (1 basis point = 0.01%). Higher rarities are rolled first;
the configured total is capped at 100%. The old `DOTS_FAILURE_RARE_CHANCE` name still
means Rainbow style probability; use `DOTS_FAILURE_RARITY_RARE_CHANCE` for the Rare tier.

## Command-not-found suggestions

The command-name candidate cache is built once and reused. It is invalidated when PATH changes or the number of registered shell functions changes. This avoids re-enumerating PATH and Zsh's large function table for every typo.

On NixOS, nix/packages.nix installs the dependency-free Rust dots-suggest helper automatically. The helper reads the cached candidate names from stdin, applies the existing one-edit / two-edit threshold and adjacent-transposition-aware optimal-string-alignment distance, then returns at most five candidates sorted by distance and name. The shell starts one small helper process per unknown command rather than running a Zsh function and dynamic-array edit-distance calculation for every candidate.

On other systems, the same cached candidate set is ranked by a pure-Zsh fallback. The Rust helper can also be built manually with:

~~~
cargo build --release --manifest-path rust/dots-suggest/Cargo.toml
~~~

The optional fzf process is started only after candidates have been prepared and the user is choosing one. A suggested command is never executed without a separate explicit confirmation.

## Installing or repairing

~~~
dots install --no-packages
dots health
~~~

This works even if the zsh executable is not currently installed or is absent from PATH. Git and GitHub connectivity are required. A failed required clone is reported as an error; the installer does not print a successful completion status in that case.

If the framework is missing when a shell starts, .zshrc uses native compinit as a fallback and prints the exact runtime path plus the repair command. It does not try to download code every time a shell opens.

## Updating

Automatic Oh My Zsh updates are disabled at shell startup to keep terminal startup deterministic. Update each runtime checkout explicitly:

~~~
git -C "$XDG_DATA_HOME/oh-my-zsh" pull --ff-only
git -C "$XDG_DATA_HOME/zsh/custom/plugins/fzf-tab" pull --ff-only
git -C "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting" pull --ff-only
git -C "$XDG_DATA_HOME/zsh/custom/plugins/zsh-completions" pull --ff-only
~~~

zsh-autosuggestions is updated with the Oh My Zsh checkout because it is included there.

## Shared Nix development environment

The dev alias enters the general-purpose development shell exported by
Katossh/shiny-rotary-phone. It uses the public main branch flake, so it
works from any current directory and does not require a local clone of that
repository:

~~~
dev
~~~

The command starts an interactive Nix development shell. Exit it with
exit or Ctrl-D. The first invocation may need to download the flake source
and toolchain from the configured Nix caches.

## Local customization

Do not modify runtime-managed upstream directories to customize the prompt or aliases. Put local configuration in ~/.config/zsh/zprofile.local or use the repository's personal override mechanism:

~~~
~/.config/dots/overrides/zsh/aliases.zsh
~~~

Keep private credentials and machine-specific values out of tracked files.
