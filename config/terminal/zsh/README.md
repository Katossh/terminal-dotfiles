# Zsh configuration

The detailed setup and recovery instructions live in [docs/ZSH.md](../../../docs/ZSH.md). Use [docs/TROUBLESHOOTING.md](../../../docs/TROUBLESHOOTING.md) when the framework or a plugin is missing.
The entry point is `dots/zshenv`. It sets XDG paths and `ZDOTDIR=$XDG_CONFIG_HOME/zsh`, so Zsh loads its startup files from this directory rather than directly from `~`. The interactive setup uses Oh My Zsh as the framework and plugin loader, while Starship remains the prompt provider.

## Files
- `.zshrc` — interactive shell setup, history, options, Oh My Zsh plugins, completion extensions, failure diagnostics, Starship, and optional automatic tmux startup.
- `aliases.zsh` — command aliases and the FZF/Neovim file preview helper.
- `completion.zsh` — completion matching rules and cache settings; Oh My Zsh runs `compinit` once using an XDG cache file.
- `command-state.zsh` — keeps the most recently completed command and exit status in shell memory.
- `failure-classifier.zsh`, `failure-messages.zsh`, `failure-message-engine.py`, `failure-animation.zsh`, and `handlers.zsh` — classify failures, load JSON message collections, select by rarity/style/character, and render notices with non-blocking animations.
- `command-suggestions.zsh` — caches command candidates and delegates fuzzy ranking to `dots-suggest` when available, with a pure-Zsh fallback.
- `diagnostics.zsh` — provides `why` and `why --verbose` without rerunning the previous command.
- `prompt.zsh` — initializes Starship; the appearance is configured in `config/starship.toml`.

## Oh My Zsh and plugins

Run `./bin/dots install` to install the framework and its external plugins. Third-party repositories are cloned outside the dotfiles checkout, under XDG data paths:

| Component | Source |
|---|---|
| Oh My Zsh framework | `$XDG_DATA_HOME/oh-my-zsh` |
| Custom plugins | `$XDG_DATA_HOME/zsh/custom/plugins/` |

The active plugins are:
- `git` and `z` — built into Oh My Zsh.
- `zsh-autosuggestions` — provided by Oh My Zsh itself.
- `fzf-tab` — installed as an Oh My Zsh custom plugin.
- `fast-syntax-highlighting` — installed as a custom plugin and loaded last.
- `zsh-completions` — installed as a custom completion source. Its `src` directory is added to `fpath` before Oh My Zsh runs `compinit`; it must not be loaded as a regular plugin.

The plugin order is intentional: `fzf-tab` must load after `compinit`, but before plugins that wrap ZLE widgets, including autosuggestions and syntax highlighting. Oh My Zsh is not auto-updated at shell startup. Update the framework and custom plugins with `git -C <path> pull --ff-only`.

Downloads can be skipped for offline/config-only setups with `DOTS_SKIP_DOWNLOADS=1`; in that case the shell falls back to native Zsh completion until the framework is installed. The installer preserves existing directories with unknown Git origins rather than overwriting them.

## Dependencies

The setup requires `zsh`, Starship, `git`, `fzf`, `bat`, `nvim`, and `tmux`. Starship is initialized by `prompt.zsh` and reads the linked `config/starship.toml`. On NixOS, the imported `nix/packages.nix` module also builds and installs the Rust `dots-suggest` command-ranking helper. Other systems retain a pure-Zsh fallback; the helper can be built with `cargo build --release --manifest-path rust/dots-suggest/Cargo.toml`.

## Portability and local settings
- `dots/zshenv` contains shared defaults only. Keep passwords, API tokens, private keys, and machine-specific credentials out of tracked files.
- `BROWSER`, `TERMINAL`, `EDITOR`, personal directories, and optional tool paths may need local overrides.
- Starship configuration is tracked in `config/starship.toml` and linked into the XDG config directory by the installer.
- For WSL, disable automatic tmux startup in `.zshrc` if each new Windows Terminal tab should not enter tmux automatically.
