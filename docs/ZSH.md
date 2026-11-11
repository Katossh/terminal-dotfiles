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
8. failure-animation.zsh — registers after Starship and inserts a style-aware animated emoji immediately before the final input prompt marker (❯ by default).

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

The first interactive Zsh prompt plays one 24-frame emoji animation (~3.4 seconds), even before any command has failed, using the shared reaction pool. Later failure notices trigger another animation on the configured 50% chance. Normal, sarcastic, and dramatic messages share the general pool; Anime, Ecchi, and Rainbow each use a dedicated pool. The final resolved message style is passed to the animation, including automatic Anime-to-Ecchi selection. Each frame is sampled randomly from that style's pool without repeating the immediately previous frame. Frames are delivered to ZLE through an asynchronous file-descriptor watcher, so typing and cursor movement remain responsive.

The animation pools are:

| Message style | Emoji pool |
|---|---|
| Normal / Sarcastic / Dramatic | 👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 |
| Anime | 😭 🥰 🥺 💖 💗 💓 💕 |
| Ecchi | 😏 🫠 ❤️ 🩷 💘 |
| Rainbow | 🧡 💛 💚 💙 🤍 |

The animation is just the changing emoji inserted immediately before the final Starship input marker (❯ by default). It never modifies the directory/path line and adds no side bars, decorative stars, text, or colour codes. RPROMPT remains untouched. Prompts without the configured marker are left unchanged rather than placing the emoji somewhere unexpected. When the one-shot stream finishes, its last emoji remains visible until another animation replaces it. Pressing Enter during a sequence cancels the remaining frames but preserves the latest emoji. Animations only run in an interactive TTY; redirected output, CI, and TERM=dumb remain unaffected.

Set DOTS_FAILURE_EMOJI_ANIMATION_INFINITE=1 # accepts 1, true, yes, on; old DOTS_FAILURE_ANIMATION_CONTINUOUS remains an alias to loop the emoji animation for as long as the prompt is idle. The stream is stopped when you press Enter and starts again at the next prompt, so it does not continue running while a command executes. Set it to 0 to return to the normal one-shot startup and failure-triggered animations. Accepted true values are 1, true, yes, and on (case-insensitive). The master switch DOTS_FAILURE_ANIMATION=0 disables all animation, including continuous mode, without disabling failure messages.

Optional overrides:

~~~sh
# Force a style while previewing or disable style randomization.
DOTS_FAILURE_STYLE=anime # auto, normal, anime, ecchi, sarcastic, dramatic, rainbow, legendary, mythic

# Change probabilities.
DOTS_FAILURE_LEGENDARY_CHANCE=2 # 0..100; DOTS_FAILURE_RAINBOW_CHANCE and DOTS_FAILURE_RARE_CHANCE are aliases
DOTS_FAILURE_MYTHIC_CHANCE=1 # 0..1000 per mille; default 1 = 0.1%
DOTS_FAILURE_ANIMATION_CHANCE=50

# Loop the emoji animation while the prompt is idle.
DOTS_FAILURE_EMOJI_ANIMATION_INFINITE=1 # DOTS_FAILURE_ANIMATION_CONTINUOUS remains a backwards-compatible alias

# Change the prompt marker the emoji is inserted before (default: ❯).
DOTS_FAILURE_ANIMATION_PROMPT_MARKER='❯'

# Disable every animation without disabling failure messages.
DOTS_FAILURE_ANIMATION=0

# Respect NO_COLOR; redirected output is plain regardless.
NO_COLOR=1
~~~

DOTS_FAILURE_RARE_CHANCE remains supported as a backwards-compatible alias for DOTS_FAILURE_RAINBOW_CHANCE. DOTS_FAILURE_MESSAGE_CHANCE still controls whether a notice is shown at all, and repeat escalation remains independently configurable through DOTS_FAILURE_MESSAGE_ESCALATION.

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
