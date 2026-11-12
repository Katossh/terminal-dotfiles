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

## Failure message styles

Failed commands receive a short, randomized notice after the command completes. The default style weights are:

| Style | Chance |
|---|---:|
| Category-aware ordinary message | 48% |
| Anime-inspired family (including ecchi) | 28% |
| Sarcastic / meme message | 14% |
| Dramatic message | 8% |
| 24-bit rainbow message | 2% |

Messages now use a broader 24-bit RGB palette, with pink, rose, coral, orange, gold, lime, teal, sky blue, violet, and lavender accents. Emoji appear throughout the ordinary category-specific pools as well as the themed styles. The rainbow renderer uses twelve RGB colour stops and does not depend on lolcat or another external program.

The 28% anime share includes traditional anime archetypes and a separate ecchi pool with adult-coded, suggestive humour; 65% of automatic anime selections use that pool. It is deliberately non-explicit and does not use school-age characters. You can force it with DOTS_FAILURE_STYLE=ecchi.

The first interactive Zsh prompt plays one 12-frame emoji animation (~1 second), even before any command has failed. Later ordinary failure notices trigger another emoji animation on the configured 50% chance. Legendary and Mythic failures bypass that chance and start a continuously moving gradient banner at the exact terminal output position where the failure notice is printed. Legendary sweeps a metallic gold gradient from left to right; Mythic uses a charcoal-to-silver gradient rather than rainbow colours. The banner is printed once, then its characters are repainted in place using terminal cursor save/restore; it is never inserted into subsequent prompts. Enter freezes its last frame at the original location so normal command output and scrollback can proceed without the animation chasing the current prompt. The notice remains in terminal history until it scrolls out of the viewport or the user clears the screen with `clear` or Ctrl+L. Normal, sarcastic, and dramatic messages share the general reaction pool; Anime, Ecchi, and Rainbow each use a dedicated pool. Frames are delivered through an asynchronous file-descriptor watcher, so typing and cursor movement remain responsive.

The animation pools are:

| Message style | Emoji pool |
|---|---|
| Normal / Sarcastic / Dramatic | 👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠 |
| Anime | 😭 🥰 🥺 💖 💗 💓 💕 |
| Ecchi | 😏 ❤️ 🩷 💘 |
| Rainbow | 🧡 💛 💚 💙 🤍 |



Ordinary animation remains a changing emoji inserted immediately before the final Starship input marker (❯ by default); it never modifies the directory/path line or touches RPROMPT. Legendary and Mythic instead render their complete message and optional detail at the original output position, above the prompt that follows the failure notice. Their gradients use true-colour ANSI spans without changing Kitty's global palette. Rare animation runs only in an interactive TTY. When ZLE animation is unavailable, the rare message falls back to a static gradient; when output is redirected or TERM=dumb, it remains plain text. Enter stops repainting and leaves the last frame in place; future prompts do not redraw or restart that banner. `clear` and Ctrl+L explicitly dismiss it. Once the terminal scrolls the notice out of the visible viewport, it remains a static entry in scrollback because standard terminal cursor addressing cannot animate rows that are no longer on screen.

## Environment variables

| Variable | Default | Meaning |
|---|---:|---|
| `DOTS_FAILURE_STYLE` | `auto` | Selects `auto`, `normal`, `anime`, `ecchi`, `sarcastic`, `dramatic`, `rainbow`, `legendary`, or `mythic`. Explicit rare styles force that style for previewing. |
| `DOTS_FAILURE_MESSAGE_CHANCE` | `100` | Percentage chance (0–100) that a failure notice is shown. |
| `DOTS_FAILURE_RAINBOW_CHANCE` | `2` | Percentage chance (0–100) for the automatic Rainbow style. `DOTS_FAILURE_RARE_CHANCE` remains a legacy alias. |
| `DOTS_FAILURE_LEGENDARY_CHANCE` | `100` | Automatic Legendary chance in basis points: 100 = 1%. |
| `DOTS_FAILURE_MYTHIC_CHANCE` | `10` | Automatic Mythic chance in basis points: 10 = 0.1%. Mythic is rolled before Legendary; the combined rare-event chance is capped at 100%. |
| `DOTS_FAILURE_ANIMATION_CHANCE` | `50` | Percentage chance (0–100) that an ordinary failure notice triggers an emoji animation. Legendary/Mythic gradients bypass this setting. |
| `DOTS_FAILURE_ANIMATION_INTERVAL` | `0.08` | Delay between animation frames in seconds (valid range: 0.01–2.00). |
| `DOTS_FAILURE_ANIMATION_INFINITE` | `0` | Set to `1`, `true`, `yes`, or `on` to loop ordinary emoji animations while the prompt is idle. Takes precedence over the older aliases below. |
| `DOTS_FAILURE_EMOJI_ANIMATION_INFINITE` | `0` | Compatibility alias for the earlier main-branch name; used only when the newer Infinite variable is unset. |
| `DOTS_FAILURE_ANIMATION_CONTINUOUS` | `0` | Older compatibility alias for Infinite mode; used only when both newer names are unset. |
| `DOTS_FAILURE_ANIMATION_PROMPT_MARKER` | `❯` | Prompt character immediately after the ordinary animated emoji. |
| `DOTS_FAILURE_ANIMATION` | `1` | Set to `0` to disable animation while keeping failure messages. Rare failures retain a static gradient. |
| `DOTS_FAILURE_MESSAGE_ESCALATION` | `1` | Set to `0`, `false`, `no`, or `off` to disable repeated-failure escalation. |
| `NO_COLOR` | unset | Disables ANSI colours, including the rare-event gradient. |

`DOTS_FAILURE_MESSAGE_CHANCE` controls whether a notice is shown at all. The Legendary and Mythic chance settings apply only when `DOTS_FAILURE_STYLE=auto`; explicitly selected styles are not replaced by rarity rolls.

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
