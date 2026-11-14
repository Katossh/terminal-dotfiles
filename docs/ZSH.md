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
8. failure-animation.zsh — registers after Starship, animates ordinary emoji before the input marker, and prints the failure-gradient banner directly into terminal output as an autonomous scrollback message independent of the prompt.

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

Every failed command uses one stable message:

\`✖ Command "<command>" failed.\`

An optional diagnostic detail is displayed on the next line. The failure category is still classified internally for diagnostics, but it no longer selects different wording, random jokes, rarity tiers, or colour palettes.

On an interactive colour-capable terminal, this exact message is animated with a moving gradient for 25 frames. The banner is printed directly into terminal scrollback output — not embedded in the prompt string — so it remains in its original position in terminal history regardless of what the user does next.

The gradient uses dedicated 256-colour palette slots (OSC 4), one block of twelve slots per concurrent failure. A disowned background worker sends OSC 4 palette-update sequences to the terminal at the configured interval for 25 frames, then exits on its own. Because the colour definitions are updated in-place, the text characters stay exactly where they were printed and animate without any cursor movement or repaint. Up to five gradient messages can coexist simultaneously in scrollback, each using its own palette block.

Typing, cursor movement, command submission, and prompt redraws have no effect on the animation. Each worker terminates according to its own frame lifecycle. The same plain message is printed when animation is unavailable, when \`DOTS_FAILURE_ANIMATION=0\`, or when \`NO_COLOR\` is set.

`DOTS_FAILURE_MESSAGE_CHANCE=0` suppresses the notice. `DOTS_FAILURE_GRADIENT_INTERVAL` controls the delay between gradient frames. The ordinary prompt emoji animation remains a separate feature and keeps its own timing and Infinite-mode settings.

## Environment variables

| Variable | Default | Meaning |
|---|---:|---|
| \`DOTS_FAILURE_MESSAGE_CHANCE\` | \`100\` | Percentage chance (0–100) that the single failure notice is shown. |
| \`DOTS_FAILURE_GRADIENT_INTERVAL\` | \`0.08\` | Delay between failure-gradient frames in seconds (valid range: 0.01–1.00). |
| \`DOTS_FAILURE_ANIMATION_INTERVAL\` | \`0.08\` | Delay between ordinary prompt emoji frames in seconds (valid range: 0.01–2.00). |
| \`DOTS_FAILURE_ANIMATION_INFINITE\` | \`0\` | Set to \`1\`, \`true\`, \`yes\`, or \`on\` to loop ordinary emoji animations while the prompt is idle. Takes precedence over the older aliases below. |
| \`DOTS_FAILURE_EMOJI_ANIMATION_INFINITE\` | \`0\` | Compatibility alias for the earlier main-branch name; used only when the newer Infinite variable is unset. |
| \`DOTS_FAILURE_ANIMATION_CONTINUOUS\` | \`0\` | Older compatibility alias for Infinite mode; used only when both newer names are unset. |
| \`DOTS_FAILURE_ANIMATION_PROMPT_MARKER\` | \`❯\` | Prompt character immediately after the ordinary animated emoji. |
| \`DOTS_FAILURE_ANIMATION\` | \`1\` | Set to \`0\` to disable animation while keeping the plain failure notice. |
| \`NO_COLOR\` | unset | Disables ANSI colours and animated gradient output. |

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
